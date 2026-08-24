import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// D21, end to end: from Todoist's own JSON to the boolean on the completion
/// row.
///
/// **This whole feature fails silently or not at all.** If the key is wrong, if
/// the cached row is read after it has been deleted, or if an initialiser
/// quietly defaults, the answer is `false` on every completion for ever — and
/// the only symptom is that the export's *Repeating* section is empty, which
/// looks exactly like a fortnight in which no habit was kept. Nothing crashes,
/// nothing warns, and nobody notices for two weeks.
///
/// So there are three tests and they cover the three doors:
///
///   1. the wrong key — `recurrenceSurvivesTheWholeJourneyFromTodoistsJSON`,
///      which starts from real snake-case JSON rather than a hand-built Swift
///      value, because a hand-built value cannot get a key wrong;
///   2. the ordering — `recurrenceIsReadBeforeTheCachedRowIsDropped`, which was
///      **verified to fail** when the read is moved below the delete;
///   3. the missing row — `aCompletionWithNoMirroredTaskIsNotRecurring`, which
///      pins the honest loss rather than leaving it undiscovered.
@Suite("RecurrenceCapture")
@MainActor
struct RecurrenceCaptureTests {
  private let container: ModelContainer

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  private var context: ModelContext {
    container.mainContext
  }

  // MARK: The whole journey

  /// A recurring task, as Todoist actually sends it, ends up as `true` on the
  /// completion row.
  ///
  /// Every step is the real one: Todoist's documented JSON, the app's own
  /// decoder, the app's own cache write, the app's own completion path. Nothing
  /// in the middle is stubbed except the network, so a wrong key anywhere along
  /// the way fails here.
  @Test("recurrenceSurvivesTheWholeJourneyFromTodoistsJSON")
  func recurrenceSurvivesTheWholeJourneyFromTodoistsJSON() async throws {
    let stub = StubTodoistTransport(answers: [
      .page(rows: [StubTodoistTransport.projectRow(id: "6X7rM8997g3RQmvh", name: "Admin")]),
      .page(rows: []),
      .page(rows: [Self.recurringTaskRow, Self.plainTaskRow])
    ])
    let cache = TodoistCacheStore(context: context, client: Self.client(stub))
    try await cache.refresh(now: Date(timeIntervalSince1970: 1_000_000))

    let mirrored = try context.fetch(FetchDescriptor<CachedTask>(sortBy: [SortDescriptor(\.id)]))
    #expect(mirrored.map(\.isRecurring) == [true, false])

    let closing = StubTodoistTransport(answers: [.bare(status: 200)])
    let completion = TaskCompletion(context: context, client: Self.client(closing))
    let outcome = await completion.complete(
      taskID: "6XGgmFVcrG5RRjVr",
      titleSnapshot: "Budget with YNAB by 7:30 AM",
      now: Date(timeIntervalSince1970: 1_100_000))

    #expect(outcome == .closed)
    let records = try Self.records(in: context)
    #expect(records.map(\.wasRecurring) == [true])
    #expect(records.first?.titleSnapshot == "Budget with YNAB by 7:30 AM")
  }

  /// The recurrence is read **before** the mirrored row is deleted.
  ///
  /// **Verified by making it fail.** Moving the read in
  /// `TaskCompletion.recordLocally` below the `context.delete(model:where:)`
  /// call turns the expectation below from `true` to `false`, which is exactly
  /// the silent failure D21 warns about: every completion would record "not
  /// recurring" for ever and the export's *Repeating* section would simply be
  /// empty.
  ///
  /// The second expectation is the other half of the same step and is what
  /// makes the first one meaningful: the row really is gone afterwards, so the
  /// answer above genuinely had to be read first.
  @Test("recurrenceIsReadBeforeTheCachedRowIsDropped")
  func recurrenceIsReadBeforeTheCachedRowIsDropped() async throws {
    context.insert(CachedTask(
      id: "t1",
      content: "Budget with YNAB by 7:30 AM",
      projectID: "p1",
      sectionID: nil,
      childOrder: 0,
      syncedAt: Date(timeIntervalSince1970: 1_000_000),
      isRecurring: true))
    try context.save()

    let stub = StubTodoistTransport(answers: [.bare(status: 200)])
    let completion = TaskCompletion(context: context, client: Self.client(stub))
    _ = await completion.complete(taskID: "t1", titleSnapshot: "Budget with YNAB by 7:30 AM")

    let records = try Self.records(in: context)
    #expect(records.map(\.wasRecurring) == [true])
    #expect(try context.fetch(FetchDescriptor<CachedTask>()).isEmpty)
  }

  /// A task that is not in the mirror records as *not recurring*, and the
  /// completion is still written.
  ///
  /// This happens when somebody is signed out, when the copy has been cleared,
  /// or when the last refresh did not return the task. It is a real and
  /// deliberate loss of information — the completion lands among the one-offs —
  /// and it is pinned here so that it is a known cost rather than a surprise.
  /// The alternative, a third state, is forbidden by this project's lint rules
  /// and by D21's own words: *one boolean*.
  @Test("aCompletionWithNoMirroredTaskIsNotRecurring")
  func aCompletionWithNoMirroredTaskIsNotRecurring() async throws {
    let stub = StubTodoistTransport(answers: [.bare(status: 200)])
    let completion = TaskCompletion(context: context, client: Self.client(stub))

    let outcome = await completion.complete(taskID: "t-unknown", titleSnapshot: "Budget with YNAB")

    #expect(outcome == .closed)
    let records = try Self.records(in: context)
    #expect(records.map(\.wasRecurring) == [false])
  }

  /// A refusal writes nothing at all, recurring or not.
  ///
  /// The order of the four steps is unchanged by D21: nothing local is written
  /// until Todoist has confirmed.
  @Test("aRefusedCloseRecordsNoRecurrenceBecauseItRecordsNothing")
  func aRefusedCloseRecordsNoRecurrenceBecauseItRecordsNothing() async throws {
    context.insert(CachedTask(
      id: "t1",
      content: "Budget with YNAB by 7:30 AM",
      projectID: "p1",
      sectionID: nil,
      childOrder: 0,
      syncedAt: Date(timeIntervalSince1970: 1_000_000),
      isRecurring: true))
    try context.save()

    let stub = StubTodoistTransport(answers: [.failure(URLError(.notConnectedToInternet))])
    let completion = TaskCompletion(context: context, client: Self.client(stub))
    let outcome = await completion.complete(taskID: "t1", titleSnapshot: "Budget with YNAB by 7:30 AM")

    #expect(outcome == .offline)
    #expect(try Self.records(in: context).isEmpty)
    // And the mirrored row is untouched, so the next attempt can still read it.
    #expect(try context.fetch(FetchDescriptor<CachedTask>()).map(\.isRecurring) == [true])
  }

  // MARK: Helpers

  /// The exact shape quoted in Todoist's own documentation and in the build
  /// contract, with `is_recurring` set.
  ///
  /// Written as raw JSON keys rather than as a Swift value on purpose: a Swift
  /// value cannot spell a key wrong, so a test built from one would pass
  /// against a decoder reading `isRecurring` from the task root — which is the
  /// mistake this whole suite exists to catch.
  private static var recurringTaskRow: [String: Any] {
    [
      "id": "6XGgmFVcrG5RRjVr",
      "content": "Budget with YNAB by 7:30 AM",
      "project_id": "6X7rM8997g3RQmvh",
      "section_id": NSNull(),
      "child_order": 1,
      "due": [
        "date": "2026-08-24T07:00:00.000000Z",
        "timezone": NSNull(),
        "is_recurring": true,
        "string": "every day at 7:30",
        "lang": "en"
      ]
    ]
  }

  /// An ordinary task with no due date at all, which is most tasks.
  private static var plainTaskRow: [String: Any] {
    [
      "id": "6XGgmFVcrG5RRjVs",
      "content": "Draft the summary",
      "project_id": "6X7rM8997g3RQmvh",
      "section_id": NSNull(),
      "child_order": 2
    ]
  }

  private static func client(_ transport: StubTodoistTransport) -> TodoistClient {
    TodoistClient(transport: transport, tokens: FakeTokenStore(), waiting: RecordingRetryWaiting())
  }

  private static func records(in context: ModelContext) throws -> [CompletedTaskRecord] {
    try context.fetch(FetchDescriptor<CompletedTaskRecord>(sortBy: [SortDescriptor(\.completedAt)]))
  }
}
