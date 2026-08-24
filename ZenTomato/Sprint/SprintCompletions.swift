import Foundation
import Observation

/// The tasks ticked off since this sprint began (D21b).
///
/// WHAT PROBLEM THIS SOLVES, IN ONE PARAGRAPH
/// Completing a recurring task in Todoist does not finish it — it advances it
/// to its next occurrence, so it is an open task again immediately. The next
/// time the local copy of Todoist refreshes it comes back, and nothing stops it
/// being offered again, or worked again, in the same afternoon. You are handed
/// work you have already done.
///
/// **The rule holds for every task, not only recurring ones.** That is the
/// whole reason it is safe: it needs no knowledge of recurrence, so it cannot
/// be wrong about a task it guessed at. A task that genuinely is finished would
/// have left Todoist's active list anyway, so the rule costs nothing there and
/// is simply always true.
///
/// **Nothing here is saved.** The set lives in memory, lasts one sprint, and is
/// empty in a fresh process. D21b: *"this is about one afternoon, not a
/// history"* — the history is `CompletedTaskRecord`, and a second store of the
/// same fact is a second thing that can disagree with the first.
///
/// `@Observable` marks it as something screens can watch: adding an id makes
/// the picker redraw without anything having to notify it or refresh it by
/// hand. `@MainActor` — main-thread only — matches the plan store and the timer
/// it sits between, so every hand-off is a plain method call with nothing that
/// can arrive out of order.
@MainActor
@Observable
final class SprintCompletions {
  // MARK: Lifecycle

  /// Creates an empty set.
  init() {}

  // MARK: Reading

  /// Todoist's identifiers for the tasks ticked off in this sprint.
  ///
  /// Readable so that a screen can watch it; writable only through the two
  /// methods below, so nobody can put something in it that this app did not do.
  private(set) var taskIDs: Set<String> = []

  /// Whether this task has already been ticked off in this sprint.
  func contains(_ taskID: String) -> Bool {
    taskIDs.contains(taskID)
  }

  // MARK: Writing

  /// Records that a task was closed during this sprint.
  ///
  /// Called only after Todoist has confirmed the close — never optimistically,
  /// and never for a task that was already gone. *Already gone* means somebody
  /// finished or deleted it somewhere else, which this app did not do and
  /// cannot tell apart; treating it as a completion here would widen the rule
  /// from *"I finished this"* to *"I believe this is gone"*, which is a
  /// different rule with a different failure mode.
  func record(taskID: String) {
    taskIDs.insert(taskID)
  }

  /// Empties the set, because the sprint it belonged to has ended.
  ///
  /// Emptying one that is already empty is deliberately a no-op rather than an
  /// error: the thing that watches for the end of a sprint may see the same
  /// resting state more than once, and over-clearing is harmless. Under-
  /// clearing is the bug this whole type exists to prevent.
  func clear() {
    taskIDs.removeAll()
  }
}
