import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// Tests for the local copy of Todoist.
///
/// THE CLAIM UNDER TEST
/// The copy is a photograph, not a second opinion. Nothing in the app edits a
/// row, and a refresh throws every row away and writes fresh ones — so there is
/// never a local version of anybody's tasks that could disagree with Todoist's,
/// and therefore never a question about which one wins. These tests are the
/// mechanical version of that sentence.
///
/// The two that matter most are the ones about failure:
///
///   * a refresh that fails part way must leave the previous copy **exactly** as
///     it was, because a half-replaced copy would show a project whose tasks had
///     been deleted;
///   * a refused token must throw the credential away and touch **nothing**
///     else, because a credential going stale is not a decision to disconnect,
///     and wiping somebody's plan for it would be a punishment for something
///     Todoist did.
///
/// `@MainActor` on the whole suite: everything that touches the database in this
/// app is main-thread only.
@Suite("TodoistCache")
@MainActor
struct TodoistCacheTests {
  private let container: ModelContainer

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  private var context: ModelContext {
    container.mainContext
  }

  // MARK: Replacing

  /// A refresh replaces the copy rather than merging into it, and two copies of
  /// one row on two pages become one row.
  ///
  /// The duplicate is not a hypothetical: Todoist's documentation says that
  /// editing an account while its pages are being read can hand the same row
  /// back twice, and tells the reader to expect it.
  @Test("refreshReplacesRatherThanMerges")
  func refreshReplacesRatherThanMerges() async throws {
    context.insert(CachedProject(id: "gone", name: "Deleted in Todoist", childOrder: 0, syncedAt: .now))
    context.insert(CachedTask(
      id: "old-task",
      content: "Yesterday's task",
      projectID: "gone",
      sectionID: nil,
      childOrder: 0,
      syncedAt: .now))
    try context.save()

    let stub = StubTodoistTransport(answers: [
      .page(rows: [
        StubTodoistTransport.projectRow(id: "p1", name: "Deep work"),
        // The same project again, as a mid-fetch edit can produce.
        StubTodoistTransport.projectRow(id: "p1", name: "Deep work")
      ]),
      .page(rows: []),
      .page(rows: [
        StubTodoistTransport.taskRow(id: "t1", content: "Draft the summary", projectID: "p1")
      ])
    ])
    let store = TodoistCacheStore(context: context, client: Self.client(stub))

    try await store.refresh(now: Date(timeIntervalSince1970: 1_000_000))

    let projects = try Self.rows(CachedProject.self, in: context)
    let tasks = try Self.rows(CachedTask.self, in: context)

    #expect(projects.map(\.id) == ["p1"])
    #expect(tasks.map(\.id) == ["t1"])
    #expect(store.lastSyncedAt == Date(timeIntervalSince1970: 1_000_000))
    #expect(stub.requestsThatWereNotReads.isEmpty)
  }

  // MARK: Failing

  /// A refresh that fails on the third list leaves the previous copy untouched.
  ///
  /// Nothing is written until all three lists have arrived, so the app never has
  /// a copy that is half of one photograph and half of another.
  @Test("refreshIsAllOrNothing")
  func refreshIsAllOrNothing() async throws {
    context.insert(CachedProject(id: "before", name: "As it was", childOrder: 0, syncedAt: .now))
    context.insert(CachedSection(
      id: "s-before",
      name: "Doing",
      projectID: "before",
      sectionOrder: 0,
      syncedAt: .now))
    try context.save()

    let stub = StubTodoistTransport(answers: [
      .page(rows: [StubTodoistTransport.projectRow(id: "p1", name: "Deep work")]),
      .page(rows: []),
      .failure(URLError(.notConnectedToInternet))
    ])
    let store = TodoistCacheStore(context: context, client: Self.client(stub))

    await #expect(throws: TodoistError.offline) {
      try await store.refresh()
    }

    let projects = try Self.rows(CachedProject.self, in: context)
    let sections = try Self.rows(CachedSection.self, in: context)
    #expect(projects.map(\.id) == ["before"])
    #expect(sections.map(\.id) == ["s-before"])
  }

  /// A refused token is thrown away, and nothing else is.
  ///
  /// The plan especially: somebody's half-worked afternoon must not be deleted
  /// because a credential expired. Signing out is the only thing that clears it,
  /// and signing out is a decision somebody made.
  @Test("unauthorizedKeepsTheCacheAndThePlan")
  func unauthorizedKeepsTheCacheAndThePlan() async throws {
    context.insert(CachedProject(id: "before", name: "As it was", childOrder: 0, syncedAt: .now))
    context.insert(SessionPlan(createdAt: .now))
    context.insert(SessionPlanItem(
      todoistID: "t1",
      titleSnapshot: "Draft the summary",
      kind: .task,
      position: 0))
    try context.save()

    let tokens = FakeTokenStore()
    let stub = StubTodoistTransport(answers: [.bare(status: 401)])
    let store = TodoistCacheStore(
      context: context,
      client: TodoistClient(transport: stub, tokens: tokens, waiting: RecordingRetryWaiting()))

    await #expect(throws: TodoistError.tokenRejected) {
      try await store.refresh()
    }

    let projects = try Self.rows(CachedProject.self, in: context)
    let plans = try Self.rows(SessionPlan.self, in: context)
    let items = try Self.rows(SessionPlanItem.self, in: context)

    #expect(tokens.holdsAToken == false)
    #expect(projects.count == 1)
    #expect(plans.count == 1)
    #expect(items.count == 1)
  }

  // MARK: Signing out

  /// Clearing removes this app's copy of somebody else's data, and keeps this
  /// app's own history.
  ///
  /// The completion records are not Todoist's rows. They are what this app did,
  /// they are what the two-week review is assembled from, and they survive
  /// signing out for the same reason a paper notebook survives cancelling a
  /// subscription.
  @Test("clearEmptiesTheMirrorButKeepsHistory")
  func clearEmptiesTheMirrorButKeepsHistory() async throws {
    context.insert(CachedProject(id: "p1", name: "Deep work", childOrder: 0, syncedAt: .now))
    context.insert(CachedSection(id: "s1", name: "Doing", projectID: "p1", sectionOrder: 0, syncedAt: .now))
    context.insert(CachedTask(
      id: "t1",
      content: "Draft the summary",
      projectID: "p1",
      sectionID: "s1",
      childOrder: 0,
      syncedAt: .now))
    context.insert(CompletedTaskRecord(
      taskID: "t0",
      titleSnapshot: "Something finished last week",
      completedAt: .now,
      wasRecurring: false))
    try context.save()

    let store = TodoistCacheStore(
      context: context,
      client: Self.client(StubTodoistTransport(answers: [])))
    try store.clear()

    let projects = try Self.rows(CachedProject.self, in: context)
    let sections = try Self.rows(CachedSection.self, in: context)
    let tasks = try Self.rows(CachedTask.self, in: context)
    let history = try Self.rows(CompletedTaskRecord.self, in: context)

    #expect(projects.isEmpty)
    #expect(sections.isEmpty)
    #expect(tasks.isEmpty)
    #expect(history.count == 1)
    #expect(store.lastSyncedAt == nil)
  }

  // MARK: How often it is allowed to ask

  /// The two automatic triggers do not both sweep.
  ///
  /// Opening the app straight into the Todoist sheet fires the foreground
  /// refresh and the sheet's own, one after the other, for one gesture. Todoist
  /// publishes no request ceiling at all for these four addresses, so the app
  /// stays under whatever it is by asking rarely — which used to be a claim in a
  /// comment and is now a floor in the code. A pull is never held back.
  @Test("anAutomaticRefreshRightAfterAnotherAsksForNothing")
  func anAutomaticRefreshRightAfterAnotherAsksForNothing() async throws {
    let stub = StubTodoistTransport(answers: [
      .page(rows: [StubTodoistTransport.projectRow(id: "p1", name: "Deep work")]),
      .page(rows: []),
      .page(rows: [StubTodoistTransport.taskRow(id: "t1", content: "Draft it", projectID: "p1")])
    ])
    let store = TodoistCacheStore(context: context, client: Self.client(stub))
    let openedAt = Date(timeIntervalSince1970: 1_787_400_000)

    try await store.refresh(now: openedAt, force: false)
    #expect(stub.recordedRequests.count == 3)

    // The sheet opens two seconds later. Nothing is sent.
    try await store.refresh(now: openedAt.addingTimeInterval(2), force: false)
    #expect(stub.recordedRequests.count == 3)

    // And the copy is still there, so the picker draws a list rather than an
    // empty screen.
    #expect(try Self.rows(CachedProject.self, in: context).count == 1)
  }

  /// A pull is somebody asking, and it always goes out.
  @Test("aPullToRefreshIsNeverHeldBack")
  func aPullToRefreshIsNeverHeldBack() async throws {
    let stub = StubTodoistTransport(answers: [
      .page(rows: [StubTodoistTransport.projectRow(id: "p1", name: "Deep work")]),
      .page(rows: []),
      .page(rows: []),
      .page(rows: [StubTodoistTransport.projectRow(id: "p1", name: "Deep work")]),
      .page(rows: []),
      .page(rows: [])
    ])
    let store = TodoistCacheStore(context: context, client: Self.client(stub))
    let openedAt = Date(timeIntervalSince1970: 1_787_400_000)

    try await store.refresh(now: openedAt, force: false)
    #expect(stub.recordedRequests.count == 3)

    try await store.refresh(now: openedAt.addingTimeInterval(2))
    #expect(stub.recordedRequests.count == 6)
  }

  // MARK: Reading a due date (D21)

  /// The documented shape, with `is_recurring` set, read from **real
  /// snake-case JSON**.
  ///
  /// **This is the test that catches the wrong key**, and it only catches it
  /// because the input is text rather than a Swift value. A hand-built
  /// `TodoistTaskDTO.Due(isRecurring: true)` cannot spell a key wrong, so a
  /// test built from one would pass just as happily against a decoder reading
  /// `is_recurring` from the task root — where it does not exist, where it
  /// would always be missing, and where the answer would therefore be `false`
  /// on every task for ever with nothing to notice.
  ///
  /// The JSON below is Todoist's own documented example, confirmed against
  /// Doist's own API v1 client library, which declares `is_recurring` inside
  /// the `Due` object and not on the task.
  @Test("aRecurringTaskIsReadFromInsideItsDueObject")
  func aRecurringTaskIsReadFromInsideItsDueObject() throws {
    let json = Data("""
      {
        "id": "6XGgmFVcrG5RRjVr",
        "content": "Budget with YNAB by 7:30 AM",
        "project_id": "6X7rM8997g3RQmvh",
        "section_id": null,
        "child_order": 1,
        "due": {
          "date": "2016-08-05T07:00:00.000000Z",
          "timezone": null,
          "is_recurring": true,
          "string": "tomorrow at 10:00",
          "lang": "en"
        }
      }
      """.utf8)

    let task = try JSONDecoder().decode(TodoistTaskDTO.self, from: json)

    #expect(task.due?.isRecurring == true)
    #expect(task.content == "Budget with YNAB by 7:30 AM")
  }

  /// A task with no `due` key at all reads, and is not recurring.
  ///
  /// This is most tasks in most accounts. A required field here would make
  /// **every task on the account fail to decode**, which presents as an empty
  /// picker on a real phone and in nobody's test.
  @Test("aTaskWithNoDueKeyStillDecodes")
  func aTaskWithNoDueKeyStillDecodes() throws {
    let json = Data("""
      {"id": "t1", "content": "Draft the summary", "project_id": "p1", "section_id": null, "child_order": 0}
      """.utf8)

    let task = try JSONDecoder().decode(TodoistTaskDTO.self, from: json)

    #expect(task.due == nil)
    #expect((task.due?.isRecurring ?? false) == false)
  }

  /// An explicit `"due": null` reads too, and is not recurring.
  @Test("aTaskWithAnExplicitNullDueStillDecodes")
  func aTaskWithAnExplicitNullDueStillDecodes() throws {
    let json = Data("""
      {"id": "t1", "content": "Draft the summary", "project_id": "p1", "section_id": null,
       "child_order": 0, "due": null}
      """.utf8)

    let task = try JSONDecoder().decode(TodoistTaskDTO.self, from: json)

    #expect(task.due == nil)
  }

  /// A due object that arrives **without** `is_recurring` reads, and is not
  /// recurring.
  ///
  /// The rarest of the three tolerances and the same catastrophe: a required
  /// field would take the whole task down with it, and the whole page of tasks
  /// with that.
  @Test("aDueObjectWithNoRecurrenceFlagStillDecodes")
  func aDueObjectWithNoRecurrenceFlagStillDecodes() throws {
    let json = Data("""
      {"id": "t1", "content": "Draft the summary", "project_id": "p1", "section_id": null,
       "child_order": 0,
       "due": {"date": "2026-08-24", "string": "tomorrow", "lang": "en"}}
      """.utf8)

    let task = try JSONDecoder().decode(TodoistTaskDTO.self, from: json)

    #expect(task.due?.isRecurring == false)
  }

  /// The flag reaches the local copy, from the one place it enters the app.
  @Test("recurrenceReachesTheMirroredRow")
  func recurrenceReachesTheMirroredRow() async throws {
    let stub = StubTodoistTransport(answers: [
      .page(rows: [StubTodoistTransport.projectRow(id: "p1", name: "Admin")]),
      .page(rows: []),
      .page(rows: [
        [
          "id": "t-habit", "content": "Budget with YNAB by 7:30 AM", "project_id": "p1",
          "section_id": NSNull(), "child_order": 0,
          "due": ["date": "2026-08-24", "string": "every day", "lang": "en", "is_recurring": true]
        ],
        StubTodoistTransport.taskRow(id: "t-plain", content: "Draft the summary", projectID: "p1", order: 1)
      ])
    ])
    let store = TodoistCacheStore(context: context, client: Self.client(stub))

    try await store.refresh(now: Date(timeIntervalSince1970: 1_000_000))

    let tasks = try Self.rows(CachedTask.self, in: context).sorted { $0.id < $1.id }
    #expect(tasks.map(\.id) == ["t-habit", "t-plain"])
    #expect(tasks.map(\.isRecurring) == [true, false])
  }

  // MARK: Helpers

  private static func client(_ transport: StubTodoistTransport) -> TodoistClient {
    TodoistClient(
      transport: transport,
      tokens: FakeTokenStore(),
      waiting: RecordingRetryWaiting())
  }

  private static func rows<Row: PersistentModel>(
    _ type: Row.Type,
    in context: ModelContext) throws -> [Row] {
    try context.fetch(FetchDescriptor<Row>())
  }
}
