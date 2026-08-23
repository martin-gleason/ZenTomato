import Foundation
import SwiftData

/// A copy of one Todoist section, kept so the picker works offline.
///
/// A section is Todoist's grouping inside a project. The picker draws exactly
/// three levels — project, section, task — and nothing deeper, because a plan is
/// flat and drawing a hierarchy the plan cannot hold is how a plan starts
/// becoming a task model one reasonable step at a time.
///
/// Like the other two mirrors: every field is a verbatim copy of a Todoist
/// field except `syncedAt`, nothing in the app ever edits one, and the whole
/// table is replaced on each refresh. See `CachedProject` for why that shape is
/// the point rather than a simplification.
@Model
final class CachedSection {
  /// Todoist's own identifier — an opaque string, never a number.
  var id: String

  /// The section's name, drawn as the heading above its tasks.
  var name: String

  /// Which project this section belongs to.
  ///
  /// WHY A COPIED IDENTIFIER RATHER THAN A DATABASE LINK
  /// SwiftData can express "this section belongs to that project" as a real
  /// relationship, and this app deliberately never does — here, or anywhere.
  /// Two reasons. A relationship is a piece of structure *this app* would own
  /// and maintain, and the whole claim of these three tables is that they own
  /// no structure of their own. And a refresh throws every row away and writes
  /// fresh ones, which relationships would turn into a graph-rebuilding problem
  /// for no gain. The distraction rows already carry a copied block identifier
  /// for the same reason; this is the house style, not a special case.
  var projectID: String

  /// Todoist's own position for this section within its project. Copied so the
  /// picker shows sections in the order the person arranged them.
  var sectionOrder: Int

  /// When this row was fetched. Freshness only — see `CachedProject.syncedAt`.
  var syncedAt: Date

  /// Creates one mirrored row.
  init(id: String, name: String, projectID: String, sectionOrder: Int, syncedAt: Date) {
    self.id = id
    self.name = name
    self.projectID = projectID
    self.sectionOrder = sectionOrder
    self.syncedAt = syncedAt
  }
}
