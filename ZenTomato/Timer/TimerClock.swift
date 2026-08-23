import Foundation

/// Everything the timer needs from time itself.
///
/// WHY TIME IS BEHIND A PROTOCOL AT ALL
/// A test that has to wait twenty-five minutes to check a twenty-five minute
/// block is not a test anybody will run. A test that waits even one second is
/// a test that makes the whole suite slower and occasionally flaky. So the
/// engine never asks the operating system what time it is: it asks whatever
/// clock it was handed. In the app that clock is the real one; in the tests it
/// is one whose hands the test moves by itself, instantly. No test in this
/// project sleeps.
///
/// WHY THERE ARE TWO CLOCKS AND NOT ONE
/// They fail in different ways and the timer needs both:
///
///   * `now` is wall-clock time — the time on the phone's screen. It is what
///     an end-of-block instant has to be recorded in, because it is the only
///     kind of time that survives the app being shut down. It can also jump,
///     backwards or forwards, when a timezone changes or the network corrects
///     the clock.
///   * `continuousNow` counts steadily from the moment the phone booted and
///     cannot be moved by anybody. It cannot be saved anywhere, because it
///     means nothing after a restart — but while the app is running it is the
///     honest answer to "how much time has actually passed".
///
/// Holding both is what lets the engine notice that the wall clock moved
/// underneath a running block. See `TimerEngine.synchronize()`.
protocol TimerClock: Sendable {
  /// Wall-clock time: the time a person would read off the phone.
  var now: Date { get }

  /// Monotonic time since the device booted. Cannot be moved by a timezone
  /// change, by the network, or by the user.
  var continuousNow: ContinuousClock.Instant { get }

  /// Suspends until the deadline, measured on the monotonic clock.
  ///
  /// Injected rather than called directly so that the engine can have a task
  /// that wakes it at the end of a block without any test being able to wait
  /// for one.
  func sleep(until deadline: ContinuousClock.Instant) async throws
}

/// The real clock: the one the app runs on.
///
/// It holds nothing, which is why it is a struct with no properties and why it
/// is safe to use from anywhere.
struct SystemTimerClock: TimerClock {
  var now: Date {
    Date()
  }

  var continuousNow: ContinuousClock.Instant {
    ContinuousClock.now
  }

  func sleep(until deadline: ContinuousClock.Instant) async throws {
    // Zero tolerance: the system is allowed to coalesce timers to save power,
    // and a block that ends "around now" is not what a Pomodoro timer promises.
    // The alarm is the real guarantee; this only wakes the app's own screen.
    try await ContinuousClock().sleep(until: deadline, tolerance: .zero)
  }
}
