import Foundation

/// Waiting, as something that can be replaced in a test.
///
/// WHY WAITING NEEDS A SEAM AT ALL
/// When Todoist answers "slow down", it says how long to wait, and the app
/// waits that long before its single retry. A test of that behaviour must not
/// actually wait: a suite with even a three-second pause in it is a suite people
/// stop running, and one that pauses for the sixty-second ceiling is a suite
/// that fails continuous integration by timing out. So the waiting is described
/// here as a thing the client is handed, the app hands it a real one, and the
/// test hands it one that writes the duration down and returns at once.
///
/// **The test then asserts on the number that was requested, not on elapsed
/// time.** No test in this project pauses for any reason.
protocol TodoistRetryWaiting: Sendable {
  /// Waits for the given length of time.
  ///
  /// - Parameter duration: how long Todoist asked us to wait.
  /// - Throws: if the surrounding work is cancelled while waiting — which is a
  ///   normal outcome, not a failure: it means the screen went away.
  func wait(for duration: Duration) async throws
}

/// The real one. Waits on the system clock.
struct SystemRetryWaiting: TodoistRetryWaiting {
  func wait(for duration: Duration) async throws {
    try await Task.sleep(for: duration)
  }
}
