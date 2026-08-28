import Foundation

@testable import ZenTomato

/// A stand-in for the alarm system that remembers everything it was asked to do.
///
/// WHY THE ENGINE TESTS USE THIS AND NEVER TOUCH ALARMKIT
/// The alarm protocol exists so that the engine knows nothing about which
/// alerting framework is underneath it. This is the other half of that bargain:
/// the whole engine test suite links no alarm framework at all, so it runs on
/// any machine, cannot be broken by a system permission, and would keep passing
/// unchanged if the real implementation were replaced tomorrow.
///
/// IT RECORDS ORDER, NOT JUST OUTCOMES. Several of this feature's requirements
/// are about sequence rather than result — an alarm must be called off *before*
/// the next one is set, or a stale alarm sounds four minutes after the user
/// skipped the block. `callLog` is what lets a test assert that.
@MainActor
final class SpyAlarmScheduler: AlarmScheduling {
  /// One thing the engine asked for.
  enum Call: Equatable {
    case requestAuthorization
    case schedule(BlockAlarmRequest)
    case cancelOutstanding
  }

  /// A plain error for the failure tests. Its type does not matter to the
  /// engine, which treats any failure the same way.
  struct Failure: Error {}

  /// Every call, in the order it was made.
  private(set) var calls: [Call] = []

  /// The alarm currently set, or `nil` if none is. Cleared by a cancellation.
  private(set) var outstanding: BlockAlarmRequest?

  /// What `authorization` reports. A test sets it before the engine reads it.
  var authorization: AlarmAuthorization = .authorized

  /// What a request for permission will answer.
  var authorizationAnswer: AlarmAuthorization = .authorized

  /// When set, scheduling throws it instead of succeeding.
  var scheduleError: (any Error)?

  /// When set, cancelling throws it instead of succeeding.
  var cancelError: (any Error)?

  /// Whether the task asking for each alarm had already been cancelled, in
  /// order.
  ///
  /// WHY A STAND-IN RECORDS THIS AT ALL. The real implementation calls into
  /// iOS, and a system call made from a cancelled task refuses to run: it would
  /// throw, the engine would record a scheduling failure, and the block would
  /// end in silence. That is invisible from here — this spy cannot fail — so
  /// the *context* the call was made in is recorded instead, and a test asserts
  /// it is always a live one.
  private(set) var cancelledAtSchedule: [Bool] = []

  /// The calls as bare names, for asserting order without restating payloads.
  var callLog: [String] {
    calls.map { call in
      switch call {
      case .requestAuthorization: "requestAuthorization"
      case .schedule: "schedule"
      case .cancelOutstanding: "cancelOutstanding"
      }
    }
  }

  /// Every alarm the engine asked for, in order, including ones that failed.
  var scheduledRequests: [BlockAlarmRequest] {
    calls.compactMap { call in
      if case .schedule(let request) = call { request } else { nil }
    }
  }

  func requestAuthorization() async -> AlarmAuthorization {
    calls.append(.requestAuthorization)
    authorization = authorizationAnswer
    return authorization
  }

  func schedule(_ request: BlockAlarmRequest, sparing: UUID?) async throws {
    calls.append(.schedule(request))
    sparedIDs.append(sparing)
    cancelledAtSchedule.append(Task.isCancelled)
    if let scheduleError {
      throw scheduleError
    }
    outstanding = request
  }

  /// Whether the outstanding alarm is currently making a noise.
  ///
  /// **The spy models this because the real scheduler now depends on it.**
  /// `AlarmKitScheduler` skips an alarm whose `Alarm.State` is `.alerting` when
  /// clearing the way for the next block, and a stand-in that could not be
  /// ringing would make that branch untestable — which is how the blocking
  /// playback read shipped in `C16`.
  var isAlerting = false

  /// What each `schedule` was told to spare, in order.
  ///
  /// Recorded because sparing by identity is the whole fix for breaks never
  /// sounding, and a stand-in that dropped the argument would let it regress
  /// silently.
  private(set) var sparedIDs: [UUID?] = []

  /// Whether a cancel was ever asked to spare a ringing alarm, and what it did.
  private(set) var sparedARingingAlarm = false

  func cancelOutstanding(sparingAlerting: Bool) throws {
    calls.append(.cancelOutstanding)
    if let cancelError {
      throw cancelError
    }
    if sparingAlerting, isAlerting {
      sparedARingingAlarm = true
      return
    }
    outstanding = nil
    isAlerting = false
  }

  // MARK: An alarm that is ringing right now

  /// What `alertingAlarmID` reports. A test sets it to make an alarm ring.
  var alertingAlarmID: UUID?

  /// Every id this stand-in was asked to silence, in order.
  private(set) var silenced: [UUID] = []

  /// When set, `stopAlerting` throws it instead of succeeding.
  var stopAlertingError: (any Error)?

  /// Values pushed into `alertingUpdates()`. Set before the stream is consumed.
  var alertingSequence: [UUID?] = []

  func alertingUpdates() -> AsyncStream<UUID?> {
    let values = alertingSequence.isEmpty ? [alertingAlarmID] : alertingSequence
    return AsyncStream { continuation in
      for value in values { continuation.yield(value) }
      continuation.finish()
    }
  }

  func stopAlerting(id: UUID) throws {
    if let stopAlertingError { throw stopAlertingError }
    silenced.append(id)
    if alertingAlarmID == id { alertingAlarmID = nil }
  }
}
