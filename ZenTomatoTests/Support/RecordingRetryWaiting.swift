import Foundation
import Synchronization

@testable import ZenTomato

/// Waiting, replaced by a notepad.
///
/// **No test in this project ever pauses.** When Todoist answers "slow down" it
/// says how long to wait, and the app waits that long before its one retry. A
/// test of that behaviour must not actually spend the time: three seconds is
/// enough to make people stop running the suite, and the app's own ceiling is
/// sixty, which would make continuous integration time out rather than fail.
///
/// So this stands in for the waiting. It writes down how long it was asked to
/// wait and returns at once, and the test asserts on the number it was asked
/// for. That is a stronger check than an elapsed-time one as well as a faster
/// one: it says exactly what the app decided, rather than what a loaded machine
/// happened to measure.
final class RecordingRetryWaiting: TodoistRetryWaiting {
  private let waits: Mutex<[Duration]> = Mutex([])

  func wait(for duration: Duration) async throws {
    waits.withLock { $0.append(duration) }
  }

  /// Every wait the app asked for, in order.
  var requestedWaits: [Duration] {
    waits.withLock { $0 }
  }
}
