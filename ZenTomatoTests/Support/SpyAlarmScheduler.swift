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
    // **CANCEL-BEFORE-SCHEDULE, LIKE THE REAL ONE.** `AlarmKitScheduler.schedule`
    // calls `cancelOutstanding` first, so only the new alarm and the spared one
    // survive. This stand-in used to accumulate every alarm a run ever scheduled,
    // which made `hasAlarm` mean *was ever scheduled* — and a stand-in that only
    // grows cannot fail a test about an alarm being called off.
    outstandingAlarmIDs = outstandingAlarmIDs.filter { $0 == sparing }
    outstandingAlarmIDs.insert(request.id)
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
    // **A CANCEL DOES NOT SILENCE AN ALERTING ALARM, AND THIS STAND-IN MUST NOT
    // PRETEND IT DOES.** `AlarmScheduling.stopAlerting`'s own note says
    // `cancel(id:)` is for an alarm counting down and `stop(id:)` for one already
    // alerting, and refuses to claim the first does the second. A stand-in more
    // generous than iOS makes every test that relies on "the cancel released it"
    // pass for a reason the device will not honour.
    //
    // So the outstanding set is emptied — the alarm is called off — and
    // `alertingAlarmIDValue` is left exactly as it was.
    outstandingAlarmIDs.removeAll()
  }

  // MARK: An alarm that is ringing right now

  /// What is ringing, as far as this stand-in is concerned. A test sets it, or
  /// calls `ring(_:)`.
  var alertingAlarmIDValue: UUID?

  /// **Mirrors the real one, including its blind spot.** `AlarmKitScheduler`
  /// spells this `try? currentAlertingAlarmID()`, so a read that fails reads as
  /// *nothing is ringing*. A stand-in that ignored `alertingReadError` here made
  /// `aReadThatFailsKeepsTheButton` unable to fail — it passed against the very
  /// code it was written to catch.
  var alertingAlarmID: UUID? {
    get { alertingReadError == nil ? alertingAlarmIDValue : nil }
    set { alertingAlarmIDValue = newValue }
  }

  /// Every id this stand-in was asked to silence, in order.
  private(set) var silenced: [UUID] = []

  /// When set, `stopAlerting` throws it instead of succeeding.
  var stopAlertingError: (any Error)?

  /// Values pushed into `alertingUpdates()`. Set before the stream is consumed.
  var alertingSequence: [UUID?] = []

  /// A stream that **stays open**, the way the real one does.
  ///
  /// It used to yield once and finish, which made every test that watched it
  /// meaningless the moment `watchForAlarms()` learned to clear its flag when
  /// the stream ends — correct behaviour that a finite stand-in cannot model.
  /// The live sequence ends only when the screen watching it goes away, so this
  /// one ends only when a test says so.
  func alertingUpdates() -> AsyncStream<UUID?> {
    AsyncStream { continuation in
      alertingContinuation = continuation
      continuation.yield(alertingAlarmIDValue)
      for value in alertingSequence { continuation.yield(value) }
    }
  }

  /// Makes an alarm ring, or stop, the way a phone would.
  func ring(_ id: UUID?) {
    alertingAlarmIDValue = id
    alertingContinuation?.yield(id)
  }

  /// Ends the stream, as a screen going away does.
  func endAlerting() {
    alertingContinuation?.finish()
    alertingContinuation = nil
  }

  private var alertingContinuation: AsyncStream<UUID?>.Continuation?

  /// When set, `currentAlertingAlarmID()` throws it — the "could not ask" case
  /// that must not be read as "nothing is ringing".
  var alertingReadError: (any Error)?

  /// When set, `hasAlarm` throws it.
  var hasAlarmError: (any Error)?

  /// Alarms this stand-in believes are outstanding, whether or not they have
  /// begun alerting. Survives a "relaunch" in a test, the way a real one does —
  /// and is **emptied by a cancel and by a stop**, because `hasAlarm` must mean
  /// *is outstanding* rather than *was ever scheduled*. A stand-in that only ever
  /// grows cannot fail a test about an alarm being called off.
  var outstandingAlarmIDs: Set<UUID> = []

  func hasAlarm(id: UUID) throws -> Bool {
    if let hasAlarmError { throw hasAlarmError }
    return outstandingAlarmIDs.contains(id)
  }

  func currentAlertingAlarmID() throws -> UUID? {
    if let alertingReadError { throw alertingReadError }
    return alertingAlarmIDValue
  }

  func stopAlerting(id: UUID) throws {
    if let stopAlertingError { throw stopAlertingError }
    silenced.append(id)
    outstandingAlarmIDs.remove(id)
    if alertingAlarmIDValue == id { alertingAlarmIDValue = nil }
  }
}
