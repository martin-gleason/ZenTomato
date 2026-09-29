import Testing

@testable import ZenTomato

/// The two scales that are not colours: spacing and corner radius.
///
/// **Split out of `DesignTokenTests` on 2026-09-29, when that file crossed its 400-line cap.** The seam
/// is real rather than arbitrary: everything left behind is about *colour* — roles, their published
/// values, and the contrast each is audited at — and these two are about *geometry*. They share the
/// design system and nothing else, and neither reads a `ColorRole`.
///
/// The cap is what forced the question, and the answer was to cut where the subject changes rather than
/// to trim the reasoning in the comments, which is the other way a file gets under a limit and the
/// worse one.
@Suite("DesignScale")
struct DesignScaleTests {
  // MARK: The non-colour scales

  /// The spacing scale is the design system's four-point ramp, unchanged.
  ///
  /// These are plain point values and do NOT grow with the reader's text size.
  /// That is correct on iOS: the system scales type and layouts reflow around
  /// it, while Apple's own layout margins stay fixed at every text size.
  /// Scaling the gaps as well would double-count.
  @Test("spacingScaleIsTheFourPointRamp")
  func spacingScaleIsTheFourPointRamp() {
    #expect(Spacing.none == 0)
    #expect(Spacing.xxxs == 2)
    #expect(Spacing.xxs == 4)
    #expect(Spacing.xs == 8)
    #expect(Spacing.sm == 12)
    #expect(Spacing.md == 16)
    #expect(Spacing.lg == 24)
    #expect(Spacing.xl == 32)
    #expect(Spacing.xxl == 48)
    #expect(Spacing.xxxl == 64)

    #expect(Spacing.borderNone == 0)
    #expect(Spacing.borderHairline == 1)
    #expect(Spacing.borderThin == 2)
    #expect(Spacing.borderThick == 3)

    // Apple's minimum touch target, which is also the design system's control
    // height. The two agree, so this one number is both rules at once.
    #expect(Spacing.controlHeight == 44)
  }

  /// Corners stay sharp.
  ///
  /// The radius scale tops out at 6 points against iOS's own 16 to 26. That gap
  /// is the single most legible signal that a person chose the shape, so a
  /// well-meaning rounding-up is exactly what this test exists to stop.
  @Test("radiusScaleStaysSharp")
  func radiusScaleStaysSharp() {
    #expect(Radius.none == 0)
    #expect(Radius.xs == 2)
    #expect(Radius.sm == 3)
    #expect(Radius.md == 4)
    #expect(Radius.lg == 6)

    // A `Radius.lg <= 6` line sat here. Directly under the `== 6` above, it
    // could not fail, and an assertion that cannot fail makes a suite look
    // more thorough than it is.
  }
}
