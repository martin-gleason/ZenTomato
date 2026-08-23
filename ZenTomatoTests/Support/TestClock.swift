import Foundation
import Synchronization

@testable import ZenTomato

/// A clock whose hands the test moves.
///
/// WHY EVERY TIMER TEST NEEDS ONE
/// A test that waited twenty-five minutes to check a twenty-five minute block
/// would never be run, and a test that waits even one second makes the whole
/// suite slower and eventually flaky. So the engine never asks the system what
/// time it is — it asks whatever clock it was given, and in a test that clock
/// is this. **No test in this project sleeps.**
///
/// THE TWO HANDS MOVE INDEPENDENTLY, AND THAT INDEPENDENCE IS THE POINT.
/// `advance(by:)` moves both, which is what ordinary time passing looks like.
/// `moveWallClock(by:)` moves only the wall clock, which is what a timezone
/// change or a hand-set clock looks like — and being able to produce that
/// separation is the only way the engine's clock-skew guard can be tested at
/// all. A clock with one hand would make that test impossible to write.
///
/// WHY `sleep(until:)` REFUSES TO WAIT
/// The engine arms a task that sleeps until the block is due to end. Here that
/// sleep records the deadline it was asked for — so a test can prove the
/// boundary was armed — and then declines, so the task exits at once. Nothing
/// is left suspended, no continuation is left dangling at the end of a test,
/// and the *effect* of a boundary is tested by calling the engine's
/// `boundaryReached()` directly, which is the same method the task would call.
///
/// The state sits behind a `Mutex` because the protocol requires this type to
/// be safe to use from any thread. Every test in fact uses it from the main
/// one; the lock costs nothing and means the file needs no unchecked promises.
final class TestClock: TimerClock {
  /// Thrown by `sleep(until:)` in place of waiting. Named so that a stack trace
  /// says what happened rather than implying a cancellation.
  struct SleepDeclined: Error {}

  /// A fixed, whole-second starting point. Whole seconds so that every
  /// arithmetic comparison in a test is exact rather than nearly exact.
  static let origin = Date(timeIntervalSinceReferenceDate: 800_000_000)

  private struct Hands {
    var now: Date
    var continuousNow: ContinuousClock.Instant
    var sleepDeadlines: [ContinuousClock.Instant]
  }

  private let hands: Mutex<Hands>

  init(now: Date = TestClock.origin) {
    hands = Mutex(Hands(now: now, continuousNow: ContinuousClock.now, sleepDeadlines: []))
  }

  var now: Date {
    hands.withLock { $0.now }
  }

  var continuousNow: ContinuousClock.Instant {
    hands.withLock { $0.continuousNow }
  }

  /// Every deadline the engine has asked to be woken at, in order. A test can
  /// assert that a boundary was armed without anything having to wait.
  var sleepDeadlines: [ContinuousClock.Instant] {
    hands.withLock { $0.sleepDeadlines }
  }

  func sleep(until deadline: ContinuousClock.Instant) async throws {
    hands.withLock { $0.sleepDeadlines.append(deadline) }
    throw SleepDeclined()
  }

  /// Ordinary time passing: both hands move together.
  func advance(by seconds: TimeInterval) {
    hands.withLock {
      $0.now = $0.now.addingTimeInterval(seconds)
      $0.continuousNow = $0.continuousNow.advanced(by: .seconds(seconds))
    }
  }

  /// Somebody changed the phone's clock: the wall clock jumps and the monotonic
  /// clock does not. This is the only thing that can produce clock skew, and it
  /// is what `clockMovedForward` uses.
  func moveWallClock(by seconds: TimeInterval) {
    hands.withLock { $0.now = $0.now.addingTimeInterval(seconds) }
  }
}
