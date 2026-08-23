import Foundation

@testable import ZenTomato

/// An alarm stand-in that lets a test run code *inside* the engine's one
/// suspension point.
///
/// WHY THIS EXISTS, AND WHY IT IS A SECOND STAND-IN RATHER THAN A FLAG ON THE
/// FIRST
/// The engine promises that a tap is filed against the block that owns the
/// instant it happened, and never against a neighbour. The interesting moment
/// for that promise is the one place the engine pauses in the middle of
/// starting a block: `begin(...)` writes the new block down and saves it, and
/// then waits while an alarm is scheduled for it. A tap arriving in that gap is
/// the hardest case in the feature, and there is no other way to produce it
/// deterministically — a real race would depend on timing and would either pass
/// by luck or fail by luck.
///
/// So this scheduler takes a closure and runs it while `schedule(_:)` is being
/// awaited. The engine is genuinely mid-`begin` when it runs, and the test can
/// tap and then assert which block the resulting row belongs to.
///
/// `SpyAlarmScheduler` is deliberately left alone. It belongs to the timer
/// feature, it is under review, and a new twenty-line file costs less than a
/// merge conflict in somebody else's work.
///
/// `@MainActor` for the same reason everything else in this feature is: the
/// alarm protocol is main-thread only, and so is every database access the
/// closure will make.
@MainActor
final class ReentrantAlarmScheduler: AlarmScheduling {
  /// Run once, from inside the next `schedule(_:)`.
  ///
  /// It clears itself after firing, so a test that installs it before a
  /// boundary gets exactly one re-entrant call even when auto-start chains one
  /// block into the next. A test that wants a second one installs a second one.
  var duringSchedule: (@MainActor () -> Void)?

  /// The same hook, for a test whose re-entrant code has to be awaited.
  ///
  /// `duringSchedule` is enough for a tap, which is synchronous by design. A
  /// *stop* is not: it is spelled `async` even though it never actually
  /// suspends, and a caller cannot pretend otherwise. Wrapping it in a `Task`
  /// would not do — that would run after the suspension rather than inside it,
  /// which is the opposite of what these tests exist to produce.
  var duringScheduleAsync: (@MainActor () async -> Void)?

  /// Every alarm that was asked for, in order. Enough for these tests to say
  /// which block was being started when the closure ran.
  private(set) var scheduledRequests: [BlockAlarmRequest] = []

  /// What the engine is told about permission. Always granted here: these tests
  /// are about the tap, not about the permission dialogue.
  var authorization: AlarmAuthorization = .authorized

  func requestAuthorization() async -> AlarmAuthorization {
    authorization
  }

  func schedule(_ request: BlockAlarmRequest) async throws {
    scheduledRequests.append(request)
    // Taken and cleared before it runs, so a closure that itself causes another
    // block to start cannot call itself again for ever.
    let hook = duringSchedule
    duringSchedule = nil
    hook?()

    let asyncHook = duringScheduleAsync
    duringScheduleAsync = nil
    await asyncHook?()
  }

  func cancelOutstanding() throws {
    // Nothing to cancel: this stand-in never holds an alarm. Cancellation order
    // is `SpyAlarmScheduler`'s subject, not this one's.
  }
}
