import Foundation
import Testing

@testable import ZenTomato

/// Tests for how the app reads a long list out of Todoist.
///
/// WHAT PAGING IS, AND THE TRAP IN IT
/// Todoist does not hand back five thousand tasks at once. It hands back a page
/// of them together with a marker meaning "ask again with this", and the list is
/// finished when there is no marker. **The number of rows on a page says nothing
/// about whether the list is finished** — Todoist's own documentation warns about
/// this specifically — and the tempting shortcut, "stop when a page comes back
/// smaller than we asked for", would silently drop the tail of a big account's
/// tasks. It would also do it invisibly: the picker would simply show fewer
/// tasks than Todoist has, with no error anywhere.
///
/// So there are three tests, and each one is a different way that loop could be
/// wrong: it could stop too early, it could ask again when it should not, or it
/// could never stop at all.
@Suite("TodoistPagination")
struct TodoistPaginationTests {
  // MARK: Following the marker

  /// Three pages, followed in order, with the marker sent back exactly as it
  /// arrived — and the first page deliberately short, because a short page must
  /// not be read as the end.
  @Test("paginationFollowsCursor")
  func paginationFollowsCursor() async throws {
    let stub = StubTodoistTransport(answers: [
      .page(rows: [Self.project("p1")], nextCursor: "cursor-one"),
      .page(rows: [Self.project("p2"), Self.project("p3")], nextCursor: "cursor-two"),
      .page(rows: [Self.project("p4")], nextCursor: nil)
    ])
    let client = Self.client(stub)

    let projects = try await client.fetchProjects()

    #expect(projects.map(\.id) == ["p1", "p2", "p3", "p4"])
    #expect(stub.recordedRequests.count == 3)

    // The first request carries no marker; the next two carry the previous
    // answer's, unaltered. The documentation is explicit that a marker must be
    // passed back as-is and never decoded or edited.
    #expect(Self.cursor(of: stub.recordedRequests[0]) == nil)
    #expect(Self.cursor(of: stub.recordedRequests[1]) == "cursor-one")
    #expect(Self.cursor(of: stub.recordedRequests[2]) == "cursor-two")

    // Every request asks for the documented maximum page size.
    for request in stub.recordedRequests {
      #expect(Self.limit(of: request) == String(TodoistAPI.pageSize))
    }

    // Reading is reading: not one of them is a write.
    #expect(stub.requestsThatWereNotReads.isEmpty)
  }

  // MARK: Stopping

  /// A page as full as the app asked for, with no marker, is the end — one
  /// request and no more.
  ///
  /// The mirror image of the test above: that one proves a short page does not
  /// stop the loop, and this proves a full page does not restart it. Between
  /// them the only thing deciding when to stop is the marker, which is what the
  /// documentation requires.
  @Test("paginationStopsOnNullCursor")
  func paginationStopsOnNullCursor() async throws {
    let fullPage = (0..<TodoistAPI.pageSize).map { Self.project("p\($0)") }
    let stub = StubTodoistTransport(answers: [.page(rows: fullPage, nextCursor: nil)])
    let client = Self.client(stub)

    let projects = try await client.fetchProjects()

    #expect(projects.count == TodoistAPI.pageSize)
    #expect(stub.recordedRequests.count == 1)
  }

  /// An empty marker is treated as no marker.
  ///
  /// The documented end is a null marker. An empty piece of text is not
  /// documented and would send the loop round again for a page that cannot
  /// exist, so it is treated as the end too.
  @Test("paginationStopsOnAnEmptyCursor")
  func paginationStopsOnAnEmptyCursor() async throws {
    let stub = StubTodoistTransport(answers: [.page(rows: [Self.project("p1")], nextCursor: "")])
    let client = Self.client(stub)

    let projects = try await client.fetchProjects()

    #expect(projects.count == 1)
    #expect(stub.recordedRequests.count == 1)
  }

  // MARK: Never stopping

  /// A server that keeps saying "there is more" is given up on, loudly.
  ///
  /// Without the ceiling this is not a slow refresh — it is a spinner that never
  /// goes away, with nothing on screen and nothing in any log to say why. The
  /// ceiling is far past any real account: 250 pages of 200 rows is fifty
  /// thousand tasks.
  @Test("paginationRefusesAnEndlessCursor")
  func paginationRefusesAnEndlessCursor() async throws {
    let stub = StubTodoistTransport(
      answers: [.page(rows: [Self.project("p1")], nextCursor: "always-more")],
      repeatingLastAnswer: true)
    let client = Self.client(stub)

    await #expect(throws: TodoistError.paginationDidNotTerminate) {
      _ = try await client.fetchProjects()
    }
    #expect(stub.recordedRequests.count == 250)
  }

  // MARK: Sections and tasks read the same way

  /// The three lists share one loop, so a fix to one is a fix to all three.
  /// This walks the other two to prove they really do.
  @Test("everyListFollowsTheSameLoop")
  func everyListFollowsTheSameLoop() async throws {
    let stub = StubTodoistTransport(answers: [
      .page(rows: [StubTodoistTransport.sectionRow(id: "s1", name: "Doing", projectID: "p1")],
            nextCursor: "more"),
      .page(rows: [StubTodoistTransport.sectionRow(id: "s2", name: "Done", projectID: "p1")]),
      .page(rows: [StubTodoistTransport.taskRow(id: "t1", content: "Draft the summary", projectID: "p1")])
    ])
    let client = Self.client(stub)

    let sections = try await client.fetchSections()
    let tasks = try await client.fetchTasks()

    #expect(sections.map(\.id) == ["s1", "s2"])
    #expect(sections.first?.sectionOrder == 0)
    #expect(tasks.map(\.content) == ["Draft the summary"])
    // A task loose in its project sends no section, and that is a permanent
    // fact about the task rather than a value waiting to be filled in.
    #expect(tasks.first?.sectionID == nil)
    #expect(stub.requestsThatWereNotReads.isEmpty)
  }

  // MARK: Helpers

  private static func client(_ transport: StubTodoistTransport) -> TodoistClient {
    TodoistClient(
      transport: transport,
      tokens: FakeTokenStore(),
      waiting: RecordingRetryWaiting())
  }

  private static func project(_ id: String) -> [String: Any] {
    StubTodoistTransport.projectRow(id: id, name: "Project \(id)")
  }

  private static func query(of request: URLRequest, named name: String) -> String? {
    guard let url = request.url,
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return nil
    }
    return components.queryItems?.first { $0.name == name }?.value
  }

  private static func cursor(of request: URLRequest) -> String? {
    query(of: request, named: "cursor")
  }

  private static func limit(of request: URLRequest) -> String? {
    query(of: request, named: "limit")
  }
}
