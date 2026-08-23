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

  /// Creates one mirrored row.
  init(
    id: String,
    content: String,
    projectID: String,
    sectionID: String?,
    childOrder: Int,
    syncedAt: Date) {
    self.id = id
    self.content = content
    self.projectID = projectID
    self.sectionID = sectionID
    self.childOrder = childOrder
    self.syncedAt = syncedAt
  }
}
