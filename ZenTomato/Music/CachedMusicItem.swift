import Foundation
import SwiftData

/// A playlist or song from the library, remembered so the picker opens at once.
///
/// WHY THIS EXISTS
/// The picker used to read the whole library every time the sheet opened.
/// MusicKit answers from the phone's own database, so it is not slow in the way
/// a network call is slow — but it pages, and on a real library that is hundreds
/// of milliseconds of nothing on screen every single time. Reported from the
/// device as "music loading is very slow".
///
/// **This is a mirror, in exactly the sense the Todoist cache is a mirror.** It
/// holds what MusicKit said, and nothing this app invented: no ordering of our
/// own, no favourites, no play counts, nothing editable. Refreshing replaces it
/// wholesale rather than merging, because a merge is where a cache starts having
/// opinions about which side is right.
///
/// It stores no audio and no rights-managed content — only an identifier and a
/// name, which is what the picker draws and what the player is handed.
@Model
final class CachedMusicItem {
  // MARK: Lifecycle

  init(kind: MusicSelection.Kind, identifier: String, title: String, syncedAt: Date) {
    self.kindRaw = kind.rawValue
    self.identifier = identifier
    self.title = title
    self.syncedAt = syncedAt
  }

  // MARK: Internal

  /// Whether this is a playlist or a song.
  ///
  /// Stored as its raw string rather than as the enum, because SwiftData is
  /// happier with a primitive here and because a value that has to survive a
  /// schema migration is easier to reason about when it is text you can read in
  /// the store.
  var kindRaw: String

  /// MusicKit's identifier. Opaque, and never parsed.
  var identifier: String

  /// What it is called, as the library said at `syncedAt`.
  var title: String

  /// When this mirror was last filled. The only field the app adds, and it is
  /// about the cache rather than about the music.
  var syncedAt: Date

  var kind: MusicSelection.Kind {
    MusicSelection.Kind(rawValue: kindRaw) ?? .song
  }

  /// The shape the rest of the feature speaks in.
  var selection: MusicSelection {
    MusicSelection(kind: kind, identifier: identifier, title: title)
  }
}
