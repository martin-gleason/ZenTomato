import Foundation

/// Layer 2, second vocabulary: **a project's own colour, as Todoist named it.**
///
/// **Why this is not a `ColorRole`.** A role names a *purpose* — "the page", "the
/// ink on an action button" — and that is what makes a colour decision
/// changeable in one place and a contrast measurement meaningful. "Berry red" is
/// not a purpose. It does not mean *the page background* or *a warning*; it means
/// *this project, the one you chose that colour for*. Putting it in `ColorRole`
/// would make `ColorRole.todoistOlive` assignable to a page background, and the
/// role table would stop being a table of intentions.
///
/// **So there are two types, and the rule is unchanged in substance: a screen
/// still never chooses an appearance.** A screen names a piece of Todoist data —
/// *this project's tint* — and this layer decides what that data looks like, in
/// both appearances, in one place, readable by a test with no screen behind it.
/// Every property the role system exists to guarantee still holds.
///
/// **`unknown` is not a failure case, it is the normal case for next year.**
/// Todoist can add a colour whenever it likes, and a mirror that throws on a
/// value it has not seen is a mirror that breaks on somebody else's release
/// schedule. An unrecognised name resolves to Todoist's own default, which
/// `colors.ts` states is charcoal, and the project still draws.
///
/// **Both appearances are declared in one `switch`**, the construction
/// `ColorRole.pair` uses, so a tint cannot exist with only one of them.
enum TodoistTint: String, CaseIterable, Sendable {
  case berryRed
  case red
  case orange
  case yellow
  case oliveGreen
  case limeGreen
  case green
  case mintGreen
  case teal
  case skyBlue
  case lightBlue
  case blue
  case grape
  case violet
  case lavender
  case magenta
  case salmon
  case charcoal
  case grey
  case taupe

  /// A colour Todoist sent that this build has never heard of, or no colour at
  /// all. Drawn as Todoist's own default rather than skipped.
  case unknown

  // MARK: Lifecycle

  /// Built **only** from what Todoist sent, which is why there is no memberwise
  /// initialiser and no way to conjure a tint from nothing.
  ///
  /// `nil` — a project with no `color` key at all, which is what a workspace
  /// project looks like — is `unknown`, the same as a name from the future. The
  /// two are the same thing to a reader: *Todoist did not tell us a colour we
  /// know*, so draw the default.
  init(todoistName: String?) {
    guard let todoistName else {
      self = .unknown
      return
    }
    self = Self.byTodoistName[todoistName] ?? .unknown
  }

  // MARK: Internal

  /// The string Todoist puts in a project's `color` field, e.g. `berry_red`.
  ///
  /// Derived from the case name rather than written twice: Swift's `rawValue` is
  /// already `berryRed`, and Todoist's spelling is the same word in snake_case.
  /// One transformation beats twenty string literals that can disagree with the
  /// case they sit next to — which is exactly the failure `everyTintRoundTripsThroughItsTodoistName`
  /// is written to catch.
  var todoistName: String {
    if self == .unknown { return "" }
    var out = ""
    for character in rawValue {
      if character.isUppercase {
        out.append("_")
        out.append(Character(character.lowercased()))
      } else {
        out.append(character)
      }
    }
    return out
  }

  /// The colour this tint is drawn as, in the appearance asked for.
  func value(dark: Bool) -> RGBColor {
    dark ? pair.dark : pair.light
  }

  // MARK: Private

  private static let byTodoistName: [String: TodoistTint] = Dictionary(
    uniqueKeysWithValues: TodoistTint.allCases
      .filter { $0 != .unknown }
      .map { ($0.todoistName, $0) })

  /// **Light and dark are deliberately the same value, and that is the whole
  /// argument rather than an omission.**
  ///
  /// These colours are chosen by the user in another app. Lightening one for dark
  /// mode would be this app editing somebody else's project colour so that our
  /// page looks better — a decision we have no standing to make, and one the user
  /// could not see the reason for. So the datum is reported unaltered in both
  /// appearances.
  ///
  /// Visibility is bought elsewhere, and unconditionally: every swatch carries a
  /// `borderStrong` ring, which is measured at 3.12:1 or better on every ground
  /// in both appearances. That is what makes the swatch a visible object whatever
  /// its fill — including Todoist's charcoal on our `slate900` page, which is
  /// otherwise a genuinely invisible combination and not one we can fix from
  /// here.
  ///
  /// The pair is kept rather than collapsed to one value because it is the shape
  /// that makes "a tint has both appearances" a thing the compiler checks. If a
  /// tint ever does need to differ, the place to say so already exists.
  private var pair: (light: RGBColor, dark: RGBColor) {
    switch self {
    case .berryRed: (light: TodoistPalette.berryRed, dark: TodoistPalette.berryRed)
    case .red: (light: TodoistPalette.red, dark: TodoistPalette.red)
    case .orange: (light: TodoistPalette.orange, dark: TodoistPalette.orange)
    case .yellow: (light: TodoistPalette.yellow, dark: TodoistPalette.yellow)
    case .oliveGreen: (light: TodoistPalette.oliveGreen, dark: TodoistPalette.oliveGreen)
    case .limeGreen: (light: TodoistPalette.limeGreen, dark: TodoistPalette.limeGreen)
    case .green: (light: TodoistPalette.green, dark: TodoistPalette.green)
    case .mintGreen: (light: TodoistPalette.mintGreen, dark: TodoistPalette.mintGreen)
    case .teal: (light: TodoistPalette.teal, dark: TodoistPalette.teal)
    case .skyBlue: (light: TodoistPalette.skyBlue, dark: TodoistPalette.skyBlue)
    case .lightBlue: (light: TodoistPalette.lightBlue, dark: TodoistPalette.lightBlue)
    case .blue: (light: TodoistPalette.blue, dark: TodoistPalette.blue)
    case .grape: (light: TodoistPalette.grape, dark: TodoistPalette.grape)
    case .violet: (light: TodoistPalette.violet, dark: TodoistPalette.violet)
    case .lavender: (light: TodoistPalette.lavender, dark: TodoistPalette.lavender)
    case .magenta: (light: TodoistPalette.magenta, dark: TodoistPalette.magenta)
    case .salmon: (light: TodoistPalette.salmon, dark: TodoistPalette.salmon)
    case .charcoal: (light: TodoistPalette.charcoal, dark: TodoistPalette.charcoal)
    case .grey: (light: TodoistPalette.grey, dark: TodoistPalette.grey)
    case .taupe: (light: TodoistPalette.taupe, dark: TodoistPalette.taupe)
    case .unknown: (light: TodoistPalette.charcoal, dark: TodoistPalette.charcoal)
    }
  }
}
