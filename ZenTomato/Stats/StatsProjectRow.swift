import Foundation

/// One project's share of a span of days, and the tasks inside it.
///
/// **Every total here is worked out from the task rows below it rather than
/// being counted a second time.** That is not tidiness: it is what makes it
/// impossible for a project's heading to disagree with the lines underneath it.
/// A number that disagrees with another number on the same page is how a
/// document stops being believed, and this is the document the whole app exists
/// to produce.
struct StatsProjectRow: Sendable, Equatable {
  // MARK: Which project

  /// The project's name snapshot, or nothing for blocks that recorded no
  /// project.
  ///
  /// Named `title` rather than `projectTitle` so that a project row and a task
  /// row answer the same question with the same word — the screen draws both
  /// through one shape, and the rows carry no other name it could be confused
  /// with.
  ///
  /// **Nothing is common, and today it is the usual case.** The timer records
  /// what the session plan handed it, and a planned *task* is handed over with
  /// its title alone — the plan holds no project for it. So blocks worked
  /// against a task currently land here with no project name, and group under
  /// whatever words the reader chooses for nothing. It is the honest reading of
  /// what was written down; changing what gets written down is a change to the
  /// timer's attachment path, not to this count.
  let title: String?

  /// The tasks worked under this project, ordered by pomodoro count descending
  /// and then by title.
  ///
  /// A block with no task produces a row here with no title rather than
  /// vanishing into the heading's total, so that the lines always add up to the
  /// heading. `F6.md`: such rows are *"rendered plainly, not as an error
  /// state."*
  let tasks: [StatsTaskRow]

  // MARK: What was counted

  /// Finished focus blocks across every task in this project.
  var pomodoroCount: Int { tasks.reduce(0) { $0 + $1.pomodoroCount } }

  /// The seconds those blocks ran for.
  var focusedSeconds: Int { tasks.reduce(0) { $0 + $1.focusedSeconds } }

  /// Internal taps across every task in this project.
  var internalCount: Int { tasks.reduce(0) { $0 + $1.internalCount } }

  /// External taps across every task in this project.
  var externalCount: Int { tasks.reduce(0) { $0 + $1.externalCount } }

  /// Every tap in this project, of either kind.
  var distractionCount: Int { internalCount + externalCount }
}
