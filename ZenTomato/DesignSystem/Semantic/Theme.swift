import Foundation

/// A complete set of colours behind the roles the app already names (`D58`).
///
/// **What a theme is, for a reader who does not write Swift.** Every screen asks for colours by
/// *role* — "the page", "the ink on an action button" — and never by value. A theme is a second
/// answer to those same questions. No screen changes when the theme does; the answers do.
///
/// **What a theme is not: an appearance.** Every theme defines both light and dark, and the phone
/// still decides which of the two is drawn. There is no "Dark" theme, by design.
///
/// **The list is closed and compiled in.** Six palettes, each measured by the same contrast audit
/// as the default. Nothing here is read from a file or built from a colour somebody typed, and
/// `D58` refuses both in the spec text: an arbitrary colour has no measured contrast, so the app
/// could no longer make the accessibility claim every comment in `ColorRole.swift` makes.
///
/// **Auto is not a case here**, because it is not a palette. It is a rule that picks one of these
/// by the clock and the season — see `ThemeChoice`.
enum Theme: String, CaseIterable, Sendable {
  /// Stone grounds, slate ink, sage accent — the look v0.1 shipped. Auto's fallback.
  case sage
  /// Tomato red accent.
  case ripen
  /// Cool water accent.
  case teal
  /// Dusk accent.
  case plum
  /// Green-warm grounds and ink; the accent stays sage.
  case matcha
  /// Near-monochrome: graphite accent on cool grey grounds.
  case ink

  // MARK: Internal

  /// The name shown in the picker.
  var name: String {
    switch self {
    case .sage: "Sage"
    case .ripen: "Ripen"
    case .teal: "Teal"
    case .plum: "Plum"
    case .matcha: "Matcha"
    case .ink: "Ink"
    }
  }

  /// The line under the name in the picker — the handoff's own descriptions.
  var summary: String {
    switch self {
    case .sage: "Stone and sage — ships today"
    case .ripen: "Tomato red accent"
    case .teal: "Cool water accent"
    case .plum: "Dusk accent"
    case .matcha: "Full palette — green-warm grounds"
    case .ink: "Full palette — near-monochrome"
    }
  }

  /// This theme's answer for a role, where it differs from Sage's; `nil` where it does not.
  ///
  /// **Sage is the reference and answers every role** — it is `ColorRole`'s own table, which the
  /// compiler already proves complete in both appearances. Every other theme states only what it
  /// changes, exactly as the handoff specifies them: an accent swap overrides the accent family,
  /// a full palette re-derives the grounds and ink. Anything a theme leaves unstated is Sage's
  /// measured value, and the audit re-measures it inside the theme anyway.
  func override(for role: ColorRole) -> (light: RGBColor, dark: RGBColor)? {
    switch self {
    case .sage: nil
    case .ripen: Self.ripen(role)
    case .teal: Self.teal(role)
    case .plum: Self.plum(role)
    case .matcha: Self.matcha(role)
    case .ink: Self.ink(role)
    }
  }

  // MARK: Private

  /// The tomato is the theme's accent **as drawn on dark** — the Dynamic Island is always dark —
  /// with the sage crown it has today. The owner, 2026-09-30: *"the themes selected are based on
  /// real tomato colors; not just red."* Light and dark are the same value, as they were under `F2f`.
  private static func fruit(_ flesh: RGBColor) -> (light: RGBColor, dark: RGBColor) {
    (light: flesh, dark: flesh)
  }

  private static let sageCrown = (light: Palette.sage400, dark: Palette.sage400)

  private static func ripen(_ role: ColorRole) -> (light: RGBColor, dark: RGBColor)? {
    switch role {
    // **Dark adjusted.** The handoff's `#E06A50` measured 4.49:1 on a raised card; `red400`
    // measures 5.29:1.
    case .action, .focus: (light: Palette.red600, dark: Palette.red400)
    case .actionHover: (light: ThemePalette.ripenHoverLight, dark: ThemePalette.ripenHoverDark)
    case .actionActive: (light: ThemePalette.ripenActiveLight, dark: ThemePalette.ripenActiveDark)
    case .actionSubtle: (light: ThemePalette.ripenSubtleLight, dark: ThemePalette.ripenSubtleDark)
    // The Island tomato exactly as the handoff draws it.
    case .tomatoFlesh: fruit(Palette.red500)
    case .tomatoLeaf: sageCrown
    default: nil
    }
  }

  private static func teal(_ role: ColorRole) -> (light: RGBColor, dark: RGBColor)? {
    switch role {
    case .action, .focus: (light: ThemePalette.tealLight, dark: ThemePalette.tealDark)
    case .actionHover: (light: ThemePalette.tealHoverLight, dark: ThemePalette.tealHoverDark)
    case .actionActive: (light: ThemePalette.tealActiveLight, dark: ThemePalette.tealActiveDark)
    case .actionSubtle: (light: ThemePalette.tealSubtleLight, dark: ThemePalette.tealSubtleDark)
    // No real tomato is teal. Stated rather than dressed up; the owner judges it at `F12-T6`.
    case .tomatoFlesh: fruit(ThemePalette.tealDark)
    case .tomatoLeaf: sageCrown
    default: nil
    }
  }

  private static func plum(_ role: ColorRole) -> (light: RGBColor, dark: RGBColor)? {
    switch role {
    case .action, .focus: (light: ThemePalette.plumLight, dark: ThemePalette.plumDark)
    case .actionHover: (light: ThemePalette.plumHoverLight, dark: ThemePalette.plumHoverDark)
    case .actionActive: (light: ThemePalette.plumActiveLight, dark: ThemePalette.plumActiveDark)
    case .actionSubtle: (light: ThemePalette.plumSubtleLight, dark: ThemePalette.plumSubtleDark)
    case .tomatoFlesh: fruit(ThemePalette.plumDark)
    case .tomatoLeaf: sageCrown
    default: nil
    }
  }

  /// Matcha keeps Sage's accent, so it keeps Sage's green tomato and dark crown too.
  private static func matcha(_ role: ColorRole) -> (light: RGBColor, dark: RGBColor)? {
    switch role {
    case .surfacePrimary: (light: ThemePalette.matchaSurfaceLight, dark: ThemePalette.matchaSurfaceDark)
    case .surfaceRaised: (light: ThemePalette.matchaRaisedLight, dark: ThemePalette.matchaRaisedDark)
    case .surfaceInset: (light: ThemePalette.matchaInsetLight, dark: ThemePalette.matchaInsetDark)
    case .textPrimary: (light: ThemePalette.matchaInkLight, dark: Palette.stone150)
    case .textMuted: (light: ThemePalette.matchaMutedLight, dark: Palette.stone400)
    case .textSubtle: (light: ThemePalette.matchaSubtleLight, dark: Palette.stone500)
    default: nil
    }
  }

  /// Ink is a full palette, so it states grounds *and* accent — in two halves, for the linter's
  /// complexity ceiling rather than for any reason a reader needs.
  private static func ink(_ role: ColorRole) -> (light: RGBColor, dark: RGBColor)? {
    inkGround(role) ?? inkAccent(role)
  }

  private static func inkGround(_ role: ColorRole) -> (light: RGBColor, dark: RGBColor)? {
    switch role {
    case .surfacePrimary: (light: ThemePalette.inkSurfaceLight, dark: ThemePalette.inkSurfaceDark)
    case .surfaceRaised: (light: Palette.stone0, dark: ThemePalette.inkRaisedDark)
    case .surfaceInset: (light: ThemePalette.inkInsetLight, dark: ThemePalette.inkInsetDark)
    default: nil
    }
  }

  private static func inkAccent(_ role: ColorRole) -> (light: RGBColor, dark: RGBColor)? {
    switch role {
    case .action, .focus: (light: ThemePalette.inkLight, dark: ThemePalette.inkDark)
    case .actionHover: (light: ThemePalette.inkHoverLight, dark: ThemePalette.inkHoverDark)
    case .actionActive: (light: ThemePalette.inkActiveLight, dark: ThemePalette.inkActiveDark)
    case .actionSubtle: (light: ThemePalette.inkSubtleLight, dark: ThemePalette.inkSubtleDark)
    case .onAction: (light: ThemePalette.inkSurfaceLight, dark: ThemePalette.inkSurfaceDark)
    case .tomatoFlesh: fruit(ThemePalette.inkDark)
    case .tomatoLeaf: sageCrown
    default: nil
    }
  }
}
