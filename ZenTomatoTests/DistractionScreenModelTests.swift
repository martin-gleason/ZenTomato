import Foundation
import Testing

@testable import ZenTomato

/// Tests for the rule that decides whether the two capture buttons are on the
/// screen at all, and what number is under each word.
///
/// WHY THIS IS A TEST WITHOUT A DATABASE, A TIMER OR A SCREEN
/// "A distraction during a break is not a distraction" is enforced twice on
/// purpose: once here, where it decides whether the buttons exist, and once in
/// the timer engine, which refuses to write a row that does not belong to a
/// running focus block whoever asks it to. The engine's guard is what makes the
/// rule true; this one is what a person sees.
///
/// Testing the visible half needs none of the machinery the engine's half needs,
/// because the rule was written as a pure function of three finished values —
/// is anything running, which kind of block it is, and what has been tapped so
/// far. So this suite runs in microseconds, cannot flake, and would still be
/// meaningful if every other part of the app were rewritten.
///
/// **The `nil` cases are the ones worth having.** A wrongly present pair is not
/// a cosmetic defect: it is a way to write a false row into the one dataset this
/// app exists to produce.
@Suite("Distraction capture on the timer screen")
struct DistractionScreenModelTests {
  // MARK: The buttons are absent unless a focus block is counting

  /// Nothing is running, so there is nothing to be distracted from. The idle
  /// screen has no slot at all — which is why the one layout shift in the whole
  /// cycle happens at Start, where it is attributable rather than mysterious.
  @Test("captureIsAbsentWhileIdle")
  func captureIsAbsentWhileIdle() {
    let capture = TimerScreenModel.Capture.forBlock(
      isRunning: false,
      kind: .work,
      taps: [])

    #expect(capture == nil)
  }

  /// Even with taps already recorded against the block that just ended, an idle
  /// screen shows no buttons. Reading a finished block back is a different
  /// feature's job entirely.
  @Test("captureIsAbsentWhileIdleEvenWithTapsRecorded")
  func captureIsAbsentWhileIdleEvenWithTapsRecorded() {
    let capture = TimerScreenModel.Capture.forBlock(
      isRunning: false,
      kind: .work,
      taps: [.internalInterruption, .externalInterruption])

    #expect(capture == nil)
  }

  /// The ratified rule, on both kinds of break. A break interrupted is not a
  /// pomodoro interrupted, and a row logged against a break would be a false
  /// entry rather than a harmless extra one.
  @Test("captureIsAbsentDuringBothBreaks")
  func captureIsAbsentDuringBothBreaks() {
    let short = TimerScreenModel.Capture.forBlock(
      isRunning: true,
      kind: .shortBreak,
      taps: [])
    let long = TimerScreenModel.Capture.forBlock(
      isRunning: true,
      kind: .longBreak,
      taps: [])

    #expect(short == nil)
    #expect(long == nil)
  }

  /// A break during which somebody has already been distracted — say the app
  /// was relaunched and the store handed back the previous block's taps — still
  /// shows nothing. The rule is about the *kind of block*, never about whether
  /// there is anything to count.
  @Test("captureIsAbsentDuringABreakWhateverHasBeenTapped")
  func captureIsAbsentDuringABreakWhateverHasBeenTapped() {
    let capture = TimerScreenModel.Capture.forBlock(
      isRunning: true,
      kind: .shortBreak,
      taps: [.internalInterruption, .internalInterruption])

    #expect(capture == nil)
  }

  // MARK: What the buttons show during a focus block

  /// A focus block that has not been interrupted yet still has both buttons.
  /// They are how a distraction gets recorded, so they cannot wait for one.
  ///
  /// The counts are zero, and zero is what makes the number *invisible* on the
  /// button rather than absent from the layout: a resting `0` would put a second
  /// and third number on a screen that should have exactly one.
  @Test("captureIsPresentFromTheFirstSecondOfAFocusBlock")
  func captureIsPresentFromTheFirstSecondOfAFocusBlock() throws {
    let capture = try #require(TimerScreenModel.Capture.forBlock(
      isRunning: true,
      kind: .work,
      taps: []))

    #expect(capture.internalCount == 0)
    #expect(capture.externalCount == 0)
  }

  /// Each button counts its own kind and neither counts the other, whatever
  /// order the taps arrived in.
  @Test("captureCountsEachKindSeparately")
  func captureCountsEachKindSeparately() throws {
    let capture = try #require(TimerScreenModel.Capture.forBlock(
      isRunning: true,
      kind: .work,
      taps: [
        .internalInterruption,
        .externalInterruption,
        .internalInterruption
      ]))

    #expect(capture.internalCount == 2)
    #expect(capture.externalCount == 1)
  }

  /// One kind and not the other. The button that has not been pressed shows
  /// nothing at all rather than a zero.
  @Test("captureLeavesTheUntappedKindAtZero")
  func captureLeavesTheUntappedKindAtZero() throws {
    let capture = try #require(TimerScreenModel.Capture.forBlock(
      isRunning: true,
      kind: .work,
      taps: [.externalInterruption, .externalInterruption]))

    #expect(capture.internalCount == 0)
    #expect(capture.externalCount == 2)
  }

  // MARK: The reserved slot

  /// The screen needs to tell three states apart, not two: a focus block, which
  /// has the buttons; a break, which keeps their exact height and has nothing in
  /// it; and an idle screen, which has no slot at all.
  ///
  /// That middle state is what stops the countdown jumping at the work-to-break
  /// boundary, and it is expressed as "a block is running but there is no
  /// capture" — so this checks the two values a screen reads to work that out.
  @Test("aRunningBreakIsTheReservedSlot")
  func aRunningBreakIsTheReservedSlot() {
    let breakScreen = TimerScreenModel(
      blockName: "Short break",
      kicker: "Short break",
      numeral: "04:31",
      spokenNumeral: "4 minutes remaining",
      progress: nil,
      capture: TimerScreenModel.Capture.forBlock(isRunning: true, kind: .shortBreak, taps: []),
      // F4 made the music row a value every screen has to state. It is present
      // in both of the states below, which is the point of it: the row exists in
      // every state of a running timer, so it can never move the countdown.
      music: MusicRowModel.forTimer(
        isRunning: true,
        kind: .shortBreak,
        isEnabled: false,
        availability: .notAsked,
        selection: nil),
      controls: .running)

    #expect(breakScreen.isRunning)
    #expect(breakScreen.capture == nil)
  }

  /// The idle screen: no block, and therefore no slot to reserve.
  @Test("anIdleScreenHasNoSlotToReserve")
  func anIdleScreenHasNoSlotToReserve() {
    let idle = TimerScreenModel(
      blockName: "Focus block",
      kicker: "Focus",
      numeral: "25:00",
      spokenNumeral: "25 minutes",
      progress: nil,
      capture: TimerScreenModel.Capture.forBlock(isRunning: false, kind: .work, taps: []),
      music: MusicRowModel.forTimer(
        isRunning: false,
        kind: .work,
        isEnabled: false,
        availability: .notAsked,
        selection: nil),
      controls: .start(isEnabled: true, spokenLabel: "Start focus block, 25 minutes"))

    #expect(idle.isRunning == false)
    #expect(idle.capture == nil)
  }
}
