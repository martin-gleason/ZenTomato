import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// Tests for what happens when the app comes back.
///
/// This is the half of the feature that the wall-clock design exists for: iOS
/// suspends the app within seconds of the phone being locked, and everything
/// below is a case where the app was not awake while time passed. Each test
/// builds a *second* engine on the same store, which is as close as a unit test
/// gets to quitting the app and opening it again.
@Suite("TimerRestoration")
@MainActor
struct TimerRestorationTests {
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

  /// A new engine on the same store: the app, relaunched.
  private func relaunched() -> TimerEngine {
    TimerEngine(context: context, clock: clock, alarms: alarms)
  }

  private func sessions() throws -> [PomodoroSession] {
    try context.fetch(FetchDescriptor<PomodoroSession>(sortBy: [SortDescriptor(\.endedAt)]))
  }

  /// Coming back while the block is still running: the same end instant, the
  /// right amount of time left, and no drift from having been away.
  @Test("restoreWhileRunning")
  func restoreWhileRunning() async throws {
    await engine.start()
    let end = try #require(engine.endsAt)

    clock.advance(by: 5 * 60)
    let restored = relaunched()
    await restored.synchronize()

    #expect(restored.isRunning)
    #expect(restored.kind == .work)
    #expect(restored.endsAt == end)
    // Twenty minutes left, not twenty-five: the block kept running while the
    // app was not there, because nothing was counting in the first place.
    #expect(restored.remaining(at: clock.now) == .seconds(20 * 60))

    let rows = try sessions()
    #expect(rows.isEmpty)
  }

  /// Coming back after the block ended: exactly one row is written, the cycle
  /// advances by exactly one, and the block counts as completed — it finished
  /// and the alarm fired; the user simply was not looking.
  @Test("restoreAfterExpiry")
  func restoreAfterExpiry() async throws {
    await engine.start()
    let end = try #require(engine.endsAt)

    clock.advance(by: 26 * 60)
    let restored = relaunched()
    await restored.synchronize()

    let rows = try sessions()
    #expect(rows.count == 1)
    #expect(rows.first?.wasAbandoned == false)
    #expect(rows.first?.kind == .work)
    // Recorded as having ended when it was due to end, not when the app noticed.
    #expect(rows.first?.endedAt == end)

    #expect(restored.isRunning == false)
    #expect(restored.kind == .shortBreak)
    #expect(restored.completedInSprint == 1)
  }

  /// A phone left on a desk overnight, with auto-start switched on.
  ///
  /// Fourteen hours of twenty-five minute blocks would be around thirty of
  /// them. **One** row is written and the timer is idle. There is no replay
  /// loop because there is nothing to replay: auto-start chains blocks the app
  /// was awake to see end, and a block that began at three in the morning is
  /// not a block anybody worked.
  @Test("restoreAfterLongGap")
  func restoreAfterLongGap() async throws {
    let stored = try AppSettings.current(in: context)
    stored.autoStartNextBlock = true
    try context.save()

    await engine.start()
    clock.advance(by: 14 * 60 * 60)

    let restored = relaunched()
    await restored.synchronize()

    let rows = try sessions()
    #expect(rows.count == 1)
    #expect(restored.isRunning == false)
    #expect(restored.kind == .shortBreak)
    #expect(restored.completedInSprint == 1)
    // The acknowledgement of a finished sprint is for the person who was there.
    #expect(restored.lastCompletedSprintSize == nil)
  }

  /// The phone's clock jumps forward an hour while a block is running.
  ///
  /// Without the guard, `endsAt` would now be thirty-five minutes in the past
  /// and the block would complete on the spot — a focus block ended by a
  /// timezone change. The monotonic clock has not moved, so it wins: the block
  /// keeps its full remaining time, nothing is recorded, and the alarm is set
  /// again because it was asked for as a length of time and may have moved with
  /// the system clock.
  @Test("clockMovedForward")
  func clockMovedForward() async throws {
    await engine.start()
    #expect(alarms.scheduledRequests.count == 1)

    clock.moveWallClock(by: 60 * 60)
    await engine.synchronize()

    #expect(engine.isRunning)
    #expect(engine.kind == .work)
    #expect(engine.remaining(at: clock.now) == .seconds(25 * 60))

    let rows = try sessions()
    #expect(rows.isEmpty)

    #expect(alarms.scheduledRequests.count == 2)
    // The re-issued alarm carries the corrected end instant, not the old one.
    #expect(alarms.scheduledRequests.last?.endsAt == engine.endsAt)
  }

  /// A block that has not ended and a clock that has not moved must be left
  /// completely alone, however many times reconciliation runs. Without this, a
  /// guard that fired on every foreground would pass `clockMovedForward` while
  /// rescheduling the alarm all day.
  @Test("synchronizeIsIdempotentWhileRunning")
  func synchronizeIsIdempotentWhileRunning() async throws {
    await engine.start()
    let end = try #require(engine.endsAt)

    clock.advance(by: 60)
    await engine.synchronize()
    await engine.synchronize()

    #expect(engine.endsAt == end)
    #expect(engine.isRunning)
    #expect(alarms.scheduledRequests.count == 1)
    let rows = try sessions()
    #expect(rows.isEmpty)
  }
}
