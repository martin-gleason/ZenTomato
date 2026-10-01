import Foundation

/// Layer 1, continued: the raw values the five non-default themes bring with them.
///
/// **Why this is not in `Palette`.** `Palette` is a one-for-one transcription of the Civic Data
/// design system's ramps, and its own header says every scale in it is closed. These values come
/// from somewhere else — the v1.5 design handoff (`D57`, `D58`) — so they live beside it, on the
/// precedent of `TodoistPalette.swift`, rather than as new steps on a ramp they do not belong to.
///
/// **The same rule applies as to `Palette`: no screen may name this type.** Screens name roles.
/// The `palette_outside_token_layer` lint rule covers this name too.
///
/// **Where a value came from is written beside it**, because three kinds are mixed here and a
/// reviewer needs to tell them apart:
/// - *handoff* — the hex exactly as the design handoff gives it.
/// - *adjusted* — a handoff value that measured under a contrast floor and moved one step, once.
///   The figure it measured and the figure it measures now are both stated.
/// - *derived* — a step the handoff does not state. Hover and active mix the accent 17% and 31%
///   toward black in light, 12% and 24% toward white in dark; applied to Sage, that reproduces the
///   shipped steps to within one unit per channel, which is why it is the rule.
/// - *derived, paler than Sage's* — the subtle ground, which the current plan row is filled with
///   and prints the accent on. Sage's own spacing (86% toward white, 80% toward the page) put
///   Ripen's accent on it at 4.40:1 and Plum's at 4.39:1, found by `F12`'s adversarial review; and
///   the handoff's literal answer — keep Sage's tint — puts Ripen at 4.48:1. So these mix 92%
///   toward white and 86% toward the theme's page, and `action` on `actionSubtle` is audited.
enum ThemePalette {
  // MARK: Ripen — tomato red. Its light accent and dark accent are `Palette.red600` / `red400`.

  static let ripenHoverLight = RGBColor(hex: 0x9F2F24) // derived
  static let ripenActiveLight = RGBColor(hex: 0x84271E) // derived
  static let ripenSubtleLight = RGBColor(hex: 0xFAEFEE) // derived, paler
  static let ripenHoverDark = RGBColor(hex: 0xE98D77) // derived
  static let ripenActiveDark = RGBColor(hex: 0xEC9C8A) // derived
  static let ripenSubtleDark = RGBColor(hex: 0x382C2B) // derived, paler

  // MARK: Teal — cool water

  static let tealLight = RGBColor(hex: 0x2E6E66) // handoff
  static let tealHoverLight = RGBColor(hex: 0x265B55) // derived
  static let tealActiveLight = RGBColor(hex: 0x204C46) // derived
  static let tealSubtleLight = RGBColor(hex: 0xEEF3F3) // derived, paler
  static let tealDark = RGBColor(hex: 0x7FB5AC) // handoff
  static let tealHoverDark = RGBColor(hex: 0x8EBEB6) // derived
  static let tealActiveDark = RGBColor(hex: 0x9EC7C0) // derived
  static let tealSubtleDark = RGBColor(hex: 0x2A3435) // derived, paler

  // MARK: Plum — dusk

  static let plumLight = RGBColor(hex: 0x6E4870) // handoff
  static let plumHoverLight = RGBColor(hex: 0x5B3C5D) // derived
  static let plumActiveLight = RGBColor(hex: 0x4C324D) // derived
  static let plumSubtleLight = RGBColor(hex: 0xF3F0F4) // derived, paler
  static let plumDark = RGBColor(hex: 0xB394B5) // handoff
  static let plumHoverDark = RGBColor(hex: 0xBCA1BE) // derived
  static let plumActiveDark = RGBColor(hex: 0xC5AEC7) // derived
  static let plumSubtleDark = RGBColor(hex: 0x312F37) // derived, paler

  // MARK: Matcha — green-warm grounds; the accent stays sage

  static let matchaSurfaceLight = RGBColor(hex: 0xF1F3EA) // handoff
  static let matchaRaisedLight = RGBColor(hex: 0xFAFBF5) // handoff
  static let matchaInsetLight = RGBColor(hex: 0xE2E6D6) // handoff
  static let matchaInkLight = RGBColor(hex: 0x232820) // handoff
  static let matchaMutedLight = RGBColor(hex: 0x575E4E) // handoff
  /// **Adjusted.** The handoff's `#6B7261` measured 4.46:1 on Matcha's page; this measures 4.78:1.
  static let matchaSubtleLight = RGBColor(hex: 0x676D5C)
  static let matchaSurfaceDark = RGBColor(hex: 0x1B1F19) // handoff
  static let matchaRaisedDark = RGBColor(hex: 0x232820) // handoff
  static let matchaInsetDark = RGBColor(hex: 0x15180F) // handoff

  // MARK: Ink — near-monochrome

  static let inkLight = RGBColor(hex: 0x33383D) // handoff
  static let inkHoverLight = RGBColor(hex: 0x2A2E33) // derived
  static let inkActiveLight = RGBColor(hex: 0x23272A) // derived
  static let inkSubtleLight = RGBColor(hex: 0xEFEFEF) // derived, paler
  static let inkSurfaceLight = RGBColor(hex: 0xF4F4F3) // handoff — also its onAction
  static let inkInsetLight = RGBColor(hex: 0xE6E6E4) // handoff
  static let inkDark = RGBColor(hex: 0xC8CCD0) // handoff
  static let inkHoverDark = RGBColor(hex: 0xCFD2D6) // derived
  static let inkActiveDark = RGBColor(hex: 0xD5D8DB) // derived
  static let inkSubtleDark = RGBColor(hex: 0x2D2F32) // derived, paler
  static let inkSurfaceDark = RGBColor(hex: 0x141618) // handoff — also its onAction
  static let inkRaisedDark = RGBColor(hex: 0x1D2023) // handoff
  static let inkInsetDark = RGBColor(hex: 0x0F1113) // handoff
}
