import Foundation
import Testing

@testable import ZenTomato

/// Tests for Todoist's priority, as drawn and as spoken — `F13-T4`.
///
/// THE FIXTURE IS THE OWNER'S OWN ACCOUNT, NOT A HAND-BUILT DTO.
/// `docs/conventions.md` is explicit that an assertion re-deriving its own
/// expected value cannot see the path that produces the real one, and that a
/// claim about another system is not settled until something has run.
/// `scripts/check-todoist-facts.sh` `CLAIM 4` ran against the owner's real
/// account on 2026-09-24 and returned:
///
///     50 task(s), 50 carrying a priority key.
///     priority values seen: {1: 9, 2: 11, 3: 22, 4: 8}
///     priority=4  id=6fMv5XxhHQvmVx67  Select 1 to 3 MITs
///     priority=4  id=658m9CV63xqmqhV7  AM Check Inboxes
///     priority=1  id=6848wXp22GPJ8PH7  Clean the downstairs bathroom
///     priority=1  id=6hP83rmMx7R4PH5q  fix printer
///
/// **That output is the fixture below**, task ids and all. The direction is read
/// off what the tasks ARE — the owner's most-important-task selection and inbox
/// sweep are `4`, cleaning the bathroom and fixing the printer are `1` — and not
/// off documentation. `F13-M3` inverts the mapping and
/// `priorityIsReadInTodoistsDirection` is what goes red.
///
/// NOT MAIN-ACTOR. Nothing here touches SwiftData, a view, or the user's data.
struct TodoistPriorityTests {
  /// Four rows from the real response, verbatim, chosen because the two possible
  /// readings disagree about them.
  private struct CapturedTask {
    let wire: Int
    let id: String
    let title: String

    /// **Stated, not derived.** The first version of this test computed
    /// `expected = row.wire == 4`, which re-derives the expectation from the input
    /// and makes the ids and titles decoration — they appeared only in a failure
    /// message, and replacing them with anything at all changed no outcome. That is
    /// the re-derived-expected-value failure `docs/conventions.md` names, and
    /// `F13`'s adversarial review caught it. Each row now carries the reading a
    /// human took from the owner's account.
    let isMostUrgent: Bool
  }

  private static let captured = [
    // The owner's most-important-task selection and morning inbox sweep: the two
    // things a day is planned around, and the reason wire 4 reads as P1.
    CapturedTask(wire: 4, id: "6fMv5XxhHQvmVx67", title: "Select 1 to 3 MITs", isMostUrgent: true),
    CapturedTask(wire: 4, id: "658m9CV63xqmqhV7", title: "AM Check Inboxes", isMostUrgent: true),
    // Household chores, which nobody marks most-urgent.
    CapturedTask(
      wire: 1, id: "6848wXp22GPJ8PH7",
      title: "Clean the downstairs bathroom @cleaning", isMostUrgent: false),
    CapturedTask(wire: 1, id: "6hP83rmMx7R4PH5q", title: "fix printer", isMostUrgent: false)
  ]

  @Test("priorityIsReadInTodoistsDirection")
  func priorityIsReadInTodoistsDirection() {
    // Wire 4 is what Todoist's own app labels P1 — its most urgent — and wire 1
    // is P4, the value a task has when nobody set one.
    #expect(TodoistPriority(wire: 4) == .urgent)
    #expect(TodoistPriority(wire: 1) == .natural)
    #expect(TodoistPriority(wire: 4)?.todoistLabel == "P1")
    #expect(TodoistPriority(wire: 3)?.todoistLabel == "P2")
    #expect(TodoistPriority(wire: 2)?.todoistLabel == "P3")
    #expect(TodoistPriority(wire: 1)?.todoistLabel == "P4")

    // And against the captured rows: the owner's daily-driver tasks are marked,
    // the household chores are not. An inverted mapping fails here on all four.
    for row in Self.captured {
      let priority = TodoistPriority(wire: row.wire)
      #expect(priority?.isMarked == row.isMostUrgent,
              "\(row.title) (wire \(row.wire), id \(row.id)) marked=\(priority?.isMarked ?? false)")
      #expect((priority?.todoistLabel == "P1") == row.isMostUrgent,
              "\(row.title) reads as \(priority?.todoistLabel ?? "nothing")")
    }
  }

  @Test("onlyTheTopPriorityIsMarked")
  func onlyTheTopPriorityIsMarked() {
    // THE LIVE TALLY IS WHY THIS IS ONE LEVEL AND NOT TWO. {1: 9, 2: 11, 3: 22,
    // 4: 8} over 50 tasks: marking the top two would mark 30 rows in 50. The gate
    // answer taken from the plan was "the top two", and the account overruled it.
    #expect(TodoistPriority.urgent.isMarked)
    #expect(TodoistPriority.high.isMarked == false)
    #expect(TodoistPriority.moderate.isMarked == false)
    #expect(TodoistPriority.natural.isMarked == false)

    // The owner's live tally, and what `isMarked` selects out of it. Eight of
    // fifty. Widening `isMarked` to `.high` gives thirty, so this number is what
    // makes that a deliberate change rather than a one-line nudge.
    //
    // The count of 50 is NOT asserted here: it would be arithmetic over a literal
    // declared three lines above, which proves nothing about anything.
    let tally = [1: 9, 2: 11, 3: 22, 4: 8]
    let marked = tally.reduce(into: 0) { total, entry in
      if TodoistPriority(wire: entry.key)?.isMarked == true { total += entry.value }
    }
    #expect(marked == 8)
  }

  @Test("aPriorityOutsideTodoistsRangeIsNotGuessedAt")
  func aPriorityOutsideTodoistsRangeIsNotGuessedAt() {
    // A wrong flag is worse than no flag: it claims something about a task that
    // nobody said. So an unknown number is nil rather than coerced to the nearest
    // level — unlike a colour, where falling back to Todoist's own default draws
    // the project correctly.
    #expect(TodoistPriority(wire: 0) == nil)
    #expect(TodoistPriority(wire: 5) == nil)
    #expect(TodoistPriority(wire: -1) == nil)
    #expect(TodoistPriority(wire: nil) == nil)
  }

  /// `@MainActor` on this one test, and it is not optional: `PickerRowView` is a
  /// SwiftUI view, and every member of one — **including a static function that
  /// touches nothing** — belongs to the main thread. Without it the test process
  /// does not fail, it *crashes*, the run restarts, and the three passing tests in
  /// this suite are reported as failures by a summary that adds up totals across
  /// launches. `PickerScreenModelTests.aRowSpeaksItsSecondLine` already carried
  /// this annotation and the reason for it; I did not read it first.
  @Test("spokenTaskLabelNamesPriority")
  @MainActor
  func spokenTaskLabelNamesPriority() {
    // The flag is hidden from VoiceOver and the priority is spoken instead, so a
    // reader who cannot see the glyph is told the same thing.
    let marked = PickerRowView.spokenToggleLabel(
      title: "Select 1 to 3 MITs", subtitle: nil, ordinal: 2, priority: .urgent)
    #expect(marked == "Select 1 to 3 MITs, priority P1, number 2 in your plan")

    // An unmarked priority says nothing. "Priority P4" on the many tasks nobody
    // flagged would make every row longer to hear and tell a reader nothing.
    let unmarked = PickerRowView.spokenToggleLabel(
      title: "fix printer", subtitle: nil, ordinal: nil, priority: .natural)
    #expect(unmarked == "fix printer, not in your plan")

    // And a project row, which has no priority at all, is unchanged by F13.
    let project = PickerRowView.spokenToggleLabel(
      title: "Dissertation", subtitle: "3 tasks", ordinal: 1, priority: nil)
    #expect(project == "Dissertation, 3 tasks, number 1 in your plan")
  }
}
