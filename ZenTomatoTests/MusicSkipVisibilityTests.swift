import Foundation
import Testing

@testable import ZenTomato

/// The skip button follows `isPlaying`, and `isPlaying` follows the player.
///
/// WHY THIS SUITE EXISTS
/// The skip button shipped invisible, and only sometimes. It was there in one
/// sprint and gone in the next, which reads as a mystery rather than a bug.
///
/// The cause was a race. `isPlaying` was refreshed only at the end of the calls
/// that start playback — but a player reports that it has started playing some
/// time AFTER `load()` or `resume()` has returned. So the reading was taken
/// before the status flipped, recorded "not playing", and was never corrected;
/// the button then stayed hidden for the whole block.
///
/// Every existing music test passed throughout, because a spy that flips its own
/// status synchronously cannot reproduce a race the real player has. The spy now
/// announces its status change separately, the way MusicKit does.
@MainActor
struct MusicSkipVisibilityTests {
  init() {
    let player = SpyMusicPlayer()
    self.player = player
    coordinator = MusicCoordinator(
      player: player,
      availability: StubMusicAvailability(),
      library: StubMusicLibrary(),
      preferences: StubMusicPreferenceStore(isEnabled: true, selection: Self.deepFocus))
  }

  /// The player starting LATER than the call that started it still shows the
  /// button. This is the shipped bug, in one test.
  @Test("a late status change is picked up")
  func lateStatusChangeIsPickedUp() async {
    coordinator.blockChanged(to: .work, isRunning: true)
    // BOTH TASKS ARE AWAITED, NOT GUESSED AT. This test drove the load with two
    // `Task.yield()` calls, which was two hops of hope: on the machine this was
    // written on it was enough, and elsewhere it was not. `F4g`.
    await coordinator.awaitPendingSound()

    // Whatever the spy reports synchronously, the coordinator must be LISTENING
    // — that is what makes a late flip reach the screen. Announce a change and
    // the coordinator must re-read rather than keep its first answer.
    player.announceStatusChange()
    await coordinator.awaitPendingPlaybackRead()

    // ASSERTED AGAINST `true`, NOT AGAINST THE PLAYER. `isPlaying == player.isPlaying`
    // is satisfied when BOTH are false, which is what a load that never completed
    // leaves behind — so the original form could not tell "re-read correctly" from
    // "nothing happened at all".
    #expect(player.isPlaying == true,
            "the fixture must actually be playing, or the comparison below is vacuous")
    #expect(coordinator.isPlaying == true,
            "a status change after the call must be re-read, not remembered")
  }

  /// The coordinator subscribes at all. Without this the test above could pass
  /// for the wrong reason if something else happened to refresh.
  @Test("the coordinator listens to the player")
  func coordinatorSubscribes() {
    #expect(player.onPlaybackStatusChanged != nil)
  }

  /// A pause the app did not cause — Control Centre, headphones unplugged —
  /// hides the button, because there is nothing to skip.
  ///
  /// **THIS TEST WAS VACUOUS IN ONE DIRECTION AND FALSE-FAILING IN THE OTHER, and
  /// the cause was one missing `await`.** `A18` moved the playback read off the
  /// main actor, so `isPlaying` lands a turn after the announcement. The sibling
  /// test above was updated for that and says so; this one was not. One test of a
  /// matched pair changed and the other did not — the same shape as `F8`'s
  /// breakless-shape defect.
  ///
  /// What that cost, measured rather than assumed. **Locally the assertion passed
  /// for the wrong reason:** the load's own off-actor read had not landed either,
  /// so `isPlaying` was still `false` before the pause and `== false` succeeded
  /// without the pause having been noticed at all. A probe asserting the
  /// precondition failed on this machine. **On CI the load did land**, `isPlaying`
  /// was `true`, the assertion became real, and it failed — reported as a defect
  /// in a documentation-only branch that changes no Swift.
  ///
  /// So the fix is two things. **The precondition is asserted**, so the test can
  /// never again pass because the button was hidden the whole time; and **both
  /// reads are awaited at the task rather than by yielding a guessed number of
  /// times**, which is the pattern the sibling test already established.
  @Test("a pause from elsewhere hides the button")
  func externalPauseIsNoticed() async {
    coordinator.blockChanged(to: .work, isRunning: true)
    await coordinator.awaitPendingSound()
    await coordinator.awaitPendingPlaybackRead()

    // THE SETUP IS ASSERTED BEFORE ANYTHING IS CONCLUDED FROM IT. Without this
    // line the expectation below is satisfied by a button that was never shown.
    #expect(coordinator.isPlaying == true,
            "the skip button must be visible before a pause can hide it")

    // A pause this app did not cause. The coordinator must follow the player.
    player.pause()
    player.announceStatusChange()
    await coordinator.awaitPendingPlaybackRead()
    #expect(coordinator.isPlaying == false,
            "a pause from Control Centre must hide the skip button")
  }

  // MARK: Private

  private static let deepFocus = MusicSelection(
    kind: .playlist, identifier: "p.deepfocus", title: "Deep Focus")

  private let player: SpyMusicPlayer
  private let coordinator: MusicCoordinator
}
