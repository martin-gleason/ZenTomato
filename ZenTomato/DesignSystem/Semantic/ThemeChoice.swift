import Foundation

/// What the owner picked in Settings: one of the six themes, or Auto (`D58`).
///
/// **Two types rather than one, because Auto is not a palette.** `Theme` is a set of colours and
/// every case of it can be measured. Auto is a *rule* that names one of them, so it lives here,
/// beside the six it can choose between, and nothing that draws ever sees it — a screen is always
/// handed a resolved `Theme`.
enum ThemeChoice: String, CaseIterable, Sendable, Identifiable {
  case auto
  case sage
  case ripen
  case teal
  case plum
  case matcha
  case ink

  // MARK: Lifecycle

  /// The choice that always draws this theme.
  init(_ theme: Theme) {
    switch theme {
    case .sage: self = .sage
    case .ripen: self = .ripen
    case .teal: self = .teal
    case .plum: self = .plum
    case .matcha: self = .matcha
    case .ink: self = .ink
    }
  }

  // MARK: Internal

  var id: String { rawValue }

  /// The theme this choice always draws, or `nil` for Auto.
  var fixed: Theme? {
    switch self {
    case .auto: nil
    case .sage: .sage
    case .ripen: .ripen
    case .teal: .teal
    case .plum: .plum
    case .matcha: .matcha
    case .ink: .ink
    }
  }

  /// The theme to draw right now.
  func resolved(at date: Date, calendar: Calendar = .current) -> Theme {
    fixed ?? Self.auto(at: date, calendar: calendar)
  }

  /// **Auto, the handoff's rule verbatim:** before 6am or from 9pm, Ink; in August or September,
  /// Ripen; otherwise Sage. The clock wins over the season, so a September night is Ink.
  ///
  /// A pure function of the date, so its boundaries are tested rather than waited for.
  static func auto(at date: Date, calendar: Calendar = .current) -> Theme {
    let hour = calendar.component(.hour, from: date)
    let month = calendar.component(.month, from: date)
    if hour < 6 || hour >= 21 { return .ink }
    if month == 8 || month == 9 { return .ripen }
    return .sage
  }

  /// The stored value turned back into a choice, safely.
  ///
  /// **Nothing stored, or a value this build has never heard of, is Auto** — the handoff's
  /// default. An unknown value must degrade rather than fail, for the reason
  /// `AlertSound.stored(_:)` gives: a theme added in a later version must not take the
  /// database with it.
  static func stored(_ rawValue: String?) -> ThemeChoice {
    rawValue.flatMap(ThemeChoice.init(rawValue:)) ?? .auto
  }
}
