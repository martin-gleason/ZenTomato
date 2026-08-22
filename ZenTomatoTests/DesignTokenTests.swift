import Foundation
import Testing

@testable import ZenTomato

/// Tests for the design-token layer.
///
/// WHAT THESE PROVE, AND WHY IT IS WORTH PROVING
/// The token layer is a transcription. Every colour in it was copied by hand
/// out of the Civic Data design system, and every one carries a measured
/// contrast figure in its comment explaining why it is that exact shade — the
/// action colour sits one step darker than the brand sage purely because the
/// brand hex measures 4.33 against the page and text needs 4.5.
///
/// A hand transcription can go wrong in two ways, and a person reading a diff
/// catches neither:
///
///   1. **A typo in a hex value.** `#5C7040` and `#5C7O40` do not look
///      different at a glance, and one of them still compiles.
///   2. **A contrast claim that stopped being true.** Somebody nudges a grey to
///      "warm it up" and text that used to clear the accessibility threshold
///      quietly stops clearing it. The comment still says 4.81.
///
/// The tests below read the values the app will actually draw and compare them
/// with the design system's published table, then measure the audited pairings
/// and assert the thresholds the token files claim — and check that no role can
/// be added without being measured. Together they mean the comments in the
/// token files cannot drift away from the code.
///
/// NOT MAIN-ACTOR, DELIBERATELY. Nothing here touches SwiftData or the user
/// interface. The whole point of keeping the semantic colour layer free of any
/// iOS type is that it is plain arithmetic, testable without a screen — so
/// these tests need no thread confinement and are not given any.
@Suite("Design tokens")
struct DesignTokenTests {
  // MARK: The published role table

  /// Every semantic role, with the exact colour the design system publishes for
  /// it in each appearance.
  ///
  /// Transcribed from the design system's role table, independently of the app
  /// source. That independence is the point: if a value here and a value in
  /// `ColorRole.swift` disagree, ONE OF THEM IS A TYPO, and the test says which
  /// role to look at. Check both against the design system before changing
  /// either.
  static let publishedRoles: [ColorRole: (light: UInt32, dark: UInt32)] = [
    // Surfaces. The inset is DARKER than the page in dark mode, which is
    // correct: a dark theme raises surfaces rather than casting shadows, so a
    // recess has to go the other way.
    .surfacePrimary: (0xF6F5F2, 0x1C1F22),
    .surfaceRaised: (0xFFFFFF, 0x24282C),
    .surfaceInset: (0xE7E4DB, 0x17191C),

    // Ink.
    .textPrimary: (0x22252A, 0xECE8DF),
    .textMuted: (0x5C5A52, 0xB3AEA3),
    .textSubtle: (0x6F6C63, 0x948F84),

    // Borders. Both appearances take the same value for `borderStrong`, and
    // that is not a copy-paste error — see `everyRoleResolvesInBothSchemes`.
    .border: (0xDEDBD4, 0x3A3F45),
    .borderStrong: (0x828074, 0x828074),

    // Action. `action` is NOT the brand sage #667A49: that hex measures 4.33
    // against the page and fails as text, so the role sits one step deeper.
    // Do not "correct" it back to the brand colour.
    .action: (0x5C7040, 0x8AA163),
    .actionHover: (0x4C5C36, 0x9CB377),
    .actionActive: (0x3F4C2D, 0xAEC48B),
    // Accents INVERT between appearances — pale ink on the light theme's
    // action, dark ink on the dark theme's. That inversion is the whole reason
    // this is a token and can never be assumed to be white.
    .onAction: (0xF6F5F2, 0x1C1F22),
    .actionSubtle: (0xE7EBDC, 0x2B3226),

    // Warning.
    .warning: (0xBD8024, 0xD99A3E),
    .onWarning: (0x22252A, 0x1C1F22),
    .warningText: (0x8A5E14, 0xDFA858),

    // Danger. The light theme's red is far too dark to read on a dark page,
    // which is why danger lightens in dark rather than staying put.
    .danger: (0xC0392B, 0xE06A50),
    .onDanger: (0xFFFFFF, 0x1C1F22),
    // Dark deliberately breaks the alias with `danger` and takes one step
    // lighter, because error text sits inside a raised block more often than it
    // sits bare on the page.
    .dangerText: (0xC0392B, 0xE67D65),

    .focus: (0x5C7040, 0x8AA163)
  ]

  /// Every role resolves to exactly the colour the design system publishes, in
  /// both appearances.
  ///
  /// This is the typo test. It also proves the two appearances did not get
  /// swapped, which is the other transcription mistake that compiles cleanly
  /// and looks wrong only once the app is running.
  @Test("everyRoleMatchesTheDesignSystem", arguments: ColorRole.allCases)
  func everyRoleMatchesTheDesignSystem(role: ColorRole) throws {
    let published = try #require(
      Self.publishedRoles[role],
      """
      The role '\(role.rawValue)' has no published value in this test's table. \
      A new role needs its light and dark values recorded here, from the design \
      system, in the same change that adds it — otherwise nothing checks it.
      """
    )

    #expect(
      role.light.hex == published.light,
      """
      \(role.rawValue) is \(role.light) in light mode; \
      the design system publishes \(RGBColor(hex: published.light)).
      """
    )
    #expect(
      role.dark.hex == published.dark,
      """
      \(role.rawValue) is \(role.dark) in dark mode; \
      the design system publishes \(RGBColor(hex: published.dark)).
      """
    )
  }

  /// Every role supplies a value for both appearances, and only one role gives
  /// the same value to both.
  ///
  /// WHY THE SECOND HALF MATTERS MORE THAN IT LOOKS
  /// A role whose two appearances are identical is either a deliberate decision
  /// or a copy-paste slip, and from the outside those look the same. There is
  /// exactly one deliberate case — the control outline, whose dark value was
  /// removed from the palette after it turned out to fail against a raised
  /// surface. Naming it here means the next accidental duplicate fails this
  /// test instead of shipping as a role that has quietly lost dark mode.
  @Test("everyRoleResolvesInBothSchemes")
  func everyRoleResolvesInBothSchemes() {
    // Every case must be listed in the published table, and vice versa — which
    // is what makes the per-role test above impossible to skip by adding a role.
    #expect(Self.publishedRoles.count == ColorRole.allCases.count)

    let identical = ColorRole.allCases.filter { $0.light == $0.dark }
    #expect(
      identical == [.borderStrong],
      """
      These roles resolve to the same colour in both appearances: \
      \(identical.map(\.rawValue).joined(separator: ", ")). Only borderStrong is \
      meant to. Any other is a role that has silently lost dark mode.
      """
    )
  }

  /// Every role that can be drawn ON something appears in a contrast pairing.
  ///
  /// The pairing lists below are hand-written on purpose, so the two documented
  /// exemptions stay visible rather than being papered over with a lowered
  /// threshold. The cost is that adding a role and forgetting to add a pairing
  /// is silent: the new ink ships unaudited while this suite reports green.
  /// `everyRoleResolvesInBothSchemes` forces a new role into the hex table;
  /// nothing forced it into a pairing. This does. Exempt are the grounds (drawn
  /// ON, never a foreground); `border`, a divider rather than the control edge
  /// — `borderStrong` is that, and is audited; and `actionHover` and `focus`,
  /// which nothing here draws.
  @Test("everyForegroundRoleIsAudited")
  func everyForegroundRoleIsAudited() {
    let neverAForeground: Set<ColorRole> = [
      .surfacePrimary, .surfaceRaised, .surfaceInset, .actionSubtle, .action,
      .actionActive, .warning, .danger, .border, .actionHover, .focus]
    let audited = Set((Self.textPairings + Self.borderPairings).map(\.foreground))
    let unaudited = Set(ColorRole.allCases).subtracting(audited).subtracting(neverAForeground)
    #expect(
      unaudited.isEmpty,
      """
      Nothing measures these roles as a foreground: \
      \(unaudited.map(\.rawValue).sorted().joined(separator: ", ")). Add a \
      pairing below, or — if the role is only ever a ground — add it to this \
      test's exemption list with the reason. An unaudited ink is unmeasured.
      """
    )
  }

  // MARK: Contrast

  /// One audited foreground-on-background pairing, with the threshold it is
  /// held to.
  struct Pairing: Sendable, CustomStringConvertible {
    let foreground: ColorRole
    let background: ColorRole
    let minimum: Double

    var description: String {
      "\(foreground.rawValue) on \(background.rawValue)"
    }
  }

  /// The pairings the design system audits as TEXT, each held to 4.5:1.
  ///
  /// DELIBERATELY NOT "EVERY INK ON EVERY GROUND". Two pairings measure below
  /// 4.5 on purpose, and both are documented as exempt rather than fixed:
  ///
  ///   * `textSubtle` on `surfaceInset` (4.13 in light). That combination
  ///     occurs only inside a control that is switched off, and the standard
  ///     exempts inactive components. The disabled Start button on the timer
  ///     screen is literally this case. Any use of that ink on an ENABLED inset
  ///     ground is a bug.
  ///   * `border` against anything. It draws dividers and decorative edges,
  ///     never the boundary that identifies a control — `borderStrong` does
  ///     that, and it is audited separately below.
  ///
  /// Listing the audited pairings explicitly, instead of generating every
  /// combination, is what keeps those two exemptions visible rather than
  /// papered over with a lowered threshold.
  static let textPairings: [Pairing] = [
    // Ink on the two grounds a reader actually reads on.
    Pairing(foreground: .textPrimary, background: .surfacePrimary, minimum: ContrastRatio.textMinimum),
    Pairing(foreground: .textPrimary, background: .surfaceRaised, minimum: ContrastRatio.textMinimum),
    Pairing(foreground: .textMuted, background: .surfacePrimary, minimum: ContrastRatio.textMinimum),
    Pairing(foreground: .textMuted, background: .surfaceRaised, minimum: ContrastRatio.textMinimum),
    Pairing(foreground: .textSubtle, background: .surfacePrimary, minimum: ContrastRatio.textMinimum),
    Pairing(foreground: .textSubtle, background: .surfaceRaised, minimum: ContrastRatio.textMinimum),

    // The action colour used AS TEXT. This is the timer screen's kicker, and
    // the only chromatic thing on that screen.
    Pairing(foreground: .action, background: .surfacePrimary, minimum: ContrastRatio.textMinimum),
    Pairing(foreground: .action, background: .surfaceRaised, minimum: ContrastRatio.textMinimum),
    Pairing(foreground: .textPrimary, background: .actionSubtle, minimum: ContrastRatio.textMinimum),

    // Ink on a filled control, at rest and pressed.
    Pairing(foreground: .onAction, background: .action, minimum: ContrastRatio.textMinimum),
    Pairing(foreground: .onAction, background: .actionActive, minimum: ContrastRatio.textMinimum),
    Pairing(foreground: .onWarning, background: .warning, minimum: ContrastRatio.textMinimum),
    Pairing(foreground: .onDanger, background: .danger, minimum: ContrastRatio.textMinimum),

    // The text weights of the two status colours.
    Pairing(foreground: .warningText, background: .surfacePrimary, minimum: ContrastRatio.textMinimum),
    Pairing(foreground: .warningText, background: .surfaceRaised, minimum: ContrastRatio.textMinimum),
    Pairing(foreground: .dangerText, background: .surfacePrimary, minimum: ContrastRatio.textMinimum),
    Pairing(foreground: .dangerText, background: .surfaceRaised, minimum: ContrastRatio.textMinimum)
  ]

  /// The control outline, against every ground it is ever drawn on, held to the
  /// 3:1 the standard requires of anything that identifies a component.
  static let borderPairings: [Pairing] = [
    Pairing(foreground: .borderStrong, background: .surfacePrimary, minimum: ContrastRatio.nonTextMinimum),
    Pairing(foreground: .borderStrong, background: .surfaceRaised, minimum: ContrastRatio.nonTextMinimum),
    Pairing(foreground: .borderStrong, background: .surfaceInset, minimum: ContrastRatio.nonTextMinimum)
  ]

  /// Every audited text pairing clears 4.5:1 in BOTH appearances.
  @Test("textOnSurfaceMeetsAA", arguments: textPairings)
  func textOnSurfaceMeetsAA(pairing: Pairing) {
    Self.expectContrast(pairing)
  }

  /// The outline that draws a control clears 3:1 against every ground, in both
  /// appearances.
  ///
  /// WHY THIS MATTERS MORE THAN IT LOOKS
  /// The disabled Start button on the timer screen is filled with the inset
  /// surface, which measures about 1.1:1 against the page — effectively
  /// invisible, and in dark mode it is DARKER than the page, so without an
  /// outline it would read as a hole rather than as a control. The outline is
  /// the only thing that draws that button, and it has to be seen against the
  /// page on one side and against its own fill on the other. That is why all
  /// three grounds are checked rather than just the page.
  @Test("borderOnSurfaceMeetsNonTextMinimum", arguments: borderPairings)
  func borderOnSurfaceMeetsNonTextMinimum(pairing: Pairing) {
    Self.expectContrast(pairing)
  }

  // MARK: The primitive layer

  /// A colour survives the trip from the hex a designer writes to the channels
  /// a screen draws, and back.
  ///
  /// The primitive layer exists so the number in this codebase is
  /// character-for-character the number in the design system, which a reviewer
  /// can diff by eye. That guarantee is only worth anything if the conversion
  /// is exact, so this test pins it: the stored value, the three channels, and
  /// the way a failure prints.
  @Test("paletteHexRoundTrip")
  func paletteHexRoundTrip() {
    // The page colour, kept verbatim.
    #expect(RGBColor(hex: 0xF6F5F2).hex == 0xF6F5F2)
    #expect(Palette.stone50.hex == 0xF6F5F2)
    #expect(Palette.slate900.hex == 0x1C1F22)

    // Channels are split off the right bytes, in the right order. A red/blue
    // swap is the classic version of this bug and it looks fine in greyscale.
    let orange = RGBColor(hex: 0xFF8000)
    #expect(orange.red == 1)
    #expect(orange.green == Double(0x80) / 255)
    #expect(orange.blue == 0)

    // Black and white are the two ends of the scale and must be exact, because
    // every contrast figure in the design system is measured against them.
    #expect(RGBColor(hex: 0x000000).red == 0)
    #expect(Palette.stone0.red == 1)
    #expect(Palette.stone0.green == 1)
    #expect(Palette.stone0.blue == 1)

    // Anything above the low 24 bits is ignored rather than corrupting the
    // colour, so a stray alpha byte cannot silently change a shade.
    #expect(RGBColor(hex: 0xFF_F6F5F2).hex == 0xF6F5F2)

    // Equal hexes are equal colours — which is what lets the appearance
    // comparison in `everyRoleResolvesInBothSchemes` mean anything.
    #expect(RGBColor(hex: 0x5C7040) == Palette.sage600)

    // A failing test has to print something a person can look up.
    #expect(Palette.sage600.description == "#5C7040")
  }

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

  // MARK: Helpers

  /// The two appearances every colour assertion is checked in.
  ///
  /// A tiny type rather than a pair of key paths, because a key path is not
  /// safe to share between threads and a `static let` holding one would not
  /// compile under this project's strict concurrency setting.
  enum Appearance: String, CaseIterable, Sendable {
    case light = "light mode"
    case dark = "dark mode"

    /// The colour this role takes in this appearance.
    func color(of role: ColorRole) -> RGBColor {
      switch self {
      case .light: role.light
      case .dark: role.dark
      }
    }
  }

  /// Measures one pairing in both appearances and reports a failure that names
  /// the measurement, the threshold, and which appearance failed.
  static func expectContrast(_ pairing: Pairing) {
    for appearance in Appearance.allCases {
      let ratio = ContrastRatio.between(
        appearance.color(of: pairing.foreground),
        and: appearance.color(of: pairing.background)
      )
      #expect(
        ratio >= pairing.minimum,
        """
        \(pairing) measures \(ContrastRatio.format(ratio)):1 in \(appearance.rawValue), \
        below the \(ContrastRatio.format(pairing.minimum)):1 required.
        """
      )
    }
  }
}
