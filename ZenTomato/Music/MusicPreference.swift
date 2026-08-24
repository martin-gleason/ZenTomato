import Foundation
import SwiftData

/// The two things F4 remembers between launches: whether music is on, and which
/// one item was chosen.
///
/// WHY THIS IS NOT A FIELD ON `AppSettings`, WHICH IS THE OBVIOUS PLACE
/// `SPEC.md`'s locked decisions table names six things the timer may be
/// customised with and ends with the words "Nothing else." `AppSettings` is that
/// list, and its own doc comment names the absence of a music switch by name as
/// a deliberate one. Music is set immediately before a sprint and is an accessory
/// to the timer rather than a property of it, so it lives here, in its own row,
/// and `AppSettings` gains zero lines. `MusicFenceTests` asserts both halves of
/// that: four columns here, six there.
///
/// EXACTLY ONE ROW, THE SAME WAY `AppSettings` AND `TimerState` ARE ONE ROW
/// There is one person with one preference. A second row would mean nothing, and
/// the first piece of code to fetch "the music preference" would have to invent a
/// rule for which one wins. `MusicPreferenceStore` is the only thing that may
/// obtain or insert one.
///
/// EXACTLY FOUR COLUMNS, AND WHY THAT IS A RULE RATHER THAN A COINCIDENCE
/// A row describing a chosen playlist is one field away from being a small local
/// copy of somebody's music library with opinions of its own — how often it was
/// played, when it was last used, which track it reached. Each of those is one
/// column and each looks harmless. So the fence is mechanical rather than
/// written: `MusicFenceTests` asks the database layer what columns this type has
/// and fails if the answer is not exactly these four.
///
/// **The position inside a track is deliberately not one of them.** Mid-track
/// position is kept by the player's own queue for as long as the app is alive,
/// and it dies with the process; persisting it would need the player's playback
/// position, which `MusicPlaying` deliberately makes unreachable. So an app that
/// is killed mid-sprint starts the chosen item from its beginning on the next
/// focus block. That is stated here rather than discovered.
///
/// WHY THE KIND IS STORED AS PLAIN TEXT
/// SwiftData splits a `Codable` enum with no raw value into two marker columns,
/// which is unreadable off a phone and was a blocking finding in F5's review. A
/// string reads as `playlist` or `song` in any database browser, and the one
/// place it is turned back into a kind is `MusicPreferenceStore`.
@Model
final class MusicPreference {
  // MARK: Stored properties

  /// Whether music should play during focus blocks.
  ///
  /// Off on a fresh install. Music is an accessory, and an app that starts
  /// playing something the first time somebody presses Start would be making a
  /// decision that is not its to make.
  var isEnabled: Bool

  /// `playlist` or `song`, or `nil` when nothing has been chosen.
  ///
  /// Stored beside the identifier rather than derived from it because Apple's
  /// identifiers are opaque: nothing about the string says which of the two
  /// kinds of thing it names, and the request that looks it up has to know
  /// before it can be made.
  var selectionKind: String?

  /// Apple's own identifier for the chosen item, as plain text.
  var selectionID: String?

  /// The title as it read at the moment it was chosen.
  ///
  /// **A snapshot, not a lookup**, for the same reason the session plan snapshots
  /// task titles: a playlist can be renamed or deleted in the Music app, and a
  /// stale identifier must produce "that one isn't in your library any more, pick
  /// another" rather than a blank row or a crash. This string is what that
  /// sentence names.
  var selectionTitle: String?

  // MARK: Initialisation

  /// Creates the preference row in its first-launch state: off, with nothing
  /// chosen.
  init(
    isEnabled: Bool = false,
    selectionKind: String? = nil,
    selectionID: String? = nil,
    selectionTitle: String? = nil
  ) {
    self.isEnabled = isEnabled
    self.selectionKind = selectionKind
    self.selectionID = selectionID
    self.selectionTitle = selectionTitle
  }
}
