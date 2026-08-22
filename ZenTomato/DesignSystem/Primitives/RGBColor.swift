import Foundation

/// A plain, opaque sRGB colour value.
///
/// **Why this type exists at all.** The design tokens in this folder have to be
/// usable in two places that have nothing to do with each other:
///
/// 1. On screen, where the answer has to be a SwiftUI `Color`.
/// 2. In a unit test, where the answer has to be three numbers that a
///    contrast-ratio calculation can do arithmetic on.
///
/// A SwiftUI `Color` cannot do the second job — it deliberately hides its
/// components, because the value it finally paints depends on the display it is
/// painted to. So the token layer stores colours as this dumb little value type,
/// and converting one into a `Color` happens in exactly one file
/// (`Color+ColorRole.swift`). That is what lets the accessibility rules in
/// `ColorRole` be *tested* rather than *asserted in a comment*.
///
/// **Foundation only, on purpose.** This file imports no UI framework. Anything
/// that imports UIKit only runs on iPhone and iPad; keeping this type free of
/// that means the whole colour vocabulary stays readable from plain,
/// non-UI code.
///
/// `Sendable` means "safe to pass between concurrent pieces of work". It is true
/// here for free: the value is a single immutable number and nothing can change
/// it after it is created.
struct RGBColor: Sendable, Equatable, Hashable, CustomStringConvertible {
  // MARK: Lifecycle

  /// Builds a colour from a 24-bit sRGB hex literal, e.g. `0xF6F5F2`.
  ///
  /// Colours are written as hex literals so that the number in this codebase is
  /// character-for-character the number in the Civic Data design system's
  /// source. A reviewer can diff the two by eye; they could not if we stored
  /// three decimal fractions instead.
  ///
  /// Only the low 24 bits are read (`RR` `GG` `BB`). Anything above them is
  /// ignored rather than rejected, because there is no such thing as a
  /// half-valid colour to report — every possible input maps to some colour.
  init(hex: UInt32) {
    self.hex = hex & 0x00FF_FFFF
  }

  // MARK: Internal

  /// The colour as the 24-bit number it was written as, e.g. `0xF6F5F2`.
  ///
  /// Kept so a test can prove that what a token file *says* is what the token
  /// actually *is* — see `DesignTokenTests.paletteHexRoundTrip`.
  let hex: UInt32

  /// Red channel, from 0 (none) to 1 (full).
  var red: Double {
    Double((hex >> 16) & 0xFF) / 255
  }

  /// Green channel, from 0 (none) to 1 (full).
  var green: Double {
    Double((hex >> 8) & 0xFF) / 255
  }

  /// Blue channel, from 0 (none) to 1 (full).
  var blue: Double {
    Double(hex & 0xFF) / 255
  }

  /// Renders as `#RRGGBB`, so a failing test prints a colour a human can look up
  /// rather than a decimal number nobody can recognise.
  var description: String {
    String(format: "#%06X", hex)
  }
}
