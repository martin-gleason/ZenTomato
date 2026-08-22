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

  /// Builds the colour for a role from scratch. Private because every screen
  /// goes through `init(_:)` above, which hands back a prepared one.
  fileprivate init(building role: ColorRole) {
    self.init(uiColor: UIColor { traits in
      let value = traits.userInterfaceStyle == .dark ? role.dark : role.light
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
