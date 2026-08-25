import Foundation
import Testing

@testable import ZenTomato

/// The no-capture rule over the **music** picker's search.
///
/// **THIS TEST IS A CONDITION, NOT A COURTESY.** `F4-contract.md` §7 permitted a
/// search field on this sheet only on terms:
///
/// > Page it, and if paging turns out to need a search field, that field must
/// > offer nothing when it finds nothing — `NoCaptureSurfaceTests` already covers
/// > the idiom and **the same test must cover this picker.**
///
/// F4e is the feature that took that permission. This file is the second half of
/// the bargain, and it deliberately mirrors `NoCaptureSurfaceTests` rather than
/// inventing a new shape: same two mechanisms, same vocabulary list, so a reader
/// of one can read the other.
///
/// **Why a music library is a real no-capture risk and not a technicality.** The
/// rule in `CLAUDE.md` is about tasks, and no playlist is a task. But the failure
/// mode is a shape rather than a noun: an empty search result is where every app
/// on the phone offers to *make* the thing you just typed, because the
/// framework's own empty-state view has a slot for an action and every tutorial
/// fills it. A "create this playlist" button would be this app writing to a
/// library it is only ever allowed to read — the music-shaped version of exactly
/// the same mistake.
@Suite("MusicNoCapture")
struct MusicNoCaptureTests {
  // MARK: By shape

  /// The picker can draw a playlist or a song. **There is no third kind of row**,
  /// in any state — not at the end of a list, not under a search with no matches.
  ///
  /// This switch has no `default`, which is the mechanism: a new case on
  /// `MusicPickerScreenModel.Row` stops the test bundle compiling, and the only
  /// way past it is a diff the owner reads. The same enforcement
  /// `MusicPickerScreenModelTests` already applies to the unfiltered lists, now
  /// applied to the filtered ones — which is where a "create this" row would
  /// actually be appended.
  @Test("aFilteredPickerCanOnlyDrawPlaylistsAndSongs")
  func aFilteredPickerCanOnlyDrawPlaylistsAndSongs() {
    let everyRow = Self.library.playlistRows(matching: "a")
      + Self.library.songRows(matching: "a")
      + Self.library.playlistRows(matching: "")
      + Self.library.songRows(matching: "nothing matches this at all")

    for row in everyRow {
      switch row {
      case .playlist, .song:
        continue
      }
    }

    #expect(everyRow.isEmpty == false)
  }

  /// `aSearchWithNoMatchesOffersNothing` — **no rows at all.**
  ///
  /// So there is nothing for a trailing "create this playlist" row to be appended
  /// to. This is the literal sentence of the contract's condition.
  @Test("aSearchWithNoMatchesOffersNothing")
  func aSearchWithNoMatchesOffersNothing() {
    let query = "make me a playlist about rain"

    #expect(Self.library.playlistRows(matching: query).isEmpty)
    #expect(Self.library.songRows(matching: query).isEmpty)
    #expect(Self.library.hasNoMatches(for: query))
  }

  // MARK: By words

  /// Nothing this sheet can say offers to make anything.
  ///
  /// The same vocabulary `NoCaptureSurfaceTests` uses on the Todoist picker. A
  /// control that offered to create a playlist would have to be labelled, and a
  /// label is a string, and every string this screen can show is below.
  @Test("nothingThisSheetSaysOffersToMakeAnything")
  func nothingThisSheetSaysOffersToMakeAnything() {
    for sentence in Self.everySentenceTheMusicPickerCanSay {
      let lowered = sentence.lowercased()
      for word in Self.creationWords {
        #expect(
          lowered.contains(word) == false,
          Comment(rawValue: "“\(sentence)” contains the creation word “\(word)”."))
      }
    }
  }

  /// The empty state names where playlists actually come from.
  ///
  /// In the place every other app puts a button — the same move the Todoist
  /// picker makes with *"Tasks are created in Todoist, not here."*
  @Test("theNoMatchStateSaysWherePlaylistsComeFrom")
  func theNoMatchStateSaysWherePlaylistsComeFrom() {
    #expect(MusicCopy.noMatchHeading == "Nothing in your library matches.")
    #expect(MusicCopy.noMatchDetail(for: "rain").contains("Apple Music"))
    #expect(MusicCopy.noMatchDetail(for: "rain").contains("rain"))
  }

  /// The search prompt is a verb that **reads**.
  @Test("theSearchPromptIsAVerbThatReads")
  func theSearchPromptIsAVerbThatReads() {
    #expect(MusicCopy.searchPrompt == "Search your music")
  }

  // MARK: By construction

  /// **No `ContentUnavailableView` on this screen**, and that is not fussiness.
  ///
  /// Its initialiser takes an `actions` closure. A slot for an action, on the one
  /// screen where an offer to create a playlist would belong, is a slot somebody
  /// eventually fills — and it would arrive looking like idiomatic SwiftUI rather
  /// than like a violation. The empty state reuses `quietBlock`, which draws text
  /// and cannot draw a button.
  @Test("theEmptyStateHasNoSlotForAnAction")
  func theEmptyStateHasNoSlotForAnAction() throws {
    let picker = try Self.source("ZenTomato/Views/MusicPickerView.swift")
    let stripped = picker
      .components(separatedBy: "\n")
      .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") == false }
      .joined(separator: "\n")

    #expect(
      stripped.contains("ContentUnavailableView") == false,
      "The music picker gained an empty-state view with a slot for an action.")
    #expect(
      stripped.contains("TextField") == false,
      "A raw text field appeared on the music sheet; the search field must be `.searchable`.")
  }

  // MARK: Private

  private static let library = MusicPickerScreenModel(
    playlists: [
      MusicSelection(kind: .playlist, identifier: "p.1", title: "Deep Focus"),
      MusicSelection(kind: .playlist, identifier: "p.2", title: "Café del Mar")
    ],
    songs: [MusicSelection(kind: .song, identifier: "s.1", title: "Rain on Tin")])

  /// Lifted verbatim from `NoCaptureSurfaceTests`, so the two screens are held to
  /// one standard rather than two.
  private static let creationWords = ["add ", "new task", "create a", "create your", "compose", "+ "]

  private static let everySentenceTheMusicPickerCanSay = [
    MusicCopy.searchPrompt,
    MusicCopy.noMatchHeading,
    MusicCopy.noMatchDetail(for: "rain"),
    MusicCopy.playlistsHeader,
    MusicCopy.songsHeader,
    MusicCopy.readingLibrary,
    MusicCopy.libraryUnreadable,
    MusicCopy.settingsFooter(for: .ready),
    MusicCopy.settingsFooter(for: .notAsked),
    MusicCopy.deniedFooter,
    MusicCopy.restrictedFooter,
    MusicCopy.noSubscriptionFooter,
    MusicCopy.couldNotBeCheckedFooter
  ]

  private static func source(_ path: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    return try String(contentsOf: root.appending(path: path), encoding: .utf8)
  }
}
