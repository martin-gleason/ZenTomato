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

  /// Today's shipped defaults: 25 / 5 / 15, four poms to a sprint. The settings a shaped block has
  /// to visibly differ from.
  private static let settings = TimerSettingsSnapshot(
    workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15,
    pomodorosPerSprint: 4, soundEnabled: true, alertSound: .systemDefault, autoStartNextBlock: false)

  private static func shape(_ budget: Int, endsWithLongBreak: Bool = true) throws -> SprintShape {
    try #require(
      SprintShaper.shape(
        budgetMinutes: budget, settings: settings, endsWithLongBreak: endsWithLongBreak))
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

  // MARK: The shape does not outlive its sprint

  /// Runs every block of `shape` to its end, the way a boundary does.
  private func run(_ engine: TimerEngine, blocks: Int, clock: TestClock) async throws {
    for _ in 0..<blocks {
      let endsAt = try #require(engine.endsAt)
      clock.advance(by: endsAt.timeIntervalSince(clock.now))
      await engine.boundaryReached()
    }
  }

  /// `aShapeDoesNotOutliveItsSprint` — run it to the end and the store is empty.
  ///
  /// This is `F8-M3`'s named test.
  @Test("aShapeDoesNotOutliveItsSprint")
  func aShapeDoesNotOutliveItsSprint() async throws {
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

    #expect(harness.store.runningShape() == nil)
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

    #expect(harness.store.runningShape() == nil)
  }

  /// Stopping the sprint forgets the shape. See `TimerEngine.shapeSurvivesBeingStoppedEarly`, which
  /// is where `F8`'s third open question is parked.
  @Test("stoppingTheSprintForgetsTheShape")
  func stoppingTheSprintForgetsTheShape() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    harness.store.start(try Self.shape(120))
    let engine = engine(harness, clock: clock, alarms: SpyAlarmScheduler())
    await engine.start()

    await engine.stop(reason: "The meeting moved.")

    #expect(harness.store.runningShape() == nil)
    // The controls are remembered between shapes, so stopping one does not reset them.
    #expect(harness.store.load()?.preset == .balanced)
    #expect(engine.remaining(at: clock.now) == .seconds(25 * 60))
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
