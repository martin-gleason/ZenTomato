import Foundation
import SwiftData

/// One finished block, written to the database the moment it ends.
///
/// WHY THE ENGINE WRITES THESE AND NOT SOME LATER FEATURE
/// The engine is the only thing that ever knows a block has ended — whether it
/// ran out, was skipped, or was dismissed from the Lock Screen. A history
/// feature that tried to reconstruct that afterwards would be guessing. So the
/// rows are written now, by the only code in a position to be right about
/// them, and a later feature reads them.
///
/// EVERY ROW IS WRITTEN, INCLUDING THE ABANDONED ONES
/// A skipped block still produces a row, marked abandoned. Two reasons. The
/// honest one: a record that quietly omits the blocks you bailed out of is a
/// record that flatters you, and the whole point of keeping one is that the
/// number means what it says. The practical one: "pomodoros today" has to mean
/// blocks *finished*, so the distinction has to be stored rather than inferred
/// from which rows exist.
///
/// NO COLUMN IS ADDED BEFORE SOMETHING READS IT
/// The row began with six fields, all about the block itself. The Todoist
/// feature added the four at the bottom — what the block was attached to — and
/// added them at the moment there was something to put in them and something to
/// read them back. None was added early and left empty: a field that is always
/// empty looks finished and is not, which is worse than a field that is absent.
@Model
final class PomodoroSession {
  /// The block's identity, carried over from the running timer state so that a
  /// finished row can be matched to the alarm that was set for it.
  var id: UUID

  /// Which kind of block this was. Only finished `work` blocks are pomodoros.
  var kind: BlockKind

  /// When the block began, on the wall clock.
  var startedAt: Date

  /// When it ended. For a block that ran out this is the moment it was due to
  /// end, not the moment the app noticed — the app may well have been closed.
  var endedAt: Date

  /// True when the block did not run to its end: skipped, stopped, or
  /// dismissed early from the Lock Screen. Abandoned blocks are excluded from
  /// every count.
  var wasAbandoned: Bool

  /// Why the person stopped, in their own words. `nil` for every block that ran
  /// to its end, and non-nil for every one they stopped.
  ///
  /// **This is the most valuable field on the row, and it is the only one the app
  /// cannot derive.** Everything else here is bookkeeping the timer knows by
  /// itself: when the block began, when it ended, whether it finished. Why it
  /// ended early is a thing only the person knows, and the moment they know it
  /// best is the moment they are stopping.
  ///
  /// The app therefore refuses to stop a block without one — see the stop sheet.
  /// That is a deliberate departure from how the distraction prompt behaves,
  /// where saying nothing is a normal outcome: there, the tap has already
  /// recorded the fact and the sentence adds colour. Here the fact of stopping
  /// is a single bit and the sentence is the whole content.
  var abandonReason: String?

  // MARK: What the block was attached to

  /// Todoist's identifier for the task this block was worked on, or `nil`.
  ///
  /// FOUR OPTIONAL COLUMNS, AND WHY EVERY ONE OF THEM IS ALLOWED TO BE EMPTY
  /// A block has an attachment when a session plan had something left in it at
  /// the moment the block began. It has none when nobody has connected Todoist,
  /// when there is no plan, when the plan has been worked through, or when the
  /// row was written before this feature existed at all. That is four ordinary
  /// situations, not four failures, so `nil` here means "this block was not
  /// attached to anything" and never "this has not been filled in yet".
  ///
  /// **They are a frozen copy, taken when the block began.** Renaming a task in
  /// Todoist afterwards cannot change what this row says was worked on, and a
  /// task deleted in Todoist next week leaves this row still telling the truth
  /// about last Tuesday. That is the entire reason the words are copied here
  /// rather than looked up later.
  var taskID: String?

  /// The task's title, as it read when the block began.
  var taskTitle: String?

  /// Todoist's identifier for the project — of the attached task, or of a
  /// project planned on its own.
  var projectID: String?

  /// The project's name, as it read when the block began.
  var projectTitle: String?

  /// Creates a finished-block row. Every value about the block itself is
  /// required: there is no sensible default for any of them, and a default would
  /// only ever hide a caller that forgot to say. The four attachment values do
  /// default to nothing, because "attached to nothing" is a real and common
  /// answer rather than a missing one.
  init(
    id: UUID,
    kind: BlockKind,
    startedAt: Date,
    endedAt: Date,
    wasAbandoned: Bool,
    abandonReason: String? = nil,
    taskID: String? = nil,
    taskTitle: String? = nil,
    projectID: String? = nil,
    projectTitle: String? = nil) {
    self.id = id
    self.kind = kind
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.wasAbandoned = wasAbandoned
    self.abandonReason = abandonReason
    self.taskID = taskID
    self.taskTitle = taskTitle
    self.projectID = projectID
    self.projectTitle = projectTitle
  }
}
