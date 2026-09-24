import Foundation
import SwiftData

/// A copy of one Todoist project, kept so the picker works offline.
///
/// WHAT "CACHE" MEANS HERE, AND WHAT IT DELIBERATELY DOES NOT MEAN
/// This is a photograph of Todoist, not a second copy of the truth. Every field
/// below except `syncedAt` is a verbatim copy of a field Todoist sent, and the
/// whole table is thrown away and rewritten on each refresh. Nothing in this
/// app ever changes one of these rows, so there is no local version of a project
/// that could disagree with Todoist's.
///
/// **That is the project's hardest data rule, and this is where it is kept:**
/// Todoist is the only place tasks live, and this app has no task model of its
/// own. The moment one of these rows gained a field this app maintained — a
/// local ordering, a flag, a note — there would be two accounts of one project
/// and a question about which one wins. There is no such field, and the build
/// contract (§3.2) lists every Todoist field deliberately left out, so that
/// adding one is an argument with a written table rather than a small
/// reasonable commit.
///
/// Rows are written by exactly one thing — `TodoistCacheStore.refresh()` — and
/// read by the picker.
@Model
final class CachedProject {
  /// Todoist's own identifier.
  ///
  /// **A string, never a number.** Todoist's v1 API made every identifier an
  /// opaque string — they look like `6XGgmFVcrG5RRjVr` — and it will not accept
  /// the numeric ones the older APIs used. A column that stored a number here
  /// would reject every real project.
  var id: String

  /// The project's name, as drawn in the picker.
  var name: String

  /// Todoist's own position for this project among its siblings.
  ///
  /// Copied rather than computed, and that is the conservative choice, not a
  /// liberty: without it the picker would have to invent an order — alphabetical,
  /// or whatever the database happened to hand back — and inventing an order is
  /// exactly the local state this app is not allowed to have. It is written by a
  /// refresh and read by a sort, and nothing else touches it.
  var childOrder: Int

  /// When this row was fetched.
  ///
  /// **Freshness, and nothing else.** It is read by one line of the interface —
  /// the one that says how old the list is when the phone is offline. It is
  /// never compared between rows, never used to decide which copy wins, and
  /// never used to detect a change. Those would all be the beginnings of a
  /// synchronisation engine, which this version of the app does not have and is
  /// not preparing for.
  var syncedAt: Date

  /// The name of the colour this project is drawn in, as Todoist sends it —
  /// `berry_red`, `olive_green`.
  ///
  /// **`colorName` and not `color`, because it is not a colour.** It holds the
  /// key from Todoist's own palette; turning that key into something paintable is
  /// `TodoistTint`'s job, one layer away from the database. A column called
  /// `color` holding the seven characters `berry_red` is the kind of name that
  /// makes the next reader look for a hex.
  ///
  /// It is a copy, like everything else here, and it is `F13`'s visible argument
  /// with the build contract's not-mirrored table (`F3-contract.md` §3.2), which
  /// lists this field by name. The v1.5 spec ratified drawing it; §3.2 is amended
  /// in the same commit rather than in a later tidy-up.
  ///
  /// `nil` when Todoist did not say — which is the ordinary case for a workspace
  /// project, not a failure. It is drawn as Todoist's own default, not skipped.
  var colorName: String?

  /// Creates one mirrored row. Every value comes from Todoist except the
  /// timestamp, which is the moment of the refresh that fetched it.
  ///
  /// - Parameter colorName: defaults to `nil` so the many tests that build a
  ///   plain project need not state it. Safe here for the reason
  ///   `CachedTask.isRecurring` gives: these rows are deleted and rewritten in
  ///   full on every refresh from Todoist's own answer, so a wrong value corrects
  ///   itself within one foreground.
  init(id: String, name: String, childOrder: Int, syncedAt: Date, colorName: String? = nil) {
    self.id = id
    self.name = name
    self.childOrder = childOrder
    self.syncedAt = syncedAt
    self.colorName = colorName
  }
}
