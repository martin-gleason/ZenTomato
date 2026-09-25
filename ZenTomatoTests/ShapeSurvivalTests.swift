import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// `F8-T4` — **the two survival cases the task names and `T2` did not cover.**
///
/// > *"One abandoned and relaunched mid-block, which must restore the shape and not fall back to
/// > settings"* … *"the settings edited mid-shape while the timer is idle between blocks — the
/// > shape's block lengths must be untouched while a sound change takes effect at the next block."*
///
/// **Why a relaunch needs its own suite when `aRunningShapedBlockIsRestoredWithoutTheStore` exists.**
/// That test asserts the block that is *already running* comes back at its shaped length, and it does
/// so without a store at all — the frozen columns on `TimerState` carry it. What it cannot see is
/// everything after that block: a relaunched engine that had lost the shape would finish the block in
/// hand correctly and then run the whole rest of the sprint out of `AppSettings`. So the assertion
/// here is on the **budget**, measured end to end, which is the promise the feature is for.
///
/// **The fourth edge `T4` lists — *"what a skipped block does to the remaining shape"* — has no test
/// here, and the reason is that the path was removed.** A skip reached the engine through a mid-block
/// dismiss button; `handleDismiss()` now records in as many words that *"the mid-block button was
/// removed"* and that a dismiss for a block that has not ended is a stale alarm rather than an
/// abandon. The consequence the plan wanted written down is written down, at `advanceShape()`: the
/// cursor moves whether or not the block completed, so a lost pomodoro costs its slot instead of
/// repeating it. A test for a path no caller can take would be a green tick over nothing.
@Suite("ShapeSurvival")
@MainActor
struct ShapeSurvivalTests {
  private let container: ModelContainer

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  private var context: ModelContext { container.mainContext }

  private func engine(_ harness: TestShapeStore, clock: TestClock) -> TimerEngine {
    TimerEngine(context: context, clock: clock, alarms: SpyAlarmScheduler(), shapes: harness.store)
  }

  /// Runs `blocks` boundaries, each at the instant the engine says the block ends.
  private func run(_ engine: TimerEngine, blocks: Int, clock: TestClock) async throws {
    for _ in 0..<blocks {
      let endsAt = try #require(engine.endsAt)
      clock.advance(by: endsAt.timeIntervalSince(clock.now))
      await engine.boundaryReached()
    }
  }

  // MARK: Killed and relaunched

  /// **A two-hour shaped sprint takes two hours across a relaunch**, not two hours and a quarter.
  ///
  /// The engine is thrown away mid-block and a second one is built over the same database and the
  /// same store, which is what a kill and a relaunch is. Then the rest of the sprint runs on the new
  /// engine.
  ///
  /// **The assertion is the elapsed wall time, and that is deliberate.** A relaunched engine that had
  /// lost the shape would still finish the block in hand at the right length — the frozen columns
  /// carry that, and a sibling test in `ShapeSeamTests` already proves it — and would then run six
  /// blocks out of `AppSettings`: 25·5·25·5·25·15 instead of 5·22·5·22·5·17. So a per-block assertion
  /// on the block after the relaunch would pass for the first of them, whose five-minute short break
  /// the shape and the settings agree about. Measuring the budget catches every version of the defect
  /// at once, because filling the budget exactly is the whole of what a shape promises.
  @Test("aShapedSprintKeepsItsBudgetAcrossARelaunch")
  func aShapedSprintKeepsItsBudgetAcrossARelaunch() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    let settings = try AppSettings.current(in: context)
    settings.autoStartNextBlock = true
    try context.save()
    let shape = try ShapeFixture.shape(120)
    // The fixture pinned as figures rather than trusted: these are `O37`'s numbers, and every
    // length but the short break disagrees with the 25/5/15 settings the sprint would fall back to.
    #expect(shape.blocks.map(\.minutes) == [22, 5, 22, 5, 22, 5, 22, 17])
    harness.store.start(shape)

    let first = engine(harness, clock: clock)
    let startedAt = clock.now
    await first.start()
    try await run(first, blocks: 1, clock: clock)
    #expect(first.isRunning, "the relaunch happens mid-block, not between blocks")

    // The kill and the relaunch. Nothing is handed across but the database and the store.
    let relaunched = engine(harness, clock: clock)
    #expect(relaunched.isRunning)
    try await run(relaunched, blocks: shape.blocks.count - 1, clock: clock)

    #expect(clock.now.timeIntervalSince(startedAt) == 120 * 60)
    #expect(relaunched.isRunning == false)
    #expect(try #require(harness.store.runningShape()).cursor == 0)
    #expect(try context.fetch(FetchDescriptor<PomodoroSession>()).count == shape.blocks.count)
  }

  /// **A relaunch in the idle gap offers the shape's next block, not the settings'.**
  ///
  /// The other half of the same edge, and the one a person actually meets: with auto-start off — the
  /// shipped default — the app is idle between every pair of blocks, which is also when it is most
  /// likely to be swiped away.
  ///
  /// **Killed at the second pomodoro and not the first break**, because the shape's short break is
  /// five minutes and so is the setting's. At the pomodoro the two answers differ by three minutes.
  ///
  /// **AND THE POSITION IS ASSERTED DIRECTLY, WHICH IT WAS NOT IN THE FIRST DRAFT.** This shape's
  /// lengths repeat — `22·5·22·5·22·5·22·17` — so a relaunch that forgot the cursor and served block
  /// zero would offer a twenty-two-minute pomodoro, which is what a correct one offers too. The
  /// length assertion alone therefore passed under `F8-M20`, the mutation written to break exactly
  /// this test: the fixture satisfied both the right implementation and the wrong one, which is this
  /// project's own named failure and was caught by running the mutation rather than by reading.
  @Test("aRelaunchInTheIdleGapStillOffersTheShape")
  func aRelaunchInTheIdleGapStillOffersTheShape() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    harness.store.start(try ShapeFixture.shape(120))
    let first = engine(harness, clock: clock)

    // Two blocks by hand, which is what auto-start off means, leaving the timer idle at the shape's
    // second pomodoro.
    for _ in 0..<2 {
      await first.start()
      try await run(first, blocks: 1, clock: clock)
    }
    #expect(first.isRunning == false)

    let relaunched = engine(harness, clock: clock)

    #expect(relaunched.kind == .work)
    #expect(relaunched.remaining(at: clock.now) == .seconds(22 * 60))
    #expect(relaunched.completedInSprint == 1)
    #expect(try #require(harness.store.runningShape()).cursor == 2, "two blocks in, and it knows it")
  }

  // MARK: Settings edited in the idle gap

  /// **The shape keeps the lengths and the settings keep everything else.**
  ///
  /// `Ruling E`'s second question, and the plan is explicit that this is the ordinary case rather
  /// than an exotic one: with auto-start off the timer is *idle* between blocks, and idle is exactly
  /// when the settings screen can be opened. `SPEC.md`'s read-only-while-running rule does not reach
  /// this window.
  ///
  /// **Both edited numbers are chosen to disagree with the shape**, in both directions — the focus
  /// length goes up from 25 to 45 against the shape's 22, and the short break goes up from 5 to 9
  /// against the shape's 5. The second one matters more than it looks: 5 is the number the shape and
  /// the shipped setting agree about, so an edit that left it alone would make this test unable to
  /// see a break taking its length from the wrong place.
  ///
  /// The sound is the control that must move, and it is asserted **off the frozen row** rather than
  /// off `AppSettings` — reading the row back is reading what the block will actually do, and reading
  /// the settings would only confirm that the edit was written.
  @Test("aSettingsEditInTheIdleGapMovesTheSoundAndNotTheLengths")
  func aSettingsEditInTheIdleGapMovesTheSoundAndNotTheLengths() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    harness.store.start(try ShapeFixture.shape(120))
    let engine = engine(harness, clock: clock)
    await engine.start()
    try await run(engine, blocks: 1, clock: clock)
    #expect(engine.isRunning == false, "idle in the gap, which is where the settings screen opens")
    #expect(engine.kind == .shortBreak)

    let settings = try AppSettings.current(in: context)
    settings.workMinutes = 45
    settings.shortBreakMinutes = 9
    settings.soundEnabled = false
    try context.save()
    // What `TimerView.settingsSheetClosed()` does, and the only thing it does.
    await engine.synchronize()

    // The break the shape says, not the nine minutes just written.
    #expect(engine.remaining(at: clock.now) == .seconds(5 * 60))
    await engine.start()
    #expect(try #require(engine.endsAt).timeIntervalSince(clock.now) == 5 * 60)
    // And the sound change took effect at this block, which is the half that must move.
    #expect(try TimerState.current(in: context).soundEnabled == false)

    try await run(engine, blocks: 1, clock: clock)

    // The pomodoro the shape says, not the forty-five minutes just written.
    #expect(engine.kind == .work)
    #expect(engine.remaining(at: clock.now) == .seconds(22 * 60))
  }
}
