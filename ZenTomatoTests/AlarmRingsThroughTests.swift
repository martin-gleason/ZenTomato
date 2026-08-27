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

  /// `dismissingEarlyStartsNothing` — the distinction the fix turns on.
  ///
  /// The same button means two things and the engine decides which. Before the
  /// end instant it is somebody abandoning a block, and abandoning must chain
  /// into nothing — otherwise stopping a block would start the next one, which is
  /// the opposite of what was asked.
  @Test("dismissingEarlyStartsNothing")
  func dismissingEarlyStartsNothing() async throws {
    let harness = try Harness(autoStart: true)
    await harness.engine.start()
    harness.clock.advance(by: 5 * 60)
    await harness.engine.handleDismiss()

    #expect(harness.engine.isRunning == false, "Abandoning a block started the next one.")
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
