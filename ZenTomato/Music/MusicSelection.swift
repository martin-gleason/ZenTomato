import Foundation

/// The one playlist or song the user has chosen to hear during focus blocks.
///
/// WHAT A READER WHO DOES NOT WRITE SWIFT NEEDS TO KNOW
/// This is a plain value — three pieces of text and nothing else. It is not a
/// live handle on anything in Apple Music; it is a note saying "the thing
/// called *Deep Focus*, with this identifier, is what I picked". Everything in
/// this feature that is not the last inch of actual playback talks in these,
/// which is why the tests can drive the whole thing with no music framework
/// linked and no sound anywhere.
///
/// **IT DELIBERATELY NAMES NO APPLE TYPE.** `identifier` is a string rather
/// than Apple's own identifier type, and `kind` is our own two-case list rather
/// than a reference to their playlist or song types. The cost is one conversion
/// inside `AppleMusicPlayer`. What it buys: this value can be stored in the
/// database, compared in a test, and handed to a stand-in player without any of
/// those places importing a music framework — and it is what keeps that
/// framework confined to three files in the whole repository.
///
/// **WHY THE TITLE IS COPIED RATHER THAN LOOKED UP.** `title` is the name as it
/// read at the moment it was chosen, saved alongside the identifier. A playlist
/// can be renamed or deleted in the Music app at any time, and when that
/// happens the app must be able to say *"'Deep Focus' isn't in your library any
/// more"* — which needs the old name. Looking the name up fresh every time
/// would mean a deleted item has no name at all, and the screen would have
/// nothing to put in that sentence. This is the same reason the Todoist feature
/// snapshots task titles rather than resolving them.
struct MusicSelection: Equatable, Hashable, Sendable, Codable {
  // MARK: Nested types

  /// Which of the two things the spec allows this to be.
  ///
  /// The contract's wording is *"an existing playlist or song from their
  /// library"* — two possibilities, closed. An album, an artist, a radio
  /// station and anything from the Apple Music catalogue are all absent on
  /// purpose, and adding one would be a change to this list that a reviewer
  /// reads in the diff.
  ///
  /// The raw value is a word rather than a number because it is written to the
  /// database: a stored `0` would mean nothing to anyone reading the file, and
  /// reordering the two cases would silently change what every saved row meant.
  enum Kind: String, Equatable, Hashable, Sendable, Codable, CaseIterable {
    /// A playlist the user has in their own library.
    case playlist

    /// A single song the user has in their own library.
    case song
  }

  // MARK: Stored properties

  /// Whether this is a playlist or a single song.
  let kind: Kind

  /// Apple's identifier for the item, as plain text.
  ///
  /// Opaque to everything in this app except `AppleMusicPlayer`, which is the
  /// only file that knows what to do with it. Nothing here parses it, splits
  /// it, or assumes anything about its shape.
  let identifier: String

  /// The item's name as it read when it was chosen. See the type's note above.
  let title: String

  // NO INITIALISER IS WRITTEN HERE, AND THAT IS DELIBERATE.
  // Swift writes one for a value like this: `MusicSelection(kind:identifier:
  // title:)` exists without anybody typing it. Writing it out by hand would be
  // three lines that can only ever say the same thing, and one more place to
  // forget when a fourth fact is added. The lint gate rejects the hand-written
  // copy for that reason.
}
