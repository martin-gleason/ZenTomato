import Foundation
import SwiftData

/// A copy of one open Todoist task, kept so the picker works offline.
///
/// **Every row here is a task that was open at the moment of the last refresh.**
/// Todoist's read endpoints return active objects only: a task that has been
/// finished, or deleted, simply stops appearing. That is why there is no column
/// saying whether a task is finished — such a column would be false on every row
/// this app ever stores, which looks finished and is not. It is also why the app
/// cannot tell "completed" from "deleted": both are the same absence, and the
/// endpoint that would distinguish them is not one this app is allowed to call.
/// The plan screen says so plainly rather than guessing.
///
/// The build contract (§3.2) lists every Todoist field left out of this table
/// and gives a reason for each. Adding one is a visible argument with that
/// table, not a small commit.
@Model
final class CachedTask {
  /// Todoist's own identifier — an opaque string, never a number.
  ///
  /// This is the value that a plan item stores, and the value the one write
  /// this app can make is addressed to.
  var id: String

  /// The task's title.
  ///
  /// Todoist calls this field `content`, and the name is kept so that anybody
  /// holding this file next to Todoist's documentation is reading the same word
  /// in both places. It is what the picker draws, and what a plan item and a
  /// finished block each keep their own frozen copy of.
  var content: String

  /// Which project the task belongs to. A copied identifier, not a database
  /// link — see `CachedSection.projectID` for why this app never uses links.
  var projectID: String

  /// Which section it sits in, or `nil` when it is loose in the project.
  ///
  /// `nil` here is a real, permanent fact about the task — "not in a section" —
  /// and not a value waiting to be filled in later.
  var sectionID: String?

  /// Todoist's own position for this task. Copied so the picker lists tasks in
  /// the order the person arranged them.
  var childOrder: Int

  /// When this row was fetched. Freshness only — see `CachedProject.syncedAt`.
  var syncedAt: Date

  /// Whether Todoist says this task has a recurring due date (D21).
  ///
  /// **Mirrored, not invented.** It is Todoist's own `is_recurring`, which
  /// arrives on the task's `due` object — a field the build contract's
  /// not-mirrored table (`F3-contract.md` §3.2) lists by name. D21 is the
  /// visible argument with that table which the table itself demands, and it
  /// moves exactly one boolean across: no date, no schedule string, no time
  /// zone, and nothing from which a recurrence rule could be rebuilt.
  ///
  /// It exists so that the one place a completion is recorded can ask what was
  /// true at that moment. Nothing else reads it, and it is thrown away and
  /// rewritten on every refresh like every other column here.
  ///
  /// `false` when the task has no due date at all, which is an ordinary task
  /// rather than a failure.
  var isRecurring: Bool = false

  /// Creates one mirrored row.
  ///
  /// - Parameter isRecurring: defaults to `false` so that the many tests which
  ///   build a plain task need not state it. That default is safe **here** and
  ///   not on `CompletedTaskRecord` for one reason: these rows are deleted and
  ///   rewritten in full on every refresh from Todoist's own answer, so a wrong
  ///   value corrects itself within one foreground, whereas a completion is
  ///   written once and never revisited.
  init(
    id: String,
    content: String,
    projectID: String,
    sectionID: String?,
    childOrder: Int,
    syncedAt: Date,
    isRecurring: Bool = false) {
    self.id = id
    self.content = content
    self.projectID = projectID
    self.sectionID = sectionID
    self.childOrder = childOrder
    self.syncedAt = syncedAt
    self.isRecurring = isRecurring
  }
}
