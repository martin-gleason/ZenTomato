import Foundation

/// Every distraction recorded against one task, in one span of days.
///
/// **Why the log is grouped by task rather than by day, which is the one real
/// editorial decision in this feature.** Chronological order tells you *when*
/// you were interrupted, and the days table already answers that. Grouping by
/// what you were working on tells you *what keeps interrupting you*, which is
/// the self-knowledge `SPEC.md` says the log exists to produce.
///
/// The group is named by a pair rather than by one string, so that a task
/// called *Thesis* and a block attached to the *Thesis* project with no task
/// chosen stay two different groups. Which words to print for each is the
/// reader's decision, not this type's.
struct StatsDistractionGroup: Sendable, Equatable {
  /// The task's title snapshot, or nothing when no task was attached.
  let taskTitle: String?

  /// The project's name snapshot, or nothing when no project was attached.
  let projectTitle: String?

  /// The taps, oldest first.
  let entries: [StatsDistractionEntry]

  /// How many taps are in the group.
  var count: Int { entries.count }
}
