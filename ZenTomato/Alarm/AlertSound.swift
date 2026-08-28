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

  /// Whether this app can actually play it.
  ///
  /// **A NAMED SOUND THAT IS NOT IN THE BUNDLE IS SILENCE, NOT A FALLBACK.**
  /// `AlertConfiguration.AlertSound.named(_:)` resolves against the bundle, and
  /// when the file is absent there is no error, no warning and no default — the
  /// alarm simply makes no noise. That is the exact failure this whole feature
  /// exists to prevent, arriving through the feature itself.
  ///
  /// So the catalogue is not the list of sounds somebody wrote down; it is the
  /// list of sounds this build can play, computed from the bundle. A case whose
  /// file has not been added yet is not offered, is never stored, and cannot be
  /// scheduled. The day the file is added it appears in the picker with no code
  /// change, and if it is ever dropped from the target the picker shrinks rather
  /// than going quiet.
  ///
  /// The system default is always playable: it is not a file.
  var isPlayable: Bool {
    guard let fileName else { return true }
    let name = (fileName as NSString).deletingPathExtension
    let type = (fileName as NSString).pathExtension
    return Bundle.main.url(forResource: name, withExtension: type) != nil
  }

  /// Who made the sounds this build ships, and where they came from, as the
  /// paragraph a person reads.
  ///
  /// **`nil` when the app ships no borrowed sound**, because a credits heading
  /// over an empty list is a claim that there is something to credit.
  ///
  /// Built from `playable` rather than `allCases`, for the reason that separates
  /// a credit from a false statement: a sound whose file is not in the target is
  /// never played, so naming its author would say we used their work when we did
  /// not. The list therefore appears and disappears with the sounds themselves.
  static var credits: String? {
    let lines = playable.compactMap { sound -> String? in
      guard let attribution = sound.attribution else { return nil }
      return "\(sound.name) — \(attribution.author), \(attribution.licence)\n\(attribution.source)"
    }
    guard lines.isEmpty == false else { return nil }
    return "Alert sounds\n\n" + lines.joined(separator: "\n\n")
  }

  /// The sounds this build can offer, in catalogue order.
  ///
  /// Never `allCases`. See `isPlayable` for why the two differ.
  static var playable: [AlertSound] { allCases.filter(\.isPlayable) }

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
  /// **Also rejects a sound this build cannot play**, for the same reason the
  /// picker will not offer one: a name that resolves to nothing is a silent
  /// alarm, and a silent alarm is indistinguishable from the bug that started
  /// this. An unplayable stored value is treated exactly like an unknown one.
  static func stored(_ rawValue: String?) -> AlertSound {
    guard let rawValue, let known = AlertSound(rawValue: rawValue) else { return .systemDefault }
    return known.isPlayable ? known : .systemDefault
  }
}
