import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// What the mirror does when Todoist tells it something it did not know.
///
/// **F3c.** `TaskCompletion` reports `.alreadyGone` when a close request comes back saying the
/// task was already finished or deleted somewhere else. Nothing acted on that, so the picker
/// went on offering the task until the next refresh — which may be a whole planning session
/// away. Offering back work already done is precisely what D21b exists to stop, arriving by a
/// route D21b does not cover and should not be widened to cover.
@Suite("TodoistCacheForget")
@MainActor
struct TodoistCacheForgetTests {
  private let container: ModelContainer

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  private var context: ModelContext { container.mainContext }

  private func store() -> TodoistCacheStore {
    TodoistCacheStore(
      context: context,
      client: TodoistClient(
        transport: StubTodoistTransport(answers: []),
        tokens: FakeTokenStore(),
        waiting: RecordingRetryWaiting()))
  }

  // MARK: F3c — the mirror catches up when Todoist says a task is gone

  /// `forgettingATaskRemovesItFromThePicker` — and leaves everything else alone.
  ///
  /// `TaskCompletion` reports `.alreadyGone` when a close comes back saying the task was
  /// already finished or deleted somewhere else. Before F3c nothing acted on that, so the
  /// picker went on offering the task until the next refresh — which may be a whole planning
  /// session away, and offering back work already done is the exact thing D21b exists to stop,
  /// arriving by a route D21b does not cover.
  @Test("forgettingATaskRemovesItFromThePicker")
  func forgettingATaskRemovesItFromThePicker() throws {
    let synced = StatsStoreFixture.at(2026, 8, 19, 8, 0)
    context.insert(CachedProject(id: "p1", name: "Thesis", childOrder: 0, syncedAt: synced))
    context.insert(CachedTask(
      id: "t-gone", content: "Finished elsewhere", projectID: "p1",
      sectionID: nil, childOrder: 0, syncedAt: synced))
    context.insert(CachedTask(
      id: "t-stays", content: "Still mine", projectID: "p1",
      sectionID: nil, childOrder: 1, syncedAt: synced))
    try context.save()

    store().forget(taskID: "t-gone")

    let remaining = try context.fetch(FetchDescriptor<CachedTask>()).map(\.id).sorted()
    #expect(remaining == ["t-stays"])
    // The project is untouched: one task going does not empty its project.
    #expect(try context.fetch(FetchDescriptor<CachedProject>()).count == 1)
  }

  /// Forgetting something the mirror never held is silent.
  @Test("forgettingAnUnknownTaskDoesNothing")
  func forgettingAnUnknownTaskDoesNothing() throws {
    store().forget(taskID: "never-existed")
    #expect(try context.fetch(FetchDescriptor<CachedTask>()).isEmpty)
  }
}
