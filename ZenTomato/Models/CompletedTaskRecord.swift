import Foundation
import SwiftData

/// One task this app ticked off in Todoist, and when.
///
/// WHY THIS ROW EXISTS WHEN TODOIST ALREADY KNOWS
/// Todoist knows what you completed, and it stays the only place tasks live —
/// that is not in question. But the export this app builds for a paper review is
/// assembled offline, at a table, two weeks later. Reaching across the network
/// to build it would make a retrospective depend on being signed in and on
/// having a connection. So the fact is written down locally at the moment it
/// happens.
///
/// **This is a record of something this app did. It is not a task list.** Four
/// columns, no hierarchy, no project, no status, nothing that could grow into a
/// second copy of Todoist. It is very nearly the same shape as the
/// finished-block rows the timer already writes: an identifier, a frozen title,
/// a time, and — since D21 — whether Todoist called the task recurring when it
/// was closed. See `wasRecurring` for why that fourth one is not the beginning
/// of a task model.
///
/// TWO RULES THAT MAKE IT TRUSTWORTHY
///
///   1. **Append-only.** A row is written and never changed and never deleted —
///      not even when somebody signs out of Todoist. Signing out removes the
///      credential and the mirrored copy of somebody else's data; this is not
///      somebody else's data, it is this app's own history.
///
///   2. **Written only after Todoist confirms.** The row is inserted after the
///      close command has succeeded, never before and never optimistically. A
///      local row claiming a completion that failed would be worse than no row
///      at all, because the whole value of the log is that the numbers mean
///      what they say.
@Model
final class CompletedTaskRecord {
  /// Todoist's identifier for the task that was closed — an opaque string.
  var taskID: String

  /// The task's title as it read at the moment it was completed.
  ///
  /// A frozen copy, deliberately. A title read live at export time would
  /// rewrite history whenever somebody renamed a task in Todoist, and a
  /// two-week-old review would quietly stop describing the two weeks it covers.
  var titleSnapshot: String

  /// When Todoist confirmed the close.
  var completedAt: Date

  /// Whether Todoist said this task was recurring at the moment it was closed
  /// (D21).
  ///
  /// **Why a fourth column does not make this a task list.** The other three
  /// say *what was closed, called what, and when*. This one says what kind of
  /// achievement it was, and it is here because without it the fortnightly
  /// review cannot tell them apart: closing a recurring task in Todoist does
  /// not finish it, it advances it to the next occurrence, so one daily habit
  /// lands on eight days of fourteen in the same list as *finished Chapter 3*
  /// with nothing to explain the difference. It is one boolean, frozen at the
  /// moment of the close, describing what was true then. It is **not** a
  /// recurrence rule, a schedule, a due date, or anything from which one could
  /// be reconstructed — there is no hierarchy here, no status, and still
  /// nothing that could grow into a second copy of Todoist.
  ///
  /// **It is read from Todoist's own answer, never inferred from repetition.**
  /// Guessing "anything that appears more than once is a habit" is a heuristic
  /// standing in for a fact Todoist already knows, and it is wrong for a task
  /// genuinely done twice and for a habit kept once in a quiet fortnight.
  ///
  /// **False is also what "we could not tell" looks like, and that is a
  /// deliberate, visible loss.** The answer is read from the local copy of the
  /// task, so a completion recorded while signed out, or after the copy was
  /// cleared, records `false` and appears among the one-off completions. A
  /// third state would be a larger and much quieter loss: this project's lint
  /// rules forbid an optional boolean by name, and D21 says *one boolean*.
  ///
  /// The stored default exists so that rows written before this column existed
  /// read as `false` without a migration plan. **The initialiser below has no
  /// default**, which is what forces the one call site — and any future one —
  /// to state the answer rather than inherit it by accident.
  var wasRecurring: Bool = false

  /// Creates the record. Called from exactly one place, after a successful
  /// close, and from nowhere else.
  ///
  /// - Parameter wasRecurring: deliberately has no default. A silent `false`
  ///   here would empty the export's *Repeating* section for good, and it would
  ///   do it silently — the section would simply look like a quiet fortnight.
  init(taskID: String, titleSnapshot: String, completedAt: Date, wasRecurring: Bool) {
    self.taskID = taskID
    self.titleSnapshot = titleSnapshot
    self.completedAt = completedAt
    self.wasRecurring = wasRecurring
  }
}
