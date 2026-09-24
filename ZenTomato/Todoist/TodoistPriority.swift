import Foundation

/// A task's priority, as Todoist's own numbers mean it (`F13`).
///
/// **THE DIRECTION WAS ESTABLISHED BY RUNNING SOMETHING, NOT BY READING.**
/// `docs/conventions.md`: a decision about what another system can do is not
/// ratifiable until a command has run. `scripts/check-todoist-facts.sh` `CLAIM 4`
/// was run against the owner's real account on 2026-09-24 and the tally was
/// `{1: 9, 2: 11, 3: 22, 4: 8}` over 50 tasks. The account's own contents settle
/// which end is urgent: *Select 1 to 3 MITs*, *AM Check Inboxes* and *Journal*
/// are all `4`, while *Clean the downstairs bathroom*, *print a few flyers* and
/// *fix printer* are all `1`.
///
/// So **wire `4` is the `P1` Todoist's app draws, and wire `1` is `P4`** — the
/// default a task has when nobody has set one. The numbers run opposite to the
/// labels, which is exactly why nothing was written against a guess: `CachedTask`
/// stores the wire value verbatim and this type is the only place the two
/// vocabularies meet. `F13-M3` inverts this mapping and
/// `priorityIsReadInTodoistsDirection` is what goes red.
///
/// **`priority` is never absent, which the plan did not expect.** All 50 tasks on
/// that account carried the key. So "no flag" is the value `natural`, not a
/// missing field — and the optional initialiser below exists for the shape of the
/// mirror's column, not because Todoist declines to answer.
enum TodoistPriority: Int, CaseIterable, Sendable {
  /// Wire `1`. Todoist draws this as `P4` and it is what a task has when nobody
  /// has set a priority. **The picker draws nothing at all for it.**
  case natural = 1

  /// Wire `2`. Todoist draws this as `P3`.
  case moderate = 2

  /// Wire `3`. Todoist draws this as `P2`.
  case high = 3

  /// Wire `4`. Todoist draws this as `P1`, its most urgent.
  case urgent = 4

  // MARK: Lifecycle

  /// Reads the mirror's column, which holds the number Todoist sent.
  ///
  /// `nil` for an absent column and for any number outside `1...4`. A value
  /// Todoist has not used before is **not** coerced onto the nearest level: a
  /// wrong flag is worse than no flag, because it claims something about a task
  /// that nobody said.
  init?(wire: Int?) {
    guard let wire, let value = TodoistPriority(rawValue: wire) else { return nil }
    self = value
  }

  // MARK: Internal

  /// The label Todoist's own app shows, so the two agree on screen.
  ///
  /// `P1` for `urgent`, down to `P4` for `natural` — the inverse of the wire
  /// number, computed rather than written out, so the pairing cannot drift.
  var todoistLabel: String {
    "P\(5 - rawValue)"
  }

  /// Whether the picker marks a task carrying this priority.
  ///
  /// **ONLY THE TOP LEVEL, AND THAT IS A CHANGE THE ACCOUNT FORCED.** The gate
  /// answer taken from the plan was *draw the top two*, and the live tally makes
  /// that wrong: wire `3` alone is 22 of 50 tasks, so the top two would mark
  /// **30 rows in 50 — 60%**. The design system's own discipline is that a
  /// warning colour *"marks exactly one thing per screen"*, and the plan said in
  /// as many words that *"a picker where half the rows are amber has spent that
  /// budget on somebody else's data."* Drawing only `urgent` marks 8 rows in 50,
  /// which is a mark worth noticing.
  ///
  /// It is one line, and `F13.md` §11 records that it is the owner's to overrule.
  var isMarked: Bool {
    self == .urgent
  }

  /// What a reader who cannot see the flag is told.
  ///
  /// **Priority is information and is treated as the opposite of the tint.** A
  /// swatch is hidden from VoiceOver because it duplicates the project name; a
  /// flag glyph that speaks as nothing is information withheld from exactly the
  /// reader who cannot see it. It speaks Todoist's own label, because that is the
  /// word the owner set in the other app.
  var spokenName: String {
    "priority \(todoistLabel)"
  }
}
