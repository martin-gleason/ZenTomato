import AVFoundation
import Foundation
import Testing

@testable import ZenTomato

/// What happens when a phone call, or another app, takes the sound away and
/// then gives it back.
///
/// **THE ONE THAT MATTERS IS `interruptionDuringBreakDoesNotResume`.** A phone
/// call that ends nine minutes into a fifteen-minute break must not bring the
/// music back on while somebody is away from their desk. It is an audible
/// defect, it is the kind that gets noticed once and remembered, and the naive
/// way of writing this feature produces it: iOS hands the app a flag saying it
/// would be reasonable to make a noise again, and the obvious thing to do with
/// that flag is to make a noise.
///
/// The design answers it structurally rather than with a check.
/// `MusicCoordinator.interruptionEnded(mayResume:)` contains no way to start
/// sound; all it can do is ask the one rule, which knows what block the timer is
/// on. So the flag is read as a *permission* — whether the app is allowed to
/// ask — and never as an instruction. These tests are what say that out loud.
@Suite("MusicInterruption")
@MainActor
struct MusicInterruptionTests {
  // MARK: Setup

  private let player: SpyMusicPlayer
  private let coordinator: MusicCoordinator

  private static let deepFocus = MusicSelection(
    kind: .playlist, identifier: "p.deepfocus", title: "Deep Focus")

  init() {
    let player = SpyMusicPlayer()
    self.player = player
    coordinator = MusicCoordinator(
      player: player,
      availability: StubMusicAvailability(),
      library: StubMusicLibrary(),
      preferences: StubMusicPreferenceStore(isEnabled: true, selection: Self.deepFocus))
  }

  // MARK: The tests

  /// A call that ends during a break leaves the music paused.
  @Test("interruptionDuringBreakDoesNotResume")
  func interruptionDuringBreakDoesNotResume() async {
    await moveTo(.work)
    await moveTo(.shortBreak)

    coordinator.interruptionEnded(mayResume: true)
    await settle(until: { false }, limit: 50)

    #expect(player.isPlaying == false)
    #expect(player.callLog == ["load", "pause", "pause"])
    #expect(player.callLog.contains("resume") == false)
  }

  /// The same during a long break, because a break is a break.
  @Test("interruptionDuringLongBreakDoesNotResume")
  func interruptionDuringLongBreakDoesNotResume() async {
    await moveTo(.work)
    await moveTo(.longBreak)

    coordinator.interruptionEnded(mayResume: true)
    await settle(until: { false }, limit: 50)

    #expect(player.isPlaying == false)
    #expect(player.callLog.contains("resume") == false)
  }

  /// A call that ends while the timer is idle leaves the music silent.
  @Test("interruptionWhileIdleDoesNotResume")
  func interruptionWhileIdleDoesNotResume() async {
    await moveTo(.work)
    coordinator.blockChanged(to: .work, isRunning: false, sprintIsOver: true)
    await settle(until: { !coordinator.isStarting })

    coordinator.interruptionEnded(mayResume: true)
    await settle(until: { false }, limit: 50)

    #expect(player.isPlaying == false)
    #expect(player.callLog.contains("resume") == false)
  }

  /// A call that ends during a focus block brings the music back, mid-track.
  ///
  /// The other half of the requirement: an interruption that ends where music
  /// belongs must not leave the person working in silence for the rest of the
  /// block. `resume` rather than a second `load` is what makes it pick up where
  /// it left off.
  @Test("interruptionDuringWorkResumesMidTrack")
  func interruptionDuringWorkResumesMidTrack() async {
    await moveTo(.work)
    // What an interruption looks like from this app's side: iOS silenced it
    // without asking, so the stand-in is put in the state iOS would have left
    // it in.
    player.pause()

    coordinator.interruptionEnded(mayResume: true)
    await settle(until: { player.isPlaying })

    #expect(player.callLog == ["load", "pause", "resume"])
    #expect(player.startedFromTheTopCount == 1)
  }

  /// Without permission from iOS, nothing happens at all.
  ///
  /// The flag is a permission to *ask*, so no flag means the question is never
  /// put — even in a focus block, where the answer would have been yes. iOS
  /// withholds it when something else still has a claim on the speaker, and
  /// making a noise over that would be this app arguing with the system.
  @Test("interruptionEndWithoutPermissionChangesNothing")
  func interruptionEndWithoutPermissionChangesNothing() async {
    await moveTo(.work)
    player.pause()
    let before = player.callLog

    coordinator.interruptionEnded(mayResume: false)
    await settle(until: { false }, limit: 50)

    #expect(player.callLog == before)
    #expect(player.isPlaying == false)
  }

  /// An interruption that begins is not something this app acts on.
  ///
  /// iOS has already silenced the app by the time anybody hears about it, and
  /// there is nothing worth remembering: what happens next is decided from
  /// scratch when the interruption ends, or at the next block boundary,
  /// whichever comes first.
  ///
  /// **THIS TEST USED TO BE UNABLE TO FAIL AND IS THE REASON THE ROUTING IS A
  /// METHOD.** It compared two cases of an enumeration for inequality, which the
  /// compiler guarantees; it never built a coordinator, never delivered an event
  /// and never asserted anything about the app. Replacing the "do nothing" arm
  /// with a pause, a resume or a fresh decision would have left it passing, and
  /// it was the only test in the suite that named this path — coverage in the
  /// count and in the pull request, and none in fact. It now drives a real
  /// `.began` through the real coordinator during a live focus block and asserts
  /// that the player was asked for nothing at all.
  @Test("interruptionBeginningIsNotActedOn")
  func interruptionBeginningIsNotActedOn() async {
    await moveTo(.work)
    let before = player.callLog

    coordinator.handleInterruption(.began)
    await settle(until: { false }, limit: 50)

    #expect(player.callLog == before, "an interruption beginning asked the player for something")
    #expect(player.isPlaying, "nothing this app did stopped the music")
  }

  /// An interruption ending travels the same routing and does reach the rule.
  ///
  /// The other half of the pair, so that the test above is a statement about
  /// `.began` rather than about the routing being broken for everything.
  @Test("interruptionEndingIsActedOnThroughTheSameDoor")
  func interruptionEndingIsActedOnThroughTheSameDoor() async {
    await moveTo(.work)
    player.pause()

    coordinator.handleInterruption(.ended(mayResume: true))
    await settle(until: { player.isPlaying })

    #expect(player.callLog == ["load", "pause", "resume"])
    #expect(player.startedFromTheTopCount == 1)
  }

  // MARK: Reading what iOS actually sends

  /// The one place in this feature where a value arrives in a shape nobody
  /// controls: a dictionary with two optional keys, every branch of which
  /// decides whether music starts.
  ///
  /// Driven by no test until now. A hand-built notification is the only way to
  /// reach it — the real ones come from the audio system on a phone with a
  /// phone call arriving — and each case below is a thing iOS really sends.
  @Test("everyShapeOfInterruptionNoticeIsReadOrRefused")
  func everyShapeOfInterruptionNoticeIsReadOrRefused() {
    #expect(AudioSessionInterruptions.event(from: Self.notice(.began)) == .began)

    #expect(
      AudioSessionInterruptions.event(
        from: Self.notice(.ended, options: AVAudioSession.InterruptionOptions.shouldResume.rawValue))
        == .ended(mayResume: true))

    // No options key at all. Absent means "no", which is the safe reading: with
    // no permission to make a noise this app stays quiet and the block carries
    // on regardless.
    #expect(AudioSessionInterruptions.event(from: Self.notice(.ended)) == .ended(mayResume: false))

    #expect(
      AudioSessionInterruptions.event(from: Self.notice(.ended, options: 0))
        == .ended(mayResume: false))

    // Nothing this app can make sense of produces no event rather than a guess.
    // Acting on a guess here would mean starting or stopping somebody's music
    // for a reason nobody could later explain.
    #expect(AudioSessionInterruptions.event(from: Notification(name: .init("x"))) == nil)
    #expect(
      AudioSessionInterruptions.event(
        from: Notification(name: .init("x"), object: nil, userInfo: [:])) == nil)
    #expect(
      AudioSessionInterruptions.event(
        from: Notification(
          name: .init("x"),
          object: nil,
          userInfo: [AVAudioSessionInterruptionTypeKey: "not a number"])) == nil)
  }

  // MARK: Helpers

  /// One of iOS's interruption notifications, built by hand.
  private static func notice(
    _ type: AVAudioSession.InterruptionType,
    options: UInt? = nil
  ) -> Notification {
    var userInfo: [AnyHashable: Any] = [AVAudioSessionInterruptionTypeKey: UInt(type.rawValue)]
    if let options { userInfo[AVAudioSessionInterruptionOptionKey] = options }
    return Notification(
      name: AVAudioSession.interruptionNotification, object: nil, userInfo: userInfo)
  }

  private func moveTo(_ kind: BlockKind) async {
    coordinator.blockChanged(to: kind, isRunning: true, sprintIsOver: false)
    await settle(until: { !coordinator.isStarting })
  }

  /// See `MusicTransitionTests.settle(until:limit:)`. Nothing here sleeps.
  private func settle(until isSettled: () -> Bool, limit: Int = 10_000) async {
    for _ in 0..<limit where !isSettled() {
      await Task.yield()
    }
  }
}
