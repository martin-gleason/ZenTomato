import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// What one tap has captured, held somewhere a closure can write to it and the
/// test can read it afterwards.
///
/// A closure cannot hand a value back to the test that installed it, so the two
/// share this small object instead. It is a class rather than a struct for
/// exactly that reason: a struct would be copied into the closure and the test
/// would read its own untouched copy.
@MainActor
private final class TapOutcome {
  /// What each mid-transition tap returned, in the order they were made.
  ///
  /// An array rather than two separate answers, because it records *that* the
  /// closure ran as well as what it said. A test asserting on a single value
  /// could be passing because the closure never ran at all, which is the one
  /// way this whole approach could quietly stop testing anything.
  var results: [Bool] = []
}

/// Tests for the claim the whole feature is judged on: **a tap cannot be lost
/// between the moment a finger leaves the screen and the moment anything asks
/// about it.**
///
/// The adversarial reviewer asks that question directly, so each test here is
/// written to answer a specific way it could go wrong rather than to
/// demonstrate that the happy path works:
///
///   * `tapIsDurableBeforePrompt` — is it really *committed*, or merely sitting
///     in memory looking committed?
///   * `killedBetweenTapAndPrompt` — does it survive the app dying?
///   * `relaunchRebuildsTheBadgeFromTheStore` — is the count on screen derived
///     from the database, or is the database derived from the count?
///   * `tapDuringATransitionAttachesToTheBlockThatOwnsTheInstant` — can a tap
///     arriving in the middle of one block becoming another be filed against
///     the wrong one?
@Suite("DistractionDurability")
@MainActor
struct DistractionDurabilityTests {
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

  private func distractions(in context: ModelContext) throws -> [Distraction] {
    try context.fetch(FetchDescriptor<Distraction>(sortBy: [SortDescriptor(\.timestamp)]))
  }

  // MARK: Committed, not merely created

  /// A row is readable through a **different database handle** the instant the
  /// tap returns, with no sheet having appeared and nothing having been
  /// dismissed.
  ///
  /// WHY A SECOND HANDLE IS THE POINT AND NOT A DETAIL
  /// SwiftData keeps newly created objects in the handle that created them
  /// until they are saved. So reading a tap back through the *same* handle
  /// proves nothing at all — it would find the object whether or not it had
  /// ever reached the disk. A second handle over the same store can only see
  /// what has actually been committed. A row appearing there is therefore proof
  /// that the save happened, which is exactly the claim being made.
  @Test("tapIsDurableBeforePrompt")
  func tapIsDurableBeforePrompt() async throws {
    await engine.start()
    let sessionID = try TimerState.current(in: context).sessionID

    #expect(engine.recordDistraction(.internalInterruption))

    let separateHandle = ModelContext(container)
    let rows = try distractions(in: separateHandle)
    #expect(rows.count == 1)
    #expect(rows.first?.kind == .internalInterruption)
    #expect(rows.first?.sessionID == sessionID)
    #expect(rows.first?.timestamp == clock.now)
    #expect(rows.first?.note == nil)

    // Nothing has been asked and nothing has been dismissed. The row is
    // complete anyway, which is the entire design: the sentence is an optional
    // annotation on a record that already exists.
    #expect(engine.pendingReflection == nil)
  }

  /// The app dies a moment after two taps. The rows are still there when it
  /// opens again, with no sentences on them.
  ///
  /// WHY THIS ONE USES A REAL FILE
  /// "It survives the app being killed" is a claim about what is left when
  /// everything in memory is gone. An in-memory store cannot answer it, because
  /// it disappears together with the thing being tested. So this test writes to
  /// an actual file, releases the container completely — which is as close to
  /// pulling the process out from under the app as a unit test gets — and then
  /// opens the same file fresh.
  @Test("killedBetweenTapAndPrompt")
  func killedBetweenTapAndPrompt() async throws {
    let store = try TestStore.temporaryFileStore()
    defer { store.remove() }

    // Written inside its own function so that everything it opens is released
    // the moment the function returns. Durability cannot be honestly tested
    // while the writer is still holding the store open.
    let sessionID = try await tapTwice(intoStoreAt: store.storeURL)

    let reopened = try AppModelContainer.make(.file(store.storeURL))
    let rows = try distractions(in: reopened.mainContext)

    #expect(rows.count == 2)
    #expect(rows.map(\.kind) == [.internalInterruption, .externalInterruption])
    #expect(rows.allSatisfy { $0.sessionID == sessionID })
    // No sheet was ever presented, so nothing was ever written on them — and
    // that is a complete record rather than a damaged one. Skipping is a
    // first-class outcome and the counts alone are data.
    #expect(rows.allSatisfy { $0.note == nil })
  }

  /// Opens the store, runs a focus block, records two taps, and lets go of
  /// everything. Returns the identity of the block they were filed against.
  private func tapTwice(intoStoreAt url: URL) async throws -> UUID {
    let container = try AppModelContainer.make(.file(url))
    let engine = TimerEngine(context: container.mainContext, clock: clock, alarms: alarms)
    await engine.start()
    let sessionID = try TimerState.current(in: container.mainContext).sessionID

    #expect(engine.recordDistraction(.internalInterruption))
    clock.advance(by: 45)
    #expect(engine.recordDistraction(.externalInterruption))

    return sessionID
  }

  // MARK: The count on screen is a view of the store

  /// A relaunched app shows the right count beside the capture buttons, because
  /// it rebuilds it from the database rather than remembering it.
  ///
  /// **This is what proves the count is a derived view and not a buffer.** If
  /// taps were being held in memory and written later, a brand-new engine would
  /// show nothing and the rows would be gone with the process that held them.
  ///
  /// The new engine is given a **new database handle**, not the one the first
  /// engine used, so nothing it finds can be an object left lying in memory.
  @Test("relaunchRebuildsTheBadgeFromTheStore")
  func relaunchRebuildsTheBadgeFromTheStore() async throws {
    await engine.start()
    #expect(engine.recordDistraction(.internalInterruption))
    clock.advance(by: 30)
    #expect(engine.recordDistraction(.externalInterruption))
    #expect(engine.currentBlockDistractions.count == 2)

    let freshHandle = ModelContext(container)
    let relaunched = TimerEngine(context: freshHandle, clock: clock, alarms: alarms)

    // Right at construction, before anything reconciles: the screen is correct
    // the instant it is first drawn.
    #expect(relaunched.currentBlockDistractions.count == 2)
    #expect(relaunched.currentBlockDistractions.map(\.kind) == [.internalInterruption, .externalInterruption])

    // And again after coming back to the foreground, which is the other path
    // that rebuilds it.
    await relaunched.synchronize()
    #expect(relaunched.currentBlockDistractions.count == 2)
    #expect(relaunched.currentBlockDistractions.map(\.kind) == [.internalInterruption, .externalInterruption])
  }

  // MARK: The hardest instant in the feature

  /// A tap that arrives while one block is turning into the next is filed
  /// against the block that owns the instant it happened — or refused.
  ///
  /// HOW THE INSTANT IS PRODUCED, SINCE IT CANNOT BE WAITED FOR
  /// Starting a block is the one place the engine pauses in the middle of
  /// something: it writes the new block down, saves it, and then waits while an
  /// alarm is scheduled. `ReentrantAlarmScheduler` runs a closure inside that
  /// wait, so the tap genuinely happens mid-transition, deterministically,
  /// every time — rather than depending on a race that would pass or fail by
  /// luck.
  ///
  /// Two halves, and both are needed. A tap landing as a **break** starts is
  /// refused, because a distraction during a break is not a distraction. A tap
  /// landing as the **next focus block** starts is accepted and filed against
  /// that new block, not the one that just ended. Without the second half this
  /// test would also pass with capture broken outright.
  @Test("tapDuringATransitionAttachesToTheBlockThatOwnsTheInstant")
  func tapDuringATransitionAttachesToTheBlockThatOwnsTheInstant() async throws {
    let chainedStore = try TestStore.inMemoryContainer()
    let chainedContext = chainedStore.mainContext
    let reentrant = ReentrantAlarmScheduler()
    let chained = TimerEngine(context: chainedContext, clock: clock, alarms: reentrant)

    // Auto-start on, so one block runs straight into the next and the engine
    // really is mid-transition rather than sitting idle between them.
    let stored = try AppSettings.current(in: chainedContext)
    stored.autoStartNextBlock = true
    try chainedContext.save()

    await chained.start()
    let firstWorkSessionID = try TimerState.current(in: chainedContext).sessionID
    let outcome = TapOutcome()

    // The short break is starting. A tap here belongs to nothing.
    reentrant.duringSchedule = {
      outcome.results.append(chained.recordDistraction(.internalInterruption))
    }
    clock.advance(by: 25 * 60)
    await chained.boundaryReached()

    #expect(chained.kind == .shortBreak)
    #expect(chained.isRunning)
    #expect(outcome.results == [false])
    #expect(try distractions(in: chainedContext).isEmpty)
    #expect(chained.currentBlockDistractions.isEmpty)

    // The next focus block is starting. A tap here belongs to *it*.
    reentrant.duringSchedule = {
      outcome.results.append(chained.recordDistraction(.externalInterruption))
    }
    clock.advance(by: 5 * 60)
    await chained.boundaryReached()

    #expect(chained.kind == .work)
    #expect(outcome.results == [false, true])

    let secondWorkSessionID = try TimerState.current(in: chainedContext).sessionID
    let rows = try distractions(in: chainedContext)
    #expect(rows.count == 1)
    #expect(rows.first?.sessionID == secondWorkSessionID)
    // Filed against the block that was starting, never against the one that had
    // just ended.
    #expect(rows.first?.sessionID != firstWorkSessionID)
    #expect(chained.currentBlockDistractions.count == 1)
  }
}
