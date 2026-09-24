import Foundation
import Testing

@testable import ZenTomato

/// Tests for the Todoist tint vocabulary — `F13-T1`.
///
/// WHAT THESE PROVE, AND WHAT THEY DELIBERATELY DO NOT
/// `TodoistPalette` is a transcription of somebody else's table, and the ways a
/// transcription goes wrong are the ways `DesignTokenTests` already names: a hex
/// typo that still compiles, and a claim that stopped being true.
///
/// **But a test that restates the table proves nothing.** Asserting
/// `TodoistTint.berryRed.value(dark: false) == RGBColor(hex: 0xB8255F)` is the
/// same twenty numbers written twice, and a copy-paste error copied into both
/// places passes. So the assertions below are about *relationships between the
/// rows* — distinctness, the name round trip, the unknown fallback — which a
/// copy-paste error breaks and a correct table satisfies.
///
/// THE ONE ASSUMPTION ABOUT AN EXTERNAL SYSTEM, CHECKED RATHER THAN ASSUMED.
/// `everyTodoistTintIsDistinct` is only a fair test if Todoist's own twenty
/// colours really are twenty distinct values. They are: read from
/// `src/utils/colors.ts` at commit `19798a37`, grouped by hex, no group larger
/// than one. Had two of Todoist's names shared a value, this test would have been
/// wrong and the table right, and the honest fix would have been to name the
/// duplicated pair here.
///
/// NOT MAIN-ACTOR. Nothing here touches SwiftData, a view, or the user's data.
struct TodoistTintTests {
  /// Every tint Todoist actually sends, i.e. everything a project can carry.
  /// `unknown` is excluded because it is deliberately an alias for charcoal and
  /// would fail a distinctness test by design.
  private var named: [TodoistTint] { TodoistTint.allCases.filter { $0 != .unknown } }

  @Test("the table holds Todoist's twenty colours and no more")
  func theTableIsTheSizeOfTodoistsPalette() {
    // Twenty is the count in the cited source. If Todoist adds a colour this
    // test fails, which is correct: somebody must read the new value out of the
    // source rather than guess it, and `unknown` covers the interim.
    #expect(named.count == 20)
  }

  @Test("no two tints resolve to the same colour")
  func everyTodoistTintIsDistinct() {
    for appearance in [false, true] {
      var seen: [RGBColor: TodoistTint] = [:]
      for tint in named {
        let value = tint.value(dark: appearance)
        if let clash = seen[value] {
          Issue.record("\(tint) and \(clash) are both \(value) (dark: \(appearance))")
        }
        seen[value] = tint
      }
      #expect(seen.count == named.count)
    }
  }

  @Test("every tint survives the round trip through the name Todoist sends")
  func everyTintRoundTripsThroughItsTodoistName() {
    // This is what catches a case whose `todoistName` does not match the name
    // Todoist uses — the derived-from-rawValue transformation is the thing under
    // test, and a wrong one silently sends a real project to `unknown`.
    for tint in named {
      #expect(TodoistTint(todoistName: tint.todoistName) == tint,
              "\(tint) round-tripped through '\(tint.todoistName)' and did not come back")
    }
  }

  @Test("the names are snake_case, which is the spelling Todoist sends")
  func theNamesAreTheSpellingTodoistUses() {
    #expect(TodoistTint.berryRed.todoistName == "berry_red")
    #expect(TodoistTint.oliveGreen.todoistName == "olive_green")
    #expect(TodoistTint.lightBlue.todoistName == "light_blue")
    // A single-word name must NOT gain an underscore.
    #expect(TodoistTint.teal.todoistName == "teal")
    // And nothing may claim to be the empty string except `unknown`, which has
    // no name Todoist would ever send.
    #expect(TodoistTint.unknown.todoistName.isEmpty)
    for tint in named {
      #expect(tint.todoistName.isEmpty == false)
    }
  }

  @Test("a colour Todoist has not told us about is drawn, not dropped")
  func anUnrecognisedColourFallsBackRatherThanFailing() {
    // The case this exists for: Todoist ships a new colour and this build has
    // never heard of it. A mirror that breaks on somebody else's release
    // schedule is worse than one that draws the default.
    #expect(TodoistTint(todoistName: "ultraviolet_2027") == .unknown)
    #expect(TodoistTint(todoistName: "") == .unknown)
    // A workspace project carries no `color` key at all, which arrives as nil.
    #expect(TodoistTint(todoistName: nil) == .unknown)
    // And the fallback is Todoist's own default, so an unknown project looks the
    // way it looks in Todoist rather than looking broken.
    #expect(TodoistTint.unknown.value(dark: false) == TodoistTint.charcoal.value(dark: false))
    #expect(TodoistTint.unknown.value(dark: true) == TodoistTint.charcoal.value(dark: true))
  }

  @Test("the case's own spelling is never accepted as Todoist's")
  func camelCaseIsNotATodoistName() {
    // Guards the direction that would otherwise pass by accident: `rawValue` is
    // `berryRed`, and if the lookup table were built from raw values instead of
    // from `todoistName` every multi-word colour would be silently unknown while
    // the round-trip test above still passed.
    #expect(TodoistTint(todoistName: "berryRed") == .unknown)
    #expect(TodoistTint(todoistName: "oliveGreen") == .unknown)
  }

  @Test("a tint reports the same colour in both appearances, on purpose")
  func aTintIsNotReinterpretedForDarkMode() {
    // Not an omission — the decision in `TodoistTint.pair`. These colours belong
    // to the user's Todoist account, and lightening one for dark mode would be
    // this app editing somebody else's project colour so our page looks better.
    // Visibility is bought by the unconditional `borderStrong` ring instead.
    //
    // The test is here so that a future change to that decision has to be
    // deliberate and has to say so, rather than arriving as a one-line nudge.
    for tint in TodoistTint.allCases {
      #expect(tint.value(dark: false) == tint.value(dark: true),
              "\(tint) differs between appearances; if that is intended, this test is the record")
    }
  }
}
