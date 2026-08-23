import Foundation
import Testing

@testable import ZenTomato

/// Tests for the segmented rule that shows how far through a sprint you are.
///
/// WHY THIS IS ITS OWN SUITE RATHER THAN A CASE IN THE TOKEN AUDIT
/// Every pairing in `DesignTokenTests` measures an ink against a *ground*, which
/// is the only question worth asking while the information on a screen lives in
/// text on a page. This rule is the first thing in the app where the information
/// lives in the difference between two inks sitting **next to each other**: a
/// finished segment beside an unfinished one. That is a different question, it
/// has a different threshold, and it needed a different test — the audit next
/// door passed on the day the rule was invisible.
@Suite("Sprint progress")
struct SprintProgressTests {
  /// The two states of the rule are told apart by something other than colour.
  ///
  /// WHAT WENT WRONG AND WHY IT IS RECORDED RATHER THAN REPAINTED
  /// A finished segment is drawn in the app's sage and an unfinished one in its
  /// strong grey. Both are chosen to stand out against the page, and both do.
  /// Against **each other** they measure about 1.37:1 in light and 1.39:1 in
  /// dark — two colours of almost identical lightness, which on a two-point rule
  /// reads as one unbroken line. The accessibility standard asks for 3:1 between
  /// anything a reader has to tell apart, and separately forbids carrying
  /// information by colour alone; this failed both, and a screenshot of a
  /// half-finished sprint was indistinguishable from a finished one.
  ///
  /// Repainting either ink would cost it its contrast against the page or spend
  /// the app's one colour somewhere it does not belong, so the distinction is
  /// carried by height instead: a finished segment is twice as tall. The two
  /// measurements below are therefore asserted as they are — low — so that the
  /// day somebody removes the height difference, this test says why it was there.
  @Test("filledAndEmptySegmentsAreNotDistinguishedByColourAlone")
  func filledAndEmptySegmentsAreNotDistinguishedByColourAlone() {
    // Each segment is visible against the page it is drawn on, in both
    // appearances. That part was always true and stays checked.
    DesignTokenTests.expectContrast(
      DesignTokenTests.Pairing(
        foreground: .action, background: .surfacePrimary, minimum: ContrastRatio.nonTextMinimum))
    DesignTokenTests.expectContrast(
      DesignTokenTests.Pairing(
        foreground: .borderStrong, background: .surfacePrimary, minimum: ContrastRatio.nonTextMinimum))

    // Against each other they are not, which is the finding this records.
    let light = ContrastRatio.between(ColorRole.action.light, and: ColorRole.borderStrong.light)
    let dark = ContrastRatio.between(ColorRole.action.dark, and: ColorRole.borderStrong.dark)
    #expect(light < ContrastRatio.nonTextMinimum)
    #expect(dark < ContrastRatio.nonTextMinimum)

    // So the shape has to carry it. A finished segment is at least twice the
    // height of an unfinished one — a step a reader can see at any colour
    // vision, in either appearance, and in a photograph.
    #expect(SprintProgressView.filledHeight >= SprintProgressView.emptyHeight * 2)
  }
}
