import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// What the music does as the timer moves from block to block.
///
/// WHAT THESE PROVE, AND WHAT THEY DELIBERATELY DO NOT
/// Every test in this file drives a stand-in player that records what it was
/// asked to do and makes no sound. That is the honest half of a split stated in
/// `MusicPlaying`: there is no simulator for "sound came out of the phone", so
/// what is proved here is every decision this app makes about *when* to play,
/// pause, resume, stop and skip. Whether the sound then arrives is the device
/// check's job on a real phone, and no test in this repository claims otherwise.
///
/// **The claim that matters most is `resumeIsNeverARestart`.** Continuing a
/// paused track and starting a playlist over both look like "music is playing",
/// so the difference is invisible from outside — which is exactly why it is the
/// requirement most likely to break unnoticed and stay broken. The stand-in
/// counts loads, and one load per sprint is the whole of the proof.
///
/// Nothing here sleeps, opens a network connection, or links a music framework.
@Suite("MusicTransition")
@MainActor
struct MusicTransitionTests {
  // MARK: Setup

  private let player: SpyMusicPlayer
  private let availability: StubMusicAvailability
  private let library: StubMusicLibrary
  private let preferences: StubMusicPreferenceStore
  private let coordinator: MusicCoordinator

  /// The chosen playlist for every test in this file.
  private static let deepFocus = MusicSelection(
    kind: .playlist, identifier: "p.deepfocus", title: "Deep Focus")

  /// A different one, for the tests about changing the choice.
  private static let seaShanties = MusicSelection(
    kind: .song, identifier: "s.shanty", title: "Wellerman")

  init() {
    let player = SpyMusicPlayer()
    let availability = StubMusicAvailability()
    let library = StubMusicLibrary()
    let preferences = StubMusicPreferenceStore(isEnabled: true, selection: Self.deepFocus)

    self.player = player
    self.availability = availability
    self.library = library
    self.preferences = preferences
    coordinator = MusicCoordinator(
      player: player, availability: availability, library: library, preferences: preferences)
  }

  // MARK: The sequence

  /// A break pauses and the next focus block continues.
  ///
  /// The three calls in order are the whole of the contract's break behaviour,
  /// and `resume` rather than a second `load` is what makes it *continue*.
  @Test("pausesOnBreakResumesOnWork")
  func pausesOnBreakResumesOnWork() async {
    await moveTo(.work)
    await moveTo(.shortBreak)
    await moveTo(.work)

    #expect(player.callLog == ["load", "pause", "resume"])
    #expect(player.isPlaying)
  }

  /// A long break behaves exactly like a short one.
  ///
  /// There is no separate long-break path anywhere in this feature, and this is
  /// the test that says so — the rule reads "a break", never "a short break".
  @Test("longBreakBehavesLikeAShortBreak")
  func longBreakBehavesLikeAShortBreak() async {
    await moveTo(.work)
    await moveTo(.longBreak)
    await moveTo(.work)

    #expect(player.callLog == ["load", "pause", "resume"])
  }

  /// A whole sprint loads the queue exactly once.
  ///
  /// Four focus blocks, three short breaks and a long break. A second load
  /// anywhere in that sequence is somebody's track starting again from the
  /// beginning halfway through their afternoon, which is the defect the
  /// pause-and-resume requirement exists to prevent and the one thing a person
  /// would certainly notice.
  @Test("resumeIsNeverARestart")
  func resumeIsNeverARestart() async {
    await moveTo(.work)
    await moveTo(.shortBreak)
    await moveTo(.work)
    await moveTo(.shortBreak)
    await moveTo(.work)
    await moveTo(.shortBreak)
    await moveTo(.work)
    await moveTo(.longBreak)

    #expect(player.startedFromTheTopCount == 1)
    #expect(
      player.callLog
        == ["load", "pause", "resume", "pause", "resume", "pause", "resume", "pause"])
  }

  /// The end of a sprint lets the queue go, and the next sprint starts the
  /// playlist from the top.
  ///
  /// The ratified wording is *"at sprint end it stops and leaves the system
  /// player alone"*. Letting the queue go is what makes that true, and it is
  /// also what makes the next Start a clean beginning rather than the middle of
  /// a track from an hour ago.
  @Test("sprintEndReleasesTheQueue")
  func sprintEndReleasesTheQueue() async {
    await moveTo(.work)
    await moveTo(.longBreak)
    await comeToRest(sprintIsOver: true)

    #expect(player.loaded == nil)
    #expect(player.isPlaying == false)

    await moveTo(.work)
    #expect(player.startedFromTheTopCount == 2)
    #expect(player.callLog == ["load", "pause", "stop", "load"])
  }

  /// Standing between two blocks of a live sprint keeps the place in the track.
  ///
  /// With auto-start switched off the timer comes to rest at every boundary,
  /// which looks like "idle" and is not the end of anything. Letting the queue
  /// go there would restart the track every time somebody took a minute before
  /// pressing Start, which is the same audible defect as restarting after a
  /// break — arrived at by a different route.
  @Test("betweenBlocksKeepsThePlaceInTheTrack")
  func betweenBlocksKeepsThePlaceInTheTrack() async {
    await moveTo(.work)
    await comeToRest(kind: .shortBreak, sprintIsOver: false)
    await moveTo(.shortBreak)
    await comeToRest(kind: .work, sprintIsOver: false)
    await moveTo(.work)

    #expect(player.startedFromTheTopCount == 1)
    #expect(player.loaded == Self.deepFocus)
    #expect(player.isPlaying)
  }

  /// Nothing plays during a break, whatever else is true.
  @Test("aBreakIsAlwaysSilent")
  func aBreakIsAlwaysSilent() async {
    await moveTo(.work)
    await moveTo(.shortBreak)

    #expect(player.isPlaying == false)
  }

  // MARK: The switch

  /// Switching music off while idle means the next focus block is silent.
  @Test("toggleOffStopsPlayback")
  func toggleOffStopsPlayback() async {
    await moveTo(.work)
    await comeToRest(sprintIsOver: true)

    await coordinator.setEnabled(false)
    #expect(coordinator.isEnabled == false)
    #expect(preferences.isEnabled == false)

    await moveTo(.work)
    await moveTo(.shortBreak)
    await moveTo(.work)

    #expect(player.isPlaying == false)
    #expect(player.startedFromTheTopCount == 1)
    #expect(player.callLog.contains("resume") == false)
  }

  /// The switch and the chosen item are both refused while a block is running.
  ///
  /// **This asserts the refusal in the model, not on the screen.** The screen
  /// draws the switch dimmed, which stops today's finger; this stops every
  /// future caller, including one added by somebody who has not read the
  /// contract. Both exist, and only this one holds for code nobody has written
  /// yet.
  @Test("toggleLockedDuringSprint")
  func toggleLockedDuringSprint() async {
    await moveTo(.work)
    let writesBefore = preferences.writes

    await coordinator.setEnabled(false)
    coordinator.setSelection(Self.seaShanties)

    #expect(coordinator.isEnabled)
    #expect(coordinator.selection == Self.deepFocus)
    #expect(preferences.writes == writesBefore)
    #expect(player.isPlaying)
  }

  /// Choosing something else while idle plays the new thing from the next block.
  @Test("choosingSomethingElseTakesEffectAtTheNextBlock")
  func choosingSomethingElseTakesEffectAtTheNextBlock() async {
    coordinator.setSelection(Self.seaShanties)
    #expect(preferences.selection == Self.seaShanties)

    await moveTo(.work)
    #expect(player.loaded == Self.seaShanties)
  }

  // MARK: Skip

  /// Skip moves to the next track and changes nothing else.
  @Test("skipMovesOnAndNothingElseHappens")
  func skipMovesOnAndNothingElseHappens() async {
    await moveTo(.work)

    coordinator.skipForward()
    await settle(until: { player.callLog.contains("skipForward") })

    #expect(player.callLog == ["load", "skipForward"])
    #expect(player.isPlaying)
    #expect(player.startedFromTheTopCount == 1)
  }

  /// Skip does nothing when nothing is playing.
  ///
  /// The button is not on screen then either. This is the second of the two
  /// refusals: the screen's, and this one, which holds for any future caller.
  @Test("skipDoesNothingWhenSilent")
  func skipDoesNothingWhenSilent() async {
    await moveTo(.work)
    await moveTo(.shortBreak)

    coordinator.skipForward()
    await settle(until: { false }, limit: 20)

    #expect(player.callLog == ["load", "pause"])
  }

  // MARK: The timer is never affected

  /// A music failure leaves the timer running exactly as it would have.
  ///
  /// **THIS IS THE FEATURE'S MOST IMPORTANT PROPERTY AND THE ONLY TEST HERE
  /// THAT USES A REAL TIMER.** The ratified decision is that every music
  /// failure degrades to a silent working timer, never to a broken one. So this
  /// test breaks the music in the worst way available — the player refuses to
  /// load anything at all — and then asserts on the timer: it starts, it is
  /// running, it knows when the block ends, and it records no failure of its
  /// own. The music reports its failure to the screen and to nobody else.
  ///
  /// It also exercises the real subscription to the timer, which is the piece
  /// this feature adds without changing a line of the timer: the engine is
  /// never told this test is happening.
  @Test("musicFailureLeavesTheTimerUntouched")
  func musicFailureLeavesTheTimerUntouched() async throws {
    let container = try TestStore.inMemoryContainer()
    let alarms = SpyAlarmScheduler()
    let engine = TimerEngine(context: container.mainContext, clock: TestClock(), alarms: alarms)

    player.loadError = SpyMusicPlayer.Failure()

    let observer = BlockPhaseObserver(engine: engine, coordinator: coordinator)
    observer.start()
    defer { observer.stop() }

    await engine.start()
    await settle(until: { coordinator.isTimerRunning && !coordinator.isStarting })

    // The timer.
    #expect(engine.isRunning)
    #expect(engine.kind == .work)
    #expect(engine.endsAt != nil)
    #expect(engine.lastFailure == nil)
    #expect(alarms.outstanding != nil)

    // The music.
    #expect(coordinator.lastPlaybackFailed)
    #expect(player.isPlaying == false)

    // And the timer still ends the way it always would.
    await engine.stop(reason: "test")
    #expect(engine.isRunning == false)
  }

  // MARK: Helpers

  /// Tells the coordinator a block of this kind is now running, and lets any
  /// work it started finish.
  private func moveTo(_ kind: BlockKind) async {
    coordinator.blockChanged(to: kind, isRunning: true, sprintIsOver: false)
    await settle(until: { !coordinator.isStarting })
  }

  /// Tells the coordinator the timer has come to rest.
  ///
  /// - Parameters:
  ///   - kind: the block that would start next.
  ///   - sprintIsOver: whether this is the end of a sprint, as opposed to a
  ///     pause between two blocks of one.
  private func comeToRest(kind: BlockKind = .work, sprintIsOver: Bool) async {
    coordinator.blockChanged(to: kind, isRunning: false, sprintIsOver: sprintIsOver)
    await settle(until: { !coordinator.isStarting })
  }

  /// Hands the thread to work the coordinator started, until the test can see
  /// what it was waiting for.
  ///
  /// The coordinator, the stand-ins and this test all run on the main thread, so
  /// a task the coordinator started can only make progress while the test is
  /// suspended. Yielding is what suspends it. **Nothing here waits on the wall
  /// or on a timer** — no test in this project sleeps. The ceiling exists so
  /// that a broken coordinator ends the test rather than hanging it.
  private func settle(until isSettled: () -> Bool, limit: Int = 10_000) async {
    for _ in 0..<limit where !isSettled() {
      await Task.yield()
    }
  }
}
