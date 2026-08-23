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
/// WHY `sleep(until:)` HAS TWO BEHAVIOURS
/// The engine arms a task that sleeps until the block is due to end. Every
/// sleep, in both modes, records the deadline it was asked for, so a test can
/// prove a boundary was armed without anything having to wait.
///
///   * `.decline` — the default. The sleep refuses and the task exits at once.
///     Nothing is left suspended and no continuation dangles at the end of a
///     test. The *effect* of a boundary is then exercised by calling the
///     engine's `boundaryReached()` directly, which is what the task would have
///     called.
///
///   * `.wake(limit:)` — the sleep moves both hands to the deadline and
///     returns, so the boundary task's own body genuinely runs. This exists
///     because declining is not free: a task body that never executes is a task
///     body nothing can check, and two real defects lived in exactly that
///     blind spot — a boundary task that cancelled itself before setting the
///     next block's alarm, and an overdue wake-up that auto-started a block
///     nobody was present for. `limit` bounds how many times it will wake, so a
///     chain of auto-started blocks cannot spin forever: past the limit it
///     declines again, exactly as the default mode does.
///
/// The state sits behind a `Mutex` because the protocol requires this type to
/// be safe to use from any thread. Every test in fact uses it from the main
/// one; the lock costs nothing and means the file needs no unchecked promises.
final class TestClock: TimerClock {
  /// Thrown by `sleep(until:)` in place of waiting. Named so that a stack trace
  /// says what happened rather than implying a cancellation.
  struct SleepDeclined: Error {}

  /// What a sleep does when it is asked to wait.
  enum SleepBehaviour {
    /// Record the deadline and refuse. The default.
    case decline

    /// Move both hands to the deadline and return, at most `limit` times.
    case wake(limit: Int)
  }

  /// A fixed, whole-second starting point. Whole seconds so that every
  /// arithmetic comparison in a test is exact rather than nearly exact.
  static let origin = Date(timeIntervalSinceReferenceDate: 800_000_000)

  private struct Hands {
    var now: Date
    var continuousNow: ContinuousClock.Instant
    var sleepDeadlines: [ContinuousClock.Instant]
    var behaviour: SleepBehaviour
    var wakesRemaining: Int
  }

  private let hands: Mutex<Hands>

  init(now: Date = TestClock.origin, sleepBehaviour: SleepBehaviour = .decline) {
    let remaining: Int = switch sleepBehaviour {
    case .decline: 0
    case .wake(let limit): limit
    }
    hands = Mutex(
      Hands(
        now: now,
        continuousNow: ContinuousClock.now,
        sleepDeadlines: [],
        behaviour: sleepBehaviour,
        wakesRemaining: remaining))
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

  /// How many wake-ups are still allowed. A test asserts on this to prove a
  /// chain stopped because the engine stopped it, not because the clock ran out.
  var wakesRemaining: Int {
    hands.withLock { $0.wakesRemaining }
  }

  func sleep(until deadline: ContinuousClock.Instant) async throws {
    let willWake = hands.withLock { hands -> Bool in
      hands.sleepDeadlines.append(deadline)
      guard case .wake = hands.behaviour, hands.wakesRemaining > 0 else { return false }
      hands.wakesRemaining -= 1
      // Both hands move together, by the same amount, exactly as ordinary time
      // passing does. A deadline already behind us moves nothing.
      let seconds = Self.seconds(hands.continuousNow.duration(to: deadline))
      if seconds > 0 {
        hands.now = hands.now.addingTimeInterval(seconds)
        hands.continuousNow = hands.continuousNow.advanced(by: .seconds(seconds))
      }
      return true
    }
    guard willWake else { throw SleepDeclined() }
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

  /// A `Duration` as a plain number of seconds.
  private static func seconds(_ duration: Duration) -> TimeInterval {
    let parts = duration.components
    return TimeInterval(parts.seconds) + TimeInterval(parts.attoseconds) / 1e18
  }
}
