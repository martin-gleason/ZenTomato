import Foundation
import SwiftData

/// Whether a planned item is one task or a whole project.
///
/// Todoist's identifiers are opaque strings, so a project's identifier and a
/// task's identifier are indistinguishable by looking at them — and only a task
/// can be ticked off. Without this the app could not tell which of the two it
/// was holding, so this is not a convenience.
///
/// It has a text value (`"task"`, `"project"`) rather than being stored as a
/// bare number, so that anybody reading the database file off a phone can see
/// what a row says without a decoder ring.
enum PlanItemKind: String, Codable, Sendable, CaseIterable {
  case task
  case project
}

/// One entry in the session plan: a pointer at something in Todoist, and the
/// words to draw for it.
///
/// # The fence this type exists inside
///
/// **A plan item stores a Todoist identifier and a title snapshot. Nothing
/// else.** It is a queue of references in exactly the sense a playlist is a
/// queue of references and not a music library.
///
/// It does not store the task's text, when it is due, how urgent it is, what it
/// is tagged with, what it belongs to, or whether it has been finished. It
/// defines no structure — a plan is flat even when it holds a project and tasks
/// from inside that same project. Nothing on it can be edited.
///
/// **Why that is written so forcefully.** An ordered list of tasks is one field
/// away from being the local copy of Todoist this app is forbidden to keep, and
/// the way it happens is never a bad decision — it is four good ones. "The plan
/// should show which ones are done." "It should sort by what's due first."
/// "Grey out the finished ones." Each is one small commit, each is obviously
/// useful, and the destination is a second task model nobody designed, with no
/// rules about which copy wins, sitting between this app and Todoist.
///
/// So the fence is mechanical rather than a promise: `planItemHasFourStoredProperties`
/// asks the database layer what columns this type actually has and fails if the
/// answer is not exactly the four below. A fifth column cannot be added quietly;
/// it has to be added along with the deliberate act of changing that test.
///
/// **The two answers that would otherwise become columns**, both of which are
/// questions the app can already answer without storing anything:
///
///   * *Is this one finished?* — either its identifier is missing from the last
///     refresh of the mirror, or this app has a completion record for it. Both
///     are lookups.
///   * *Which one am I on?* — the cursor on `SessionPlan`.
@Model
final class SessionPlanItem {
  /// Todoist's identifier for the task or project this item points at — an
  /// opaque string, never a number.
  var todoistID: String

  /// The title as it read when the plan was built.
  ///
  /// **This is why the plan does not chase Todoist.** A planned task can be
  /// renamed, finished, or deleted between planning it and working it. When
  /// that happens the item still shows these words, with a quiet note that it is
  /// no longer there, and it can be stepped over. The plan is a record of
  /// intent, and intent is not invalidated by the world moving.
  var titleSnapshot: String

  /// Whether this points at a task or at a project.
  var kind: PlanItemKind

  /// Where this sits in the list, counting from zero.
  ///
  /// This is a property of the *list*, not of the thing in Todoist — it says
  /// nothing whatsoever about the task, and Todoist neither knows nor cares
  /// about it. An order has to be written down somewhere, and with no links
  /// between rows this is the only place it can go.
  var position: Int

  /// Creates one entry. Entries are only ever created together, when a plan is
  /// built, and are never edited afterwards.
  init(todoistID: String, titleSnapshot: String, kind: PlanItemKind, position: Int) {
    self.todoistID = todoistID
    self.titleSnapshot = titleSnapshot
    self.kind = kind
    self.position = position
  }
}
