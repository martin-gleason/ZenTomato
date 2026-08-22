import Foundation

/// The point-metric scale: gaps, the minimum size of a control, and stroke
/// widths.
///
/// **What a "point" is.** iOS measures layout in points, not pixels. One point
/// is roughly one sixty-fourth of an inch on every iPhone ever made, whatever the
/// screen's pixel density. So the numbers below are physical sizes, and they mean
/// the same thing on every device.
///
/// **Why the steps are the steps.** Four points is the base unit. It divides
/// evenly into the eight-point rhythm iOS itself uses, while still allowing a
/// fine adjustment where one is needed. Every value below is a multiple of four
/// apart from the two-point hairline gap. The scale is *closed*: picking a gap
/// means picking one of these, and if none of them is right the answer is
/// usually that the layout is wrong, not that the scale needs an eleventh step.
///
/// **These do not grow with Dynamic Type, and that is deliberate.** When someone
/// raises their text size on iOS, the *type* grows and the layout reflows around
/// it; the margins stay put. Apple's own apps work this way. Scaling the padding
/// too would double-count the increase and push content off the screen.
///
/// **Why stroke widths live here too.** A stroke width is a point measurement
/// like every other value in this file, and the design system states them in the
/// same units. Keeping them together means there is exactly one file to open
/// when the question is "how many points?".
enum Spacing {
  // MARK: Gaps
  //
  // Named by t-shirt size rather than by number, so a diff reads as a decision
  // ("this gap is small") rather than as arithmetic ("this gap is 12").

  /// No gap at all. Named rather than written as a bare `0`, so that "there is
  /// deliberately no space here" is distinguishable from "nobody thought about
  /// it".
  static let none: CGFloat = 0
  /// 2pt — a hairline separation, used between things that are almost touching.
  static let xxxs: CGFloat = 2
  /// 4pt — the base unit.
  static let xxs: CGFloat = 4
  /// 8pt — inside a small control.
  static let xs: CGFloat = 8
  /// 12pt — between two closely related lines of text.
  static let sm: CGFloat = 12
  /// 16pt. Also iOS's own standard side margin on an iPhone, which is a
  /// coincidence worth naming: the screen margin is simultaneously this token
  /// and the platform default.
  static let md: CGFloat = 16
  /// 24pt — between groups.
  static let lg: CGFloat = 24
  /// 32pt — between major regions of a screen.
  static let xl: CGFloat = 32
  /// 48pt — a deliberate, large breathing space.
  static let xxl: CGFloat = 48
  /// 64pt — the largest step in the closed scale.
  static let xxxl: CGFloat = 64

  // MARK: Control size

  /// 44pt — the smallest a tappable control is ever allowed to be.
  ///
  /// The design system sets this to clear the touch-target floor, and Apple's own
  /// Human Interface Guidelines give the same number. The two agree, so this
  /// single value satisfies both at once.
  ///
  /// **Always apply it as a *minimum* height, never as a fixed height.** A fixed
  /// height clips its own label once someone turns their text size up, and
  /// truncating a button label is a correctness bug rather than a layout one.
  static let controlHeight: CGFloat = 44

  // MARK: Stroke widths

  /// No stroke.
  static let borderNone: CGFloat = 0
  /// 1pt — the standard outline. This is the correct translation of the design
  /// system's 1px: a CSS pixel is a device-independent unit and maps one-to-one
  /// onto a point. Do not "correct" it into a fraction of a physical pixel.
  static let borderHairline: CGFloat = 1
  /// 2pt — an emphasised outline, and the width of a focus ring.
  static let borderThin: CGFloat = 2
  /// 3pt — the heaviest stroke in the closed scale.
  static let borderThick: CGFloat = 3
}
