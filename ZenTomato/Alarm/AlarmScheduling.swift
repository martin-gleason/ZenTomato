import Foundation

/// Everything this feature needs from an alerting system, and nothing about
/// which one it is.
///
/// THIS PROTOCOL IS A DELIBERATE INSURANCE POLICY.
/// The plan for this feature names one risk as its largest: AlarmKit shipped
/// with iOS 26 and its behaviour around rescheduling and cancelling is the
/// least documented part of the release. The mitigation is this file. Nothing
/// here names an AlarmKit type, the timer engine talks only to this, and every
/// engine test is written against a stand-in. If the framework disappoints,
/// one file is replaced and the engine, the screens and the whole test suite
/// are untouched.
///
/// `@MainActor` puts the whole alarm path on one thread. That is not caution
/// for its own sake: it removes every possible question about whether a cancel
/// and a schedule issued back to back can arrive out of order.
///
/// `AnyObject` means only a class can implement it — the scheduler holds state
/// (what is currently scheduled), and a value type would copy it.
@MainActor
protocol AlarmScheduling: AnyObject {
  /// Whether the app may set alarms right now. Cheap to read; no waiting.
  var authorization: AlarmAuthorization { get }

  /// Asks the user for permission and reports the answer.
  ///
  /// Called at the first tap on Start, never at launch: asking for permission
  /// to sound alarms before the person has ever started a timer is the surest
  /// way to be refused.
  func requestAuthorization() async -> AlarmAuthorization

  /// Cancels anything outstanding, then schedules this one.
  ///
  /// CANCEL-BEFORE-SCHEDULE IS PART OF THE CONTRACT, NOT AN IMPLEMENTATION
  /// DETAIL. An alarm sounding four minutes after the user skipped the block
  /// it belonged to is the most likely user-visible bug in this feature, and
  /// it is stated here so that any future implementation of this protocol
  /// inherits the obligation rather than rediscovering it.
  /// - Parameter sparing: the alarm that must **not** be cancelled to make room
  ///   for this one — the block that just ended, whose alarm is due at this very
  ///   instant.
  ///
  ///   **By identity rather than by state, and the difference is a race.**
  ///   Sparing "whatever is currently `.alerting`" works when a person dismisses
  ///   an alarm before the next block starts, because by then it has certainly
  ///   fired. It fails when the app chains automatically: the finished block's
  ///   alarm is due at the same instant this one is scheduled and may still read
  ///   `.countdown`, so it is cancelled a moment before it would have sounded.
  ///
  ///   That asymmetry is exactly what shipped — focus blocks alarmed because
  ///   somebody dismissed them, breaks never did because nothing waited.
  func schedule(_ request: BlockAlarmRequest, sparing: UUID?) async throws

  /// Cancels every alarm this app has scheduled.
  ///
  /// Deliberately "everything of ours" rather than "the one with this
  /// identifier". After the app has been closed and reopened there is nothing
  /// left in memory that remembers an identifier, so cancelling by identity
  /// would leave a stale alarm behind with no way to reach it. Cancelling
  /// everything is the only self-healing answer, and this app never has more
  /// than one block running at a time, so nothing is lost by it.
  /// Calls off this app's alarms.
  ///
  /// - Parameter sparingAlerting: when `true`, an alarm that is **currently
  ///   ringing** is left alone. Scheduling passes `true`: clearing the way for
  ///   the next block must never silence the alarm for the one that just ended,
  ///   which with auto-start on happen at the same instant. An explicit stop or
  ///   dismiss passes `false`, because being asked for silence is when silence
  ///   is wanted.
  func cancelOutstanding(sparingAlerting: Bool) throws

  // MARK: An alarm that is ringing right now

  /// The alarm of this app's that is **currently making a noise**, if any.
  ///
  /// **`D26` EXISTS BECAUSE NOTHING USED TO ASK THIS QUESTION.** The owner tried
  /// to stop a ringing alarm from inside the app and could not — *"This wasn't a
  /// stop the timer bug. stop the alarm bug."* No view observed `alerting`, and
  /// `cancelOutstanding` was reachable only from a *confirmed* Stop, so the one
  /// control that ended the noise belonged to iOS. If that alert was missed, the
  /// sound had no off switch anywhere in ZenPom.
  ///
  /// Cheap to read, like `authorization`. It is a snapshot; `alertingUpdates()`
  /// is how a screen stays current.
  var alertingAlarmID: UUID? { get }

  /// A stream of that same answer, one value per change.
  ///
  /// **A stream rather than a poll**, because the moment being drawn is the
  /// instant an alarm starts, and a timer that samples it is a timer that draws
  /// the button late — at the one moment somebody is reaching for it.
  ///
  /// The first value is the current state, so a screen that starts listening
  /// after an alarm has already begun still sees it.
  func alertingUpdates() -> AsyncStream<UUID?>

  /// Ends a ringing alarm.
  ///
  /// **Distinct from `cancelOutstanding`, and the SDK draws the same
  /// distinction**: `AlarmManager` has `cancel(id:)` for an alarm still counting
  /// down and `stop(id:)` for one that is alerting. Silencing is not cancelling,
  /// and conflating them is how this protocol would grow a method that sometimes
  /// works.
  func stopAlerting(id: UUID) throws
}
