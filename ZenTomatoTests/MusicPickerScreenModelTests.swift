import Foundation
import Testing

@testable import ZenTomato

/// The Music sheet's rows, and the fence around them.
///
/// THE MECHANISM THIS FILE EXISTS FOR
/// The first test below switches over every row the sheet can draw **with no
/// catch-all clause**. A third kind of row — "make a playlist", "search the Apple
/// Music catalogue", "add this to a playlist" — would be a new case on
/// `MusicPickerScreenModel.Row`, and a new case stops this file compiling. The
/// only way past it is for somebody to change this test as well, in a diff the
/// owner reads. That is the enforcement; the comments are the explanation.
///
/// It is the same mechanism `NoCaptureSurfaceTests` uses on the Todoist picker,
/// applied to the one screen in this feature where somebody might reasonably
/// expect to build something.
@Suite("MusicPickerScreenModel")
struct MusicPickerScreenModelTests {
  // MARK: By shape

  /// The sheet can draw a playlist or a song. **There is no third kind of row**,
  /// in any state — not at the end of a list, not in an empty library, not
  /// anywhere.
  @Test("theSheetCanOnlyDrawPlaylistsAndSongs")
  func theSheetCanOnlyDrawPlaylistsAndSongs() {
    let everyRow = Self.library.playlistRows + Self.library.songRows

    for row in everyRow {
      switch row {
      case .playlist, .song:
        continue
      }
    }

    #expect(everyRow.isEmpty == false)
  }

  /// An empty library produces no rows at all, so there is nothing for a
  /// "why not build one" row to be appended to.
  @Test("anEmptyLibraryOffersNothing")
  func anEmptyLibraryOffersNothing() {
    let nothing = MusicPickerScreenModel()

    #expect(nothing.playlistRows.isEmpty)
    #expect(nothing.songRows.isEmpty)
    #expect(nothing.isEmpty)
  }

  /// Playlists come first. `SPEC.md`'s own phrasing is "an existing playlist or
  /// song", and a playlist is what a focus block actually wants.
  @Test("playlistsComeFirstAndKeepTheLibrarysOwnOrder")
  func playlistsComeFirstAndKeepTheLibrarysOwnOrder() {
    #expect(Self.library.playlistRows.map(\.selection.title) == ["Deep Focus", "Piano"])
    #expect(Self.library.songRows.map(\.selection.title) == ["So What", "Blue in Green"])
  }

  /// Each row says what kind of thing it is before it says what it is called, so
  /// that a reader who is not looking at the screen is never guessing.
  @Test("aRowNamesItsKindFirst")
  func aRowNamesItsKindFirst() {
    let playlist = MusicPickerScreenModel.Row.playlist(Self.deepFocus)
    let song = MusicPickerScreenModel.Row.song(Self.soWhat)

    #expect(playlist.spokenKind == "Playlist")
    #expect(song.spokenKind == "Song")
    #expect(MusicCopy.spokenRow(kind: playlist.spokenKind, title: "Deep Focus", detail: nil)
      == "Playlist. Deep Focus.")
  }

  /// A playlist and a song could in principle carry the same opaque identifier,
  /// and two rows with one identity in a list is a defect that presents as rows
  /// swapping places while somebody scrolls.
  @Test("aPlaylistAndASongWithTheSameIdentifierAreStillTwoRows")
  func aPlaylistAndASongWithTheSameIdentifierAreStillTwoRows() {
    let playlist = MusicPickerScreenModel.Row.playlist(
      MusicSelection(kind: .playlist, identifier: "same", title: "One"))
    let song = MusicPickerScreenModel.Row.song(
      MusicSelection(kind: .song, identifier: "same", title: "One"))

    #expect(playlist.id != song.id)
  }

  // MARK: Paging

  /// A long library is drawn a page at a time, and revealing more never drops or
  /// reorders anything.
  ///
  /// **The reveal is a scroll rather than a control.** There is no button here to
  /// test, and that is the point: nothing is drawn at the bottom of the list to
  /// tap.
  @Test("pagingRevealsMoreAndNeverLosesARow")
  func pagingRevealsMoreAndNeverLosesARow() {
    let many = (0..<250).map {
      MusicSelection(kind: .song, identifier: "s.\($0)", title: "Song \($0)")
    }
    let model = MusicPickerScreenModel(songs: many)
    let all = model.songRows

    let firstPage = MusicPickerScreenModel.page(all, shown: MusicPickerScreenModel.pageSize)
    #expect(firstPage.count == MusicPickerScreenModel.pageSize)
    #expect(MusicPickerScreenModel.hasMore(all, shown: MusicPickerScreenModel.pageSize))

    let secondPage = MusicPickerScreenModel.page(all, shown: 200)
    #expect(secondPage.count == 200)
    #expect(Array(secondPage.prefix(firstPage.count)) == firstPage)

    let everything = MusicPickerScreenModel.page(all, shown: 1_000)
    #expect(everything == all)
    #expect(MusicPickerScreenModel.hasMore(all, shown: 1_000) == false)
  }

  /// A short library is drawn whole, and asking for more of it is not an error.
  @Test("aShortLibraryIsDrawnWholeWithNothingLeftToReveal")
  func aShortLibraryIsDrawnWholeWithNothingLeftToReveal() {
    let rows = Self.library.playlistRows

    #expect(MusicPickerScreenModel.page(rows, shown: MusicPickerScreenModel.pageSize) == rows)
    #expect(MusicPickerScreenModel.hasMore(rows, shown: MusicPickerScreenModel.pageSize) == false)
  }

  // MARK: The chosen item

  /// A chosen item is matched on its identifier, never on its whole value.
  ///
  /// A playlist renamed in the Music app is the same playlist. Comparing titles
  /// would report it as deleted and put "isn't in your library any more" under
  /// something that is sitting right there in the list.
  @Test("aRenamedPlaylistIsStillTheSamePlaylist")
  func aRenamedPlaylistIsStillTheSamePlaylist() {
    let renamed = MusicSelection(kind: .playlist, identifier: "p.1", title: "Deep focus (old name)")

    #expect(Self.library.contains(renamed))
  }

  /// Something that really has left the library is reported as absent, which is
  /// what gives the "Now chosen" section something to say.
  @Test("anItemThatHasLeftTheLibraryIsReportedAsAbsent")
  func anItemThatHasLeftTheLibraryIsReportedAsAbsent() {
    let gone = MusicSelection(kind: .playlist, identifier: "p.gone", title: "Late nights")

    #expect(Self.library.contains(gone) == false)
  }

  /// A song's identifier is not looked for among the playlists, and the other way
  /// round.
  @Test("theTwoKindsAreLookedForInTheirOwnLists")
  func theTwoKindsAreLookedForInTheirOwnLists() {
    let songWearingAPlaylistIdentifier = MusicSelection(kind: .song, identifier: "p.1", title: "Deep Focus")

    #expect(Self.library.contains(songWearingAPlaylistIdentifier) == false)
  }

  // MARK: Private

  private static let deepFocus = MusicSelection(kind: .playlist, identifier: "p.1", title: "Deep Focus")
  private static let soWhat = MusicSelection(kind: .song, identifier: "s.1", title: "So What")

  private static let library = MusicPickerScreenModel(
    playlists: [
      deepFocus,
      MusicSelection(kind: .playlist, identifier: "p.2", title: "Piano")
    ],
    songs: [
      soWhat,
      MusicSelection(kind: .song, identifier: "s.2", title: "Blue in Green")
    ])
}
