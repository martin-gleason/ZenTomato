import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// Tests for the only change this app can make to anybody's Todoist account.
///
/// **`noMutatingRequestsOtherThanClose` is the most important test in this
/// bundle.** The commit-time script reads the source and checks which addresses
/// appear in it; this runs a whole session and checks what the app actually
/// sent. One looks at the code, the other at the traffic, and the project cares
/// enough about this rule to want both.
///
/// The rest of the file is about the order of three steps, which is the contract
/// the local record depends on: ask Todoist, wait for confirmation, and only
/// then write anything down. A row claiming a completion that failed would be
/// worse than no row, because the value of the log is that its numbers mean what
/// they say.
///
/// `@MainActor`: everything that touches the database is.
@Suite("TaskCompletion")
@MainActor
struct TaskCompletionTests {
  private let container: ModelContainer

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  private var context: ModelContext {
    container.mainContext
  }

  // MARK: The request itself

  /// One request, addressed to the close command, carrying no body.
  ///
  /// The body matters as much as the address. Creating a task means sending one,
  /// so a client that never writes a body cannot become one that creates a task
  /// without somebody adding that ability on purpose.
  @Test("completeHitsCloseEndpoint")
  func completeHitsCloseEndpoint() async throws {
    let stub = StubTodoistTransport(answers: [.bare(status: 200)])
    let completion = TaskCompletion(context: context, client: Self.client(stub))

    let outcome = await completion.complete(taskID: "6XGgmFVcrG5RRjVr", titleSnapshot: "Draft the summary")

    #expect(outcome == .closed)
    #expect(stub.recordedRequests.count == 1)

    let request = try #require(stub.recordedRequests.first)
    #expect(request.httpMethod == TodoistAPI.Method.post.rawValue)
    #expect(request.httpBody == nil)
    // The expected address is built from the endpoint table rather than written
    // out, both because a Todoist address in a test is something the commit-time
    // check has to inspect, and because a copy here could agree with itself
    // while the table changed.
    #expect(request.url?.path() == Self.expectedPath(forClosing: "6XGgmFVcrG5RRjVr"))
    // A close carries no page parameters — those belong to reading.
    #expect(request.url?.query() == nil)
  }

  // MARK: The order of the three steps

  /// Nothing is written down until Todoist confirms.
  ///
  /// This is the test that fails the moment somebody moves the record above the
  /// request to make the button feel instant.
  @Test("completionRecordedOnlyAfterTodoistConfirms")
  func completionRecordedOnlyAfterTodoistConfirms() async throws {
    let failing = StubTodoistTransport(answers: [.failure(URLError(.notConnectedToInternet))])
    let offline = TaskCompletion(context: context, client: Self.client(failing))

    let refused = await offline.complete(taskID: "t1", titleSnapshot: "Draft the summary")
    let afterFailure = try Self.records(in: context)

    #expect(refused == .offline)
    #expect(afterFailure.isEmpty)

    let succeeding = StubTodoistTransport(answers: [.bare(status: 200)])
    let working = TaskCompletion(context: context, client: Self.client(succeeding))

    let confirmed = await working.complete(
      taskID: "t1",
      titleSnapshot: "Draft the summary",
      now: Date(timeIntervalSince1970: 1_000_000))
    let afterSuccess = try Self.records(in: context)

    #expect(confirmed == .closed)
    #expect(afterSuccess.count == 1)
    #expect(afterSuccess.first?.taskID == "t1")
    #expect(afterSuccess.first?.titleSnapshot == "Draft the summary")
    #expect(afterSuccess.first?.completedAt == Date(timeIntervalSince1970: 1_000_000))
  }

  /// A task that is already gone writes nothing.
  ///
  /// Todoist answers "no such task" when it was finished or removed somewhere
  /// else, and **the two cannot be told apart** — the address that would
  /// distinguish them is not one this app may call. So nothing is claimed and
  /// nothing is recorded: this app did not do it, and the log is a record of
  /// what this app did.
  @Test("alreadyGoneWritesNoRecord")
  func alreadyGoneWritesNoRecord() async throws {
    let stub = StubTodoistTransport(answers: [.bare(status: 404)])
    let completion = TaskCompletion(context: context, client: Self.client(stub))

    let outcome = await completion.complete(taskID: "t1", titleSnapshot: "Draft the summary")
    let records = try Self.records(in: context)

    #expect(outcome == .alreadyGone)
    #expect(records.isEmpty)
    #expect(stub.recordedRequests.count == 1)
  }

  /// A refused token is reported as such, and still writes nothing.
  @Test("tokenRejectedDuringCompletionWritesNoRecord")
  func tokenRejectedDuringCompletionWritesNoRecord() async throws {
    let tokens = InMemoryTokenStore()
    let stub = StubTodoistTransport(answers: [.bare(status: 401)])
    let completion = TaskCompletion(
      context: context,
      client: TodoistClient(transport: stub, tokens: tokens, waiting: RecordingRetryWaiting()))

    let outcome = await completion.complete(taskID: "t1", titleSnapshot: "Draft the summary")
    let records = try Self.records(in: context)

    #expect(outcome == .tokenRejected)
    #expect(records.isEmpty)
    #expect(tokens.holdsAToken == false)
  }

  // MARK: After a confirmed close

  /// A completed task leaves the local copy, so the picker stops offering it.
  ///
  /// This is the copy catching up early rather than a flag: the next full
  /// refresh would remove the row anyway, because Todoist's read addresses
  /// return open tasks only. There is no "completed" column anywhere, and a task
  /// that has gone is expressed by absence, exactly as it is in Todoist.
  @Test("completedTaskLeavesTheLocalCopy")
  func completedTaskLeavesTheLocalCopy() async throws {
    context.insert(CachedTask(
      id: "t1",
      content: "Draft the summary",
      projectID: "p1",
      sectionID: nil,
      childOrder: 0,
      syncedAt: .now))
    context.insert(CachedTask(
      id: "t2",
      content: "Reply to Anna",
      projectID: "p1",
      sectionID: nil,
      childOrder: 1,
      syncedAt: .now))
    try context.save()

    let stub = StubTodoistTransport(answers: [.bare(status: 200)])
    let completion = TaskCompletion(context: context, client: Self.client(stub))

    _ = await completion.complete(taskID: "t1", titleSnapshot: "Draft the summary")
    let remaining = try context.fetch(FetchDescriptor<CachedTask>())

    #expect(remaining.map(\.id) == ["t2"])
  }

  // MARK: The whole session

  /// A whole session's traffic, checked request by request.
  ///
  /// Connect, refresh everything, complete one task: eight requests, of which
  /// **exactly one is not a read, and that one is the close command**. Nothing
  /// about a plan, a search, a screen or a block can add a ninth of a different
  /// kind, because there is no other address in the app to send one to.
  @Test("noMutatingRequestsOtherThanClose")
  func noMutatingRequestsOtherThanClose() async throws {
    let stub = StubTodoistTransport(answers: [
      // Projects, over two pages, to prove paging adds only reads.
      .page(rows: [StubTodoistTransport.projectRow(id: "p1", name: "Deep work")], nextCursor: "more"),
      .page(rows: [StubTodoistTransport.projectRow(id: "p2", name: "Admin")]),
      // Sections.
      .page(rows: [StubTodoistTransport.sectionRow(id: "s1", name: "Doing", projectID: "p1")]),
      // Tasks.
      .page(rows: [
        StubTodoistTransport.taskRow(id: "t1", content: "Draft the summary", projectID: "p1", sectionID: "s1"),
        StubTodoistTransport.taskRow(id: "t2", content: "Reply to Anna", projectID: "p2")
      ]),
      // The one write.
      .bare(status: 200)
    ])
    let client = Self.client(stub)

    let cache = TodoistCacheStore(context: context, client: client)
    try await cache.refresh()

    let completion = TaskCompletion(context: context, client: client)
    let outcome = await completion.complete(taskID: "t1", titleSnapshot: "Draft the summary")
    #expect(outcome == .closed)

    #expect(stub.recordedRequests.count == 5)

    let writes = stub.requestsThatWereNotReads
    #expect(writes.count == 1)
    #expect(writes.first?.httpMethod == TodoistAPI.Method.post.rawValue)
    #expect(writes.first?.url?.path() == Self.expectedPath(forClosing: "t1"))
    #expect(writes.first?.httpBody == nil)

    // And every other request really was a read, rather than merely not a POST.
    let reads = stub.recordedRequests.filter { $0.httpMethod == TodoistAPI.Method.get.rawValue }
    #expect(reads.count == 4)
    #expect(reads.allSatisfy { $0.httpBody == nil })
  }

  // MARK: Helpers

  private static func client(_ transport: StubTodoistTransport) -> TodoistClient {
    TodoistClient(
      transport: transport,
      tokens: InMemoryTokenStore(),
      waiting: RecordingRetryWaiting())
  }

  /// The address a close is expected at, built from the endpoint table so the
  /// test cannot drift away from the app — or spell a Todoist address out in a
  /// file the commit-time check has to read.
  private static func expectedPath(forClosing id: String) -> String {
    TodoistAPI.baseURL.appending(path: TodoistAPI.closeTask(id: id).path).path()
  }

  private static func records(in context: ModelContext) throws -> [CompletedTaskRecord] {
    try context.fetch(FetchDescriptor<CompletedTaskRecord>(sortBy: [SortDescriptor(\.completedAt)]))
  }
}
