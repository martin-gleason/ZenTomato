import Foundation

/// Layer 1, second table: **Todoist's** colour values, not ours.
///
/// **Why there are two primitive tables.** `Palette` holds the colours this app
/// chose. This holds the twenty colours a Todoist user can choose for a project,
/// reported back to them. The separateness is the point: a reader can see at a
/// glance which colours are a design decision and which are somebody else's data
/// arriving over the wire. Mixing them would make the sentence *"the only colour
/// vocabulary the app is allowed to speak"* stop being true of anything.
///
/// **THE CITED SOURCE, so the numbers are transcribed and not remembered.**
/// `src/utils/colors.ts` in Doist's own TypeScript SDK,
/// <https://github.com/Doist/todoist-api-typescript>, at commit `19798a37`
/// (2026-09-14), read on 2026-09-24. Each `key` there is the string the API
/// sends in a project's `color` field and each `hexValue` is the number below.
/// Twenty colours; **no two share a hex value**, which is why
/// `everyTodoistTintIsDistinct` can be written as a flat assertion —
/// checked against the source rather than assumed, because a duplicate would
/// have made that test wrong rather than the table.
///
/// **This table is not a design system and must not grow into one.** Adding a
/// colour here is correct only when Todoist adds one; inventing a step is not a
/// patch, it is a claim about somebody else's product. A colour Todoist adds
/// tomorrow arrives as `TodoistTint.unknown` and is drawn, not dropped.
///
/// Same rule as `Palette`: no view, no screen, no model may name this type. The
/// `palette_outside_token_layer` rule in `.swiftlint.yml` covers both tables by
/// name, and it was widened to cover this one **in the commit that created it**,
/// so the guard has never had a hole for it to fall through.
enum TodoistPalette {
  static let berryRed = RGBColor(hex: 0xB825_5F)
  static let red = RGBColor(hex: 0xDB40_35)
  static let orange = RGBColor(hex: 0xFF99_33)
  static let yellow = RGBColor(hex: 0xFAD0_00)
  static let oliveGreen = RGBColor(hex: 0xAFB8_3B)
  static let limeGreen = RGBColor(hex: 0x7ECC_49)
  static let green = RGBColor(hex: 0x2994_38)
  static let mintGreen = RGBColor(hex: 0x6ACC_BC)
  static let teal = RGBColor(hex: 0x158F_AD)
  static let skyBlue = RGBColor(hex: 0x14AA_F5)
  static let lightBlue = RGBColor(hex: 0x96C3_EB)
  static let blue = RGBColor(hex: 0x4073_FF)
  static let grape = RGBColor(hex: 0x884D_FF)
  static let violet = RGBColor(hex: 0xAF38_EB)
  static let lavender = RGBColor(hex: 0xEB96_EB)
  static let magenta = RGBColor(hex: 0xE051_94)
  static let salmon = RGBColor(hex: 0xFF8D_85)

  /// Todoist's own default, and therefore ours for a colour we have never seen.
  /// `colors.ts`: `export const defaultColor: Color = charcoal`.
  static let charcoal = RGBColor(hex: 0x8080_80)
  static let grey = RGBColor(hex: 0xB8B8_B8)
  static let taupe = RGBColor(hex: 0xCCAC_93)
}
