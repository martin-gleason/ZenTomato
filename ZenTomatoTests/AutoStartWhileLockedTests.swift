import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// Auto-start has to survive the phone being locked, because that is the only
/// way anybody actually uses a Pomodoro timer.
///
/// WHY THIS SUITE EXISTS
/// A block ends on one of two paths. `boundaryReached()` runs when the app is
/// awake and watching, and auto-starts the next block. `synchronize()` runs when
/// the block ended while the app was suspended — and it did not.
///
/// Locking the phone suspends the app, so *every* block took the second path and
/// the cycle stalled until somebody opened the app and pressed Start. The setting
/// worked only while you were staring at it, which makes it a setting that does
/// not do what its name says.
///
/// The protection it was providing is real and is kept: a phone left overnight
/// must not wake up and start a focus block nobody asked for. The difference is
/// how long the gap was.
@MainActor
struct AutoStartWhileLockedTests {
  init() throws {
    let clock = TestClock()
    let container = try TestStore.inMemoryContainer()
    self.clock = clock
    self.container = container
    engine = TimerEngine(context: container.mainContext, clock: clock, alarms: SpyAlarmScheduler())

    let settings = try AppSettings.current(in: container.mainContext)
    settings.autoStartNextBlock = true
    try container.mainContext.save()
  }

  /// THE BUG. Phone locked, a block ends, the app wakes a moment later: the next
  /// block must be running.
  @Test("a locked sprint carries on by itself")
  func lockedSprintContinues() async throws {
    await engine.start()
    #expect(engine.kind == .work)

    // The block ends while the app is suspended. Nothing runs. Then iOS wakes it
    // a couple of seconds later, which is what the alarm firing looks like.
    clock.advance(by: 25 * 60 + 2)
    await engine.synchronize()

    #expect(engine.isRunning, "the cycle must not stall because the screen was locked")
    #expect(engine.kind == .shortBreak, "and it must have moved on to the break")
  }

  /// The protection that path was providing, kept. A phone picked up the next
  /// morning must not be mid-focus-block.
  @Test("a long gap still comes to rest")
  func overnightGapGoesIdle() async throws {
    await engine.start()

    clock.advance(by: 14 * 60 * 60)
    await engine.synchronize()

    #expect(engine.isRunning == false, "nobody was there; it must not have carried on")
  }

  /// With auto-start OFF the wake must not start anything, however short the gap.
  @Test("auto-start off still means off")
  func autoStartOffIsRespected() async throws {
    let settings = try AppSettings.current(in: container.mainContext)
    settings.autoStartNextBlock = false
    try container.mainContext.save()

    await engine.start()
    clock.advance(by: 25 * 60 + 2)
    await engine.synchronize()

    #expect(engine.isRunning == false)
  }

  // MARK: Private

  private let container: ModelContainer
  private let clock: TestClock
  private let engine: TimerEngine
}
