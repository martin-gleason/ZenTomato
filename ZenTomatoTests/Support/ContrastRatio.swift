import Foundation

@testable import ZenTomato

/// Measures the contrast between two colours, the way the Web Content
/// Accessibility Guidelines define it.
///
/// WHY A TEST NEEDS THIS AT ALL
/// The design system states a measured contrast figure next to almost every
/// colour it defines — "5.01:1 light, 5.80:1 dark on the page" and so on. Those
/// figures are the reason each colour is the exact shade it is: the brand sage
/// was moved one step darker specifically because the original hex measures
/// 4.33 against the page and text needs 4.5. A number written in a comment is a
/// claim; a number a test computes from the shipped colour is a fact. This type
/// turns the claims into facts.
///
/// TEST-ONLY. It lives in the test target and is never part of the app.
///
/// IT WORKS ON `RGBColor`, NOT ON A SCREEN COLOUR. That is deliberate and it is
/// what makes the token layer testable at all: the semantic layer resolves to
/// plain numbers with no reference to iOS, so contrast can be measured without
/// a running app, a simulator, or a screen.
///
/// THE TWO THRESHOLDS THAT MATTER HERE
///   * **4.5** — normal-size text on its background (WCAG 2.2, rule 1.4.3).
///   * **3.0** — the outline of a control, and anything else that has to be
///     seen in order to know a component is there (rule 1.4.11).
///
/// HOW THE MEASUREMENT WORKS, IN ONE PARAGRAPH
/// A screen's red, green and blue values are not proportional to how bright the
/// colour looks — they are stored on a curve. The first step undoes that curve.
/// The second weights the three channels by how much each contributes to
/// perceived brightness; green contributes most by far, blue least. That gives
/// one number per colour, its *relative luminance*. The ratio between two of
/// them, each nudged by 0.05 to keep black from dividing by zero, is the
/// contrast ratio.
enum ContrastRatio {
  // MARK: Thresholds

  /// The minimum contrast for normal-size text against its background.
  static let textMinimum = 4.5

  /// The minimum contrast for something that is not text but must still be
  /// seen — the outline that tells you a button is there, for instance.
  static let nonTextMinimum = 3.0

  // MARK: Measurement

  /// The contrast ratio between two colours, from 1 (identical) to 21 (pure
  /// black against pure white).
  ///
  /// The order of the arguments does not matter: the brighter of the two is
  /// always used as the numerator, exactly as the standard specifies.
  static func between(_ first: RGBColor, and second: RGBColor) -> Double {
    let firstLuminance = relativeLuminance(of: first)
    let secondLuminance = relativeLuminance(of: second)
    let lighter = max(firstLuminance, secondLuminance)
    let darker = min(firstLuminance, secondLuminance)
    return (lighter + 0.05) / (darker + 0.05)
  }

  /// How bright a colour appears, on a scale from 0 (black) to 1 (white).
  static func relativeLuminance(of color: RGBColor) -> Double {
    0.2126 * linearised(color.red)
      + 0.7152 * linearised(color.green)
      + 0.0722 * linearised(color.blue)
  }

  /// Two decimal places, so a failing test prints a number that can be compared
  /// with the design system's own audit table by eye.
  static func format(_ ratio: Double) -> String {
    String(format: "%.2f", ratio)
  }

  // MARK: Internals

  /// Undoes the curve a colour value is stored on, so the result is
  /// proportional to physical light rather than to how the value is encoded.
  private static func linearised(_ channel: Double) -> Double {
    channel <= 0.03928
      ? channel / 12.92
      : pow((channel + 0.055) / 1.055, 2.4)
  }
}
