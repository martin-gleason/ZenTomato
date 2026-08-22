import SwiftUI

/// The type scale: every font the app is allowed to set.
///
/// **The one rule that makes this file worth having.** There is no
/// `Font.system(...)` and no `Font.custom(...)` anywhere else in the app. Every
/// piece of text gets its font from a role named below. That is a property a
/// reviewer can check with a search, and it is what would make swapping in a
/// different typeface later a change to this one file and nothing else.
///
/// **Why the app uses the system typeface.** The Civic Data design system ships
/// three custom faces — but only as `.woff2` files, which is a web-only format
/// that iOS has no way to load at all. Converting them is a licensing question as
/// much as a build one, and it is not in the agreed scope of this work. Using
/// Apple's own San Francisco family instead is not a compromise here: it is the
/// single largest reason an app reads as belonging on the phone, and it solves
/// for free the thing the source system needed two separate faces for — iOS
/// automatically switches to a wider-spaced cut of San Francisco below about
/// twenty points and a tighter one above it, so one family covers both the
/// "display" and "body" jobs.
///
/// **Every role below is built from one of Apple's named text styles** — `.body`,
/// `.headline`, `.largeTitle` and so on — and never from a raw point size. This
/// is what makes Dynamic Type work: when someone raises their text size in
/// Settings, a text style grows through Apple's own curves, including the
/// non-linear compression at the largest accessibility sizes. A hard-coded point
/// size would simply ignore the setting.
///
/// **There is exactly one exception, and it is the countdown numeral.** Apple's
/// largest text style tops out around 34 points, and the agreed design calls for
/// the number to be roughly five times the size of everything else rather than
/// twice it — so no standard style is big enough. `numeralBaseSize` states the
/// size directly. It does *not* give up Dynamic Type in exchange: its single call
/// site scales it with `@ScaledMetric(relativeTo: .largeTitle)`, which puts it
/// back on the same growth curve every other role uses. If a second raw point
/// size ever appears in this file, that is the moment to ask what went wrong.
///
/// **Monospaced is for data, never for prose.** Only `kicker`, `data` and
/// `timerNumeral` use fixed-width digits or a fixed-width face, and none of them
/// is a body role — so there is no way to set a paragraph in a typewriter face
/// without adding a new token, which is a visible decision in a diff.
enum Typography {
  // MARK: Display

  /// The starting size of the countdown numeral, in points, before the reader's
  /// text-size setting is applied.
  ///
  /// **This is the one raw point size in the app, and it is deliberate.** Every
  /// other role above is built from one of Apple's named text styles, because
  /// that is what makes Dynamic Type work. This role cannot be, because the
  /// largest style Apple offers — `.largeTitle` — is about 34 points, and the
  /// agreed design calls for the numeral to be roughly five times the size of
  /// anything else on screen rather than twice it. There is no standard style
  /// that large, so the size is stated here and scaled by hand at the one place
  /// it is used. See `numeralTrackingRatio` for how it stays legible.
  ///
  /// Dynamic Type is *not* given up in exchange. The single call site pairs this
  /// with `@ScaledMetric(relativeTo: .largeTitle)`, which puts the number back on
  /// Apple's own growth curve — the same one `.largeTitle` follows, including the
  /// compression at the largest accessibility sizes. The number still grows when
  /// the reader raises their text size; it simply starts far bigger.
  static let numeralBaseSize: CGFloat = 96

  /// The weight of the countdown numeral.
  ///
  /// Lighter than it looks like it should be. At 96 points a semibold numeral
  /// turns into a slab that dominates by sheer ink rather than by size, and reads
  /// as shouting. `.medium` at this size is still unmistakably the loudest thing
  /// on the screen while staying calm — which is the point of a focus timer.
  static let numeralWeight: Font.Weight = .medium

  /// How tightly the numeral's characters are set, as a fraction of its size.
  ///
  /// Type set very large needs its letters pulled slightly closer together than
  /// type set small, or the gaps between characters read as gaps between words.
  /// This is the design system's own "tight" tracking value, −0.015em, carried
  /// across unchanged. It is expressed as a *ratio* rather than a fixed number of
  /// points precisely so that it scales with the numeral: at 96 points it closes
  /// the letters by about 1.4 points, and at an accessibility size it closes them
  /// proportionally more, so the setting looks the same at every text size.
  static let numeralTrackingRatio: CGFloat = -0.015

  /// The countdown numeral at a given size: the loudest thing on the timer screen.
  ///
  /// A function rather than a constant because the size is not fixed — it is the
  /// reader's text-size setting applied to ``numeralBaseSize``, computed at the
  /// call site. Everything else about the role is decided here.
  ///
  /// `.monospacedDigit()` switches only the *digits* to fixed width while keeping
  /// San Francisco itself. That distinction is worth spelling out, because it is
  /// easy to get wrong: fixed-width digits mean a countdown ticking from `25:00`
  /// to `24:59` does not shuffle sideways on every tick. Switching to a
  /// *monospaced font* instead would swap in a typewriter face, whose character is
  /// "terminal output", not "clock". In this first version the numeral never
  /// changes, so the shuffle is invisible — specifying it now means nobody has to
  /// rediscover why the number wobbles later.
  static func timerNumeral(size: CGFloat) -> Font {
    .system(size: size, weight: numeralWeight).monospacedDigit()
  }

  /// A display heading.
  static let display = Font.system(.title, weight: .bold)

  /// A section title.
  static let title = Font.system(.title2, weight: .semibold)

  // MARK: Body and labels

  /// Body text, and the app's default. `.body` is 17 points at the standard
  /// setting, which is Apple's reading size and the right thing to defer to.
  static let body = Font.system(.body)

  /// Body text with emphasis.
  static let bodyEmphasis = Font.system(.body, weight: .semibold)

  /// A secondary label — the smaller line under a heading, or a supporting note.
  static let label = Font.system(.subheadline, weight: .medium)

  /// The label on a control. `.headline` is iOS's own button weight, so a button
  /// set in it reads as native even though its colour and shape do not.
  static let button = Font.system(.headline)

  // MARK: Data

  /// The design system's "kicker": a short, quiet, all-capitals label that names
  /// what the thing below it is. Set in a fixed-width face at caption size, which
  /// gives it the "this is a marker, not prose" character the design system uses
  /// it for.
  static let kicker = Font.system(.caption, design: .monospaced, weight: .semibold)

  /// Tabular figures and code. Never body prose.
  static let data = Font.system(.footnote, design: .monospaced)
}
