import Foundation

/// Layer 1 of the colour system: the raw ramps.
///
/// **What these are.** Context-free colour values, transcribed one-for-one from
/// the Civic Data design system's `src/tokens/_primitives.scss`. They describe
/// *what a colour is* — "the sixth step down the warm-grey ramp" — and never
/// *where it is used*. Every family is numbered by lightness, so a bigger number
/// is always a darker colour within that family.
///
/// **The rule that matters, and it is not enforceable by the compiler here.**
/// No view, no screen and no component may ever mention `Palette`. Views may
/// only name a *role* from `ColorRole` — "the page background", "the ink on an
/// action button". That indirection is the entire point of a design system: it
/// is what lets one colour decision be changed in one place instead of hunted
/// through screens.
///
/// In the SCSS source this rule is enforced by the file being private to the
/// token layer. Swift's `private` does not reach across files, and this type
/// *must* be reachable from `ColorRole.swift` (a different file) and from the
/// test target. So it is `internal` — visible to the whole app — and the rule
/// is carried instead by the `palette_outside_token_layer` rule in
/// `.swiftlint.yml`, which fails the build if the word `Palette.` appears in
/// `App/`, `Views/` or `Models/`. If you are reading a diff and you see
/// `Palette.` outside `DesignSystem/`, that is a defect, regardless of how
/// reasonable the colour looks.
///
/// **Every scale here is closed.** Adding a step is a design-system change, not
/// a patch. If a screen needs a colour that is not here, the answer is almost
/// always that it needs an existing *role*, not a new *value*.
enum Palette {
  // MARK: Stone — the warm neutral family
  //
  // Light-theme grounds at the pale end; light-theme ink and both themes' quiet
  // text at the dark end. Numbered by lightness: 0 is white, 800 is the darkest
  // warm grey.

  static let stone0 = RGBColor(hex: 0xFFFFFF)
  static let stone50 = RGBColor(hex: 0xF6F5F2)
  static let stone100 = RGBColor(hex: 0xECEAE3)
  /// "Bone". Sits between 100 and 200 in lightness but is perceptibly warmer
  /// than either, which is why it is its own step rather than being rounded onto
  /// a neighbour. It is the dark theme's body ink.
  static let stone150 = RGBColor(hex: 0xECE8DF)
  static let stone200 = RGBColor(hex: 0xE7E4DB)
  static let stone300 = RGBColor(hex: 0xDEDBD4)
  static let stone400 = RGBColor(hex: 0xB3AEA3)
  static let stone500 = RGBColor(hex: 0x948F84)
  static let stone600 = RGBColor(hex: 0x828074)
  static let stone700 = RGBColor(hex: 0x6F6C63)
  static let stone800 = RGBColor(hex: 0x5C5A52)

  // MARK: Slate — the cool blue-grey family
  //
  // Hue is around 205, i.e. barely blue. These are the dark theme's grounds and
  // the light theme's ink.
  //
  // The source ramp also carries `$slate-400` and `$slate-500`, which are the
  // same hue at chart saturation. They are NOT transcribed here: their only
  // consumer in the source is a chart series, ZenTomato v0.1 draws no charts,
  // and porting them would be building furniture for a feature that has not been
  // agreed. They come across whole, from the same table, if and when charts do.

  static let slate600 = RGBColor(hex: 0x3A3F45)
  static let slate700 = RGBColor(hex: 0x2C3136)
  static let slate800 = RGBColor(hex: 0x24282C)
  static let slate850 = RGBColor(hex: 0x22252A)
  static let slate900 = RGBColor(hex: 0x1C1F22)
  static let slate950 = RGBColor(hex: 0x17191C)

  // MARK: Sage — the brand family

  static let sage50 = RGBColor(hex: 0xE7EBDC)
  static let sage200 = RGBColor(hex: 0xAEC48B)
  static let sage300 = RGBColor(hex: 0x9CB377)
  static let sage400 = RGBColor(hex: 0x8AA163)
  /// Brand sage — the colour a brand guideline would hand you.
  ///
  /// It is deliberately **not** used as text anywhere. Measured against the pale
  /// page (`stone50`) it reaches only 4.33:1, and the accessibility floor for
  /// normal-size text is 4.5:1. That is why `ColorRole.action` takes `sage600`
  /// in light instead. This step is kept in the ramp so that nobody "corrects"
  /// the action role back to the brand hex without meeting the reason not to.
  static let sage500 = RGBColor(hex: 0x667A49)
  static let sage600 = RGBColor(hex: 0x5C7040)
  static let sage700 = RGBColor(hex: 0x4C5C36)
  static let sage800 = RGBColor(hex: 0x3F4C2D)
  static let sage900 = RGBColor(hex: 0x2B3226)

  // MARK: Amber — warning, and scarce emphasis
  //
  // 500 and 400 are FILL weights: amber behind something, never amber as text on
  // a pale ground. Measured against the light page they reach only 3.07:1 and
  // 2.23:1 against a text floor of 4.5:1 — legible as a shape, not as words.
  // 700 is the light theme's text weight, 300 the dark theme's.

  static let amber300 = RGBColor(hex: 0xDFA858)
  static let amber400 = RGBColor(hex: 0xD99A3E)
  static let amber500 = RGBColor(hex: 0xBD8024)
  static let amber700 = RGBColor(hex: 0x8A5E14)

  // MARK: Red — danger
  //
  // 600–800 carry the light theme (dark enough to be read on stone); 300–500
  // carry the dark theme (light enough to be read on slate). A single red used
  // in both themes fails in one of them, which is why there are two halves.

  static let red300 = RGBColor(hex: 0xEC907A)
  static let red400 = RGBColor(hex: 0xE67D65)
  static let red500 = RGBColor(hex: 0xE06A50)
  static let red600 = RGBColor(hex: 0xC0392B)
  static let red700 = RGBColor(hex: 0xA93226)
  static let red800 = RGBColor(hex: 0x922B21)

  // MARK: Families deliberately not transcribed
  //
  // `$teal-*`, `$clay-*` and `$plum-*` exist in the source only as categorical
  // chart series. ZenTomato v0.1 has no chart, so they are absent rather than
  // dormant. Same reasoning as `$slate-400/500` above.
  //
  // One value in the source palette was dropped by the design system itself and
  // is therefore absent here too: `#6F6D64`, the old dark border colour. It was
  // measured against the page only, and failed the 3:1 floor once it was put on
  // a raised card. It was replaced by `stone600`, which both themes now share.
  // Do not "restore" a separate dark border value.
}
