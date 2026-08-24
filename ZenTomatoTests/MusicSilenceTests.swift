import Foundation
import Testing

@testable import ZenTomato

/// What Stop actually does, and — the part that was wrong — what it stops doing.
///
/// WHY THIS SUITE EXISTS
/// D20's whole promise is *"silence for this block; the next block plays again"*.
/// It shipped with the flag set and never cleared, so one tap silenced music for
/// the rest of the app's life. Every one of 291 tests stayed green, because not
/// one of them silenced a block and then started another.
///
/// A feature's central claim needs a test that fails when the claim is false.
@MainActor
struct MusicSilenceTests {
  init() {
    let player = SpyMusicPlayer()
    self.player = player
    coordinator = MusicCoordinator(
      player: player,
      availability: StubMusicAvailability(),
      library: StubMusicLibrary(),
      preferences: StubMusicPreferenceStore(isEnabled: true, selection: Self.deepFocus))
  }

  /// THE BUG. Silence one block; the next one must play.
  @Test("silence lasts exactly one block")
  func silenceEndsWithTheBlock() async {
    coordinator.blockChanged(to: .work, isRunning: true)
    await settle()
    player.announceStatusChange()
    #expect(coordinator.isPlaying, "precondition: the block is playing")

    coordinator.silenceThisBlock()
    #expect(coordinator.isSilencedForThisBlock)
    #expect(player.isPlaying == false, "Stop silences the music")

    // The break, then the next focus block.
    coordinator.blockChanged(to: .shortBreak, isRunning: true)
    await settle()
    coordinator.blockChanged(to: .work, isRunning: true)
    await settle()

    #expect(coordinator.isSilencedForThisBlock == false,
            "the silence was about the block that ended, not about music")
    #expect(player.isPlaying, "the next block must play again")
  }

  /// Silence must survive everything that happens *within* the same block. A
  /// flag cleared too eagerly is as wrong as one never cleared at all.
  @Test("silence survives events inside the same block")
  func silenceSurvivesTheBlock() async {
    coordinator.blockChanged(to: .work, isRunning: true)
    await settle()
    coordinator.silenceThisBlock()

    // Things that happen mid-block and must not un-silence it.
    coordinator.refreshAvailability()
    coordinator.availabilityChanged(to: .ready)
    coordinator.blockChanged(to: .work, isRunning: true)
    await settle()

    #expect(coordinator.isSilencedForThisBlock, "still the same block")
    #expect(player.isPlaying == false, "and still silent")
  }

  /// Stop while the music is still loading. MusicKit's `play()` is not
  /// cancellation-cooperative, so an in-flight load can finish AFTER the request
  /// to be quiet — and must not leave audio running.
  @Test("stopping during load does not let the music start")
  func stoppingDuringLoadStaysSilent() async {
    player.gateLoads = true
    coordinator.blockChanged(to: .work, isRunning: true)
    await Task.yield()

    coordinator.silenceThisBlock()
    player.releaseLoad()
    await settle()

    #expect(player.isPlaying == false, "a load that finishes late must not restart the music")
    #expect(coordinator.isStarting == false, "and the row must not still claim it is starting")
  }

  // MARK: Private

  private static let deepFocus = MusicSelection(
    kind: .playlist, identifier: "p.deepfocus", title: "Deep Focus")

  private let player: SpyMusicPlayer
  private let coordinator: MusicCoordinator

  /// Lets the coordinator's in-flight work finish.
  private func settle() async {
    for _ in 0 ..< 8 { await Task.yield() }
  }
}

// MARK: - Getting the music back

/// Stop is not a one-way door.
///
/// It shipped as one: silence a block and the only way back was Control Centre,
/// which left this app believing the block was quiet while sound was coming out
/// of it. Reported from the device as "there is no play button to reactivate it".
@MainActor
struct MusicResumeTests {
  init() {
    let player = SpyMusicPlayer()
    self.player = player
    coordinator = MusicCoordinator(
      player: player,
      availability: StubMusicAvailability(),
      library: StubMusicLibrary(),
      preferences: StubMusicPreferenceStore(
        isEnabled: true,
        selection: MusicSelection(kind: .playlist, identifier: "p.1", title: "Deep Focus")))
  }

  @Test("the music comes back for the same block")
  func resumeBringsItBack() async {
    coordinator.blockChanged(to: .work, isRunning: true)
    await settle()
    coordinator.silenceThisBlock()
    #expect(player.isPlaying == false)

    coordinator.resumeThisBlock()
    await settle()

    #expect(coordinator.isSilencedForThisBlock == false)
    #expect(player.isPlaying, "the same block plays again")
  }

  /// The row offers one control in two states rather than two controls — the
  /// count D20 ratified is unchanged.
  @Test("silenced offers start, playing offers stop, never both")
  func oneControlTwoStates() {
    let playing = Self.row(playback: .playing, isSilenced: false)
    #expect(playing.canStop)
    #expect(playing.stopIsResume == false)
    #expect(playing.interactiveControlCount == 2)

    let silenced = Self.row(playback: .silent, isSilenced: true)
    #expect(silenced.canStop, "there must be a way back")
    #expect(silenced.stopIsResume)
    // Skip is not offered: there is nothing to skip to when nothing is playing.
    #expect(silenced.canSkip == false)
    #expect(silenced.interactiveControlCount == 1)
  }

  // MARK: Private

  private let player: SpyMusicPlayer
  private let coordinator: MusicCoordinator

  private static func row(
    playback: MusicRowModel.Playback,
    isSilenced: Bool
  ) -> MusicRowModel {
    MusicRowModel.forTimer(
      isRunning: true, kind: .work, isEnabled: true, availability: .ready,
      selection: MusicSelection(kind: .playlist, identifier: "p.1", title: "Deep Focus"),
      playback: playback, isSilenced: isSilenced)
  }

  private func settle() async {
    for _ in 0 ..< 8 { await Task.yield() }
  }
}
