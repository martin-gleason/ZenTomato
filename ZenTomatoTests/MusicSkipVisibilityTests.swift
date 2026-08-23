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
    await Task.yield()
    await Task.yield()

    // Whatever the spy reports synchronously, the coordinator must be LISTENING
    // — that is what makes a late flip reach the screen. Announce a change and
    // the coordinator must re-read rather than keep its first answer.
    player.announceStatusChange()
    #expect(coordinator.isPlaying == player.isPlaying,
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
  @Test("a pause from elsewhere hides the button")
  func externalPauseIsNoticed() async {
    coordinator.blockChanged(to: .work, isRunning: true)
    await Task.yield()
    await Task.yield()

    // A pause this app did not cause. The coordinator must follow the player.
    player.pause()
    player.announceStatusChange()
    #expect(coordinator.isPlaying == false,
            "a pause from Control Centre must hide the skip button")
  }

  // MARK: Private

  private static let deepFocus = MusicSelection(
    kind: .playlist, identifier: "p.deepfocus", title: "Deep Focus")

  private let player: SpyMusicPlayer
  private let coordinator: MusicCoordinator
}
