import Foundation

/// Everything the Music sheet draws, worked out from what the library returned
/// and from nothing else.
///
/// **TWO KINDS OF ROW, AND THERE IS NO THIRD.**
/// `SPEC.md` allows *"an existing playlist or song from their library"*, so this
/// model can produce a playlist row or a song row. A row that offered to build
/// something, to rename something, or to fetch something from the Apple Music
/// catalogue would have to be a new case on `Row` — and `MusicPickerScreenModelTests`
/// switches over that list with no catch-all clause, so a third case stops the
/// test bundle compiling. That is the enforcement; this paragraph is only the
/// explanation. It is the same mechanism `PickerScreenModel` uses to hold the
/// no-capture rule on the Todoist picker.
///
/// **THERE IS NO SEARCH FIELD ON THIS SHEET.** The design sketched one, and the
/// ratified scope fence forbids it by name — a text field of any kind in this
/// feature is a finding, and a field over a music library is the sharpest
/// no-capture risk this feature could carry. Long libraries are handled by
/// revealing rows a page at a time as somebody scrolls, which adds no control at
/// all: no field, no button, not even a "show more". See `pageSize`.
///
/// **A ROW IS A TITLE.** No artwork, and no second line. Artwork means a fetch
/// per row, a blank where somebody is offline, and a second visual language on a
/// screen that is otherwise type — the same argument that keeps `PlanRowView` and
/// the Todoist task picker title-only. What kind of thing a row is is said by a
/// leading glyph and, for anybody not looking at the screen, by the first word of
/// its spoken label.
struct MusicPickerScreenModel: Equatable, Sendable {
  // MARK: Nested types

  /// One row of the sheet. **Exactly two cases.**
  enum Row: Identifiable, Hashable, Sendable {
    case playlist(MusicSelection)
    case song(MusicSelection)

    /// The item this row would choose.
    var selection: MusicSelection {
      switch self {
      case .playlist(let selection): selection
      case .song(let selection): selection
      }
    }

    /// The distinguishing word, spoken first.
    ///
    /// The shape `DistractionButtons` already uses: a reader who is not looking
    /// at the screen learns what kind of thing this is before they learn what it
    /// is called.
    var spokenKind: String {
      switch self {
      case .playlist: "Playlist"
      case .song: "Song"
      }
    }

    /// Apple's identifiers are opaque strings, and a playlist and a song could in
    /// principle carry the same one. The kind is folded into the identity so that
    /// two rows can never collide in a list.
    var id: String {
      switch self {
      case .playlist(let selection): "playlist-\(selection.identifier)"
      case .song(let selection): "song-\(selection.identifier)"
      }
    }
  }

  // MARK: How much is drawn at once

  /// How many rows of each list are drawn before more are revealed.
  ///
  /// **This is display paging, and it is a different problem from reading the
  /// library.** `AppleMusicLibrary` already fetches in pages so that no single
  /// request stalls; this stops SwiftUI building four thousand rows the instant
  /// the sheet opens. More appear as somebody reaches the end of what is drawn,
  /// which is a scroll rather than a control — there is no button and nothing to
  /// tap.
  static let pageSize = 100

  // MARK: What the library returned

  /// Every playlist, in the order the library gave them.
  let playlists: [MusicSelection]

  /// Every song, in the same order.
  let songs: [MusicSelection]

  // MARK: Lifecycle

  init(playlists: [MusicSelection] = [], songs: [MusicSelection] = []) {
    self.playlists = playlists
    self.songs = songs
  }

  // MARK: The rows

  /// Playlists first. `SPEC.md`'s own phrasing puts them first — *"an existing
  /// playlist or song"* — and a playlist is what a focus block actually wants.
  var playlistRows: [Row] {
    playlists.map(Row.playlist)
  }

  var songRows: [Row] {
    songs.map(Row.song)
  }

  /// The library was read and held nothing at all.
  ///
  /// Distinct from "not read yet", which the sheet shows as a quiet line instead.
  /// Reporting an unread library as an empty one would tell somebody with four
  /// thousand songs that they own no music, which is the music-shaped version of
  /// the mistake the session plan refuses to make about Todoist.
  var isEmpty: Bool {
    playlists.isEmpty && songs.isEmpty
  }

  /// The first `shown` rows of a list.
  ///
  /// A pure function so the paging can be checked without a screen: hand it a
  /// list and a number, read back what would be drawn.
  static func page(_ rows: [Row], shown: Int) -> [Row] {
    guard shown < rows.count else { return rows }
    return Array(rows.prefix(max(shown, 0)))
  }

  /// Whether there is anything left to reveal.
  static func hasMore(_ rows: [Row], shown: Int) -> Bool {
    shown < rows.count
  }

  /// Whether the chosen item is still one of the things on offer.
  ///
  /// The sheet uses this for one thing: an item that has left the library will
  /// not appear in either list, so without somewhere to report it the choice
  /// would simply vanish. That is what the "Now chosen" section is for.
  /// Matched on the identifier alone, never on the whole value. The stored title
  /// is a snapshot taken when the item was chosen, so a playlist renamed in the
  /// Music app since then is the same playlist with a different name — and
  /// comparing titles would report it as gone.
  func contains(_ selection: MusicSelection) -> Bool {
    switch selection.kind {
    case .playlist: playlists.contains { $0.identifier == selection.identifier }
    case .song: songs.contains { $0.identifier == selection.identifier }
    }
  }
}
