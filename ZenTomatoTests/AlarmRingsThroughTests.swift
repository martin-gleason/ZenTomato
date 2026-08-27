import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// The alarm sounds at the end of every block, and nothing this app does silences it.
///
/// **WHY THESE TESTS DID NOT EXIST, AND WHAT IT COST.** `SPEC.md` F2 promises the
/// alert sounds "through silent mode and through an active Focus" — the whole
/// reason AlarmKit was chosen over a notification. Nothing asserted it, and the
/// engine quietly cancelled the alarm on two paths:
///
///   * `boundaryReached()` cancelled whenever the app was awake to reach the end
///     of a block. The reasoning, never written down, was that an awake app meant
///     somebody was watching. **It does not.** A phone lying face down on a desk —
///     which is what people do to remove distractions, and therefore exactly when
///     the alarm is the only thing that can reach them — has this app frontmost.
///   * With auto-start on, the next block's `schedule()` cleared what was
///     outstanding at the same instant the finished block's alarm was firing.
///
/// The audio background mode made the first one worse rather than rarer: a sprint
/// playing music keeps the app alive, so the boundary fires on time with the phone
/// locked — cancelling the alarm while no screen exists to show a sheet on.
///
/// The owner reported it as *"alarm only went off on the 3rd pomodoro"*, and no
/// test disagreed.
@Suite("AlarmRingsThrough")
@MainActor
struct AlarmRingsThroughTests {
  // MARK: The boundary

  /// `endingABlockDoesNotSilenceItsAlarm` — the defect, as one assertion.
  @Test("endingABlockDoesNotSilenceItsAlarm")
  func endingABlockDoesNotSilenceItsAlarm() async throws {
    let harness = try Harness()
    await harness.engine.start()
    harness.clock.advance(by: 25 * 60)
    await harness.engine.boundaryReached()

    #expect(
      harness.alarms.calls.contains(.cancelOutstanding) == false,
      "Reaching the end of a block cancelled its own alarm — the app is awake, so it is quiet.")
    #expect(harness.alarms.outstanding != nil)
  }

  /// `anAwakeAppIsNotEvidenceAnybodyIsWatching` — the reasoning, stated once.
  ///
  /// The engine has no way to tell a phone being read from a phone face down with
  /// music playing, and it must not act as though it does. This is the same
  /// assertion as above from the other side: whatever the app's state, the alarm
  /// survives the block ending.
  @Test("anAwakeAppIsNotEvidenceAnybodyIsWatching")
  func anAwakeAppIsNotEvidenceAnybodyIsWatching() async throws {
    let harness = try Harness()
    await harness.engine.start()
    harness.clock.advance(by: 25 * 60)
    await harness.engine.boundaryReached()

    #expect(harness.alarms.outstanding?.kind == .work)
  }

  // MARK: The dismiss

  /// `dismissingTheAlarmOffersTheSheet` — the second half of the owner's ruling.
  ///
  /// The dismiss path used to refuse a reflection, on the grounds that a dismiss
  /// "arrives from a locked phone where there is no screen in front of anybody".
  /// That is backwards: **dismissing an alarm is somebody reaching for the
  /// phone**, which is the most reliable evidence this engine ever gets that a
  /// person is present. The old rule refused a prompt at the one moment it was
  /// certain of an audience.
  @Test("dismissingTheAlarmOffersTheSheet")
  func dismissingTheAlarmOffersTheSheet() async throws {
    let harness = try Harness()
    await harness.engine.start()
    harness.engine.recordDistraction(.externalInterruption)
    harness.clock.advance(by: 25 * 60)

    await harness.engine.handleDismiss()

    let reflection = harness.engine.consumePendingReflection()
    #expect(reflection != nil, "The alarm was dismissed by a person and they were asked nothing.")
    #expect(reflection?.prompts.count == 1)
  }

  /// `dismissingAFinishedBlockStartsItsBreak` — the regression, as a test.
  ///
  /// **This is the bug the owner found within an hour of the first build.** The
  /// dismiss path refused to chain, on reasoning written when a dismiss was rare:
  /// before the alarm was allowed to fire, the boundary handled block ends and it
  /// chained. Letting the alarm through made dismissing the *normal* way a block
  /// ends, so a rule written for an edge case began governing every block —
  /// *"it appears stopping the alarm cancels the break."* Eight blocks in a row,
  /// none of them rolling into its break.
  ///
  /// `D4` is explicit: *"the break timer starts running the instant the block
  /// ends, behind the sheet."*
  @Test("dismissingAFinishedBlockStartsItsBreak")
  func dismissingAFinishedBlockStartsItsBreak() async throws {
    let harness = try Harness(autoStart: true)
    await harness.engine.start()
    harness.clock.advance(by: 25 * 60)
    await harness.engine.handleDismiss()

    #expect(harness.engine.isRunning, "Dismissing the alarm ended the sprint instead of starting the break.")
    #expect(harness.engine.kind == .shortBreak)
  }

  /// `dismissingBeforeTheEndDoesNothingAtAll` — because it cannot be a person.
  ///
  /// `DismissBlockIntent` records that the mid-block dismiss button **was
  /// removed**, and that *"the only way to arrive here is a sounding alarm."*
  /// There is therefore no legitimate way to dismiss a block that has not ended,
  /// and a dismiss that arrives anyway belongs to an earlier block whose alarm
  /// outlived it.
  ///
  /// The old behaviour — abandon the running block — is what killed the owner's
  /// short break.
  @Test("dismissingBeforeTheEndDoesNothingAtAll")
  func dismissingBeforeTheEndDoesNothingAtAll() async throws {
    let harness = try Harness(autoStart: true)
    await harness.engine.start()
    harness.clock.advance(by: 5 * 60)
    await harness.engine.handleDismiss()

    #expect(harness.engine.isRunning, "A stale alarm abandoned the block that was running.")
    #expect(harness.engine.kind == .work)
  }

  /// `aStaleDismissDoesNotTakeTheCurrentAlarmWithIt` — the tempting wrong fix.
  ///
  /// Cleaning up on the way out would mean `cancelAlarm()`, which clears
  /// *everything* outstanding — including the alarm for the block now running,
  /// leaving it to end in silence. No cleanup is needed: this path runs because
  /// somebody dismissed that alarm, so iOS has already ended it.
  @Test("aStaleDismissDoesNotTakeTheCurrentAlarmWithIt")
  func aStaleDismissDoesNotTakeTheCurrentAlarmWithIt() async throws {
    let harness = try Harness(autoStart: true)
    await harness.engine.start()
    harness.clock.advance(by: 5 * 60)
    await harness.engine.handleDismiss()

    #expect(harness.alarms.outstanding != nil, "A stale dismiss cancelled the running block's alarm.")
  }

  // MARK: Clearing the way for the next block

  /// `theNextBlockDoesNotSilenceTheRingingOne` — the second door the defect had.
  ///
  /// With auto-start on, the next block is scheduled at the instant the previous
  /// one ends, and every schedule clears what is outstanding first. Without the
  /// `.alerting` check that clearing lands on an alarm that is making a noise
  /// right now — the same defect as the boundary cancel, through a different
  /// method.
  @Test("theNextBlockDoesNotSilenceTheRingingOne")
  func theNextBlockDoesNotSilenceTheRingingOne() async throws {
    let harness = try Harness(autoStart: true)
    await harness.engine.start()
    harness.alarms.isAlerting = true
    harness.clock.advance(by: 25 * 60)
    await harness.engine.boundaryReached()

    #expect(
      harness.alarms.sparedARingingAlarm || harness.alarms.calls.contains(.cancelOutstanding) == false,
      "The next block's scheduling silenced the alarm that was ringing for the one that just ended.")
  }

  /// `askingForSilenceStillSilences` — sparing is for scheduling, not for people.
  ///
  /// Stopping a block is somebody asking for quiet, and a ringing alarm is the
  /// loudest thing there is to be asked about. The exemption must not leak into
  /// the paths a person drives.
  @Test("askingForSilenceStillSilences")
  func askingForSilenceStillSilences() async throws {
    let harness = try Harness()
    await harness.engine.start()
    harness.alarms.isAlerting = true
    await harness.engine.stop(reason: "testing")

    #expect(harness.alarms.outstanding == nil, "A stop left a ringing alarm going.")
    #expect(harness.alarms.sparedARingingAlarm == false)
  }

  // MARK: The stale alarm

  /// `aStaleAlarmDoesNotEndTheBlockAfterIt` — the owner's finding, as a test.
  ///
  /// **Reported from a compressed sprint (1-minute focus, 2-minute break):** the
  /// focus block ended, the sheet appeared, the break started — and then *"alarm
  /// fired, reset short break."*
  ///
  /// The alarm that fired was the **focus block's**, arriving after the break had
  /// begun. Dismissing it runs `handleDismiss()`, which acts on whatever block is
  /// running *now* — the break — and since the break has not reached its end
  /// instant, `completed` is false and the break is abandoned.
  ///
  /// **This is a hole in the sparing rule I added, not in the alarm fix.**
  /// Scheduling spares an alarm that is `.alerting` so the next block cannot
  /// silence it. Nothing then cleans that alarm up, so it outlives the block it
  /// belonged to and its dismiss lands on the next one.
  @Test("aStaleAlarmDoesNotEndTheBlockAfterIt")
  func aStaleAlarmDoesNotEndTheBlockAfterIt() async throws {
    let harness = try Harness(autoStart: true)
    await harness.engine.start()
    harness.clock.advance(by: 25 * 60)

    // The focus block's alarm fires and is dismissed: break begins.
    await harness.engine.handleDismiss()
    #expect(harness.engine.kind == .shortBreak)
    #expect(harness.engine.isRunning)

    // The stale alarm from the finished focus block is dismissed a moment later.
    harness.clock.advance(by: 10)
    await harness.engine.handleDismiss()

    #expect(
      harness.engine.isRunning,
      "A dismiss belonging to the block BEFORE this one abandoned the break.")
    #expect(harness.engine.kind == .shortBreak)
  }

  // MARK: Chaining does not silence the block it leaves

  /// `chainingSparesTheAlarmOfTheBlockThatJustEnded` — why breaks never sounded.
  ///
  /// **The owner's sprint 2, in one line:** every focus block alarmed and every
  /// break did not. The asymmetry is the tell. A focus block ends when somebody
  /// **dismisses its alarm**, so by then it has certainly fired. A break ends by
  /// itself — and `begin()` schedules the next block's alarm at that same
  /// instant, cancelling everything not yet `.alerting`. The break's alarm is due
  /// exactly then and often still reads `.countdown`, so it is cancelled a moment
  /// before it would have sounded.
  ///
  /// Sparing by **state** loses that race. Sparing by **identity** cannot: the
  /// engine knows which block just ended and names its alarm.
  @Test("chainingSparesTheAlarmOfTheBlockThatJustEnded")
  func chainingSparesTheAlarmOfTheBlockThatJustEnded() async throws {
    let harness = try Harness(autoStart: true)
    await harness.engine.start()
    let focusAlarm = harness.alarms.outstanding?.id

    harness.clock.advance(by: 25 * 60)
    await harness.engine.boundaryReached()

    #expect(harness.engine.kind == .shortBreak)
    #expect(
      harness.alarms.sparedIDs.last == focusAlarm,
      """
      The break was scheduled without sparing the finished block's alarm, so that \
      alarm is cancelled at the instant it is due and never sounds.
      """)
  }

  /// `everyBlockInASprintSparesItsPredecessor` — the pattern, not one boundary.
  ///
  /// The owner saw this across a whole sprint: focus, break, focus, break. Each
  /// chain is a chance to cancel the alarm that is ringing, so the guarantee has
  /// to hold at every one of them rather than at the first.
  @Test("everyBlockInASprintSparesItsPredecessor")
  func everyBlockInASprintSparesItsPredecessor() async throws {
    let harness = try Harness(autoStart: true)
    await harness.engine.start()

    for _ in 0 ..< 3 {
      let ending = harness.alarms.outstanding?.id
      harness.clock.advance(by: 60 * 60)
      await harness.engine.boundaryReached()
      guard harness.engine.isRunning else { break }
      #expect(harness.alarms.sparedIDs.last == ending)
    }
  }

  // MARK: Stale alarms do not accumulate

  /// `onlyTheLastBlockSAlarmSurvivesAChain` — the cost of sparing too much.
  ///
  /// **Reported with Do Not Disturb on:** a break's alert appeared and vanished
  /// before it could be dismissed, so it stayed `.alerting`; later blocks then
  /// found alarms from earlier ones still registered, and *"turning off alarm
  /// turned off the stale alarm"* rather than the current one.
  ///
  /// The cause was sparing by **state as well as** identity. An alarm that has
  /// fired and not been dismissed stays `.alerting` indefinitely, so the state
  /// check spared it at every later boundary and a sprint accumulated one stale
  /// alarm per block.
  ///
  /// Exactly one alarm may survive a schedule: the block that just ended.
  @Test("onlyTheLastBlockSAlarmSurvivesAChain")
  func onlyTheLastBlockSAlarmSurvivesAChain() async throws {
    let harness = try Harness(autoStart: true)
    harness.alarms.isAlerting = true
    await harness.engine.start()

    harness.clock.advance(by: 60 * 60)
    await harness.engine.boundaryReached()
    harness.clock.advance(by: 60 * 60)
    await harness.engine.boundaryReached()

    #expect(
      harness.alarms.sparedARingingAlarm == false,
      """
      A schedule spared an alarm for being noisy rather than for being the one \
      that just ended, so alarms from finished blocks accumulate across a sprint.
      """)
  }

  // MARK: Private

  private struct Harness {
    let engine: TimerEngine
    let alarms: SpyAlarmScheduler
    let clock: TestClock

    /// **Held, and that is not tidiness.** The first version let the container go
    /// out of scope at the end of `init`, keeping only its `mainContext` — and
    /// every test in this file then hung for forty-five seconds and was killed by
    /// the timeout, which reads in the log as a crash rather than as a dangling
    /// context. Every other suite in this project keeps it; that was the tell.
    let container: ModelContainer

    @MainActor
    init(autoStart: Bool = false) throws {
      let container = try TestStore.inMemoryContainer()
      self.container = container
      let context = container.mainContext
      let stored = try AppSettings.current(in: context)
      stored.autoStartNextBlock = autoStart
      try context.save()

      let alarms = SpyAlarmScheduler()
      let clock = TestClock()
      self.alarms = alarms
      self.clock = clock
      engine = TimerEngine(context: context, clock: clock, alarms: alarms)
    }
  }
}
