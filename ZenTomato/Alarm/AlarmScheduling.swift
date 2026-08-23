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
  func schedule(_ request: BlockAlarmRequest) async throws

  /// Cancels every alarm this app has scheduled.
  ///
  /// Deliberately "everything of ours" rather than "the one with this
  /// identifier". After the app has been closed and reopened there is nothing
  /// left in memory that remembers an identifier, so cancelling by identity
  /// would leave a stale alarm behind with no way to reach it. Cancelling
  /// everything is the only self-healing answer, and this app never has more
  /// than one block running at a time, so nothing is lost by it.
  func cancelOutstanding() throws
}
