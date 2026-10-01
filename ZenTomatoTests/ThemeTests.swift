import SwiftUI
import Testing

@testable import ZenTomato

/// `F12-T1`/`T2` — the theme seam, and what the contrast audit cannot see.
///
/// `DesignTokenTests` measures every pairing under every theme. This suite checks the three things
/// that audit does not: that a theme actually reaches the colour a screen paints, that Sage is still
/// exactly what shipped, and that every theme's tomato is a tomato.
@Suite("Themes")
@MainActor
struct ThemeTests {
  // MARK: The seam

  /// **The standing version of the spike (`F12-M3`).** A screen asks for `Color(.action)`; under
  /// Ripen it must paint Ripen's red, in both appearances. This goes through the real rule that
  /// every screen uses — the cached `Color`, the bridged trait, SwiftUI's own resolution — so if the
  /// trait stopped reaching the rule, every screen would stay Sage and this is what would say so.
  @Test("aThemeReachesTheColourAScreenPaints", arguments: Theme.allCases)
  func aThemeReachesTheColourAScreenPaints(theme: Theme) {
    for role in [ColorRole.action, .surfacePrimary, .tomatoFlesh] {
      var environment = EnvironmentValues()
      environment.theme = theme
      environment.colorScheme = .light
      #expect(
        Self.hex(Color(role).resolve(in: environment)) == role.light(in: theme).description,
        "\(theme.name) light: \(role.rawValue) painted the wrong colour.")
      environment.colorScheme = .dark
      #expect(
        Self.hex(Color(role).resolve(in: environment)) == role.dark(in: theme).description,
        "\(theme.name) dark: \(role.rawValue) painted the wrong colour.")
    }
  }

  /// Nothing set means Sage — so every screen and preview that predates themes draws what it drew.
  @Test("noThemeSetMeansSage")
  func noThemeSetMeansSage() {
    #expect(EnvironmentValues().theme == .sage)
    for role in ColorRole.allCases {
      #expect(Theme.sage.override(for: role) == nil, "Sage overrides \(role.rawValue); it is the reference.")
      #expect(role.light(in: .sage) == role.light)
      #expect(role.dark(in: .sage) == role.dark)
    }
  }

  /// Every theme but Sage changes something a person would see first: the accent or the page.
  /// A theme that equals Sage is a picker row that does nothing.
  @Test("everyThemeIsDistinct")
  func everyThemeIsDistinct() {
    let looks = Theme.allCases.map { theme in
      [ColorRole.action, .surfacePrimary, .tomatoFlesh].flatMap {
        [$0.light(in: theme).hex, $0.dark(in: theme).hex]
      }
    }
    #expect(Set(looks).count == Theme.allCases.count, "Two themes draw identically.")
  }

  // MARK: The tomato

  /// **Every theme's tomato has a crown you can see (`F12-M6`).** Under Sage the fruit is `sage400`,
  /// and a `sage400` crown on it measures 1.00:1 — the leaf vanishes. That was measured before it
  /// was built, and this is what keeps it from coming back.
  ///
  /// **Measured as colour distance, not as contrast — and the first version got that wrong.** It
  /// asserted a contrast above 1.1:1 and failed on Plum, whose purple fruit and green crown are
  /// plainly different colours at nearly the same lightness (1.06:1). Contrast compares lightness
  /// only; a crown is told from its fruit by hue. So this measures straight-line distance in RGB,
  /// where the collision it exists for — sage on sage — is exactly zero, and the closest real pair
  /// (Plum) is well clear of the floor.
  @Test("everyTomatoHasAVisibleCrown", arguments: Theme.allCases)
  func everyTomatoHasAVisibleCrown(theme: Theme) {
    let flesh = ColorRole.tomatoFlesh.dark(in: theme)
    let leaf = ColorRole.tomatoLeaf.dark(in: theme)
    let distance = Self.distance(flesh, leaf)
    #expect(distance >= 40, "\(theme.name): the crown is \(Int(distance)) from the fruit — the same colour.")
  }

  /// The fruit is drawn on the Dynamic Island, which is black. It must clear the 3:1 a graphic
  /// needs against it, in every theme.
  @Test("everyTomatoReadsOnTheIsland", arguments: Theme.allCases)
  func everyTomatoReadsOnTheIsland(theme: Theme) {
    let black = RGBColor(hex: 0x000000)
    for role in [ColorRole.tomatoFlesh, .tomatoSkin] {
      let ratio = ContrastRatio.between(role.dark(in: theme), and: black)
      #expect(
        ratio >= ContrastRatio.nonTextMinimum,
        "\(theme.name): \(role.rawValue) measures \(ContrastRatio.format(ratio)):1 on the Island.")
    }
  }

  /// Ripen draws the handoff's tomato exactly — `#E06A50` fruit, `#8AA163` crown.
  @Test("ripenIsTheHandoffsTomato")
  func ripenIsTheHandoffsTomato() {
    #expect(ColorRole.tomatoFlesh.dark(in: .ripen).hex == 0xE06A50)
    #expect(ColorRole.tomatoLeaf.dark(in: .ripen).hex == 0x8AA163)
    #expect(ColorRole.tomatoSkin.dark(in: .ripen).hex == 0x948F84)
  }

  // MARK: Helpers

  /// Straight-line distance between two colours in 0–255 RGB. 0 is identical; about 441 is black
  /// to white.
  private static func distance(_ lhs: RGBColor, _ rhs: RGBColor) -> Double {
    let deltas = [lhs.red - rhs.red, lhs.green - rhs.green, lhs.blue - rhs.blue].map { $0 * 255 }
    return deltas.map { $0 * $0 }.reduce(0, +).squareRoot()
  }

  /// `Color.Resolved` prints as `#RRGGBBAA`; the design system prints `#RRGGBB`.
  private static func hex(_ resolved: Color.Resolved) -> String {
    String(resolved.description.prefix(7))
  }
}
