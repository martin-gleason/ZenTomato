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

  func schedule(_ request: BlockAlarmRequest) async throws {
    calls.append(.schedule(request))
    if let scheduleError {
      throw scheduleError
    }
    outstanding = request
  }

  func cancelOutstanding() throws {
    calls.append(.cancelOutstanding)
    if let cancelError {
      throw cancelError
    }
    outstanding = nil
  }
}
