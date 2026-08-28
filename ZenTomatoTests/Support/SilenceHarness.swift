import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// The shared setup for `D26`'s two suites: a store, a clock, a stand-in
/// scheduler, an engine, and the one sequence that makes an alarm ring.
///
/// **A real extraction, unlike the one this project claimed once and did not
/// make.** `SilenceAlarmTests` crossed the 400-line file limit for real after the
/// third adversarial pass, and the tests that had to move — the drift pair —
/// needed every one of these members. Duplicating them into a second suite is how
/// two harnesses drift apart, so there is one.
///
/// `@MainActor` because the engine is.
@MainActor
final class SilenceHarness {
  let container: ModelContainer
  let clock: TestClock
  let alarms: SpyAlarmScheduler
  let engine: TimerEngine

  init() throws {
    let clock = TestClock()
    let alarms = SpyAlarmScheduler()
    let container = try TestStore.inMemoryContainer()
    self.clock = clock
    self.alarms = alarms
    self.container = container
    engine = TimerEngine(context: container.mainContext, clock: clock, alarms: alarms)
  }

  var context: ModelContext { container.mainContext }

  private let watcherBox = WatcherBox()

  func sessions() throws -> [PomodoroSession] {
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
  func runToTheAlarm() async throws -> UUID {
    await engine.start()
    // The identity the engine handed the alarm system, which is the block's
    // session id. Read from the stand-in rather than from the engine, whose
    // state is private — and this is the same identity a phone would ring with.
    let id = try #require(alarms.outstanding?.id)
    clock.advance(by: 25 * 60)
    startWatching()
    alarms.ring(id)
    await settle()
    try requireRinging()
    return id
  }

  /// Starts the watcher and remembers it, so a test can end it.
  func startWatching() {
    watcher = Task { await engine.watchForAlarms() }
  }

  /// Lets the watcher pick up whatever was just pushed.
  func settle() async {
    for _ in 0..<20 {
      await Task.yield()
      if engine.ringingAlarmID != nil { return }
    }
  }

  /// The watcher really did pick the alarm up.
  ///
  /// **A bounded wait that is never asserted is a test that passes having done
  /// nothing** — `silenceAlarm()` returns at its own first guard when no alarm is
  /// ringing, so every assertion after it would hold vacuously. This suite has
  /// already shipped that mistake once.
  func requireRinging() throws {
    // `#require`, not `#expect`: this must **stop** the test. Written as an
    // `#expect` first, which recorded a failure and then let every downstream
    // assertion run vacuously — the exact shape of the bug it was added to
    // prevent, since `silenceAlarm()` returns at its own first guard when
    // nothing is ringing.
    _ = try #require(engine.ringingAlarmID, "The watcher never saw the alarm; the test would prove nothing.")
  }

  /// Holds the watcher so every test can end it without each one remembering to.
  ///
  /// **`deinit` cancels**, because nine tests leaked a suspended task each — every
  /// one retaining an engine, a stand-in and a `ModelContainer` for the life of
  /// the run. Main-actor confined in practice: the box is created and read only
  /// from the `@MainActor` suite.
  private final class WatcherBox: @unchecked Sendable {
    var task: Task<Void, Never>?
    deinit { task?.cancel() }
  }

  var watcher: Task<Void, Never>? {
    get { watcherBox.task }
    set { watcherBox.task = newValue }
  }
}
