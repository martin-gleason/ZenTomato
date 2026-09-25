import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// `F8-T2` — the seam: where the length of the block about to run comes from.
///
/// **WHY THE EXISTING SUITE PASSING IS NOT EVIDENCE THAT THIS WORKS.** Every other engine test
/// hands the engine no shape store, so all of them prove the seam is *inert*. Being inert is the
/// acceptance condition and it is only half the claim. These tests put a shape in the store and
/// watch the number the engine writes into the block change — which is the half nothing else can
/// see.
@Suite("ShapeSeam")
@MainActor
struct ShapeSeamTests {
  private let container: ModelContainer

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  private var context: ModelContext { container.mainContext }

  /// The settings and the shapes fitted to them, in `ShapeFixture` so that the suite next door
  /// reads the same numbers instead of agreeing with these by coincidence.
  private static func shape(_ budget: Int, endsWithLongBreak: Bool = true) throws -> SprintShape {
    try ShapeFixture.shape(budget, endsWithLongBreak: endsWithLongBreak)
  }

  private func engine(_ harness: TestShapeStore, clock: TestClock, alarms: SpyAlarmScheduler) -> TimerEngine {
    TimerEngine(context: context, clock: clock, alarms: alarms, shapes: harness.store)
  }

  private func minutes(_ engine: TimerEngine, from startedAt: Date) throws -> Double {
    try #require(engine.endsAt).timeIntervalSince(startedAt) / 60
  }

  // MARK: A shaped block is a different length

  /// **The headline: a shaped block runs at the shape's length, not the settings length.**
  ///
  /// Two hours produces poms of twenty-two minutes against a twenty-five minute setting, so the
  /// right answer and the wrong one differ by three minutes — a fixture chosen because a shape that
  /// happened to agree with the settings would assert nothing.
  @Test("aShapedBlockRunsAtTheShapesLength")
  func aShapedBlockRunsAtTheShapesLength() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    harness.store.start(try Self.shape(120))
    let engine = engine(harness, clock: clock, alarms: SpyAlarmScheduler())

    await engine.start()

    #expect(try minutes(engine, from: clock.now) == 22)
  }

  /// The idle screen announces the shape's length too, before anything is started.
  ///
  /// **This is the reason the seam is in the settings re-read rather than in `begin`.** A shape
  /// resolved only where the block's end instant is calculated would show a person twenty-five
  /// minutes on the idle screen and then run twenty-two, which is not a crash and is exactly the
  /// silent wrongness this project's review dimensions call correctness.
  @Test("theIdleScreenAnnouncesTheShapesLength")
  func theIdleScreenAnnouncesTheShapesLength() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    harness.store.start(try Self.shape(120))

    let engine = engine(harness, clock: clock, alarms: SpyAlarmScheduler())

    #expect(engine.remaining(at: clock.now) == .seconds(22 * 60))
  }

  /// A shape of three poms makes the sprint three poms, everywhere the number is read.
  ///
  /// Without this the shape would take a short break where it says long, the completion line would
  /// announce a number nobody asked for, and the Lock Screen — a separate process that cannot read
  /// this database — would say "2 of 4" for the whole run.
  @Test("theSprintSizeFollowsTheShape")
  func theSprintSizeFollowsTheShape() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    // Forty-five minutes cannot hold four poms at their floors, so the shaper returns three.
    let shape = try Self.shape(45)
    #expect(shape.pomCount == 3)
    harness.store.start(shape)
    let engine = engine(harness, clock: clock, alarms: SpyAlarmScheduler())

    await engine.start()

    #expect(engine.pomodorosPerSprint == 3)
  }

  /// **The monotonic twin follows the shape, and reconciliation leaves the block alone.**
  ///
  /// The engine holds a second deadline on a clock that cannot be reset, and compares the two on
  /// every return to the foreground. If the block's end instant came from the shape while that
  /// deadline still came from the settings, the two would disagree by the shape's remainder — three
  /// minutes a pom here, far outside the five-second tolerance — and the first foreground
  /// reconciliation would "correct" every shaped block back towards the settings length, move the
  /// start instant with it and re-issue the alarm. It would fail only on a real device, only on
  /// returning from the background, and it would look like a shape that quietly stopped being one.
  @Test("aShapedBlockSurvivesReconciliation")
  func aShapedBlockSurvivesReconciliation() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    harness.store.start(try Self.shape(120))
    let engine = engine(harness, clock: clock, alarms: SpyAlarmScheduler())
    await engine.start()
    let startedAt = clock.now
    let armed = try #require(engine.endsAt)

    clock.advance(by: 60)
    await engine.synchronize()

    #expect(engine.endsAt == armed)
    #expect(try minutes(engine, from: startedAt) == 22)
  }

  // MARK: No shape is v1.0

  /// With nothing stored, the engine is exactly what it was.
  @Test("noShapeIsSettingsBehaviour")
  func noShapeIsSettingsBehaviour() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    let engine = engine(harness, clock: clock, alarms: SpyAlarmScheduler())

    await engine.start()

    // ASSERT THE SNAPSHOT AS THE ARTEFACT, NOT ONE LENGTH DERIVED FROM IT.
    //
    // This test IS the acceptance condition for the whole task — "with no shape present, behaviour
    // is byte-for-byte what it is today" — and it was written asserting `minutes == 25` alone. A
    // mutation audit broke the no-shape path to return a sixty-minute short break and the entire
    // 606-test suite stayed green: four of the seven columns could change in silence, and the one
    // that could not was guarded only by accident, from a sibling test about unreadable bytes.
    //
    // So the comparison is the frozen row against what the settings say, as whole values. Adding an
    // eighth column to the snapshot extends this assertion for free; asserting a derived length
    // would not have noticed it.
    let frozen = try TimerState.current(in: context).snapshot
    let fromSettings = try TimerSettingsSnapshot(clamping: AppSettings.current(in: context))
    #expect(frozen == fromSettings)

    // Kept: the length is what a reader of this test came for, and an equality failure on a struct
    // of seven fields is harder to read than a number.
    #expect(try minutes(engine, from: clock.now) == 25)
  }

  /// `anUnreadableShapeIsNoShape` — a stored value this build cannot read runs on `AppSettings`.
  ///
  /// **The bytes are a literal carrying a version tag no build has written**, not a value round
  /// tripped through the app's own encoder: an encoder round trip tests the encoder, and the right
  /// implementation and one that reaches for a default agree about it. This is `F8-M4`'s named
  /// test, and it asserts the end state the plan names — the engine runs on the settings, as though
  /// no shape had ever existed.
  @Test("anUnreadableShapeIsNoShape")
  func anUnreadableShapeIsNoShape() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    harness.write(
      raw: """
        {"version":99,"preset":"balanced","endsWithLongBreak":true,\
        "run":{"blocks":[{"kind":"work","minutes":22},{"kind":"longBreak","minutes":8}],\
        "budgetMinutes":30,"isUnderSuggestedMinimum":true,"cursor":0}}
        """)
    let engine = engine(harness, clock: clock, alarms: SpyAlarmScheduler())

    await engine.start()

    #expect(try minutes(engine, from: clock.now) == 25)
    #expect(engine.pomodorosPerSprint == 4)
  }

  // MARK: The shape outlives its sprint — and its position does not
  //
  // **TWO TESTS IN THIS SECTION USED TO ASSERT THE OPPOSITE, AND THEY WERE RIGHT WHEN WRITTEN.**
  // `aShapeDoesNotOutliveItsSprint` and `stoppingTheSprintForgetsTheShape` encoded Ruling E as it
  // stood on 2026-09-22: the shape was deleted when its sprint ended. The owner superseded that on
  // 2026-09-24 — *"the rule to discard a stored shape should last until a new shape is added"*, and
  // a shape survives being stopped early — with a 36-hour grace on the **position** only. So the
  // assertions are inverted here rather than deleted, and what each of them still protects is the
  // half of the old test that was never about the lifetime: the sprint must still *end*.

  /// Runs every block of `shape` to its end, the way a boundary does.
  private func run(_ engine: TimerEngine, blocks: Int, clock: TestClock) async throws {
    for _ in 0..<blocks {
      let endsAt = try #require(engine.endsAt)
      clock.advance(by: endsAt.timeIntervalSince(clock.now))
      await engine.boundaryReached()
    }
  }

  /// `aShapeSurvivesItsOwnSprint` — run it to the end and the shape is still there, back at its
  /// first block.
  ///
  /// This is `F8-M3`'s named test, and **the assertion it carries is now the pair rather than the
  /// absence**: the blocks are still stored (the owner's ruling) *and* the cursor is zero (the sprint
  /// ended). Asserting only the first would pass while the shape ran for ever; asserting only the
  /// second is what the old version did, and it passed while the shape was deleted.
  @Test("aShapeSurvivesItsOwnSprint")
  func aShapeSurvivesItsOwnSprint() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    let stored = try AppSettings.current(in: context)
    stored.autoStartNextBlock = true
    try context.save()
    let shape = try Self.shape(120)
    harness.store.start(shape)
    let engine = engine(harness, clock: clock, alarms: SpyAlarmScheduler())
    await engine.start()

    try await run(engine, blocks: shape.blocks.count, clock: clock)

    let after = try #require(harness.store.runningShape(), "the shape outlives its sprint")
    #expect(after.blocks.count == shape.blocks.count)
    #expect(after.cursor == 0, "and its position does not")
    #expect(engine.isRunning == false)
  }

  /// **The same, for a shape that does not end with a long break** — the half of this feature a
  /// clear keyed on the timer cycle would never fire for.
  ///
  /// `TimerCycle` raises "the sprint has ended" only when a long break finishes, and this shape's
  /// last block is a focus block. Run against one toggle state only, `F8-M3` would pass while the
  /// bug shipped for the other.
  @Test("aTrailingBreaklessShapeDoesNotOutliveItsSprintEither")
  func aTrailingBreaklessShapeDoesNotOutliveItsSprintEither() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    let stored = try AppSettings.current(in: context)
    stored.autoStartNextBlock = true
    try context.save()
    let shape = try Self.shape(120, endsWithLongBreak: false)
    #expect(shape.endsWithLongBreak == false)
    harness.store.start(shape)
    let engine = engine(harness, clock: clock, alarms: SpyAlarmScheduler())
    await engine.start()

    try await run(engine, blocks: shape.blocks.count, clock: clock)

    #expect(try #require(harness.store.runningShape()).cursor == 0)
    // **The assertion this test was written for, and did not carry.** Its sibling twenty lines up
    // has it; this one did not, which is the "per-theme rule checked once against one theme"
    // failure `conventions.md` names. Without it the suite is green while the sprint runs 135
    // minutes on a 120-minute budget: `advanceShape()` spends the cursor before the auto-start
    // guard, `resolvedSettings()` finds no run and falls back to `AppSettings`, and the engine
    // starts a 15-minute long break the shape never contained. Ruling D's control 1 — "Off drops
    // the trailing long break and gives the time back to the shape" — was true on the sheet and
    // false in the timer. `F8-M7`.
    #expect(engine.isRunning == false)
  }

  /// **The same shape with auto-start OFF**, where the defect idles instead of running.
  ///
  /// **This test exists because the bug above was caused by exactly the gap it fills.** Its sibling
  /// twenty lines up asserted `isRunning == false`; the breakless one did not, and that single
  /// missing line let a 120-minute budget run 135 through 627 green tests. Fixing that without
  /// adding this one would leave a second unmatched pair behind — the same defect, one toggle over.
  ///
  /// With auto-start off the engine does not run past the boundary, so the overrun is not visible
  /// in `isRunning`. It is visible in what the idle screen offers: before the fix the spent shape
  /// left `.longBreak` queued from `TimerCycle`, so the next tap would have started a fifteen-minute
  /// long break out of `AppSettings`. A spent shape ends its sprint, so the screen must offer the
  /// start of a new one.
  @Test("aSpentBreaklessShapeLeavesTheIdleScreenAtTheStartOfASprint")
  func aSpentBreaklessShapeLeavesTheIdleScreenAtTheStartOfASprint() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    let stored = try AppSettings.current(in: context)
    stored.autoStartNextBlock = false
    try context.save()
    let shape = try Self.shape(120, endsWithLongBreak: false)
    harness.store.start(shape)
    let engine = engine(harness, clock: clock, alarms: SpyAlarmScheduler())

    // Each block is started by hand, because that is what auto-start off means.
    for _ in 0..<shape.blocks.count {
      await engine.start()
      let endsAt = try #require(engine.endsAt)
      clock.advance(by: endsAt.timeIntervalSince(clock.now))
      await engine.boundaryReached()
    }

    #expect(try #require(harness.store.runningShape()).cursor == 0)
    #expect(engine.isRunning == false)

    // ASSERT WHAT THE SCREEN OFFERS, NOT THAT A FLAG IS FALSE. `isRunning == false` is true of the
    // defect too — it idles on a queued long break. The frozen row is where the difference lives.
    let state = try TimerState.current(in: context)
    #expect(state.kind == .work)
    #expect(state.completedInSprint == 0)
  }

  /// **Stopping the sprint keeps the shape and drops the position.** `F8`'s third open question,
  /// ruled by the owner 2026-09-24: a shape survives being stopped early.
  ///
  /// **The last assertion is the one that inverted, and it is the whole ruling in one number.** It
  /// used to read `25 * 60` — after a stop the shape was gone and the idle screen quoted the settings.
  /// It now reads `22 * 60`, the shape's own first pomodoro, and the two differ by three minutes
  /// precisely because this fixture's shape disagrees with the settings. A shape that happened to
  /// agree would have made the inversion invisible.
  @Test("theShapeSurvivesBeingStoppedEarly")
  func theShapeSurvivesBeingStoppedEarly() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    let shape = try Self.shape(120)
    harness.store.start(shape)
    let engine = engine(harness, clock: clock, alarms: SpyAlarmScheduler())
    await engine.start()

    await engine.stop(reason: "The meeting moved.")

    let after = try #require(harness.store.runningShape(), "a stop does not forget the shape")
    #expect(after.blocks.count == shape.blocks.count)
    // The position goes, because `stop` puts the cycle's own tally back to zero and a shape held at
    // block four beside a tally of zero is two accounts of one sprint.
    #expect(after.cursor == 0)
    // The controls are remembered between shapes, so stopping one does not reset them.
    #expect(harness.store.load()?.preset == .balanced)
    #expect(engine.remaining(at: clock.now) == .seconds(22 * 60))
  }

  // MARK: The restore path

  /// **A block already running is restored from its own frozen columns, not from the store.**
  ///
  /// A kill and a relaunch mid-block travel `TimerState.snapshot`, which rebuilds the block from the
  /// numbers written into the row when it began — and those were written from a resolved snapshot.
  /// So the shaped length survives a relaunch even for an engine that is handed no shape store at
  /// all, which is worth asserting rather than reasoning about: it is the reason the restore path
  /// needed no seam of its own.
  @Test("aRunningShapedBlockIsRestoredWithoutTheStore")
  func aRunningShapedBlockIsRestoredWithoutTheStore() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    harness.store.start(try Self.shape(120))
    let engine = engine(harness, clock: clock, alarms: SpyAlarmScheduler())
    await engine.start()
    let armed = try #require(engine.endsAt)

    let relaunched = TimerEngine(context: context, clock: clock, alarms: SpyAlarmScheduler())

    #expect(relaunched.endsAt == armed)
    #expect(relaunched.isRunning)
  }
}
