import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// `D26` — the app's Silence button and the system alert's Dismiss must land on
/// the same engine call.
///
/// **Its own file because `SilenceAlarmTests` genuinely crossed the 400-line
/// limit** after the third adversarial pass, and these are the tests that could
/// move: everything they need is in `SilenceHarness`. (An earlier commit claimed
/// a split of this file that never happened — see `SilenceControlFenceTests`. This
/// one is real: `git show` will find the lines leaving `SilenceAlarmTests.swift`.)
@MainActor
struct SilenceDismissAgreementTests {
  private let harness: SilenceHarness

  /// A throwing `init` rather than a force-try. The store can fail to open, and a
  /// crash in setup reads as a crashed test rather than a failed one.
  init() throws {
    harness = try SilenceHarness()
  }
  private var engine: TimerEngine { harness.engine }
  private var alarms: SpyAlarmScheduler { harness.alarms }
  private var container: ModelContainer { harness.container }
  private var context: ModelContext { harness.context }

  private func sessions() throws -> [PomodoroSession] { try harness.sessions() }
  private func runToTheAlarm() async throws -> UUID { try await harness.runToTheAlarm() }

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
      // Asserted, not assumed: a bounded wait that times out would make every
      // line below it vacuous.
      #expect(engine.ringingAlarmID != nil, "The watcher never saw the alarm.")
      await engine.silenceAlarm()
    }
    await engine.boundaryReached()
    watcher.cancel()

    #expect(
      engine.pendingReflection != nil,
      "The finished block's reflection prompt was swallowed by a Silence tap.")
  }
}
