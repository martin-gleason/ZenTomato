import Foundation
import Testing

@testable import ZenTomato

/// Sequencing: what happens when two decisions about sound are in the air at
/// once, and what happens when there is nothing to make a sound with yet.
///
/// **THESE ARE THE TESTS THAT WERE MISSING, AND THEY ARE THE ONES THE BUILD
/// CONTRACT NAMED AS THE TOP RISK.** Every other test in this feature drives a
/// stand-in whose methods finish the instant they are called, which is not what
/// a real queue load does: on a phone it takes hundreds of milliseconds, and a
/// block boundary is exactly when it is in flight. So the generation counter,
/// the re-check after every suspension and the re-statement of silence by
/// superseded work were executed by nothing — the sharpest requirement in the
/// feature protected only by somebody reading the code and agreeing with it.
/// `SpyMusicPlayer.gateLoads` is what lets a load be held open at the moment a
/// break arrives.
///
/// They live in their own file rather than in `MusicTransitionTests` because
/// that file is at the length this project holds a file to, and because these
/// are about *ordering* rather than about the sequence of blocks.
///
/// Nothing here sleeps, opens a network connection, or links a music framework.
@Suite("MusicOrdering")
@MainActor
struct MusicOrderingTests {
  // MARK: Setup

  private let player: SpyMusicPlayer
  private let library: StubMusicLibrary
  private let coordinator: MusicCoordinator

  private static let deepFocus = MusicSelection(
    kind: .playlist, identifier: "p.deepfocus", title: "Deep Focus")

  init() {
    let player = SpyMusicPlayer()
    let library = StubMusicLibrary()
    self.player = player
    self.library = library
    coordinator = MusicCoordinator(
      player: player,
      availability: StubMusicAvailability(),
      library: library,
      preferences: StubMusicPreferenceStore(isEnabled: true, selection: Self.deepFocus))
  }

  // MARK: A rename is not a different playlist

  /// A playlist renamed in the Music app between two blocks of a live sprint
  /// keeps its place in the track.
  ///
  /// **The narrowest defect in this feature and the one that would have been
  /// hardest to believe.** Deciding resume-or-load by comparing whole values
  /// meant comparing titles too, and the title changes on its own: this app
  /// deliberately takes a playlist's new name so the row matches the Music app.
  /// So a rename between two blocks made the coordinator think a *different*
  /// playlist had been chosen, take the load branch, and start it from the top.
  /// It would have presented as "my track sometimes starts over after a break",
  /// with nothing in the log and no test able to catch it — `resumeIsNeverARestart`
  /// least of all, because the same equality is what it counts.
  @Test("aRenameBetweenBlocksIsNotARestart")
  func aRenameBetweenBlocksIsNotARestart() async {
    await moveTo(.work)
    await comeToRest(kind: .work, sprintIsOver: false)

    library.resolution = .renamed("Deep Focus 2026")
    coordinator.refreshAvailability()
    await settle(until: { coordinator.selection?.title == "Deep Focus 2026" })

    await moveTo(.work)

    #expect(coordinator.selection?.title == "Deep Focus 2026")
    #expect(player.startedFromTheTopCount == 1, "a rename restarted the playlist")
    #expect(player.callLog == ["load", "pause", "resume"])
    #expect(player.isPlaying)
  }

  // MARK: Nothing is said to the player until there is something to say

  /// A coordinator that has never played anything asks Apple's player for
  /// nothing at all.
  ///
  /// This runs at launch, before anybody has switched music on, and at every
  /// block boundary of every sprint whether or not music is in use. Without the
  /// guard it is a synchronous call into Apple's player four times an hour on
  /// the phone of somebody who has never touched the feature.
  @Test("nothingIsSaidToThePlayerUntilThereIsSomethingToSay")
  func nothingIsSaidToThePlayerUntilThereIsSomethingToSay() async {
    coordinator.blockChanged(to: .work, isRunning: false, sprintIsOver: true)
    coordinator.blockChanged(to: .shortBreak, isRunning: false, sprintIsOver: true)
    await settle(until: { false }, limit: 50)

    #expect(player.callLog.isEmpty)
  }

  // MARK: The ordering guard, with a load genuinely in flight

  /// A break that arrives while the queue is still loading ends in silence.
  ///
  /// **THE SHAPE OF THE TIMER'S OWN FIRST BLOCKING DEFECT, IN THE MUSIC.** On a
  /// real phone a queue load is the one operation here that takes hundreds of
  /// milliseconds, and a block boundary is exactly when it is in flight.
  /// Cancelling is not enough on its own, because the load may already have
  /// started the sound by the time the cancellation lands — so the superseded
  /// work re-checks and re-states the silence the newer decision asked for.
  /// Until the stand-in could hold a load open, none of that machinery was run
  /// by any test.
  @Test("aBreakArrivingMidLoadEndsInSilence")
  func aBreakArrivingMidLoadEndsInSilence() async {
    player.gateLoads = true
    coordinator.blockChanged(to: .work, isRunning: true, sprintIsOver: false)
    await settle(until: { player.callLog.contains("load") })

    // The break lands with the load still suspended.
    coordinator.blockChanged(to: .shortBreak, isRunning: true, sprintIsOver: false)
    player.releaseLoad()
    await settle(until: { player.callLog.filter { $0 == "pause" }.count == 2 })

    #expect(player.isPlaying == false, "sound was left running into a break")
    #expect(player.callLog.last == "pause")
    #expect(player.startedFromTheTopCount == 1)
  }

  /// The mirror: a superseded load finishing during a *later* focus block must
  /// not silence it.
  ///
  /// The re-statement of silence is deliberately conditional — it asks the same
  /// rule again rather than pausing on principle. If it did not, a load left
  /// over from an earlier block would arrive and cut off music that is correctly
  /// playing now.
  @Test("aStaleLoadArrivingInALaterBlockDoesNotSilenceIt")
  func aStaleLoadArrivingInALaterBlockDoesNotSilenceIt() async {
    player.gateLoads = true
    coordinator.blockChanged(to: .work, isRunning: true, sprintIsOver: false)
    await settle(until: { player.callLog.contains("load") })

    coordinator.blockChanged(to: .shortBreak, isRunning: true, sprintIsOver: false)
    // A new focus block, whose own load is not gated and finishes at once.
    await moveTo(.work)
    #expect(player.isPlaying)

    // Only now does the very first load come back.
    player.releaseLoad()
    await settle(until: { false }, limit: 200)

    #expect(player.isPlaying, "a load left over from an earlier block silenced a live one")
    #expect(player.callLog.last != "pause")
    #expect(player.callLog.last != "stop")
  }

  // MARK: Helpers

  private func moveTo(_ kind: BlockKind) async {
    coordinator.blockChanged(to: kind, isRunning: true, sprintIsOver: false)
    await settle(until: { !coordinator.isStarting })
  }

  private func comeToRest(kind: BlockKind = .work, sprintIsOver: Bool) async {
    coordinator.blockChanged(to: kind, isRunning: false, sprintIsOver: sprintIsOver)
    await settle(until: { !coordinator.isStarting })
  }

  /// See `MusicTransitionTests.settle(until:limit:)`. Nothing here sleeps.
  private func settle(until isSettled: () -> Bool, limit: Int = 10_000) async {
    for _ in 0..<limit where !isSettled() {
      await Task.yield()
    }
  }
}
