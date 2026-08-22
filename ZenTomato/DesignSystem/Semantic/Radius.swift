import Foundation

/// Corner radii, in points.
///
/// **This is the scale that makes the app look like somebody chose it.** iOS 26
/// rounds its own controls at roughly 16 to 26 points. The Civic Data
/// personality is sharp-cornered: two to six points, and no further. A six-point
/// corner against the platform's twenty-six is the single most legible signal
/// that a human made a decision here rather than accepting a default.
///
/// **These never scale with Dynamic Type.** A corner radius is a physical shape,
/// not a piece of type. If it grew when someone raised their text size, a
/// two-point chamfer would become a four-point bulge and the whole personality
/// would soften on exactly the devices where it matters most.
///
/// The scale is closed. A seventh value is a design-system change.
enum Radius {
  /// A true square corner.
  static let none: CGFloat = 0
  /// 2pt — barely a chamfer; the sharpest thing that is still not a raw corner.
  static let xs: CGFloat = 2
  /// 3pt.
  static let sm: CGFloat = 3
  /// 4pt.
  static let md: CGFloat = 4
  /// 6pt — the largest radius in the personality, and the one used on buttons.
  static let lg: CGFloat = 6

  /// A number large enough that any rectangle it is applied to comes out fully
  /// rounded at the ends.
  ///
  /// **Transcribed for completeness of the scale, and it should not be used.**
  /// In the source system this exists for circular avatars, which ZenTomato does
  /// not have; there are no pill-shaped elements in this app by design. On iOS
  /// the honest way to spell "fully rounded" is the `Capsule()` shape, which says
  /// what it means instead of relying on a sentinel number being big enough.
  static let full: CGFloat = 9999
}
