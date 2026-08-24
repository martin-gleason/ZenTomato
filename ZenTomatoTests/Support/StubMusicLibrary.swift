import Foundation

@testable import ZenTomato

/// A music library that holds whatever a test puts in it.
///
/// WHY THIS EXISTS, AND WHAT IT DELIBERATELY DOES NOT PROVE
/// There is no music library in a simulator and no Apple Music account behind
/// one, so every test in this suite runs against this. It answers the three
/// questions `MusicLibraryReading` allows and records what it was asked, which is
/// enough to prove the *logic* — that a deleted playlist produces the explaining
/// state, that an empty library produces the empty-library block, that a library
/// that cannot be read is not reported as an empty one.
///
/// It proves nothing at all about whether sound comes out of a phone, and it is
/// not meant to. That split is stated in the pull request as well as here: our
/// rules are checked against stubs, and the device check is what covers the
/// reality.
///
/// **It has no write side, because the protocol has none.** There is nothing here
/// to record a playlist being built, because nothing in the app can ask for one.
@MainActor
final class StubMusicLibrary: MusicLibraryReading {
  // MARK: Nested types

  /// What `resolve` should answer.
  enum Resolution {
    /// Still in the library, under the same name.
    case unchanged
    /// Still there, renamed since it was chosen.
    case renamed(String)
    /// Gone.
    case gone
    /// The question could not be answered at all.
    case fails
  }

  // MARK: What it holds

  var playlistsInTheLibrary: [MusicSelection] = []
  var songsInTheLibrary: [MusicSelection] = []

  /// What the next `resolve` will answer.
  var resolution = Resolution.unchanged

  /// Set to make both list reads throw, which is a library that cannot be read
  /// rather than one that is empty. The difference matters: the first must never
  /// be reported as the second.
  var listReadFails = false

  // MARK: What it was asked

  private(set) var playlistReads = 0
  private(set) var songReads = 0
  private(set) var resolveRequests: [MusicSelection] = []

  // MARK: MusicLibraryReading

  func playlists() async throws -> [MusicSelection] {
    playlistReads += 1
    if listReadFails { throw StubLibraryFailure.couldNotRead }
    return playlistsInTheLibrary
  }

  func songs() async throws -> [MusicSelection] {
    songReads += 1
    if listReadFails { throw StubLibraryFailure.couldNotRead }
    return songsInTheLibrary
  }

  func resolve(_ selection: MusicSelection) async throws -> MusicSelection? {
    resolveRequests.append(selection)
    switch resolution {
    case .unchanged:
      return selection
    case .renamed(let title):
      return MusicSelection(kind: selection.kind, identifier: selection.identifier, title: title)
    case .gone:
      return nil
    case .fails:
      throw StubLibraryFailure.couldNotRead
    }
  }
}

/// The one thing a stubbed library can go wrong with.
///
/// Named rather than a bare `NSError` so that a test reading the failure path
/// says what it is testing.
enum StubLibraryFailure: Error {
  case couldNotRead
}
