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

  private func sessions() throws -> [PomodoroSession] {
    try context.fetch(FetchDescriptor<PomodoroSession>())
  }

  /// Runs the block to its end and makes its alarm ring, the way a phone does.
  private func runToTheAlarm() async throws -> UUID {
    await engine.start()
    // The identity the engine handed the alarm system, which is the block's
    // session id. Read from the stand-in rather than from the engine, whose
    // state is private — and this is the same identity a phone would ring with.
    let id = try #require(alarms.outstanding?.id)
    clock.advance(by: 25 * 60)
    alarms.alertingAlarmID = id
    await engine.watchForAlarms()
    return id
  }

  // MARK: The button exists exactly when the noise does

  /// Nothing is ringing, so there is nothing to silence.
  @Test("noButtonWhenNothingIsRinging")
  func noButtonWhenNothingIsRinging() async {
    await engine.start()
    await engine.watchForAlarms()

    #expect(engine.ringingAlarmID == nil)
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

    await engine.watchForAlarms()

    #expect(engine.ringingAlarmID == id)
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

  /// **The app's button and `DismissBlockIntent` must reach the same engine
  /// call.** Two implementations of "dismiss" that drift apart is this project's
  /// most repeated defect, and here they would drift silently: one path is a
  /// button on a screen and the other is a system intent nobody sees.
  ///
  /// Run twice from identical state, and the recorded outcome must match.
  @Test("theButtonAndTheSystemAlertAgree")
  func theButtonAndTheSystemAlertAgree() async throws {
    _ = try await runToTheAlarm()
    await engine.silenceAlarm()
    let viaButton = try sessions().map { ($0.kind, $0.wasAbandoned, $0.abandonReason) }
    let sprintAfterButton = engine.completedInSprint

    // A second engine over a fresh store, dismissed the way iOS does it.
    let otherAlarms = SpyAlarmScheduler()
    let otherContainer = try TestStore.inMemoryContainer()
    let otherClock = TestClock()
    let other = TimerEngine(
      context: otherContainer.mainContext, clock: otherClock, alarms: otherAlarms)
    await other.start()
    otherClock.advance(by: 25 * 60)
    await other.handleDismiss()
    let viaIntent = try otherContainer.mainContext
      .fetch(FetchDescriptor<PomodoroSession>())
      .map { ($0.kind, $0.wasAbandoned, $0.abandonReason) }

    #expect(viaButton.count == viaIntent.count)
    #expect(viaButton.map(\.0) == viaIntent.map(\.0))
    #expect(viaButton.map(\.1) == viaIntent.map(\.1))
    #expect(viaButton.map(\.2) == viaIntent.map(\.2))
    #expect(sprintAfterButton == other.completedInSprint)
  }
}
