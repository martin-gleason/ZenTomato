import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// The whole of an afternoon, driven through the screens' own collaborators,
/// with every request recorded — and then the one question this project cares
/// most about asked of the log.
///
/// THE QUESTION
/// `CLAUDE.md`: *"The only write to Todoist is complete task. Never call create,
/// update, or comment endpoints."* A committed allowlist and a pre-commit check
/// answer that question about the **source**. This answers it about the
/// **traffic**: a session is played out — connect, fill the copy, build a plan,
/// work a block, tick the task off, work the next one, refresh again — and every
/// request the app made is read back. All of them are reads except one, and that
/// one is the close.
///
/// WHY BOTH CHECKS EXIST
/// The static one cannot see a request assembled at runtime. This one cannot see
/// an endpoint nobody happened to call during the test. Together they cover the
/// two ways the rule could break, which is why the build contract asks for both.
///
/// NO PATH IS WRITTEN OUT IN THIS FILE. Every address the test expects is built
/// from the same constants the app builds its requests from, so a change to the
/// endpoint table cannot leave this test passing against an address the app no
/// longer uses — and so the source check has no hard-coded identifier to object
/// to.
@Suite("TodoistSessionTraffic")
@MainActor
struct TodoistSessionTrafficTests {
  // MARK: Lifecycle

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  // MARK: The whole session

  @Test("noMutatingRequestsAcrossAWholeSession")
  func noMutatingRequestsAcrossAWholeSession() async throws {
    let credentials = InMemoryTokenStore()
    let stub = Self.anAfternoonOfAnswers()

    let client = TodoistClient(transport: stub, tokens: credentials, waiting: RecordingRetryWaiting())
    let cache = TodoistCacheStore(context: context, client: client)
    let plan = SessionPlanStore(context: context)
    let completion = TaskCompletion(context: context, client: client)

    // 1. Fill the copy, exactly as opening the picker does.
    try await cache.refresh()
    #expect(try context.fetch(FetchDescriptor<CachedTask>()).count == 2)

    // 2. Build a plan from it. Nothing here reaches Todoist.
    plan.replacePlan(with: [
      SessionPlanStore.Selection(todoistID: "t1", titleSnapshot: "Draft the Q3 summary", kind: .task),
      SessionPlanStore.Selection(todoistID: "t2", titleSnapshot: "Reply to Anna", kind: .task)
    ])
    let requestsAfterPlanning = stub.recordedRequests.count

    // 3. Start a focus block: the timer takes the plan's next item.
    let attachment = try #require(plan.takeNextAttachment())
    #expect(attachment.taskTitle == "Draft the Q3 summary")
    #expect(stub.recordedRequests.count == requestsAfterPlanning, "Attaching a task must not make a request.")

    // 4. Tick it off from the end-of-block sheet. **The one write.**
    let outcome = await completion.complete(taskID: "t1", titleSnapshot: "Draft the Q3 summary")
    #expect(outcome == .closed)

    // 5. Search the copy while the break runs. Still no request.
    let requestsBeforeSearching = stub.recordedRequests.count
    for query in ["r", "re", "rep", "reply", "nothing matches this"] {
      _ = Self.pickerAfterTheFirstTaskWentAway.rows(matching: query)
    }
    #expect(stub.recordedRequests.count == requestsBeforeSearching, "Searching must not make a request.")

    // 6. The next focus block takes the next item, and the app comes back to
    //    the foreground and fills the copy again.
    #expect(plan.takeNextAttachment()?.taskTitle == "Reply to Anna")
    try await cache.refresh()

    // THE ASSERTION THE WHOLE FEATURE IS JUDGED ON.
    try Self.expectExactlyOneClose(in: stub, forTask: "t1")

    // The completion was recorded locally, once, and only after Todoist
    // confirmed it.
    let history = try context.fetch(FetchDescriptor<CompletedTaskRecord>())
    #expect(history.count == 1)
    #expect(history.first?.taskID == "t1")
    #expect(history.first?.titleSnapshot == "Draft the Q3 summary")

    // And the plan did not move because of it. The cursor moved twice, once per
    // focus block, and not once for the completion.
    #expect(plan.currentIndex == 2)
  }

  /// A session in which nothing is ever ticked off makes **no** non-read
  /// request at all — which is the ordinary shape of an afternoon.
  @Test("aSessionWithNoCompletionMakesNoWriteAtAll")
  func aSessionWithNoCompletionMakesNoWriteAtAll() async throws {
    let stub = StubTodoistTransport(answers: [
      .page(rows: [StubTodoistTransport.projectRow(id: "p1", name: "Deep work")]),
      .page(rows: []),
      .page(rows: [StubTodoistTransport.taskRow(id: "t1", content: "Draft the Q3 summary", projectID: "p1")])
    ])
    let credentials = InMemoryTokenStore()
    let client = TodoistClient(transport: stub, tokens: credentials, waiting: RecordingRetryWaiting())
    let cache = TodoistCacheStore(context: context, client: client)
    let plan = SessionPlanStore(context: context)

    try await cache.refresh()
    plan.replacePlan(with: [
      SessionPlanStore.Selection(todoistID: "t1", titleSnapshot: "Draft the Q3 summary", kind: .task)
    ])
    _ = plan.takeNextAttachment()
    plan.stepOver()
    plan.clear()

    #expect(stub.requestsThatWereNotReads.isEmpty)
  }

  // MARK: Private

  private let container: ModelContainer

  private var context: ModelContext { container.mainContext }

  /// The answers one afternoon needs: a first refresh, one close, and the
  /// refresh on the way back into the app with the closed task no longer in it.
  private static func anAfternoonOfAnswers() -> StubTodoistTransport {
    StubTodoistTransport(answers: [
      .page(rows: [
        StubTodoistTransport.projectRow(id: "p1", name: "Deep work"),
        StubTodoistTransport.projectRow(id: "p2", name: "Admin", order: 1)
      ]),
      .page(rows: [StubTodoistTransport.sectionRow(id: "s1", name: "This week", projectID: "p1")]),
      .page(rows: [
        StubTodoistTransport.taskRow(id: "t1", content: "Draft the Q3 summary", projectID: "p1", sectionID: "s1"),
        StubTodoistTransport.taskRow(id: "t2", content: "Reply to Anna", projectID: "p1", order: 1)
      ]),
      .bare(status: 200),
      .page(rows: [
        StubTodoistTransport.projectRow(id: "p1", name: "Deep work"),
        StubTodoistTransport.projectRow(id: "p2", name: "Admin", order: 1)
      ]),
      .page(rows: [StubTodoistTransport.sectionRow(id: "s1", name: "This week", projectID: "p1")]),
      .page(rows: [
        StubTodoistTransport.taskRow(id: "t2", content: "Reply to Anna", projectID: "p1")
      ])
    ])
  }

  /// The picker as it stands during the break, with the ticked-off task already
  /// out of the copy.
  private static let pickerAfterTheFirstTaskWentAway = PickerScreenModel(
    projects: [PickerScreenModel.Project(id: "p1", name: "Deep work", openTaskCount: 1)],
    sections: [],
    tasks: [
      PickerScreenModel.TaskItem(
        id: "t2",
        title: "Reply to Anna",
        projectID: "p1",
        projectName: "Deep work",
        sectionID: nil)
    ])

  /// Reads the whole request log back and asserts the rule.
  ///
  /// **Every expected address is built from `TodoistAPI`**, never written out
  /// here — so a change to the endpoint table cannot leave this passing against
  /// an address the app no longer uses, and the source check has no hard-coded
  /// identifier to object to.
  private static func expectExactlyOneClose(in stub: StubTodoistTransport, forTask taskID: String) throws {
    let writes = stub.requestsThatWereNotReads
    #expect(writes.count == 1)

    let close = try #require(writes.first)
    #expect(close.httpMethod == TodoistAPI.Method.post.rawValue)
    #expect(close.url?.path().hasSuffix(TodoistAPI.closeTask(id: taskID).path) == true)
    // The close endpoint takes no body, and a client with no body-writing code
    // cannot grow a create call by accident.
    #expect(close.httpBodyStream == nil)
    #expect(close.httpBody == nil)

    // And every other request was a read of one of the three addresses the
    // allowlist names.
    let readPaths = Set(stub.recordedRequests
      .filter { $0.httpMethod == TodoistAPI.Method.get.rawValue }
      .compactMap { $0.url?.path() })
    let allowedReads = [TodoistAPI.projects, TodoistAPI.sections, TodoistAPI.tasks].map(\.path)
    for path in readPaths {
      #expect(allowedReads.contains { path.hasSuffix($0) }, "An unexpected address was read.")
    }
  }
}
