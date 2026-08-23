import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// The one chosen playlist or song: remembered, replaced, and checked against the
/// library it came from.
///
/// **`@MainActor` on the whole suite**, because everything here holds a
/// `ModelContext` and those are not safe to share between threads. Every
/// persistence suite in this project is annotated the same way.
@Suite("MusicSelection")
@MainActor
struct MusicSelectionTests {
  // MARK: What survives a launch

  /// The switch and the choice must still be there after the app is closed and
  /// opened again.
  ///
  /// WHY THIS ONE USES A REAL FILE AND THE OTHERS DO NOT
  /// "It persists" is a claim about what happens after everything in memory is
  /// gone, and an in-memory store cannot answer it — it disappears together with
  /// the thing being tested. So this writes to an actual file, releases the
  /// container completely, and opens the same file fresh. It is the same shape
  /// `AppSettingsTests.settingsRoundTrip` uses, for the same reason.
  @Test("theSwitchAndTheChoiceSurviveALaunch")
  func theSwitchAndTheChoiceSurviveALaunch() throws {
    let store = try TestStore.temporaryFileStore()
    defer { store.remove() }

    // Written inside its own function so the container it opens is released the
    // moment the function returns.
    try chooseDeepFocus(in: store.storeURL)

    let reopened = try AppModelContainer.make(.file(store.storeURL))
    let preferences = MusicPreferenceStore(context: reopened.mainContext)

    #expect(preferences.isEnabled)
    #expect(preferences.selection == Self.deepFocus)
  }

  /// **The title is a snapshot**, stored beside the identifier for the same
  /// reason the session plan snapshots task titles: it is what the row can say
  /// when the thing itself has gone.
  @Test("theTitleIsStoredBesideTheIdentifier")
  func theTitleIsStoredBesideTheIdentifier() throws {
    let container = try TestStore.inMemoryContainer()
    let preferences = MusicPreferenceStore(context: container.mainContext)

    preferences.setSelection(Self.deepFocus)

    let row = try MusicPreferenceStore.current(in: container.mainContext)
    #expect(row.selectionID == "p.1")
    #expect(row.selectionTitle == "Deep Focus")
    // Stored as readable text rather than as a coded value, so the database can
    // be read off a phone and understood. F5's review was blocked once by a
    // stored value that could not be read this way.
    #expect(row.selectionKind == "playlist")
  }

  /// Asking for the preference twice must return the same single row.
  ///
  /// The accessor creates a row when it does not find one. If it ever failed to
  /// find the row it had just created, the app would gain a new one on every
  /// launch and music would silently switch itself off.
  @Test("thereIsOnlyEverOneRow")
  func thereIsOnlyEverOneRow() throws {
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext

    let first = try MusicPreferenceStore.current(in: context)
    first.isEnabled = true
    try context.save()

    let second = try MusicPreferenceStore.current(in: context)

    #expect(second.isEnabled)
    #expect(first.persistentModelID == second.persistentModelID)
    #expect(try context.fetch(FetchDescriptor<MusicPreference>()).count == 1)
  }

  /// A fresh install has music off with nothing chosen. Music is an accessory,
  /// and an app that started playing something the first time somebody pressed
  /// Start would be making a decision that is not its to make.
  @Test("aFreshInstallHasMusicOffWithNothingChosen")
  func aFreshInstallHasMusicOffWithNothingChosen() throws {
    let container = try TestStore.inMemoryContainer()
    let preferences = MusicPreferenceStore(context: container.mainContext)

    #expect(preferences.isEnabled == false)
    #expect(preferences.selection == nil)
  }

  // MARK: Exactly one thing is chosen, ever

  /// Choosing something else replaces what was chosen. There is no list here and
  /// no history of what was played before.
  @Test("choosingSomethingElseReplacesTheChoice")
  func choosingSomethingElseReplacesTheChoice() throws {
    let container = try TestStore.inMemoryContainer()
    let preferences = MusicPreferenceStore(context: container.mainContext)

    preferences.setSelection(Self.deepFocus)
    preferences.setSelection(Self.soWhat)

    #expect(preferences.selection == Self.soWhat)
    #expect(try container.mainContext.fetch(FetchDescriptor<MusicPreference>()).count == 1)
  }

  /// Turning the switch off leaves the choice exactly where it was, so turning it
  /// back on does not ask somebody to pick their playlist again.
  @Test("turningMusicOffKeepsTheChoice")
  func turningMusicOffKeepsTheChoice() throws {
    let container = try TestStore.inMemoryContainer()
    let preferences = MusicPreferenceStore(context: container.mainContext)

    preferences.setSelection(Self.deepFocus)
    preferences.setEnabled(true)
    preferences.setEnabled(false)

    #expect(preferences.isEnabled == false)
    #expect(preferences.selection == Self.deepFocus)
  }

  /// A row holding half a choice reads as nothing chosen.
  ///
  /// An identifier with no kind cannot be looked up, and a kind with no
  /// identifier names nothing. Either is a half-written row, and the honest
  /// reading of one is that nothing is chosen — rather than a blank title on the
  /// timer screen or a request for something that cannot exist.
  @Test("aHalfWrittenRowReadsAsNothingChosen")
  func aHalfWrittenRowReadsAsNothingChosen() throws {
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext

    let row = try MusicPreferenceStore.current(in: context)
    row.selectionID = "p.1"
    row.selectionKind = nil
    row.selectionTitle = nil
    try context.save()

    #expect(MusicPreferenceStore(context: context).selection == nil)
  }

  /// A kind this version of the app does not recognise reads as nothing chosen
  /// rather than being guessed at.
  @Test("anUnknownKindReadsAsNothingChosen")
  func anUnknownKindReadsAsNothingChosen() throws {
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext

    let row = try MusicPreferenceStore.current(in: context)
    row.selectionID = "x.1"
    row.selectionKind = "album"
    row.selectionTitle = "Kind of Blue"
    try context.save()

    #expect(MusicPreferenceStore(context: context).selection == nil)
  }

  // MARK: Against the library it came from

  /// A playlist deleted in the Music app resolves to nothing, which is the only
  /// route to the "isn't in your library any more" state.
  @Test("aDeletedPlaylistResolvesToNothing")
  func aDeletedPlaylistResolvesToNothing() async throws {
    let library = StubMusicLibrary()
    library.resolution = .gone

    #expect(try await library.resolve(Self.deepFocus) == nil)
    #expect(library.resolveRequests == [Self.deepFocus])
  }

  /// A playlist renamed in the Music app is still the same playlist, and comes
  /// back with the name it has now.
  @Test("aRenamedPlaylistComesBackWithItsNewName")
  func aRenamedPlaylistComesBackWithItsNewName() async throws {
    let library = StubMusicLibrary()
    library.resolution = .renamed("Deep focus, mornings")

    let resolved = try await library.resolve(Self.deepFocus)

    #expect(resolved?.identifier == Self.deepFocus.identifier)
    #expect(resolved?.title == "Deep focus, mornings")
  }

  /// **A library that cannot be read is not a library the item has left.** The
  /// read throws rather than answering "gone", so the screen can treat the two
  /// differently — reporting somebody's playlist as deleted because their phone
  /// could not answer would be the music-shaped version of the mistake the
  /// session plan refuses to make about an unfilled Todoist mirror.
  @Test("aLibraryThatCannotBeReadDoesNotClaimTheItemIsGone")
  func aLibraryThatCannotBeReadDoesNotClaimTheItemIsGone() async {
    let library = StubMusicLibrary()
    library.resolution = .fails

    await #expect(throws: StubLibraryFailure.self) {
      _ = try await library.resolve(Self.deepFocus)
    }
  }

  /// The same distinction one level up: a list read that fails is not an empty
  /// library.
  @Test("aListReadThatFailsIsNotAnEmptyLibrary")
  func aListReadThatFailsIsNotAnEmptyLibrary() async {
    let library = StubMusicLibrary()
    library.listReadFails = true

    await #expect(throws: StubLibraryFailure.self) {
      _ = try await library.playlists()
    }
    await #expect(throws: StubLibraryFailure.self) {
      _ = try await library.songs()
    }
  }

  // MARK: Private

  private static let deepFocus = MusicSelection(
    kind: .playlist,
    identifier: "p.1",
    title: "Deep Focus")

  private static let soWhat = MusicSelection(
    kind: .song,
    identifier: "s.1",
    title: "So What")

  /// Opens the store, makes a choice, and lets go of the store again.
  private func chooseDeepFocus(in url: URL) throws {
    let container = try AppModelContainer.make(.file(url))
    let preferences = MusicPreferenceStore(context: container.mainContext)
    preferences.setSelection(Self.deepFocus)
    preferences.setEnabled(true)
  }
}
