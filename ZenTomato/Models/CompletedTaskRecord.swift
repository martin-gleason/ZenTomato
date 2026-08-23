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
/// **This is a record of something this app did. It is not a task list.** Three
/// columns, no hierarchy, no project, no status, nothing that could grow into a
/// second copy of Todoist. It is the same shape as the finished-block rows the
/// timer already writes: an identifier, a frozen title, and a time.
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

  /// Creates the record. Called from exactly one place, after a successful
  /// close, and from nowhere else.
  init(taskID: String, titleSnapshot: String, completedAt: Date) {
    self.taskID = taskID
    self.titleSnapshot = titleSnapshot
    self.completedAt = completedAt
  }
}
