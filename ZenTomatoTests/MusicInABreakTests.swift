import Foundation
import Testing

@testable import ZenTomato

/// Music can be switched on during a break — and a break is silent until it is.
///
/// **THE CONTRACT IS ONE SENTENCE WITH THREE OBLIGATIONS**, and the danger is
/// that satisfying the middle one destroys the first. `SPEC.md` line 27:
///
/// > Music during breaks — **Pauses**, and **can be switched back on by hand**.
/// > **Resumes by itself** at the next pomodoro.
///
/// "Music can be switched on during a break" is easy to implement as "breaks play
/// music", which passes a careless reading of the middle clause and contradicts
/// the opening one. Somebody who leaves music switched on for weeks would never
/// get a silent break again.
///
/// So the standing intention — `isEnabled` — is deliberately **not** what makes a
/// break sound. A separate per-break request is, and it is cleared at every
/// boundary. These tests exist mostly to hold that distinction.
@Suite("MusicInABreak")
struct MusicInABreakTests {
  // MARK: The obligation a careless fix destroys

  /// `aBreakIsSilentEvenWithMusicSwitchedOn` — obligation one.
  ///
  /// The single most important assertion in this file. Music is on, available,
  /// and a playlist is chosen; the break must still be silent, because nobody
  /// has asked for sound in *this* break.
  @Test("aBreakIsSilentEvenWithMusicSwitchedOn")
  func aBreakIsSilentEvenWithMusicSwitchedOn() {
    for breakKind in [BlockKind.shortBreak, BlockKind.longBreak] {
      #expect(
        MusicPlaybackPhase.shouldSound(
          isRunning: true, kind: breakKind, intention: .init(standing: true, breakSoundWasRequested: false),
          availability: .ready, selection: Self.chosen) == false,
        "A break played music nobody asked for, which contradicts 'Pauses'.")
    }
  }

  /// `askingMakesTheBreakSound` — obligation two.
  @Test("askingMakesTheBreakSound")
  func askingMakesTheBreakSound() {
    #expect(
      MusicPlaybackPhase.shouldSound(
        isRunning: true, kind: .shortBreak, intention: .init(standing: true, breakSoundWasRequested: true),
        availability: .ready, selection: Self.chosen))
  }

  /// `aWorkBlockIgnoresTheBreakRequest` — the two rules do not leak into each other.
  ///
  /// A work block sounds because music is switched on, and for no other reason. A
  /// stale break request must never make a work block play when the person has
  /// music switched off.
  @Test("aWorkBlockIgnoresTheBreakRequest")
  func aWorkBlockIgnoresTheBreakRequest() {
    #expect(
      MusicPlaybackPhase.shouldSound(
        isRunning: true, kind: .work, intention: .init(standing: false, breakSoundWasRequested: true),
        availability: .ready, selection: Self.chosen) == false,
      "A break request leaked into a work block whose music is switched off.")

    #expect(
      MusicPlaybackPhase.shouldSound(
        isRunning: true, kind: .work, intention: .init(standing: true, breakSoundWasRequested: false),
        availability: .ready, selection: Self.chosen),
      "A work block needed a break request to play, which is backwards.")
  }

  /// `permissionAndAChoiceAreStillRequired` — the request is not a bypass.
  ///
  /// Asking for sound cannot conjure a library that is not there or permission
  /// that was refused. Every other condition still has to hold.
  @Test("permissionAndAChoiceAreStillRequired")
  func permissionAndAChoiceAreStillRequired() {
    #expect(
      MusicPlaybackPhase.shouldSound(
        isRunning: true, kind: .shortBreak, intention: .init(standing: true, breakSoundWasRequested: true),
        availability: .denied, selection: Self.chosen) == false)

    #expect(
      MusicPlaybackPhase.shouldSound(
        isRunning: true, kind: .shortBreak, intention: .init(standing: true, breakSoundWasRequested: true),
        availability: .ready, selection: nil) == false)
  }

  // MARK: The switch, and what it shows

  /// `theSwitchShowsTheBreakRatherThanTheSprint` — why it has to.
  ///
  /// `isOn` is the standing intention, so during a break with music enabled it
  /// reads **on** while nothing is playing — leaving nothing to switch back on,
  /// which is what the contract promises. Inside a break the switch therefore
  /// shows *this break*.
  @Test("theSwitchShowsTheBreakRatherThanTheSprint")
  func theSwitchShowsTheBreakRatherThanTheSprint() {
    let untouched = MusicRowModel.forTimer(
      isRunning: true, kind: .shortBreak, isEnabled: true,
      availability: .ready, selection: Self.chosen,
      breakSoundWasRequested: false)
    #expect(untouched.isOn == false, "The switch read 'on' during a silent break, so there was nothing to switch.")
    #expect(untouched.isTogglable)

    let asked = MusicRowModel.forTimer(
      isRunning: true, kind: .shortBreak, isEnabled: true,
      availability: .ready, selection: Self.chosen,
      breakSoundWasRequested: true)
    #expect(asked.isOn)
  }

  /// `aBreakWithNothingChosenCannotBeSwitched` — a control that would do nothing.
  ///
  /// The row's standing rule: nothing offers a control that cannot act. With no
  /// playlist chosen there is nothing to play, so the switch stays locked rather
  /// than turning on and producing silence.
  @Test("aBreakWithNothingChosenCannotBeSwitched")
  func aBreakWithNothingChosenCannotBeSwitched() {
    let noChoice = MusicRowModel.forTimer(
      isRunning: true, kind: .shortBreak, isEnabled: true,
      availability: .ready, selection: nil,
      breakSoundWasRequested: false)
    #expect(noChoice.isTogglable == false)
  }

  // MARK: The switch itself

  /// The switch is locked during a **work block** and usable during a break.
  ///
  /// **This used to assert locked in every kind, and `D25` changed the contract
  /// under it.** `SPEC.md` line 27 now says music "pauses, and can be switched
  /// back on by hand" — so the break case had to move.
  ///
  /// The work-block half did not, and is the half worth keeping: `D19` puts the
  /// music decision *before* a sprint, and a switch that can be flipped
  /// mid-focus is a decision surface in the middle of the thing this app exists
  /// to protect. The row still draws it in both cases, because removing it would
  /// make a control appear and disappear at every boundary — the movement
  /// `D19.3` forbids.
  @Test("theSwitchIsLockedInAWorkBlockAndUsableInABreak")
  func theSwitchIsLockedInAWorkBlockAndUsableInABreak() {
    #expect(Self.row(isRunning: true, kind: .work).isTogglable == false)

    for breakKind in [BlockKind.shortBreak, BlockKind.longBreak] {
      #expect(Self.row(isRunning: true, kind: breakKind).isTogglable)
    }

    #expect(Self.row(isRunning: false, kind: .work).isTogglable)
  }

  // MARK: The request lives for exactly one block

  /// `theRequestDiesWithTheBreakItWasAbout` — obligation three, and the one no
  /// test caught until a mutation went looking.
  ///
  /// **`SPEC.md` line 27: "Resumes by itself at the next pomodoro."** That is only
  /// true if asking for sound in one break says nothing about anything after it.
  /// Deleting the line that clears the flag left every pure-function test in this
  /// file green, because they test the rule and this is about the state the rule
  /// is fed.
  ///
  /// It is the same defect `D20`'s silence flag shipped with: set, never cleared,
  /// and 291 tests stayed green because none of them crossed a boundary.
  @Test("theRequestDiesWithTheBreakItWasAbout")
  @MainActor
  func theRequestDiesWithTheBreakItWasAbout() async {
    let harness = Harness()
    harness.coordinator.blockChanged(to: .shortBreak, isRunning: true)
    await harness.coordinator.setEnabled(true)
    #expect(harness.coordinator.breakSoundWasRequested, "The switch did nothing in a break.")

    harness.coordinator.blockChanged(to: .work, isRunning: true)
    #expect(
      harness.coordinator.breakSoundWasRequested == false,
      "The break's sound request outlived the break, so it can reach a later block.")
  }

  /// `aSecondBreakStartsSilent` — the consequence a person would actually meet.
  ///
  /// The assertion above is about a flag. This is about the fortnight: ask for
  /// sound in one break, and the next one must still start quiet.
  @Test("aSecondBreakStartsSilent")
  @MainActor
  func aSecondBreakStartsSilent() async {
    let harness = Harness()
    harness.coordinator.blockChanged(to: .shortBreak, isRunning: true)
    await harness.coordinator.setEnabled(true)

    harness.coordinator.blockChanged(to: .work, isRunning: true)
    harness.coordinator.blockChanged(to: .shortBreak, isRunning: true)

    #expect(
      harness.coordinator.breakSoundWasRequested == false,
      "The second break inherited the first one's request.")
  }

  /// `theSwitchStillDoesNothingInAWorkBlock` — the lock `D19` put there.
  @Test("theSwitchStillDoesNothingInAWorkBlock")
  @MainActor
  func theSwitchStillDoesNothingInAWorkBlock() async {
    let harness = Harness()
    harness.coordinator.blockChanged(to: .work, isRunning: true)
    await harness.coordinator.setEnabled(true)

    #expect(
      harness.coordinator.breakSoundWasRequested == false,
      "A work block accepted a break request, so the switch is live mid-focus.")
  }

  /// `theRequestDiesAcrossTheIdleStepToo` — the sequence auto-start-off emits.
  ///
  /// **The tests above skip a step the app does not.** With auto-start off a
  /// sprint does not go break → work; it goes break → *idle* → work, because
  /// somebody has to press Start. `BlockPhaseObserver` delivers a phase for that
  /// middle state, and it is the transition a test written from the happy path
  /// forgets.
  ///
  /// Written because the owner reported the request looking inherited on a
  /// device. This is the first place to look, being the transition the suite had
  /// never run.
  @Test("theRequestDiesAcrossTheIdleStepToo")
  @MainActor
  func theRequestDiesAcrossTheIdleStepToo() async {
    let harness = Harness()
    harness.coordinator.blockChanged(to: .shortBreak, isRunning: true)
    await harness.coordinator.setEnabled(true)
    #expect(harness.coordinator.breakSoundWasRequested)

    // The break ends and nothing auto-starts: the engine sits at rest with the
    // next work block queued.
    harness.coordinator.blockChanged(to: .work, isRunning: false)
    #expect(
      harness.coordinator.breakSoundWasRequested == false,
      "The request survived the block ending, so it can reach whatever comes next.")

    harness.coordinator.blockChanged(to: .work, isRunning: true)
    harness.coordinator.blockChanged(to: .shortBreak, isRunning: true)
    #expect(
      harness.coordinator.breakSoundWasRequested == false,
      "The next break inherited a request from the one before it.")
  }

  /// `aRepeatedObservationDoesNotCutSoundOff` — the mirror of the defect above.
  ///
  /// `BlockPhaseObserver` delivers only when the phase changes, and the
  /// coordinator clears only when kind or running-ness moves. A repeated
  /// observation of the *same* break must not clear a request somebody is still
  /// listening to — which is why the clear is conditional rather than
  /// unconditional, and is the lesson `D20`'s silence flag paid for.
  @Test("aRepeatedObservationDoesNotCutSoundOff")
  @MainActor
  func aRepeatedObservationDoesNotCutSoundOff() async {
    let harness = Harness()
    harness.coordinator.blockChanged(to: .shortBreak, isRunning: true)
    await harness.coordinator.setEnabled(true)

    harness.coordinator.blockChanged(to: .shortBreak, isRunning: true)
    #expect(
      harness.coordinator.breakSoundWasRequested,
      "A repeated observation of the same break cut off sound the person asked for.")
  }

  // MARK: Private

  @MainActor
  private struct Harness {
    let coordinator: MusicCoordinator

    init() {
      coordinator = MusicCoordinator(
        player: SpyMusicPlayer(),
        availability: StubMusicAvailability(),
        library: StubMusicLibrary(),
        preferences: StubMusicPreferenceStore(
          isEnabled: true, selection: MusicInABreakTests.chosen))
    }
  }

  /// A row in the ordinary case: music on, available, something chosen.
  ///
  /// The same shape `MusicRowModelTests` uses, duplicated rather than shared
  /// because the two files ask different questions of it and a helper reaching
  /// across suites is a dependency neither would expect.
  private static func row(
    isRunning: Bool,
    kind: BlockKind,
    breakSoundWasRequested: Bool = false
  ) -> MusicRowModel {
    MusicRowModel.forTimer(
      isRunning: isRunning,
      kind: kind,
      isEnabled: true,
      availability: .ready,
      selection: chosen,
      breakSoundWasRequested: breakSoundWasRequested)
  }

  private static let chosen = MusicSelection(
    kind: .playlist, identifier: "p.1", title: "Deep Focus")
}
