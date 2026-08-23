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
    let tokens = FakeTokenStore()
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

  // MARK: Being asked to slow down, on the one address that writes

  /// **ONE TAP IS ONE CLOSE, EVEN WHEN TODOIST SAYS "SLOW DOWN".**
  ///
  /// This is the test the feature's headline claim was missing. The client
  /// retries a rate-limited request once, which is right for a read — the answer
  /// is the same list either way. It used to do it for *every* request, and this
  /// address is a write: one tap on Complete produced two close commands against
  /// somebody's real account, unwatched, which is the exact thing the ratified
  /// design forbids in its own words. It is not harmless duplication either.
  /// Todoist's documentation for this address, quoted in `TodoistAPI`, says a
  /// recurring task is *"scheduled to its next occurrence"* — so closing twice
  /// silently advances it two occurrences, and the person sees one tap, one
  /// confirmation, one local record and a task that has skipped a day.
  ///
  /// The stub is scripted `[429 with a Retry-After, 200]`. A retrying client
  /// takes the second answer and reports success; the shipping one stops at the
  /// first, sends nothing more, and reports the refusal.
  @Test("oneTapOnCompleteIsOneCloseEvenWhenRateLimited")
  func oneTapOnCompleteIsOneCloseEvenWhenRateLimited() async throws {
    let waiting = RecordingRetryWaiting()
    let stub = StubTodoistTransport(answers: [
      .bare(status: 429, headers: ["Retry-After": "3"]),
      .bare(status: 200)
    ])
    let completion = TaskCompletion(
      context: context,
      client: TodoistClient(transport: stub, tokens: FakeTokenStore(), waiting: waiting))

    let outcome = await completion.complete(taskID: "t1", titleSnapshot: "Draft the summary")

    // ONE close command left the device. Not two.
    #expect(stub.requestsThatWereNotReads.count == 1)
    #expect(stub.recordedRequests.count == 1)

    // Nothing waited, because nothing was going to be sent again.
    #expect(waiting.requestedWaits.isEmpty)

    // It is reported as its own thing, with the wait Todoist named, so the sheet
    // can say how long rather than "try again in a moment".
    #expect(outcome == .rateLimited(retryAfter: .seconds(3)))

    // AND NOTHING WAS WRITTEN DOWN. The task is still open in Todoist.
    #expect(try Self.records(in: context).isEmpty)
  }

  /// The wording that goes with it names the wait, and the button stays live —
  /// tapping again is the retry, and it is the only one.
  @Test("aRateLimitedCompletionSaysHowLongAndStaysTappable")
  func aRateLimitedCompletionSaysHowLongAndStaysTappable() {
    let message = TaskCompletionSection.failureMessage(for: .rateLimited(retryAfter: .seconds(30)))

    #expect(message == "Todoist asked us to slow down, so the task is still open. Try again in 30 seconds.")
    #expect(TaskCompletionSection.control(after: .rateLimited(retryAfter: .seconds(30)), at: Date()) == .ready)

    // With no stated wait, no number is invented.
    let vague = TaskCompletionSection.failureMessage(for: .rateLimited(retryAfter: nil))
    #expect(vague == "Todoist asked us to slow down, so the task is still open. Try again shortly.")
  }

  // MARK: A credential that has stopped working

  /// A refused token switches the button off rather than leaving it live.
  ///
  /// The second tap was the problem. The control used to go back to `.ready`
  /// after a 401, but by then the credential has been taken out of the Keychain,
  /// so tapping again reached a client with nothing to send and came back as a
  /// generic failure — "try again in a moment", naming no cause, for something
  /// that can never succeed. Both paths now agree, and both say where to fix it.
  @Test("aRefusedTokenSwitchesTheButtonOffRatherThanLeavingItLive")
  func aRefusedTokenSwitchesTheButtonOffRatherThanLeavingItLive() async throws {
    let reconnect = "ZenTomato isn't connected to Todoist, so this can't be ticked off. Reconnect in Settings."

    // The first tap: Todoist refuses the token.
    let refused = TaskCompletionSection.control(after: .tokenRejected, at: Date())
    #expect(refused == .unavailable(reconnect))

    // The second tap, if the button were still live, reaches a client with no
    // credential. It reports the same cause rather than a nameless failure.
    let stub = StubTodoistTransport(answers: [])
    let completion = TaskCompletion(
      context: context,
      client: TodoistClient(
        transport: stub,
        tokens: FakeTokenStore(token: nil),
        waiting: RecordingRetryWaiting()))

    let outcome = await completion.complete(taskID: "t1", titleSnapshot: "Draft the summary")

    #expect(outcome == .tokenRejected)
    #expect(stub.recordedRequests.isEmpty)
    #expect(try Self.records(in: context).isEmpty)

    // And a sheet opening fresh with no credential says the same sentence.
    #expect(
      TaskCompletionSection.restingControl(
        hasToken: false,
        todoistIsReachable: true,
        taskIsInTodoist: .present) == .unavailable(reconnect))
  }

  // MARK: The identifier is the only part of an address that is not a constant

  /// An identifier that is not an opaque Todoist identifier makes no request.
  ///
  /// The close command is the one address in this app with anything substituted
  /// into it. Building a web address does not remove dot segments, so an
  /// identifier carrying them could point the request somewhere other than where
  /// the source says. It cannot reach a write today — every path this app can
  /// produce ends in `/close` — but that is the shape being lucky rather than a
  /// guarantee, so the identifier is refused before a request exists.
  @Test("aTaskIdentifierThatIsNotOpaqueSendsNothing")
  func aTaskIdentifierThatIsNotOpaqueSendsNothing() async throws {
    let stub = StubTodoistTransport(answers: [.bare(status: 200)])
    let completion = TaskCompletion(context: context, client: Self.client(stub))

    let outcome = await completion.complete(taskID: "a/../..", titleSnapshot: "Draft the summary")

    #expect(stub.recordedRequests.isEmpty)
    #expect(outcome == .failed)
    #expect(try Self.records(in: context).isEmpty)

    // A real Todoist identifier is accepted, so the rule is a filter rather than
    // a wall.
    #expect(TodoistAPI.isOpaqueIdentifier("6XGgmFVcrG5RRjVr"))
    #expect(TodoistAPI.isOpaqueIdentifier("a/../..") == false)
    #expect(TodoistAPI.isOpaqueIdentifier("") == false)
  }

  // MARK: Helpers

  private static func client(_ transport: StubTodoistTransport) -> TodoistClient {
    TodoistClient(
      transport: transport,
      tokens: FakeTokenStore(),
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
