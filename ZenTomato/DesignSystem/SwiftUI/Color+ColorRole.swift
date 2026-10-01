import SwiftUI
import UIKit

/// Turns a design-system colour role into a colour SwiftUI can paint.
///
/// **This is the only file in the design system that knows iOS exists.**
/// Everything else in `DesignSystem/` is plain Swift with no user-interface
/// framework in it. Keeping the platform-specific step in one small file is what
/// makes the colour vocabulary testable off-screen, and it means a future port to
/// another Apple platform rewrites this file and nothing else.
extension Color {
  /// Builds a colour that follows the phone's light/dark setting on its own.
  ///
  /// **How it works, and why it is done this way.** Instead of deciding *now*
  /// whether the phone is in light or dark mode, this hands iOS a small rule —
  /// "if the surroundings are dark use this colour, otherwise use that one" — and
  /// lets iOS apply the rule at the moment it draws. Three things fall out of
  /// that for free:
  ///
  /// 1. No screen ever contains an `if dark { ... }`. There is no appearance
  ///    branch anywhere in this app outside this initialiser.
  /// 2. It updates *live*. If someone switches their phone to dark mode while
  ///    ZenTomato is open, the screen changes underneath without the app being
  ///    told and without anything being redrawn by hand.
  /// 3. It works in Xcode's previews, so the light and dark previews on
  ///    `TimerView` are a real check on this mechanism rather than a decoration.
  ///
  /// **Since `F12`, the rule has a second input: the theme** (`D58`). It arrives the same way the
  /// appearance does — as a trait iOS hands the rule at draw time — so a theme change repaints every
  /// screen live, exactly as a switch to dark mode does, and not one of the app's `Color(.role)`
  /// call sites had to change. See `ThemeTrait` below for how SwiftUI passes it in.
  ///
  /// An appearance that is neither light nor dark — which iOS reports as
  /// "unspecified" in a handful of edge cases — falls through to light. That
  /// matches the design system, where light is defined as the default and dark is
  /// the override.
  ///
  /// - Parameter role: what the colour is *for*, e.g. `.surfacePrimary`. Roles
  ///   are the only colour vocabulary a screen may use; see `ColorRole`.
  init(_ role: ColorRole) {
    self = ColorRoleTable.colors[role] ?? Color(building: role)
  }

  /// A role's colour under one named theme, still following light and dark on its own.
  ///
  /// **For the few places a colour leaves this app's view tree** — the alarm's tint, which AlarmKit
  /// carries to the system, and the Lock Screen card's ground, which iOS may read outside the views
  /// that set a theme. Everywhere else a screen writes `Color(role)` and the theme arrives through
  /// the environment. Not cached: it is built once per block, not once per frame.
  init(_ role: ColorRole, in theme: Theme) {
    self.init(uiColor: UIColor { traits in
      let value = traits.userInterfaceStyle == .dark ? role.dark(in: theme) : role.light(in: theme)
      return UIColor(
        red: CGFloat(value.red),
        green: CGFloat(value.green),
        blue: CGFloat(value.blue),
        alpha: 1)
    })
  }

  /// Builds the colour for a role from scratch. Private because every screen
  /// goes through `init(_:)` above, which hands back a prepared one.
  fileprivate init(building role: ColorRole) {
    self.init(uiColor: UIColor { traits in
      let theme = traits[ThemeTrait.self]
      let value = traits.userInterfaceStyle == .dark ? role.dark(in: theme) : role.light(in: theme)
      return UIColor(
        red: CGFloat(value.red),
        green: CGFloat(value.green),
        blue: CGFloat(value.blue),
        alpha: 1)
    })
  }
}

/// One prepared colour per role, built once.
///
/// **Why this exists.** Every screen asks for its colours inside the code that
/// draws it, and that code runs again every time anything on the screen
/// changes. Without this table each of those asks would build a brand new
/// colour object and a brand new rule to go with it. On this screen, which is
/// drawn once and then sits still, that costs nothing — but the next piece of
/// work turns this screen into a countdown that redraws every second, and by
/// then the waste is spread across a dozen places and is tedious to find.
/// Preparing them once, now, is a few lines.
///
/// **It is still fully automatic.** What is stored is the *rule* — "dark or
/// light, pick accordingly" — not the answer. iOS still applies it at the
/// moment it draws, so the colours still follow the phone's setting live and
/// still resolve correctly in Xcode's previews. Caching a colour that decides
/// for itself is not the same as deciding early, which would be the bug.
private enum ColorRoleTable {
  /// Built on first use and then reused. `ColorRole` lists its own cases, so a
  /// role added later joins this table automatically with nothing to remember.
  static let colors: [ColorRole: Color] = Dictionary(
    uniqueKeysWithValues: ColorRole.allCases.map { ($0, Color(building: $0)) })
}

// MARK: - The theme, carried as a trait

/// The theme a colour rule resolves under, as a UIKit trait.
///
/// **Why a trait, for a reader who does not write Swift.** iOS already hands every colour rule a
/// description of its surroundings when it draws — "the phone is in dark mode", "the text is extra
/// large". A trait is one entry in that description. Registering the theme as one more entry means
/// the rule above can read it the same way it reads light/dark, at the moment of drawing, which is
/// what makes a theme change repaint live instead of waiting for a relaunch.
///
/// **Verified before it was built on, 2026-09-30.** That SwiftUI passes a bridged trait into colour
/// resolution was a claim about Apple's framework, so a throwaway test resolved one colour with the
/// value unset and then set, and saw `#0000FF` become `#FF0000`. `ThemeResolutionTests` keeps that
/// check standing against the real rule.
///
/// `affectsColorAppearance` tells UIKit that a change to this trait changes colours, so anything
/// UIKit draws redraws too.
struct ThemeTrait: UITraitDefinition {
  static let defaultValue = Theme.sage
  static let affectsColorAppearance = true
  static let name = "ZenTomato theme"
}

/// The same value on the SwiftUI side. A screen sets it once, near the root, with
/// `.environment(\.theme, …)`, and SwiftUI copies it into the trait above for everything beneath.
struct ThemeEnvironmentKey: EnvironmentKey {
  static let defaultValue = Theme.sage
}

extension ThemeEnvironmentKey: UITraitBridgedEnvironmentKey {
  static func read(from traitCollection: UITraitCollection) -> Theme {
    traitCollection[ThemeTrait.self]
  }

  static func write(to mutableTraits: inout UIMutableTraits, value: Theme) {
    mutableTraits[ThemeTrait.self] = value
  }
}

extension EnvironmentValues {
  /// The theme every `Color(.role)` beneath this point resolves under. Sage when nothing sets it.
  var theme: Theme {
    get { self[ThemeEnvironmentKey.self] }
    set { self[ThemeEnvironmentKey.self] = newValue }
  }
}
