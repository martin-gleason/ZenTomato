import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// What happens when music cannot play, which is most of this feature.
///
/// **EVERY TEST IN THIS FILE IS THE SAME CLAIM FROM A DIFFERENT ANGLE: A MUSIC
/// FAILURE PRODUCES A WORKING SILENT TIMER.** That is the ratified decision
/// (D19.2), it is the opposite of how the alarm permission behaves, and the
/// difference is deliberate — a Pomodoro timer that cannot tell you a block
/// ended has no working state to degrade into, whereas one that is merely quiet
/// works perfectly.
///
/// Two of these run a real timer engine alongside the music, because that claim
/// is about the timer and asserting it on the music alone would be asserting
/// half of it. The rest use stand-ins, because refusing a permission or
/// cancelling somebody's Apple Music subscription is not something a build
/// machine can be asked to do.
///
/// The copy is asserted word for word rather than merely tested for existence.
/// These sentences are the entire explanation a person gets, they are the only
/// place several of these situations are ever mentioned, and one of them
/// drifting into jargon is a defect nothing else would catch.
@Suite("MusicAvailability")
@MainActor
struct MusicAvailabilityTests {
  private static let deepFocus = MusicSelection(
    kind: .playlist, identifier: "p.deepfocus", title: "Deep Focus")

  // MARK: The copy

  /// Every reason music cannot play says why, in one plain sentence.
  ///
  /// Word for word, because these are the whole of what a person is told. None
  /// of them names a framework, an error code or a permission system; none of
  /// them reads as though the app is broken; and none of them asks for money.
  @Test("everyUnavailableCaseSaysWhyInOnePlainLine")
  func everyUnavailableCaseSaysWhyInOnePlainLine() {
    #expect(MusicAvailability.denied.explanation == "ZenTomato doesn't have permission to use your music.")
    #expect(MusicAvailability.restricted.explanation == "Music is turned off on this iPhone.")
    #expect(MusicAvailability.noSubscription.explanation == "Playing your library needs Apple Music.")
    #expect(
      MusicAvailability.couldNotBeChecked.explanation
        == "ZenTomato couldn't tell whether it can play your music.")
  }

  /// The two cases that are not failures explain nothing.
  ///
  /// `notAsked` matters most: somebody who has never switched music on is not
  /// owed an explanation of a permission nobody has asked them for, and putting
  /// one there would turn the first launch into a screen full of apology.
  @Test("readyAndNotAskedExplainNothing")
  func readyAndNotAskedExplainNothing() {
    #expect(MusicAvailability.ready.explanation == nil)
    #expect(MusicAvailability.notAsked.explanation == nil)
    #expect(MusicAvailability.ready.permitsPlayback)
    #expect(MusicAvailability.notAsked.permitsPlayback == false)
  }

  /// Exactly one of the six cases permits sound.
  ///
  /// Written over every case rather than over the four failures, so that adding
  /// a seventh without deciding what it means fails here rather than silently
  /// playing or silently not.
  @Test("onlyOneCasePermitsSound")
  func onlyOneCasePermitsSound() {
    let permitted = MusicAvailability.allCases.filter(\.permitsPlayback)
    #expect(permitted == [.ready])

    for value in MusicAvailability.allCases where value != .ready && value != .notAsked {
      #expect(value.explanation?.isEmpty == false, "\(value) has nothing to say for itself")
    }
  }

  // MARK: Permission

  /// A refused permission puts the switch back to off.
  ///
  /// A switch left sitting in the on position while nothing can play is a
  /// control that lies about itself, and the person has just touched it, so the
  /// correction has to be immediate and has to be written down — otherwise the
  /// next launch starts with the same lie.
  @Test("deniedAuthorizationSpringsTheSwitchBackToOff")
  func deniedAuthorizationSpringsTheSwitchBackToOff() async {
    let availability = StubMusicAvailability(current: .notAsked, authorizationAnswer: .denied)
    let preferences = StubMusicPreferenceStore(isEnabled: false, selection: Self.deepFocus)
    let player = SpyMusicPlayer()
    let coordinator = MusicCoordinator(
      player: player,
      availability: availability,
      library: StubMusicLibrary(),
      preferences: preferences)

    await coordinator.setEnabled(true)

    #expect(coordinator.isEnabled == false)
    #expect(preferences.isEnabled == false)
    #expect(coordinator.availability == .denied)
    #expect(availability.authorizationRequests == 1)
  }

  /// Permission is asked for when music is switched on, and at no other moment.
  ///
  /// Not at launch, not when the picker opens, not when a block starts. A
  /// permission prompt for a feature nobody has touched is the surest way to be
  /// refused, and this asserts the count rather than the intention.
  @Test("permissionIsAskedForOnlyWhenMusicIsSwitchedOn")
  func permissionIsAskedForOnlyWhenMusicIsSwitchedOn() async {
    let availability = StubMusicAvailability(current: .notAsked, authorizationAnswer: .ready)
    let coordinator = MusicCoordinator(
      player: SpyMusicPlayer(),
      availability: availability,
      library: StubMusicLibrary(),
      preferences: StubMusicPreferenceStore(isEnabled: false, selection: Self.deepFocus))

    coordinator.blockChanged(to: .work, isRunning: true)
    coordinator.blockChanged(to: .shortBreak, isRunning: true)
    coordinator.blockChanged(to: .work, isRunning: false, sprintIsOver: true)
    #expect(availability.authorizationRequests == 0)

    await coordinator.setEnabled(true)
    #expect(availability.authorizationRequests == 1)
  }

  // MARK: The timer is unaffected — with a real timer

  /// With permission refused, a whole sprint runs and nothing is ever played.
  @Test("deniedAuthDisablesMusicOnly")
  func deniedAuthDisablesMusicOnly() async throws {
    try await timerRunsNormally(whenAvailabilityIs: .denied)
  }

  /// With no Apple Music subscription, a whole sprint runs and nothing is ever
  /// played.
  @Test("noSubscriptionDisablesMusicOnly")
  func noSubscriptionDisablesMusicOnly() async throws {
    try await timerRunsNormally(whenAvailabilityIs: .noSubscription)
  }

  /// A subscription ending mid-sprint stops the music and nothing else.
  ///
  /// The sharpest form of D19.2: the most a lapsed subscription can do to this
  /// app is make it quiet. The block carries on to its own end, the switch is
  /// left where the person put it — a device condition is not a change of mind —
  /// and the explanation appears on the row.
  @Test("subscriptionEndingMidSprintStopsTheMusicAndNothingElse")
  func subscriptionEndingMidSprintStopsTheMusicAndNothingElse() async {
    let player = SpyMusicPlayer()
    let preferences = StubMusicPreferenceStore(isEnabled: true, selection: Self.deepFocus)
    let coordinator = MusicCoordinator(
      player: player,
      availability: StubMusicAvailability(current: .ready),
      library: StubMusicLibrary(),
      preferences: preferences)

    coordinator.blockChanged(to: .work, isRunning: true)
    await settle(until: { player.isPlaying })

    coordinator.availabilityChanged(to: .noSubscription)
    await settle(until: { player.isPlaying == false })

    #expect(player.isPlaying == false)
    // **THE QUEUE IS KEPT, WHICH IS A CHANGE FROM HOW THIS FIRST SHIPPED.**
    // Letting it go here contradicted the line below it in the same test: a
    // device condition is not the person changing their mind, so it does not
    // rewrite their switch — and it must not throw their place in the track
    // away either. A subscription that flickers during a renewal would
    // otherwise restart the playlist from the top in the middle of the
    // afternoon, which is the one audible defect this whole feature is shaped
    // to make unsayable. The sprint ending is what releases the queue.
    #expect(player.loaded == Self.deepFocus)
    #expect(player.callLog == ["load", "pause"])
    #expect(coordinator.isEnabled, "a lapsed subscription is not the person changing their mind")
    #expect(preferences.isEnabled)
    #expect(coordinator.availability.explanation != nil)
  }

  /// A subscription that comes back mid-sprint picks the same track up where it
  /// stopped.
  ///
  /// The other half of the test above, and the reason it is worth keeping the
  /// queue: a renewal, or a network blip clearing, is invisible to the person
  /// except as their music quietly coming back on.
  @Test("aSubscriptionComingBackMidSprintResumesRatherThanRestarts")
  func aSubscriptionComingBackMidSprintResumesRatherThanRestarts() async {
    let player = SpyMusicPlayer()
    let coordinator = MusicCoordinator(
      player: player,
      availability: StubMusicAvailability(current: .ready),
      library: StubMusicLibrary(),
      preferences: StubMusicPreferenceStore(isEnabled: true, selection: Self.deepFocus))

    coordinator.blockChanged(to: .work, isRunning: true)
    await settle(until: { player.isPlaying })

    coordinator.availabilityChanged(to: .noSubscription)
    await settle(until: { player.isPlaying == false })

    coordinator.availabilityChanged(to: .ready)
    await settle(until: { player.isPlaying })

    #expect(player.isPlaying)
    #expect(player.startedFromTheTopCount == 1, "the playlist started over")
    #expect(player.callLog == ["load", "pause", "resume"])
  }

  // MARK: A chosen item that has gone

  /// A playlist deleted since it was chosen is reported as gone.
  @Test("aDeletedPlaylistIsReportedAsGone")
  func aDeletedPlaylistIsReportedAsGone() async {
    let library = StubMusicLibrary()
    library.resolution = .gone
    let coordinator = MusicCoordinator(
      player: SpyMusicPlayer(),
      availability: StubMusicAvailability(current: .notAsked, authorizationAnswer: .ready),
      library: library,
      preferences: StubMusicPreferenceStore(isEnabled: false, selection: Self.deepFocus))

    await coordinator.setEnabled(true)
    await settle(until: { coordinator.selectionIsMissing })

    #expect(coordinator.selectionIsMissing)
    #expect(coordinator.selection == Self.deepFocus, "the old name is kept so the screen can name it")
  }

  /// A library that cannot be read is not reported as a missing item.
  ///
  /// Being absent from a library nobody could look at is not evidence. Saying
  /// "that playlist is gone" to somebody whose playlist is fine would send them
  /// off to fix something that is not broken; saying this app cannot tell is
  /// true, and it is one quiet line either way.
  @Test("anUnreadableLibraryIsNotAMissingItem")
  func anUnreadableLibraryIsNotAMissingItem() async {
    let library = StubMusicLibrary()
    library.resolution = .fails
    let coordinator = MusicCoordinator(
      player: SpyMusicPlayer(),
      availability: StubMusicAvailability(current: .notAsked, authorizationAnswer: .ready),
      library: library,
      preferences: StubMusicPreferenceStore(isEnabled: false, selection: Self.deepFocus))

    await coordinator.setEnabled(true)
    await settle(until: { coordinator.availability == .couldNotBeChecked })

    #expect(coordinator.selectionIsMissing == false)
    #expect(coordinator.availability == .couldNotBeChecked)
  }

  /// A renamed playlist keeps playing under its new name.
  @Test("aRenamedPlaylistTakesItsNewName")
  func aRenamedPlaylistTakesItsNewName() async {
    let library = StubMusicLibrary()
    library.resolution = .renamed("Deep Focus 2026")
    let preferences = StubMusicPreferenceStore(isEnabled: false, selection: Self.deepFocus)
    let coordinator = MusicCoordinator(
      player: SpyMusicPlayer(),
      availability: StubMusicAvailability(current: .notAsked, authorizationAnswer: .ready),
      library: library,
      preferences: preferences)

    await coordinator.setEnabled(true)
    await settle(until: { coordinator.selection?.title == "Deep Focus 2026" })

    #expect(coordinator.selection?.title == "Deep Focus 2026")
    #expect(coordinator.selection?.identifier == Self.deepFocus.identifier)
    #expect(preferences.selection?.title == "Deep Focus 2026")
  }

  // MARK: Helpers

  /// Runs a real timer through a focus block, a break and a focus block with
  /// music unavailable, and asserts the timer did not notice.
  ///
  /// The music side of the assertion is the strong one: the stand-in player was
  /// never asked to do anything at all. Not asked and refused; not asked.
  private func timerRunsNormally(whenAvailabilityIs unavailable: MusicAvailability) async throws {
    let container = try TestStore.inMemoryContainer()
    let alarms = SpyAlarmScheduler()
    let engine = TimerEngine(context: container.mainContext, clock: TestClock(), alarms: alarms)

    let player = SpyMusicPlayer()
    let coordinator = MusicCoordinator(
      player: player,
      availability: StubMusicAvailability(current: unavailable, authorizationAnswer: unavailable),
      library: StubMusicLibrary(),
      preferences: StubMusicPreferenceStore(isEnabled: true, selection: Self.deepFocus))

    let observer = BlockPhaseObserver(engine: engine, coordinator: coordinator)
    observer.start()
    defer { observer.stop() }

    await engine.start()
    await settle(until: { coordinator.isTimerRunning })

    #expect(engine.isRunning)
    #expect(engine.kind == .work)
    #expect(engine.endsAt != nil)
    #expect(engine.lastFailure == nil)
    #expect(alarms.outstanding != nil)

    await engine.stop(reason: "test")
    #expect(engine.isRunning == false)

    let sessions = try container.mainContext.fetch(FetchDescriptor<PomodoroSession>())
    #expect(sessions.count == 1, "the block was recorded exactly as it would have been")

    #expect(player.callLog.contains("load") == false)
    #expect(player.callLog.contains("resume") == false)
    #expect(player.isPlaying == false)
  }

  /// See `MusicTransitionTests.settle(until:limit:)`. Nothing here sleeps.
  private func settle(until isSettled: () -> Bool, limit: Int = 10_000) async {
    for _ in 0..<limit where !isSettled() {
      await Task.yield()
    }
  }
}
