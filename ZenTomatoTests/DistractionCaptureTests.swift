import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// Tests for the tap itself: what a tap writes, and — just as important — when
/// a tap is refused.
///
/// THE SPEC'S OWN *DONE WHEN* IS THE FIRST TEST IN THIS FILE, VERBATIM:
/// "a pomodoro with three taps yields three records with the right task and
/// timestamps". F5 builds nothing that displays a distraction — reading them
/// back is F6's feature — so this suite, and the store pulled off the phone by
/// hand, are the only two places that claim can be checked at all.
///
/// `@MainActor` on the whole suite: SwiftData's context is main-thread only and
/// so is the engine.
@Suite("DistractionCapture")
@MainActor
struct DistractionCaptureTests {
  private let container: ModelContainer
  private let clock: TestClock
  private let alarms: SpyAlarmScheduler
  private let engine: TimerEngine

  /// Swift Testing builds a fresh instance of this struct for every test, so
  /// each one gets its own empty in-memory store, its own clock stopped at the
  /// same instant, and an engine that has never run anything.
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

  /// Every recorded distraction, oldest first.
  private func distractions() throws -> [Distraction] {
    try context.fetch(FetchDescriptor<Distraction>(sortBy: [SortDescriptor(\.timestamp)]))
  }

  /// The identity of the block the timer is running now, read from the database
  /// rather than from the engine — the engine deliberately does not publish it.
  private func runningSessionID() throws -> UUID {
    try TimerState.current(in: context).sessionID
  }

  // MARK: The spec's done-when

  /// **The spec's acceptance criterion, written out as a test.** Three taps
  /// during one pomodoro produce three rows, with the right kinds, all filed
  /// against that pomodoro, at the exact instants they were tapped.
  ///
  /// The last two checks are the ones worth explaining. The timestamps come
  /// from the engine's clock, which the test controls, so they can be asserted
  /// exactly rather than approximately — nothing here waits for real time to
  /// pass. And the finished-block row written when the pomodoro ends carries
  /// the same identity the taps do, which is what makes a distraction findable
  /// from its block without the database maintaining a link between them.
  @Test("threeTapsThreeRecords")
  func threeTapsThreeRecords() async throws {
    await engine.start()
    let sessionID = try runningSessionID()
    let firstTap = clock.now

    #expect(engine.recordDistraction(.internalInterruption))
    clock.advance(by: 60)
    #expect(engine.recordDistraction(.externalInterruption))
    clock.advance(by: 90)
    #expect(engine.recordDistraction(.internalInterruption))

    let rows = try distractions()
    #expect(rows.count == 3)
    #expect(rows.map(\.kind) == [.internalInterruption, .externalInterruption, .internalInterruption])
    #expect(rows.allSatisfy { $0.sessionID == sessionID })
    #expect(rows.map(\.timestamp) == [
      firstTap,
      firstTap.addingTimeInterval(60),
      firstTap.addingTimeInterval(150)
    ])
    // Nothing has been asked yet, so nothing has been said. Three taps and no
    // sentences is a complete, normal record.
    #expect(rows.allSatisfy { $0.note == nil })

    // Finish the block: the row it writes carries the same identity the three
    // taps were filed under.
    clock.advance(by: 25 * 60 - 150)
    await engine.boundaryReached()
    let session = try #require(context.fetch(FetchDescriptor<PomodoroSession>()).first)
    #expect(session.id == sessionID)
  }

  // MARK: When a tap is refused

  /// A distraction during a break is not a distraction — that is what a break
  /// is for. Both kinds of break refuse both kinds of tap.
  ///
  /// The two work blocks in the middle are the control. A test that only showed
  /// taps being refused could be passing because capture is broken outright, so
  /// this one records a real tap either side of the refusals and counts the
  /// rows at the end.
  @Test("tapsOnlyDuringWork")
  func tapsOnlyDuringWork() async throws {
    // A sprint of two, so the second focus block earns the long break and both
    // kinds of break can be reached inside one test.
    let stored = try AppSettings.current(in: context)
    stored.pomodorosPerSprint = 2
    try context.save()

    // First focus block: a tap is accepted.
    await engine.start()
    #expect(engine.recordDistraction(.internalInterruption))

    // Short break.
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()
    await engine.start()
    #expect(engine.kind == .shortBreak)
    #expect(engine.isRunning)
    #expect(engine.recordDistraction(.internalInterruption) == false)
    #expect(engine.recordDistraction(.externalInterruption) == false)
    #expect(engine.currentBlockDistractions.isEmpty)
    #expect(try distractions().count == 1)

    // Second focus block: accepted again.
    clock.advance(by: 5 * 60)
    await engine.boundaryReached()
    await engine.start()
    #expect(engine.kind == .work)
    #expect(engine.recordDistraction(.externalInterruption))

    // Long break.
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()
    await engine.start()
    #expect(engine.kind == .longBreak)
    #expect(engine.isRunning)
    #expect(engine.recordDistraction(.internalInterruption) == false)
    #expect(engine.recordDistraction(.externalInterruption) == false)

    // Exactly the two taps made during focus blocks, and nothing from either
    // break.
    let rows = try distractions()
    #expect(rows.count == 2)
    #expect(rows.map(\.kind) == [.internalInterruption, .externalInterruption])
  }

  /// A tap whose instant is past the block's end instant is refused, even
  /// though the block is still marked as running.
  ///
  /// WHY THIS CASE EXISTS AT ALL, AND WHY THE GUARD IT TESTS IS NOT REDUNDANT
  /// A block stays marked as running from the moment its end time passes until
  /// the app notices — the waking task may not have fired, or the phone may
  /// have been asleep across the boundary. A tap in that gap belongs to no
  /// block: the work block is over by the wall clock, and the break has not
  /// started. Without the engine's second guard it would be filed against the
  /// finished work block and then swept into that block's reflection sheet — a
  /// distraction that happened during a break, presented as if it happened
  /// during work.
  ///
  /// **Deleting `guard now < state.endsAt` from the engine makes this test
  /// fail.** The first half is the reason it has to be an inequality rather
  /// than something looser: one second earlier is a perfectly good tap.
  @Test("tapAfterTheBlocksEndInstantIsRefused")
  func tapAfterTheBlocksEndInstantIsRefused() async throws {
    await engine.start()
    let endsAt = try #require(engine.endsAt)

    // One second inside the block: accepted.
    clock.advance(by: 25 * 60 - 1)
    #expect(engine.recordDistraction(.internalInterruption))

    // Exactly on the end instant, with the boundary deliberately not run: the
    // block is still marked as running and the tap is still refused.
    clock.advance(by: 1)
    #expect(clock.now == endsAt)
    #expect(engine.isRunning)
    #expect(engine.recordDistraction(.internalInterruption) == false)

    // And well past it.
    clock.advance(by: 30)
    #expect(engine.recordDistraction(.externalInterruption) == false)

    #expect(try distractions().count == 1)
    #expect(engine.currentBlockDistractions.count == 1)
  }

  /// Nothing is running, so there is no block for a tap to belong to.
  @Test("tapWhileIdleIsRefused")
  func tapWhileIdleIsRefused() throws {
    #expect(engine.isRunning == false)
    #expect(engine.recordDistraction(.internalInterruption) == false)
    #expect(try distractions().isEmpty)
    #expect(engine.currentBlockDistractions.isEmpty)
  }

  /// A tap the guard turns away builds no row at all — not one that is created
  /// and then thrown away, and not one left waiting in the database handle.
  ///
  /// **What this test does NOT cover, said out loud.** The refusal it produces
  /// is the guard at the top of `recordDistraction(_:)` firing while the engine
  /// is idle, which returns before a `Distraction` is ever constructed. The
  /// *other* refusal — `context.save()` throwing, whose `catch` deletes the
  /// half-made row so that a later successful save cannot commit it silently —
  /// has no test anywhere, because SwiftData offers no supported way to make a
  /// save fail in-process. That gap is stated in `docs/reviews/F5.md` rather
  /// than papered over with a test that cannot reach the branch.
  ///
  /// This is a claim about what *did not* happen, so it is checked by doing
  /// something that saves — starting a block writes the timer row — and then
  /// counting.
  @Test("aTapRefusedByTheGuardInsertsNothing")
  func aTapRefusedByTheGuardInsertsNothing() async throws {
    #expect(engine.recordDistraction(.internalInterruption) == false)
    await engine.start()
    #expect(try distractions().isEmpty)

    clock.advance(by: 25 * 60)
    await engine.boundaryReached()
    #expect(try distractions().isEmpty)
  }

  /// A tap the engine refuses does not leave a warning about the *block* behind
  /// it.
  ///
  /// `.persistenceFailed` reads "This block couldn't be saved and may be lost if
  /// you close the app", and nothing clears `lastFailure` until the next block
  /// boundary. Recording it for a refused tap meant that tapping again — which
  /// is exactly what the screen's own amber line tells the person to do — put a
  /// block-loss warning up at the instant of the tap that worked, and left it up
  /// for the rest of the block. The screen owns the wording for a refused tap;
  /// the engine says nothing.
  @Test("aRefusedTapLeavesNoWarningAboutTheBlock")
  func aRefusedTapLeavesNoWarningAboutTheBlock() async throws {
    #expect(engine.recordDistraction(.internalInterruption) == false)
    #expect(engine.lastFailure == nil)

    await engine.start()
    #expect(engine.recordDistraction(.internalInterruption))
    #expect(engine.lastFailure == nil)
  }

  /// A wall-clock jump backwards mid-block does not make the taps that follow it
  /// disappear from the count.
  ///
  /// WHY THIS IS A REAL SHAPE AND NOT A CONTRIVANCE
  /// `endsAt` and `startedAt` are both absolute times. The skew correction used
  /// to rewrite only `endsAt`, which left the block claiming to have started
  /// after it would finish. `rehydrateDistractions` bounds its query at
  /// `startedAt`, so every tap made after the correction carried a timestamp
  /// below that bound and was silently dropped the next time the app came back
  /// to the foreground — the rows stayed on disk, but the number under the
  /// button fell back and the end-of-block sheet would have omitted them.
  ///
  /// The control half matters: without the tap being *accepted* first, this
  /// would pass with capture switched off entirely.
  @Test("aBackwardClockJumpDoesNotHideTheTapsThatFollowIt")
  func aBackwardClockJumpDoesNotHideTheTapsThatFollowIt() async throws {
    await engine.start()
    let startedAt = try TimerState.current(in: context).startedAt

    // An hour backwards: a timezone change, or a network clock correction.
    clock.moveWallClock(by: -3600)
    await engine.synchronize()

    let corrected = try TimerState.current(in: context)
    #expect(corrected.startedAt < corrected.endsAt)
    #expect(corrected.startedAt < startedAt)

    #expect(engine.recordDistraction(.internalInterruption))
    #expect(engine.currentBlockDistractions.count == 1)

    // Coming back to the foreground rebuilds the count from the store. The tap
    // must survive that rebuild.
    await engine.synchronize()
    #expect(engine.currentBlockDistractions.count == 1)
    #expect(try distractions().count == 1)
  }

  // MARK: What the screen is told

  /// The running count the capture buttons draw is exactly the rows in the
  /// database, in the same order, and it empties at the block boundary without
  /// deleting anything.
  ///
  /// The tally line is checked here too, against the owner's own
  /// `DistractionTally.summary(of:)`. It is the line both sheets show, and a
  /// hand-written function with no caller is a function nobody would notice
  /// going wrong.
  @Test("badgeCountsMatchTheRows")
  func badgeCountsMatchTheRows() async throws {
    await engine.start()
    #expect(engine.recordDistraction(.internalInterruption))
    #expect(engine.recordDistraction(.externalInterruption))
    #expect(engine.recordDistraction(.internalInterruption))

    let rows = try distractions()
    #expect(engine.currentBlockDistractions.count == 3)
    #expect(engine.currentBlockDistractions.map(\.id) == rows.map(\.id))
    #expect(engine.currentBlockDistractions.map(\.kind) == rows.map(\.kind))
    #expect(engine.currentBlockDistractions.map(\.timestamp) == rows.map(\.timestamp))
    #expect(DistractionTally.summary(of: engine.currentBlockDistractions.map(\.kind)) == "2 internal · 1 external")

    // The boundary empties the count — it is about the block in progress — and
    // touches none of the rows.
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()
    #expect(engine.currentBlockDistractions.isEmpty)
    #expect(try distractions().count == 3)
  }
}
