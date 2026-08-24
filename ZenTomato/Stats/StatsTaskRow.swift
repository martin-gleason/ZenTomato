import Foundation

/// One task's share of a span of days: how many pomodoros, how long, and what
/// interrupted them.
///
/// **A row is keyed by the title that was written down, not by a Todoist
/// identifier.** Two consequences, both deliberate. A task renamed half way
/// through a fortnight produces two rows, one under each name, which is what
/// the record actually says happened. And nothing in this feature carries an
/// identifier at all, so the rule that the document contains no ids is
/// structural: there is no id in the values the document is built from.
struct StatsTaskRow: Sendable, Equatable {
  // MARK: Which task

  /// The task's title snapshot, or nothing for blocks attached to no task.
  ///
  /// **Nothing is an ordinary answer.** A block has no task when a project was
  /// planned on its own, when the plan had been worked through, when nobody has
  /// connected Todoist, or when the row was written before Todoist existed in
  /// this app at all. The reader prints its own words for it — the counting
  /// layer holds no human-readable string.
  let title: String?

  /// The project the block recorded, or nothing.
  ///
  /// Carried on the task row as well as on the project group so that a flat
  /// list of tasks can still say where each one belongs, without the screen
  /// having to walk back up.
  let projectTitle: String?

  // MARK: What was counted

  /// Finished, non-abandoned focus blocks. Breaks are not pomodoros and
  /// stopped blocks count for nothing.
  let pomodoroCount: Int

  /// The seconds those blocks actually ran for, summed. Truncated to whole
  /// seconds and never negative.
  let focusedSeconds: Int

  /// Internal taps recorded against this task.
  ///
  /// **Taps count wherever they were tapped, including inside a block that was
  /// later stopped.** The tap is a finished fact of its own, and the block you
  /// bailed out of is the most interesting one in the log. So a task can show
  /// zero pomodoros and three internal taps, and that is a true reading rather
  /// than an inconsistency.
  let internalCount: Int

  /// External taps recorded against this task.
  let externalCount: Int

  /// Every tap against this task, of either kind.
  var distractionCount: Int { internalCount + externalCount }
}
