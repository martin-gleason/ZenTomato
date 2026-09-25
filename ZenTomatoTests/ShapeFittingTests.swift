import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// `F8-T4`, note 1 from use — **fitting a shape, and the moment the idle timer says so.**
///
/// > *"When 'fit a sprint' is used, the focus timer has to update immediately — not when the sprint
/// > starts."* — the owner, 2026-09-25, ruled the same day as *"idle should update when the sprint is
/// > fitted."*
///
/// **A suite of its own rather than three more tests in `ShapeSeamTests`, and the reason is not file
/// length.** That suite asks where a *running* block's length comes from; these three ask what
/// happens at a moment when nothing is running at all. The one thing they must not share is the
/// engine-with-a-shape-already-in-it setup those tests open with — every test here has to start from
/// an engine quoting the settings, or it cannot see the readout change.
@Suite("ShapeFitting")
@MainActor
struct ShapeFittingTests {
  private let container: ModelContainer

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  private var context: ModelContext { container.mainContext }

  private func engine(_ harness: TestShapeStore, clock: TestClock) -> TimerEngine {
    TimerEngine(context: context, clock: clock, alarms: SpyAlarmScheduler(), shapes: harness.store)
  }

  private func minutes(_ engine: TimerEngine, from startedAt: Date) throws -> Double {
    try #require(engine.endsAt).timeIntervalSince(startedAt) / 60
  }

  // MARK: Fitting a shape updates the idle readout

  /// **Note 1 from use, and the assertion is the number the idle screen shows.**
  ///
  /// > *"When 'fit a sprint' is used, the focus timer has to update immediately — not when the sprint
  /// > starts."* Ruled 2026-09-25: *"idle should update when the sprint is fitted."*
  ///
  /// The engine is built with an empty store, so it starts out quoting the settings — which is what
  /// makes this test able to fail. Writing the shape alone does not move the readout: `idleSettings`
  /// is a copy taken at the last read, and nothing had asked for a new one. `shapeWasFitted()` is
  /// the ask.
  @Test("theIdleReadoutFollowsAFreshlyFittedShape")
  func theIdleReadoutFollowsAFreshlyFittedShape() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    let engine = engine(harness, clock: clock)
    #expect(engine.remaining(at: clock.now) == .seconds(25 * 60), "the settings, before any shape")

    harness.store.start(try ShapeFixture.shape(120))
    engine.shapeWasFitted()

    #expect(engine.remaining(at: clock.now) == .seconds(22 * 60))
  }

  /// **Fitting a shape takes the sprint back to its start**, tally and all.
  ///
  /// The case is the ordinary one rather than an exotic one: with auto-start off — the shipped
  /// default — the timer is *idle* between two blocks, which is precisely when the shape sheet can be
  /// opened. A shape written there while the cycle still held two finished pomodoros would leave the
  /// shape at block zero, a pomodoro, against a cycle expecting a short break: two accounts of one
  /// sprint. So the tally goes with the shape.
  @Test("fittingAShapeTakesTheSprintBackToItsStart")
  func fittingAShapeTakesTheSprintBackToItsStart() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    let engine = engine(harness, clock: clock)
    await engine.start()
    let endsAt = try #require(engine.endsAt)
    clock.advance(by: endsAt.timeIntervalSince(clock.now))
    await engine.boundaryReached()
    #expect(engine.completedInSprint == 1, "one pomodoro done, idle in the gap")
    #expect(engine.kind == .shortBreak)

    harness.store.start(try ShapeFixture.shape(120))
    engine.shapeWasFitted()

    #expect(engine.completedInSprint == 0)
    #expect(engine.kind == .work)
    #expect(engine.remaining(at: clock.now) == .seconds(22 * 60))
  }

  /// **A running block is never re-lengthed underneath the person**, which is note 1's refused
  /// reading and `readSettings()`'s own standing rule.
  ///
  /// The guard is asserted rather than trusted to the screen. `TimerView.openShape()` will not
  /// present the sheet while a block runs, so in the shipped app this path is unreachable — and a
  /// rule that is true only because of where a button is drawn is a rule the next caller breaks.
  @Test("fittingAShapeIsRefusedWhileABlockRuns")
  func fittingAShapeIsRefusedWhileABlockRuns() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    let engine = engine(harness, clock: clock)
    await engine.start()
    let armed = try #require(engine.endsAt)

    harness.store.start(try ShapeFixture.shape(120))
    engine.shapeWasFitted()

    #expect(engine.endsAt == armed, "the block that is running keeps the end instant it was given")
    #expect(try minutes(engine, from: clock.now) == 25)
  }

  // MARK: What the sheet's own write path does

  /// **`fit` writes the shape and says it did.** The layer below `onFit`, asserted on its own.
  ///
  /// The sheet's `onFit` closure is a literal in a SwiftUI `body` and there is no UI test target in
  /// this project, so the one link in the chain nothing can assert is `TimerView` passing
  /// `engine.shapeWasFitted()` in. **That is stated rather than covered by a test that looks as though
  /// it covers it**: what these two assert is that the write happens and that the caller is told, which
  /// is everything on either side of that literal.
  @Test("fittingWritesTheShapeAndSaysSo")
  func fittingWritesTheShapeAndSaysSo() throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let actions = ShapeSheetActions(store: harness.store, settings: try AppSettings.current(in: context))
    let shape = try ShapeFixture.shape(120)

    #expect(actions.fit(shape) == true)

    let run = try #require(harness.store.runningShape())
    #expect(run.blocks.map(\.minutes) == shape.blocks.map(\.minutes))
  }

  /// **A budget that fits nothing replaces nothing.** The stored shape is left exactly as it was, and
  /// the caller is told not to announce anything.
  ///
  /// The fixture is a store that already holds a *different* shape, because an empty store would pass
  /// this test against an implementation that wrote a shape of no blocks at all.
  @Test("aBudgetThatFitsNothingLeavesTheStoredShapeAlone")
  func aBudgetThatFitsNothingLeavesTheStoredShapeAlone() throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let existing = try ShapeFixture.shape(120)
    harness.store.start(existing)
    let actions = ShapeSheetActions(store: harness.store, settings: try AppSettings.current(in: context))

    #expect(actions.fit(nil) == false)

    let run = try #require(harness.store.runningShape())
    #expect(run.blocks.map(\.minutes) == existing.blocks.map(\.minutes))
  }
}
