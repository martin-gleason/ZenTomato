import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// Tests for the engine's commands: what a block start freezes, what a skip
/// records, and where auto-start stops.
///
/// `@MainActor` on the whole suite. SwiftData's context is main-thread only and
/// so is the engine; annotating the suite means a future test cannot forget.
@Suite("TimerEngine")
@MainActor
struct TimerEngineTests {
  private let container: ModelContainer
  private let clock: TestClock
  private let alarms: SpyAlarmScheduler
  private let engine: TimerEngine

  /// Swift Testing builds a fresh instance of this struct for every test, so
  /// every test gets its own empty in-memory store, its own clock stopped at
  /// the same instant, and an engine that has never run anything.
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

  private func settings() throws -> AppSettings {
    try AppSettings.current(in: context)
  }

  private func sessions() throws -> [PomodoroSession] {
    try context.fetch(FetchDescriptor<PomodoroSession>(sortBy: [SortDescriptor(\.endedAt)]))
  }

  /// Changing the focus length while a focus block is running must not shorten
  /// the block you are already in — and the next block must use the new value.
  ///
  /// This is the test the frozen-snapshot design exists to make cheap. If a
  /// running block ever re-read the settings row, the first two checks below
  /// would fail immediately.
  @Test("settingsChangeMidBlock")
  func settingsChangeMidBlock() async throws {
    await engine.start()
    let runningEnd = try #require(engine.endsAt)
    #expect(engine.remaining(at: clock.now) == .seconds(25 * 60))

    let stored = try settings()
    stored.workMinutes = 10
    try context.save()

    #expect(engine.endsAt == runningEnd)
    #expect(engine.remaining(at: clock.now) == .seconds(25 * 60))

    // Cross two boundaries to reach the next focus block. Skip is gone (D13), so
    // the only way past a block is to let it end.
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()
    await engine.start()
    clock.advance(by: 5 * 60)
    await engine.boundaryReached()
    await engine.start()

    #expect(engine.kind == .work)
    #expect(engine.remaining(at: clock.now) == .seconds(10 * 60))
  }

  /// Abandoning a block that has not reached its end records it as abandoned
  /// and does not count it towards the sprint.
  ///
  /// **This used to drive the same invariant through `handleDismiss()`, and that
  /// path no longer exists.** `DismissBlockIntent` is reachable from exactly one
  /// place — AlarmKit's stop button — because the mid-block dismiss button was
  /// removed, and the intent's own documentation says so: *"the only way to
  /// arrive here is a sounding alarm."* An alarm only sounds at its block's end,
  /// so a dismiss can no longer mean "abandon this block".
  ///
  /// Leaving it pointed at `handleDismiss` was worse than a dead test: it made a
  /// *stale* alarm — one belonging to a finished block, still registered — look
  /// like a legitimate abandon, and the owner watched it kill a short break. The
  /// invariant is real and still worth holding; the path is `stop(reason:)`,
  /// which is what the stop sheet actually calls.
  @Test("abandonedBlockRecorded")
  func abandonedBlockRecorded() async throws {
    await engine.start()
    clock.advance(by: 60)
    await engine.stop(reason: "abandoned in a test")

    let rows = try sessions()
    #expect(rows.count == 1)
    #expect(rows.first?.kind == .work)
    #expect(rows.first?.wasAbandoned == true)
    #expect(engine.isRunning == false)
    #expect(engine.completedInSprint == 0)
  }

  /// A stopped focus block is recorded, marked abandoned, carries the reason the
  /// person gave, and does not become a pomodoro.
  @Test("stoppedWorkBlockIsAbandoned")
  func stoppedWorkBlockIsAbandoned() async throws {
    await engine.start()
    clock.advance(by: 120)
    await engine.stop(reason: "Fire alarm went off.")

    let rows = try sessions()
    #expect(rows.count == 1)
    #expect(rows.first?.kind == .work)
    #expect(rows.first?.wasAbandoned == true)
    // The reason is the whole point of making stop the only exit. A row marked
    // abandoned with no reason would mean the sheet let somebody past without
    // one.
    #expect(rows.first?.abandonReason == "Fire alarm went off.")
    #expect(engine.completedInSprint == 0)
    // Stop ends the SPRINT, not just the block, so the timer goes idle with a
    // focus block queued rather than advancing to a break. Skip used to advance;
    // skip is gone (D13), and this is the difference between the two.
    #expect(engine.kind == .work)
    #expect(engine.isRunning == false)
  }

  /// A block that runs to its end carries no reason. `abandonReason` is what
  /// separates "I stopped this and here is why" from "this finished", and a
  /// completed block acquiring one would make the two indistinguishable in the
  /// export.
  @Test("completedBlockHasNoAbandonReason")
  func completedBlockHasNoAbandonReason() async throws {
    await engine.start()
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()

    let rows = try sessions()
    #expect(rows.count == 1)
    #expect(rows.first?.wasAbandoned == false)
    #expect(rows.first?.abandonReason == nil)
  }

  /// With auto-start switched ON, the end of a long break returns the timer to
  /// idle rather than beginning a fifth block. Four pomodoros and a long break
  /// is a stopping point, and a timer that starts another while you have walked
  /// away is a timer that fills the record with blocks nobody was present for.
  @Test("sprintEndReturnsToIdle")
  func sprintEndReturnsToIdle() async throws {
    let stored = try settings()
    stored.pomodorosPerSprint = 1
    stored.autoStartNextBlock = true
    try context.save()

    await engine.start()
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()

    // The long break chained on, because it is inside the sprint.
    #expect(engine.isRunning)
    #expect(engine.kind == .longBreak)

    clock.advance(by: 15 * 60)
    await engine.boundaryReached()

    #expect(engine.isRunning == false)
    #expect(engine.kind == .work)
    #expect(engine.completedInSprint == 0)
    #expect(engine.lastCompletedSprintSize == 1)
    // Two blocks ran, so two alarms were set. A third would be the fifth block
    // this test exists to prevent.
    #expect(alarms.scheduledRequests.count == 2)
    // **THE LONG BREAK'S ALARM IS STILL REGISTERED, AND THAT IS DELIBERATE.**
    //
    // This used to assert `nil`, because the engine cancelled the alarm the
    // moment a block ended — including the one that was ringing to say so. An
    // alarm whose time has passed is not a leak waiting to fire; it has already
    // fired, and the next `schedule()` clears it before setting anything new.
    //
    // What must never be outstanding is an alarm that has NOT yet fired, and
    // nothing here can produce one: going idle schedules nothing.
    #expect(alarms.outstanding?.kind == .longBreak)
  }

  /// With auto-start switched ON, blocks inside a sprint chain without a tap.
  @Test("autoStartAdvancesWithinSprint")
  func autoStartAdvancesWithinSprint() async throws {
    let stored = try settings()
    stored.autoStartNextBlock = true
    try context.save()

    await engine.start()
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()

    #expect(engine.isRunning)
    #expect(engine.kind == .shortBreak)
    #expect(engine.completedInSprint == 1)

    clock.advance(by: 5 * 60)
    await engine.boundaryReached()

    #expect(engine.isRunning)
    #expect(engine.kind == .work)
    #expect(engine.completedInSprint == 1)

    // Both finished blocks were recorded, and neither was abandoned.
    let rows = try sessions()
    #expect(rows.count == 2)
    #expect(rows.allSatisfy { $0.wasAbandoned == false })
    #expect(alarms.scheduledRequests.count == 3)
  }

  /// Stopping abandons the sprint: the running block is recorded as abandoned,
  /// the tally returns to zero, and a focus block is queued. That reset is the
  /// whole difference between Stop and Skip.
  @Test("stopAbandonsTheSprint")
  func stopAbandonsTheSprint() async throws {
    let stored = try settings()
    stored.autoStartNextBlock = true
    try context.save()

    await engine.start()
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()
    #expect(engine.completedInSprint == 1)

    // A minute into the break, so the two rows have distinguishable end times.
    clock.advance(by: 60)
    await engine.stop(reason: "test")

    #expect(engine.isRunning == false)
    #expect(engine.kind == .work)
    #expect(engine.completedInSprint == 0)
    let rows = try sessions()
    #expect(rows.count == 2)
    #expect(rows.last?.wasAbandoned == true)
  }

  /// While idle the screen shows the whole length of the block Start would
  /// begin, and it follows the settings rather than the last block's copy.
  @Test("idleShowsTheQueuedBlocksLength")
  func idleShowsTheQueuedBlocksLength() async throws {
    #expect(engine.remaining(at: clock.now) == .seconds(25 * 60))

    let stored = try settings()
    stored.workMinutes = 40
    try context.save()
    await engine.synchronize()

    #expect(engine.isRunning == false)
    #expect(engine.remaining(at: clock.now) == .seconds(40 * 60))
  }
}
