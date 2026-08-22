import Foundation
import Testing

@testable import ZenTomato

/// Proves the launch screen's colour is the same colour as the app's page.
///
/// WHY THIS TEST EXISTS
/// iOS shows a blank screen for a fraction of a second between the tap on the
/// icon and the app's first frame. Its colour is not set in code — it is set in
/// the asset catalog, which is data, so nothing in the compiler can check it
/// against `ColorRole.surfacePrimary`. Get them out of step and every launch
/// flashes the wrong colour: white against warm stone, or worse, white against
/// the dark page.
///
/// It is the kind of mistake that is invisible in a diff and obvious on a phone,
/// and it goes wrong by *neglect* rather than by edit — somebody adjusts the page
/// colour in `Palette.swift`, which is the natural place to adjust it, and has no
/// reason to know a JSON file three directories away also has to move. So the
/// test reads the JSON the app actually ships and compares it against the role
/// the app actually draws.
struct LaunchBackgroundTests {
  /// The launch colour set matches `ColorRole.surfacePrimary` in both appearances.
  ///
  /// If this fails, the two have drifted. Fix whichever one is wrong — the values
  /// live in `Palette.swift` and in
  /// `ZenTomato/Resources/Assets.xcassets/LaunchBackground.colorset/Contents.json`.
  @Test("The launch screen colour matches the page colour, light and dark")
  func launchBackgroundMatchesSurfacePrimary() throws {
    let colorSet = try LaunchBackgroundColorSet.load()
    let page = ColorRole.surfacePrimary

    #expect(
      colorSet.light == page.light,
      """
      The light launch colour is \(colorSet.light) but the light page is \(page.light). \
      A cold launch will flash the wrong colour. Update LaunchBackground.colorset/Contents.json \
      to match, or update the palette if the page colour is the one that changed.
      """)

    #expect(
      colorSet.dark == page.dark,
      """
      The dark launch colour is \(colorSet.dark) but the dark page is \(page.dark). \
      A cold launch in dark mode will flash the wrong colour.
      """)
  }
}

// MARK: - LaunchBackgroundColorSet

/// The two colours in the launch screen's asset-catalog entry, read from disk.
///
/// This decodes the real `Contents.json` rather than a copy of it, because a copy
/// would be one more thing that could drift — and drift is the entire subject of
/// this file.
private struct LaunchBackgroundColorSet {
  // MARK: Internal

  let light: RGBColor
  let dark: RGBColor

  /// Reads and decodes the colour set that ships inside the app.
  ///
  /// The file is found by walking up from this source file rather than by asking
  /// the test bundle, because an asset catalog is compiled into a binary format
  /// at build time — the readable JSON only exists in the source tree, which is
  /// exactly where the mistake this test catches would be made.
  static func load() throws -> Self {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()   // ZenTomatoTests
      .deletingLastPathComponent()   // repository root
      .appending(path: "ZenTomato/Resources/Assets.xcassets/LaunchBackground.colorset/Contents.json")

    let decoded = try JSONDecoder().decode(
      ColorSetFile.self,
      from: try Data(contentsOf: url))

    // "Light" is the entry with no appearance qualifier — the asset catalog's
    // default — and "dark" is the one qualified with luminosity/dark. Selecting
    // them by their qualifier rather than by their position means reordering the
    // file cannot silently swap the two.
    guard
      let lightEntry = decoded.colors.first(where: { $0.appearances == nil }),
      let darkEntry = decoded.colors.first(where: { entry in
        entry.appearances?.contains { $0.appearance == "luminosity" && $0.value == "dark" } == true
      })
    else {
      throw LoadError.missingAppearance
    }

    return Self(
      light: try lightEntry.color.components.rgbColor(),
      dark: try darkEntry.color.components.rgbColor())
  }

  // MARK: Private

  private enum LoadError: Error {
    case missingAppearance
    case unreadableComponent(String)
  }

  private struct ColorSetFile: Decodable {
    let colors: [Entry]
  }

  private struct Entry: Decodable {
    let appearances: [Appearance]?
    let color: ColorValue
  }

  private struct Appearance: Decodable {
    let appearance: String
    let value: String
  }

  private struct ColorValue: Decodable {
    let components: Components
  }

  private struct Components: Decodable {
    let red: String
    let green: String
    let blue: String

    /// Turns the catalog's `"0xF6"` strings into the app's own colour type, so
    /// the comparison is between two values of the same kind rather than between
    /// a string and a colour.
    func rgbColor() throws -> RGBColor {
      let channels = try [red, green, blue].map { text -> UInt32 in
        let digits = text.hasPrefix("0x") ? String(text.dropFirst(2)) : text
        guard let value = UInt32(digits, radix: 16), value <= 0xFF else {
          throw LoadError.unreadableComponent(text)
        }
        return value
      }
      return RGBColor(hex: channels[0] << 16 | channels[1] << 8 | channels[2])
    }
  }
}
