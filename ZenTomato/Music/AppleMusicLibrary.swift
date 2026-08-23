@preconcurrency import MusicKit

/// The one place in this app that reads somebody's music library.
///
/// **This file is one of exactly three that name Apple's music framework at
/// all.** The other two own the player and the permission. Everything else in the
/// app — the picker, the row on the timer screen, the coordinator and every test
/// — deals in `MusicSelection`, which is three plain strings. That is what lets
/// the whole feature be tested with no framework anywhere near it, and it is why
/// a scope grep for the framework's name has exactly three answers.
///
/// **`@preconcurrency import` is deliberate and it is the prescribed remedy.**
/// Apple's music framework is built in Swift 5 and marks nothing with a global
/// actor, while this app is built in Swift 6 with the strictest data-race
/// checking the compiler offers. That mismatch produces diagnostics about values
/// that are perfectly safe here because this whole type is confined to the main
/// thread. The import is how that is said once, at the top, rather than with a
/// suppression at each call site — and the two shortcuts that would also silence
/// it, an unsafe global or an unchecked promise of thread safety, are forbidden
/// by the build contract because both would move real work off the main thread
/// and reintroduce an ordering bug F2 already paid for once.
///
/// WHAT IT READS, AND WHAT IT CANNOT DO
/// Two kinds of thing — playlists and songs — from the user's **own library**.
/// `SPEC.md` says *"an existing playlist or song from their library"*, so there is
/// no catalogue request anywhere in this file: a catalogue result is something
/// the person does not own and cannot be given. There is no request here that
/// changes anything, in the library or out of it. The framework's write side
/// exists and is named nowhere in this repository.
///
/// A NOTE FOR ANYONE RUNNING THIS IN A SIMULATOR
/// A simulator has no music library and no Apple Music, so every method here
/// answers with nothing. That is not a bug and it is not a state worth
/// special-casing: an empty library is a real state on a real phone, it has its
/// own copy on the picker, and the device check is what covers the rest.
@MainActor
final class AppleMusicLibrary: MusicLibraryReading {
  // MARK: Internal

  /// Every playlist in the user's own library.
  func playlists() async throws -> [MusicSelection] {
    try await everything(Playlist.self) { playlist in
      MusicSelection(kind: .playlist, identifier: playlist.id.rawValue, title: playlist.name)
    }
  }

  /// Every song in the user's own library.
  func songs() async throws -> [MusicSelection] {
    try await everything(Song.self) { song in
      MusicSelection(kind: .song, identifier: song.id.rawValue, title: song.title)
    }
  }

  /// Whether the chosen item is still there, and what it is called now.
  ///
  /// One request, filtered by identifier, for the one kind of thing the stored
  /// preference says it is. An answer of nothing is the stale-identifier state
  /// and is the only route to it.
  func resolve(_ selection: MusicSelection) async throws -> MusicSelection? {
    switch selection.kind {
    case .playlist:
      var request = MusicLibraryRequest<Playlist>()
      request.filter(matching: \.id, equalTo: MusicItemID(selection.identifier))
      request.limit = 1
      guard let found = try await request.response().items.first else { return nil }
      return MusicSelection(kind: .playlist, identifier: found.id.rawValue, title: found.name)

    case .song:
      var request = MusicLibraryRequest<Song>()
      request.filter(matching: \.id, equalTo: MusicItemID(selection.identifier))
      request.limit = 1
      guard let found = try await request.response().items.first else { return nil }
      return MusicSelection(kind: .song, identifier: found.id.rawValue, title: found.title)
    }
  }

  // MARK: Private

  /// How many items are asked for in one request.
  ///
  /// **The library is read in pages rather than in one go, and the reason is a
  /// stall rather than politeness.** The framework documents no default for how
  /// much a single request returns, and a library of ten thousand songs fetched
  /// in one call is a visible freeze on the first tap of the Music sheet. Pages
  /// keep each individual request small and let the work be cancelled part way
  /// through — closing the sheet stops it.
  ///
  /// The number is a compromise with no science behind it: small enough that one
  /// request is quick, large enough that an ordinary library is one or two
  /// requests rather than fifty.
  private static let pageSize = 250

  /// Reads one kind of thing, a page at a time, until the library runs out.
  ///
  /// The loop ends when a page comes back shorter than it asked for, which is how
  /// the framework says "that is all of them". Every pass checks whether the work
  /// has been cancelled, so a sheet that is closed mid-read stops rather than
  /// carrying on against a screen nobody is looking at.
  ///
  /// The request is built fresh inside the loop and never touched again after the
  /// answer arrives. That is not tidiness: it is what lets the compiler see that
  /// nothing is shared across the wait, in a file where the framework underneath
  /// makes no promises about threads at all.
  private func everything<Item: MusicLibraryRequestable>(
    _ type: Item.Type,
    as makeSelection: (Item) -> MusicSelection
  ) async throws -> [MusicSelection] {
    var found: [MusicSelection] = []
    var offset = 0

    while true {
      try Task.checkCancellation()

      var request = MusicLibraryRequest<Item>()
      request.limit = Self.pageSize
      request.offset = offset
      let page = try await request.response().items

      found.append(contentsOf: page.map(makeSelection))
      guard page.count == Self.pageSize else { return found }
      offset += page.count
    }
  }
}
