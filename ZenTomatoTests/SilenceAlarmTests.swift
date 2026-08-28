import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// `D26` — the alarm can be silenced from inside the app, and doing so moves the
/// sprint on exactly as the system alert's own Dismiss does.
@MainActor
struct SilenceAlarmTests {
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

  private var context: ModelContext { container.mainContext }

  private let watcherBox = WatcherBox()

  private func sessions() throws -> [PomodoroSession] {
    try context.fetch(FetchDescriptor<PomodoroSession>())
  }

  /// Runs the block to its end and makes its alarm ring, the way a phone does,
  /// **with the watcher still running** — because that is the only state in
  /// which the button exists.
  ///
  /// The watcher is a live task rather than an awaited call. `watchForAlarms()`
  /// clears its flag when the stream ends, correctly: the flag means *an alarm
  /// is ringing right now*, and a screen that has stopped listening does not
  /// know that any more. A stand-in whose stream finished immediately made every
  /// assertion here vacuous, so the stream stays open and the test cancels it.
  private func runToTheAlarm() async throws -> UUID {
    await engine.start()
    // The identity the engine handed the alarm system, which is the block's
    // session id. Read from the stand-in rather than from the engine, whose
    // state is private — and this is the same identity a phone would ring with.
    let id = try #require(alarms.outstanding?.id)
    clock.advance(by: 25 * 60)
    startWatching()
    alarms.ring(id)
    await settle()
    return id
  }

  /// Starts the watcher and remembers it, so a test can end it.
  private func startWatching() {
    watcher = Task { await engine.watchForAlarms() }
  }

  /// Lets the watcher pick up whatever was just pushed.
  private func settle() async {
    for _ in 0..<20 {
      await Task.yield()
      if engine.ringingAlarmID != nil { return }
    }
  }

  private final class WatcherBox: @unchecked Sendable {
    var task: Task<Void, Never>?
  }

  private var watcher: Task<Void, Never>? {
    get { watcherBox.task }
    nonmutating set { watcherBox.task = newValue }
  }

  // MARK: The button exists exactly when the noise does

  /// Nothing is ringing, so there is nothing to silence.
  @Test("noButtonWhenNothingIsRinging")
  func noButtonWhenNothingIsRinging() async {
    await engine.start()
    startWatching()
    await Task.yield()

    #expect(engine.ringingAlarmID == nil)
    watcher?.cancel()
  }

  /// The alarm rings, and the engine says so.
  @Test("theEngineKnowsWhenTheAlarmIsRinging")
  func theEngineKnowsWhenTheAlarmIsRinging() async throws {
    let id = try await runToTheAlarm()

    #expect(engine.ringingAlarmID == id)
  }

  /// **The stream's first value is the current state**, so a screen opened while
  /// an alarm is already ringing still draws the button. Without this, the one
  /// case the feature exists for — reaching for the phone *because* it is making
  /// a noise — is the case that shows nothing.
  @Test("aScreenOpenedMidAlarmStillSeesIt")
  func aScreenOpenedMidAlarmStillSeesIt() async throws {
    await engine.start()
    let id = try #require(alarms.outstanding?.id)
    clock.advance(by: 25 * 60)
    // The alarm began before anybody started watching.
    alarms.alertingAlarmID = id

    startWatching()
    await settle()

    #expect(engine.ringingAlarmID == id)
    watcher?.cancel()
  }

  /// **The flag does not stick when the watcher stops.** Start and Stop are both
  /// disabled while it is set, so a stale `true` is a screen with three controls
  /// on it and nothing that can be pressed — no way out short of a relaunch.
  @Test("theFlagClearsWhenWatchingEnds")
  func theFlagClearsWhenWatchingEnds() async throws {
    _ = try await runToTheAlarm()
    #expect(engine.ringingAlarmID != nil)

    alarms.endAlerting()
    for _ in 0..<20 where engine.ringingAlarmID != nil { await Task.yield() }

    #expect(engine.ringingAlarmID == nil, "The Silence flag survived the stream that fed it.")
  }

  // MARK: What the button does

  /// It stops the noise.
  @Test("silencingStopsTheAlarm")
  func silencingStopsTheAlarm() async throws {
    let id = try await runToTheAlarm()

    await engine.silenceAlarm()

    #expect(alarms.silenced == [id])
    #expect(engine.ringingAlarmID == nil)
  }

  /// **The block is recorded COMPLETED, never abandoned, and no reason is asked
  /// for.** This is the whole of `D26`'s answer: silence *and advance*, like
  /// Dismiss — not `stop(reason:)`, which ends the sprint and demands a sentence.
  /// One method carrying both meanings is how the `F2b` arc produced four fixes
  /// in a row.
  @Test("silencingCompletesTheBlockRatherThanAbandoningIt")
  func silencingCompletesTheBlockRatherThanAbandoningIt() async throws {
    _ = try await runToTheAlarm()

    await engine.silenceAlarm()

    let recorded = try sessions()
    #expect(recorded.count == 1)
    let session = try #require(recorded.first)
    #expect(session.wasAbandoned == false)
    #expect(session.abandonReason == nil)
  }

  /// Silencing does not stop the sprint the way Stop does.
  @Test("silencingDoesNotResetTheSprint")
  func silencingDoesNotResetTheSprint() async throws {
    _ = try await runToTheAlarm()

    await engine.silenceAlarm()

    // A focus block was completed, so the sprint has moved on rather than
    // returned to nothing — which is what `stop(reason:)` does.
    #expect(engine.completedInSprint == 1)
  }

  /// Nothing is ringing, so nothing happens. In particular the sprint does not
  /// advance: a button that cannot be seen must not be reachable by accident.
  @Test("silencingWithNothingRingingDoesNothing")
  func silencingWithNothingRingingDoesNothing() async throws {
    await engine.start()

    await engine.silenceAlarm()

    #expect(alarms.silenced.isEmpty)
    #expect(try sessions().isEmpty)
    #expect(engine.isRunning)
  }

  /// **A refusal from iOS must not also strand the timer.**
  ///
  /// Somebody who asked for quiet and got an error is already having a bad
  /// moment; leaving the sprint stuck as well would be the app failing twice for
  /// one fault. The noise is reported and the block still advances.
  @Test("aFailureToSilenceStillAdvancesTheSprint")
  func aFailureToSilenceStillAdvancesTheSprint() async throws {
    _ = try await runToTheAlarm()
    alarms.stopAlertingError = SpyAlarmScheduler.Failure()

    await engine.silenceAlarm()

    #expect(engine.lastFailure == .alarmSilenceFailed)
    #expect(try sessions().count == 1)
    #expect(try #require(sessions().first).wasAbandoned == false)
  }

  // MARK: The drift test

  /// **The app's button and the system alert must land on the same engine call.**
  ///
  /// The first version of this test called `engine.handleDismiss()` directly for
  /// the second half, which proved nothing: the intent path is
  /// `DismissBlockIntent.perform()` → `TimerEngineHolder.dismissRunningBlock()`,
  /// and that could grow a step tomorrow while this stayed green. Worse, both
  /// halves were put in the same hand-built state, so both took the same
  /// `guard` and the comparison was between two methods that differ only by the
  /// `stopAlerting` call the assertions never looked at. **It could not fail for
  /// the reason it was written**, which the adversarial review said plainly.
  ///
  /// So the second half goes through `TimerEngineHolder`, which is what the
  /// intent actually calls.
  @Test("theButtonAndTheSystemAlertAgree")
  func theButtonAndTheSystemAlertAgree() async throws {
    _ = try await runToTheAlarm()
    await engine.silenceAlarm()
    let viaButton = try sessions().map { ($0.kind, $0.wasAbandoned, $0.abandonReason) }
    let sprintAfterButton = engine.completedInSprint
    let reflectionAfterButton = engine.pendingReflection != nil

    let otherAlarms = SpyAlarmScheduler()
    let otherContainer = try TestStore.inMemoryContainer()
    let otherClock = TestClock()
    let other = TimerEngine(
      context: otherContainer.mainContext, clock: otherClock, alarms: otherAlarms)
    await other.start()
    otherClock.advance(by: 25 * 60)

    // The real route the system alert takes.
    TimerEngineHolder.engine = other
    await TimerEngineHolder.dismissRunningBlock()
    TimerEngineHolder.engine = nil

    let viaIntent = try otherContainer.mainContext
      .fetch(FetchDescriptor<PomodoroSession>())
      .map { ($0.kind, $0.wasAbandoned, $0.abandonReason) }

    #expect(viaButton.count == viaIntent.count)
    #expect(viaButton.map(\.0) == viaIntent.map(\.0))
    #expect(viaButton.map(\.1) == viaIntent.map(\.1))
    #expect(viaButton.map(\.2) == viaIntent.map(\.2))
    #expect(sprintAfterButton == other.completedInSprint)
    // And the reflection offer, which is the thing the app exists for.
    #expect(reflectionAfterButton == (other.pendingReflection != nil))
  }

  /// **The button silences, and only the button silences.** The half the old
  /// drift test never inspected: `handleDismiss()` alone must not call
  /// `stopAlerting`, because it runs after iOS has already ended the alert.
  @Test("onlyTheButtonStopsTheAlarmItself")
  func onlyTheButtonStopsTheAlarmItself() async throws {
    let id = try await runToTheAlarm()

    await engine.handleDismiss()

    #expect(alarms.silenced.isEmpty, "handleDismiss silenced an alarm iOS had already ended.")
    #expect(engine.ringingAlarmID == id, "handleDismiss should not clear a flag it does not own.")
  }

  // MARK: The two the plan promised

  /// **Auto-start is honoured, both ways.** `F2d.md` listed this and the first
  /// build shipped without it.
  @Test("silencingHonoursAutoStart")
  func silencingHonoursAutoStart() async throws {
    let settings = try #require(try context.fetch(FetchDescriptor<AppSettings>()).first)
    settings.autoStartNextBlock = true
    _ = try await runToTheAlarm()

    await engine.silenceAlarm()

    #expect(engine.isRunning, "With auto-start on, the break should have begun.")
  }

  /// And with it off, the timer waits.
  @Test("silencingWithAutoStartOffWaits")
  func silencingWithAutoStartOffWaits() async throws {
    let settings = try #require(try context.fetch(FetchDescriptor<AppSettings>()).first)
    settings.autoStartNextBlock = false
    _ = try await runToTheAlarm()

    await engine.silenceAlarm()

    #expect(engine.isRunning == false, "With auto-start off, the timer should be waiting.")
  }

  /// **A REFLECTION PROMPT IS NOT SWALLOWED BY SILENCING IN THE AUTO-START
  /// WINDOW.** The worst defect the adversarial review found, and the one this
  /// app can least afford: the distraction log is the point.
  ///
  /// The sequence: a focus block ends, `end()` chains into `begin()`, which
  /// suspends awaiting the alarm system — a real AlarmKit round trip — and the
  /// alarm rings at that instant. A Silence tap then reaches `handleDismiss()`
  /// with the *new* block running and not yet complete. That path used to bump
  /// `abandonGeneration` before returning, and `publishReflection` then refused
  /// to publish the finished block's prompts.
  ///
  /// `ReentrantAlarmScheduler` exists to drive exactly that suspension.
  @Test("silencingInsideTheAutoStartWindowKeepsTheReflection")
  func silencingInsideTheAutoStartWindowKeepsTheReflection() async throws {
    let reentrant = ReentrantAlarmScheduler()
    let container = try TestStore.inMemoryContainer()
    let clock = TestClock()
    let engine = TimerEngine(context: container.mainContext, clock: clock, alarms: reentrant)

    let settings = try #require(try container.mainContext.fetch(FetchDescriptor<AppSettings>()).first)
    settings.autoStartNextBlock = true

    await engine.start()
    _ = engine.recordDistraction(.internalInterruption)
    let focusID = try #require(reentrant.scheduledRequests.first?.id)
    clock.advance(by: 25 * 60)

    // The screen is watching, as it is whenever the app is in the foreground —
    // which is the only situation `D26` is about.
    let watcher = Task { await engine.watchForAlarms() }
    await Task.yield()

    // The focus block's alarm rings at the instant the *next* block is being
    // scheduled, and Silence is tapped then. That is the window: `begin()` is
    // suspended awaiting the alarm system, and `handleDismiss()` therefore sees
    // a block that has not completed.
    reentrant.duringScheduleAsync = {
      reentrant.ring(focusID)
      for _ in 0..<20 where engine.ringingAlarmID == nil { await Task.yield() }
      await engine.silenceAlarm()
    }
    await engine.boundaryReached()
    watcher.cancel()

    #expect(
      engine.pendingReflection != nil,
      "The finished block's reflection prompt was swallowed by a Silence tap.")
  }
}
