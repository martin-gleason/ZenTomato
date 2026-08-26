import Foundation
import Testing

@testable import ZenTomato

/// The main actor must not wait on the media server.
///
/// **THIS IS THE TEST THAT DID NOT EXIST**, and its absence is why
/// `docs/crashes/ZenTomato-2026-08-26-134602.ips` happened: iOS killed the app
/// with `0x8BADF00D` after ten seconds of wall clock in which our own code used
/// **53 milliseconds** of CPU. Blocked, not looping. The main-thread stack ended
/// in `xpc_connection_send_message_with_reply_sync` beneath
/// `MPMusicPlayerController.playbackState`.
///
/// **Why 484 passing tests said nothing.** `playbackStatus` reads like a property
/// and behaves like a call to another process. `SpyMusicPlayer` answered
/// instantly, so no test could fail on a call that is free in a test and blocking
/// on a device — and no fence in this repository distinguishes a property read
/// from an IPC round trip. The gap was in the standard of proof, not in anyone's
/// care: `F4-contract.md` §8 chose to read it live for a good reason and simply
/// did not price it as IPC.
///
/// So the spy now **blocks for `snapshotDelay`** when its synchronous properties
/// are read, exactly as the real one does. That is what gives these tests teeth:
/// with the old implementation they fail, because the main actor waits.
@Suite("MusicWatchdog")
@MainActor
struct MusicWatchdogTests {
  init() {
    let player = SpyMusicPlayer()
    self.player = player
    coordinator = MusicCoordinator(
      player: player,
      availability: StubMusicAvailability(),
      library: StubMusicLibrary(),
      preferences: StubMusicPreferenceStore(isEnabled: true, selection: Self.chosen))
  }

  /// `aWedgedMediaServerDoesNotStallTheMainActor` — the whole point.
  ///
  /// The player takes a second to answer. The main actor must come back
  /// immediately regardless, because on the device the budget is ten seconds and
  /// the watchdog does not negotiate.
  ///
  /// The margin is deliberately wide. This asserts *"did not wait for the
  /// player"*, not a performance figure — a tight bound would fail on a loaded
  /// machine and teach everyone to ignore it.
  @Test("aWedgedMediaServerDoesNotStallTheMainActor")
  func aWedgedMediaServerDoesNotStallTheMainActor() async {
    player.snapshotDelay = .seconds(1)

    let clock = ContinuousClock()
    let elapsed = clock.measure {
      // Exactly what the media server does when it reports a change: this is the
      // path that fired most often, and most often while it was busiest.
      player.announceStatusChange()
    }

    #expect(
      elapsed < .milliseconds(250),
      """
      The main actor waited \\(elapsed) on a player that takes a second. On the \\
      device this is the watchdog kill: the reading has moved back onto this thread.
      """)
  }

  /// `theAnswerStillArrives` — off the main actor is not the same as ignored.
  ///
  /// Not waiting would be easy to achieve by never reading at all, and that would
  /// bring back the defect `F4-contract.md` §8 was written to prevent: a skip
  /// button that lies about whether there is anything to skip. The reading is
  /// still taken and still not cached; it simply lands a moment later.
  @Test("theAnswerStillArrives")
  func theAnswerStillArrives() async {
    coordinator.blockChanged(to: .work, isRunning: true)
    for _ in 0 ..< 8 { await Task.yield() }

    player.nowPlayingTitle = "Music for Airports"
    player.announceStatusChange()
    await coordinator.awaitPendingPlaybackRead()

    #expect(coordinator.isPlaying == player.isPlayingStorage)
    #expect(coordinator.nowPlayingTitle == "Music for Airports")
  }

  /// `aLateReadingDoesNotOverwriteANewerOne` — the hazard the hop introduces.
  ///
  /// `F6-contract.md` warns that *"a suspension point is where the last two
  /// features found their real bugs"*, and this is the one this change adds: two
  /// readings in flight, the older finishing second, putting a stale row on
  /// screen. The coordinator counts readings separately from decisions, so the
  /// stale one is discarded.
  @Test("aLateReadingDoesNotOverwriteANewerOne")
  func aLateReadingDoesNotOverwriteANewerOne() async {
    coordinator.blockChanged(to: .work, isRunning: true)
    for _ in 0 ..< 8 { await Task.yield() }

    // A slow reading starts…
    player.snapshotDelay = .milliseconds(400)
    player.nowPlayingTitle = "The stale one"
    player.announceStatusChange()

    // …and a fast one overtakes it before it lands.
    player.snapshotDelay = .zero
    player.nowPlayingTitle = "The current one"
    player.announceStatusChange()
    await coordinator.awaitPendingPlaybackRead()

    // Long enough that the slow reading has certainly finished and been dropped.
    try? await Task.sleep(for: .milliseconds(600))

    #expect(
      coordinator.nowPlayingTitle == "The current one",
      "A superseded reading landed on the row and overwrote the current one.")
  }

  // MARK: Private

  private let player: SpyMusicPlayer
  private let coordinator: MusicCoordinator

  private static let chosen = MusicSelection(
    kind: .playlist, identifier: "p.1", title: "Deep Focus")
}
