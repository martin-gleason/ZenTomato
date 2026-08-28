import Foundation

/// Which sound a block's alarm makes.
///
/// **`D24`, and `SPEC.md` line 30 now ends "which alert sound … Nothing else."**
/// Those last two words survived the amendment on purpose: the settings list
/// moved by exactly one and stayed closed.
///
/// WHAT THE FRAMEWORK ALLOWS, CHECKED IN THE SDK RATHER THAN ASSUMED
/// `AlarmKit` takes `ActivityKit.AlertConfiguration.AlertSound`, which has exactly
/// two members: `.default`, and `.named(_:)` resolving to **a file in this app's
/// bundle**. iOS's ringtone library is not reachable from an app, so a
/// system-sound picker was never possible — the choice is between iOS's default
/// and something this app ships.
///
/// **A `String` raw value, stored, and the cases are that contract.** `AppSettings`
/// holds the raw value rather than the case, so a stored value written by a later
/// version — a sound this build has never heard of — reads back as `nil` and falls
/// to the default rather than failing to open the database. A person who syncs a
/// device backup forward and then back must not lose their history over a sound.
enum AlertSound: String, CaseIterable, Sendable {
  /// What iOS plays when asked for nothing in particular.
  ///
  /// **The default, and it stays the default through this change.** An existing
  /// install must sound exactly as it did yesterday until somebody chooses
  /// otherwise; a migration that changes what the alarm sounds like is a
  /// migration that changes behaviour without being asked.
  case systemDefault

  /// A small bell, five seconds. CC0.
  case smallBell

  /// A single struck bell. CC0.
  case struckBell

  /// What the person sees. Short, because it sits as a trailing value in a row.
  var name: String {
    switch self {
    case .systemDefault: "Default"
    case .smallBell: "Small bell"
    case .struckBell: "Struck bell"
    }
  }

  /// The bundled file, or `nil` for the system default — which is not a file and
  /// must never be looked for as one.
  var fileName: String? {
    switch self {
    case .systemDefault: nil
    case .smallBell: "SmallBell.caf"
    case .struckBell: "StruckBell.caf"
    }
  }

  /// Who made it and where it came from.
  ///
  /// **The owner's ruling: every sound is attributed, with a link.** Stricter than
  /// the licences demand — both bells are CC0 and require nothing — and right
  /// regardless: the person who made the sound is credited whether or not a
  /// licence compels it, and the link is what makes the credit checkable rather
  /// than decorative.
  ///
  /// `nil` for the system default, which is Apple's and is not ours to credit.
  var attribution: Attribution? {
    switch self {
    case .systemDefault:
      nil
    case .smallBell:
      Attribution(
        author: "15HVojta_Michael",
        licence: "CC0",
        source: "https://freesound.org/people/15HVojta_Michael/sounds/462044/")
    case .struckBell:
      Attribution(
        author: "fmiramar_",
        licence: "CC0",
        source: "https://freesound.org/people/fmiramar_/sounds/397349/")
    }
  }

  /// A credit for one sound.
  struct Attribution: Equatable, Sendable {
    let author: String
    let licence: String
    let source: String
  }

  /// The stored value turned back into a choice, safely.
  ///
  /// **An unknown value is the default, not a crash and not a `nil` the caller
  /// has to think about.** Forward compatibility is the whole reason the raw
  /// value is stored: a sound added in a later version must degrade to the
  /// default here rather than take the database with it.
  static func stored(_ rawValue: String?) -> AlertSound {
    guard let rawValue, let known = AlertSound(rawValue: rawValue) else { return .systemDefault }
    return known
  }
}
