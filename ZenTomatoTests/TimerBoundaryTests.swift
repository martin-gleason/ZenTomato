import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// Tests for the piece of the engine that wakes the app when a block ends.
///
/// WHY THIS SUITE EXISTS SEPARATELY FROM THE OTHER ENGINE TESTS
/// Every other test in this project reaches a block boundary by calling
/// `boundaryReached()` itself, from the test's own healthy, uncancelled task.
/// That is a fair way to check the *rules* — what follows what, what is written
/// down — and it is not the shape the app runs in. In the app the boundary is
/// reached by a task the engine armed, and that task's body was, until these
/// tests were written, executed by nothing at all: the shared test clock always
/// refused to sleep, so the task exited before it did anything.
///
/// Two real defects lived in that gap, and both are checked below: an alarm
/// scheduled from a task that had just cancelled itself, and a block auto-started
/// hours late because a suspended app was finally resumed. The clock here is put
/// into its waking mode so the task body genuinely runs.
@Suite("TimerBoundary")
@MainActor
struct TimerBoundaryTests {
  // MARK: Fixtures

  private let container: ModelContainer

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  private var context: ModelContext {
    container.mainContext
  }

  private func sessions() throws -> [PomodoroSession] {
    try context.fetch(FetchDescriptor<PomodoroSession>(sortBy: [SortDescriptor(\.endedAt)]))
  }

  /// Hands the thread to the engine's boundary task until the test can see the
  /// work it was waiting for.
  ///
  /// The engine, the clock and this test all run on the main thread, so a task
  /// the engine armed can only make progress while the test is suspended.
  /// Yielding is what suspends it. **Nothing here waits on the wall or on a
  /// timer** — no test in this project sleeps — it simply lets other work on the
  /// same thread run. The ceiling exists so that a broken engine ends the test
  /// rather than hanging it.
  ///
  /// - Parameter isSettled: checked before every yield. The loop stops as soon
  ///   as it answers true, so a passing test costs a handful of yields and only
  ///   a broken one pays the ceiling.
  private func settle(until isSettled: () -> Bool) async {
    for _ in 0..<10_000 where !isSettled() {
      await Task.yield()
    }
  }

  // MARK: The boundary task's own body

  /// Every alarm in an auto-started chain is asked for from a task that is
  /// still alive.
  ///
  /// WHAT THIS IS PROTECTING, IN PLAIN TERMS
  /// When one block flows into the next, the code that starts the next block is
  /// running *inside* the task that was waiting for the previous one to end.
  /// Starting a block also arranges the next wake-up, and arranging a wake-up
  /// begins by calling off the one before it — which, at that instant, is the
  /// task doing the calling. It used to cancel itself, and then ask iOS for the
  /// alarm. A system call made from a cancelled task refuses to run, so every
  /// block after the first would have ended in silence: the exact failure this
  /// whole feature exists to prevent, on the path a person meets most often.
  ///
  /// The stand-in scheduler cannot refuse, so what is asserted is the thing that
  /// would have made the real one refuse.
  @Test("chainedAlarmsAreScheduledFromALiveTask")
  func chainedAlarmsAreScheduledFromALiveTask() async throws {
    let clock = TestClock(sleepBehaviour: .wake(limit: 3))
    let alarms = SpyAlarmScheduler()
    let stored = try AppSettings.current(in: context)
    stored.autoStartNextBlock = true
    try context.save()

    let engine = TimerEngine(context: context, clock: clock, alarms: alarms)
    await engine.start()
    await settle(until: { clock.wakesRemaining == 0 && alarms.scheduledRequests.count >= 4 })

    // Four blocks ran: the one Start began, and three the boundary task chained.
    #expect(alarms.cancelledAtSchedule.count == 4)
    #expect(alarms.cancelledAtSchedule.allSatisfy { $0 == false })
    #expect(engine.lastFailure == nil)
    #expect(engine.isRunning)
    // The chain stopped because the clock stopped waking, not because the
    // engine gave up.
    #expect(clock.wakesRemaining == 0)
  }

  /// A boundary reached long after the block was due does **not** chain into
  /// the next block, even with auto-start switched on.
  ///
  /// A sleeping task does not fire while iOS has the app suspended — it fires
  /// the moment the app is resumed, however many hours later. So arriving at the
  /// boundary is not by itself evidence that anybody was present when the block
  /// ended. Auto-start carries a person through a sprint they are sitting in
  /// front of; it must never start a focus block because a phone was picked up
  /// at breakfast.
  @Test("overdueBoundaryDoesNotAutoStart")
  func overdueBoundaryDoesNotAutoStart() async throws {
    let clock = TestClock()
    let alarms = SpyAlarmScheduler()
    let stored = try AppSettings.current(in: context)
    stored.autoStartNextBlock = true
    try context.save()

    let engine = TimerEngine(context: context, clock: clock, alarms: alarms)
    await engine.start()
    let due = try #require(engine.endsAt)

    // Fourteen hours: a phone left on a desk overnight and picked up in the
    // morning, which is when the overdue wake-up finally fires.
    clock.advance(by: 14 * 60 * 60)
    await engine.boundaryReached()

    #expect(engine.isRunning == false)
    #expect(engine.kind == .shortBreak)
    #expect(engine.completedInSprint == 1)

    // Exactly one row, ended when it was due rather than when the app noticed.
    let rows = try sessions()
    #expect(rows.count == 1)
    #expect(rows.first?.wasAbandoned == false)
    #expect(rows.first?.endedAt == due)
  }

  /// A boundary reached on time still chains, so the guard above is a guard and
  /// not a switch that turns auto-start off.
  @Test("onTimeBoundaryStillAutoStarts")
  func onTimeBoundaryStillAutoStarts() async throws {
    let clock = TestClock()
    let alarms = SpyAlarmScheduler()
    let stored = try AppSettings.current(in: context)
    stored.autoStartNextBlock = true
    try context.save()

    let engine = TimerEngine(context: context, clock: clock, alarms: alarms)
    await engine.start()

    // A second late: a task can wake a moment after the instant it asked for,
    // and that must still count as having been there.
    clock.advance(by: 25 * 60 + 1)
    await engine.boundaryReached()

    #expect(engine.isRunning)
    #expect(engine.kind == .shortBreak)
    #expect(engine.completedInSprint == 1)
  }

  // MARK: The failure message belongs to one block

  /// A chained block does not inherit the previous block's warning.
  ///
  /// The amber line on the timer screen is the app's only signal that a block
  /// will end in silence. Left on screen after the condition has cleared it
  /// becomes something a person learns to ignore, which disarms the one message
  /// that matters.
  @Test("chainedBlockClearsThePreviousBlocksFailure")
  func chainedBlockClearsThePreviousBlocksFailure() async throws {
    let clock = TestClock()
    let alarms = SpyAlarmScheduler()
    let stored = try AppSettings.current(in: context)
    stored.autoStartNextBlock = true
    try context.save()

    let engine = TimerEngine(context: context, clock: clock, alarms: alarms)
    alarms.scheduleError = SpyAlarmScheduler.Failure()
    await engine.start()
    #expect(engine.lastFailure == .alarmSchedulingFailed)

    // The next alarm succeeds, so the next block has nothing to warn about.
    alarms.scheduleError = nil
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()

    #expect(engine.isRunning)
    #expect(engine.kind == .shortBreak)
    #expect(engine.lastFailure == nil)
  }

  // MARK: A boundary is armed at the right instant

  /// A relaunched app arms exactly one wake-up, at the stored end of the block
  /// it found running.
  ///
  /// This is the assertion the clock's record of requested deadlines was built
  /// for. Without it that record was written and never read, which reads as
  /// coverage without being coverage.
  @Test("restoredBlockArmsOneBoundaryAtItsEnd")
  func restoredBlockArmsOneBoundaryAtItsEnd() async throws {
    let clock = TestClock()
    let alarms = SpyAlarmScheduler()
    let engine = TimerEngine(context: context, clock: clock, alarms: alarms)
    await engine.start()
    // The wake-up is asked for by a task the engine armed, and a task only runs
    // while this test is suspended — so the request has not been made yet at the
    // moment `start()` returns.
    await settle(until: { clock.sleepDeadlines.count == 1 })
    #expect(clock.sleepDeadlines.count == 1)

    // Five minutes in, the app is relaunched: a second engine on the same store.
    clock.advance(by: 5 * 60)
    let restored = TimerEngine(context: context, clock: clock, alarms: alarms)
    await restored.synchronize()
    await settle(until: { clock.sleepDeadlines.count == 2 })

    #expect(restored.isRunning)
    // One further wake-up, asked for at twenty minutes from now — the remaining
    // life of the block that was found running.
    #expect(clock.sleepDeadlines.count == 2)
    #expect(clock.sleepDeadlines.last == clock.continuousNow.advanced(by: .seconds(20 * 60)))
  }
}
