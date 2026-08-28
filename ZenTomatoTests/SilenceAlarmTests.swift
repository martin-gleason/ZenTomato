import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// `D26` — the alarm can be silenced from inside the app, and doing so moves the
/// sprint on exactly as the system alert's own Dismiss does.
///
/// Setup lives in `SilenceHarness`, shared with `SilenceDismissAgreementTests`.
@MainActor
struct SilenceAlarmTests {
  private let harness: SilenceHarness

  /// A throwing `init` rather than a force-try. The store can fail to open, and a
  /// crash in setup reads as a crashed test rather than a failed one.
  init() throws {
    harness = try SilenceHarness()
  }
  private var engine: TimerEngine { harness.engine }
  private var alarms: SpyAlarmScheduler { harness.alarms }
  private var clock: TestClock { harness.clock }
  private var container: ModelContainer { harness.container }
  private var context: ModelContext { harness.context }
  private var watcher: Task<Void, Never>? { harness.watcher }

  private func sessions() throws -> [PomodoroSession] { try harness.sessions() }
  private func runToTheAlarm() async throws -> UUID { try await harness.runToTheAlarm() }
  private func startWatching() { harness.startWatching() }
  private func settle() async { await harness.settle() }

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

  /// **A REFUSED STOP MUST NOT MAKE THE BUTTON DISAPPEAR FOR THE SESSION.**
  ///
  /// The second attempt at the dead-screen fix cleared the flag on both branches,
  /// reasoning that the stream would re-raise it. It would not: `alertingUpdates()`
  /// de-duplicates against its last value and a refused stop changes no AlarmKit
  /// state, so the same id is never yielded again and the button is gone for the
  /// rest of the session — while the alarm is still audibly ringing. That is the
  /// reported defect back, through the branch added to fix it.
  ///
  /// So a failure re-reads the truth. The alarm is still ringing, so the offer
  /// stands.
  @Test("aRefusedStopLeavesTheButtonReachable")
  func aRefusedStopLeavesTheButtonReachable() async throws {
    let id = try await runToTheAlarm()
    alarms.stopAlertingError = SpyAlarmScheduler.Failure()

    await engine.silenceAlarm()

    #expect(
      engine.ringingAlarmID == id,
      "The Silence button vanished while the alarm was still ringing.")

    // And it works on the second press, once iOS stops refusing.
    alarms.stopAlertingError = nil
    await engine.silenceAlarm()
    #expect(alarms.silenced == [id])
    #expect(engine.ringingAlarmID == nil)
    // **The complaint goes away with the fault.** It used to survive the retry:
    // `handleDismiss()` returns at its own guard before the line that clears
    // `lastFailure`, so "use the alert on the Lock Screen" sat there for the
    // whole break, telling somebody to do a thing they had just done.
    #expect(engine.lastFailure == nil)
  }

  /// **"Could not ask" is not "nothing is ringing".**
  ///
  /// The failure branch re-reads the alarm system so as not to hide a button for
  /// a bell that is still going. The moment iOS is most likely to refuse that
  /// *read* is the moment it has just refused the *stop* — and a `try?` there
  /// turned an unwell alarm subsystem into "all quiet", cleared the flag, and the
  /// de-duplicating stream never raised it again. `O26`, one layer down.
  @Test("aReadThatFailsKeepsTheButton")
  func aReadThatFailsKeepsTheButton() async throws {
    let id = try await runToTheAlarm()
    alarms.stopAlertingError = SpyAlarmScheduler.Failure()
    alarms.alertingReadError = SpyAlarmScheduler.Failure()

    await engine.silenceAlarm()

    #expect(
      engine.ringingAlarmID == id,
      "A failed read was taken as silence, and the button vanished with the bell still ringing.")
  }

  /// **Silencing must not erase a warning about the block that follows.**
  ///
  /// `handleDismiss()` chains into the next block, which can fail to schedule its
  /// alarm or fail to save — both reported through `lastFailure`. Clearing that
  /// property unconditionally on a successful silence wiped the message a line
  /// after it was written.
  @Test("silencingDoesNotEraseTheNextBlocksWarning")
  func silencingDoesNotEraseTheNextBlocksWarning() async throws {
    let settings = try #require(try context.fetch(FetchDescriptor<AppSettings>()).first)
    settings.autoStartNextBlock = true
    _ = try await runToTheAlarm()
    alarms.scheduleError = SpyAlarmScheduler.Failure()

    await engine.silenceAlarm()

    #expect(
      engine.lastFailure == .alarmSchedulingFailed,
      "The next block's warning was erased by the silence that preceded it.")
  }

  /// **Two taps inside the suspension advance the sprint once.**
  ///
  /// `silenceAlarm()` suspends across a real AlarmKit round trip, and the button
  /// deliberately survives a refusal — so a double tap is reachable, and without
  /// a guard both calls pass `handleDismiss()`'s guards and both call `end(...)`.
  /// That is the double advance `O29` asks the owner to watch for.
  @Test("twoTapsAdvanceOnce")
  func twoTapsAdvanceOnce() async throws {
    _ = try await runToTheAlarm()

    async let first: Void = engine.silenceAlarm()
    async let second: Void = engine.silenceAlarm()
    _ = await (first, second)

    #expect(try sessions().count == 1, "The sprint advanced twice on one alarm.")
  }
}
