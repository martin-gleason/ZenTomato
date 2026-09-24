import SwiftUI
import UIKit

/// Turns a Todoist project's tint into a colour SwiftUI can paint.
///
/// **The second of two files in the design system that know iOS exists**, and it
/// exists for the same reason as the first: `TodoistTint` and `TodoistPalette`
/// are plain Swift with no user-interface framework in them, so the whole tint
/// vocabulary stays readable from a test with no screen behind it. The platform
/// step lives here and nowhere else.
///
/// It mirrors `Color(_ role:)` deliberately — same shape, same caching, same
/// live-appearance mechanism — so that a screen asking for a tint and a screen
/// asking for a role are written the same way and neither one contains an
/// appearance branch.
extension Color {
  /// Builds a colour for a Todoist tint that follows the phone's setting on its
  /// own.
  ///
  /// The light and dark values of a tint are the same value today, and
  /// `TodoistTint.pair` says why: the colour belongs to the user's Todoist
  /// account and this app has no standing to reinterpret it for dark mode. The
  /// appearance-aware construction is kept anyway, because the day one tint does
  /// need to differ the place to say so already exists and no screen has to
  /// change.
  ///
  /// - Parameter tint: the project's own colour, as Todoist named it. Never a
  ///   role — a tint means *this project*, a role means *this purpose*.
  init(_ tint: TodoistTint) {
    self = TodoistTintTable.colors[tint] ?? Color(building: tint)
  }

  /// Builds the colour for a tint from scratch. Private because every screen goes
  /// through `init(_:)` above, which hands back a prepared one.
  fileprivate init(building tint: TodoistTint) {
    self.init(uiColor: UIColor { traits in
      let value = tint.value(dark: traits.userInterfaceStyle == .dark)
      return UIColor(
        red: CGFloat(value.red),
        green: CGFloat(value.green),
        blue: CGFloat(value.blue),
        alpha: 1)
    })
  }
}

/// One prepared colour per tint, built once.
///
/// **Why it matters more here than for roles.** A picker row asks for its tint
/// inside the code that draws it, and a list of forty projects draws forty rows,
/// each time anything on the screen changes. Twenty-one prepared colours built
/// once is cheaper than a new colour object per row per redraw, and the saving
/// scales with the size of somebody's Todoist account rather than with ours.
///
/// What is stored is the *rule* — "dark or light, pick accordingly" — not the
/// answer, so the colours still follow the phone's setting live.
private enum TodoistTintTable {
  /// Built on first use and then reused. `TodoistTint` lists its own cases, so a
  /// tint added when Todoist adds a colour joins this table automatically.
  static let colors: [TodoistTint: Color] = Dictionary(
    uniqueKeysWithValues: TodoistTint.allCases.map { ($0, Color(building: $0)) })
}
