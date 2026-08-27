import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// Tests for the engine's side of the alarm contract: that an alarm is always
/// called off before the next one is set, and that a failure to set one is
/// never silent.
///
/// None of this links AlarmKit. The engine talks to a protocol, so these tests
/// talk to a stand-in, and they would keep passing unchanged if the alerting
/// framework underneath were replaced.
@Suite("AlarmScheduling")
@MainActor
struct AlarmSchedulingTests {
  private let container: ModelContainer
  private let clock: TestClock
  private let alarms: SpyAlarmScheduler
  private let engine: TimerEngine

  init() throws {
    let clock = TestClock()
    let alarms = SpyAlarmScheduler()
    let container = try TestStore.inMemoryContainer()
    self.clock = clock
    self.alarms = alarms
    self.container = container
    engine = TimerEngine(context: container.mainContext, clock: clock, alarms: alarms)
  }

  private var context: ModelContext {
    container.mainContext
  }

  private func sessions() throws -> [PomodoroSession] {
    try context.fetch(FetchDescriptor<PomodoroSession>())
  }

  /// Nothing is left outstanding after a stop.
  @Test("stopCancelsAlarm")
  func stopCancelsAlarm() async throws {
    await engine.start()
    await engine.stop(reason: "test")

    #expect(alarms.outstanding == nil)
    #expect(alarms.callLog == ["schedule", "cancelOutstanding"])
  }

  /// The order, when auto-start leads one block straight into the next: the old
  /// alarm is called off BEFORE the new one is set. An alarm sounding four
  /// minutes after the block it belonged to has ended is this feature's most
  /// likely user-visible bug, and it is an ordering bug rather than a logic one.
  ///
  /// This is now the ONLY path on which one block chains into another. Skip used
  /// to be a second one and was removed with D13, which makes this test the sole
  /// guard on the ordering rather than one of two.
  @Test("cancelPrecedesTheNextSchedule")
  func cancelPrecedesTheNextSchedule() async throws {
    let stored = try AppSettings.current(in: context)
    stored.autoStartNextBlock = true
    try context.save()

    await engine.start()
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()

    // **THE ENGINE NO LONGER CANCELS BETWEEN BLOCKS, AND THAT IS THE FIX.**
    //
    // It used to, and the cancel it issued here landed at the same instant the
    // finished block's alarm was firing — so with auto-start on, the alarm for
    // the block that just ended was silenced to make room for the next one. With
    // auto-start off it was worse still: `boundaryReached()` cancelled whenever
    // the app was awake, which a phone face down on a desk is.
    //
    // The ordering this test was written to protect is unchanged and now lives
    // where it belongs: `AlarmKitScheduler.schedule()` clears what is outstanding
    // before setting the next, and spares only an alarm that is actually ringing.
    // So no stale alarm can survive into a later block, and no ringing one is cut
    // off. See `AlarmRingsThroughTests`.
    #expect(alarms.callLog == ["schedule", "schedule"])
    #expect(alarms.outstanding != nil)
    #expect(alarms.outstanding?.kind == .shortBreak)
  }

  /// The alarm describes the same block the engine is running: the same end
  /// instant, the same kind, and the sprint numbers the Lock Screen will draw.
  @Test("scheduledAlarmMatchesTheEngine")
  func scheduledAlarmMatchesTheEngine() async throws {
    let stored = try AppSettings.current(in: context)
    stored.soundEnabled = false
    try context.save()

    await engine.start()

    let request = try #require(alarms.outstanding)
    #expect(request.endsAt == engine.endsAt)
    #expect(request.kind == .work)
    #expect(request.completedInSprint == 0)
    #expect(request.pomodorosPerSprint == 4)
    #expect(request.soundEnabled == false)
  }

  /// An alarm that could not be set is reported. This is the worst failure this
  /// feature can have — the screen counts down normally and nothing sounds at
  /// the end — so it must be visible rather than swallowed. The block itself is
  /// still running, because it was saved before the alarm was asked for.
  @Test("schedulingFailureIsSurfaced")
  func schedulingFailureIsSurfaced() async throws {
    alarms.scheduleError = SpyAlarmScheduler.Failure()

    await engine.start()

    #expect(engine.lastFailure == .alarmSchedulingFailed)
    #expect(engine.isRunning)
    #expect(alarms.outstanding == nil)
  }

  /// An alarm that could not be called off is reported too: the risk is one
  /// sounding for a block the user has already stopped.
  @Test("cancellationFailureIsSurfaced")
  func cancellationFailureIsSurfaced() async throws {
    await engine.start()
    alarms.cancelError = SpyAlarmScheduler.Failure()

    await engine.stop(reason: "test")

    #expect(engine.lastFailure == .alarmCancellationFailed)
    #expect(engine.isRunning == false)
  }

  /// Refused permission starts nothing at all: no block, no alarm, no row. The
  /// screen shows a blocking explainer instead, because a timer that cannot
  /// reliably tell you a block ended has no working state to degrade into.
  @Test("deniedAuthorizationStartsNothing")
  func deniedAuthorizationStartsNothing() async throws {
    alarms.authorization = .notDetermined
    alarms.authorizationAnswer = .denied

    await engine.start()

    #expect(engine.authorization == .denied)
    #expect(engine.isRunning == false)
    #expect(alarms.callLog == ["requestAuthorization"])
    let rows = try sessions()
    #expect(rows.isEmpty)
  }

  /// Permission is asked for once, at the first Start, and not again.
  @Test("authorizationIsRequestedOnlyWhenUndetermined")
  func authorizationIsRequestedOnlyWhenUndetermined() async throws {
    alarms.authorization = .notDetermined
    alarms.authorizationAnswer = .authorized

    await engine.start()
    await engine.stop(reason: "testing the prompt")
    await engine.start()

    #expect(alarms.callLog.filter { $0 == "requestAuthorization" }.count == 1)
  }
}
