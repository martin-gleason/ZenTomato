import Foundation

@testable import ZenTomato

/// A stand-in for "may this app play music at all", with the answer set by the
/// test.
///
/// **WHY EVERY MUSIC TEST NEEDS ONE.** The three answers that matter most —
/// permission refused, permission restricted by the device, and no Apple Music
/// subscription — cannot be produced on demand anywhere. Refusing a permission
/// on a build machine is impossible, and cancelling a subscription to make a
/// test pass is not a thing anybody is going to do. Behind the protocol, a test
/// simply states the answer and asserts what the app does about it.
///
/// Those are exactly the tests that prove this feature's most important
/// promise: that every music failure leaves a **working silent timer** rather
/// than a broken one. Without this object that promise could only be asserted,
/// and an assertion is not evidence.
///
/// It records how many times permission was asked for, because *when* the
/// prompt appears is itself a requirement: once, at the moment somebody first
/// switches music on, and never at launch.
@MainActor
final class StubMusicAvailability: MusicAvailabilityChecking {
  /// The last answer, and what `refresh()` will report unless told otherwise.
  var current: MusicAvailability

  /// What `requestAuthorization()` will answer.
  var authorizationAnswer: MusicAvailability

  /// What `refresh()` will answer, or `nil` to keep reporting `current`.
  var refreshAnswer: MusicAvailability?

  /// How many times the app has asked the person for permission.
  private(set) var authorizationRequests = 0

  init(current: MusicAvailability = .ready, authorizationAnswer: MusicAvailability = .ready) {
    self.current = current
    self.authorizationAnswer = authorizationAnswer
  }

  func refresh() async -> MusicAvailability {
    if let refreshAnswer {
      current = refreshAnswer
    }
    return current
  }

  func requestAuthorization() async -> MusicAvailability {
    authorizationRequests += 1
    current = authorizationAnswer
    return current
  }

  /// An empty, finished stream.
  ///
  /// The real one carries subscription changes from Apple. A test drives that
  /// path by calling `MusicCoordinator.availabilityChanged(to:)` directly,
  /// which is the identical entry point the stream feeds — so the stream itself
  /// has nothing to add here, and returning a live one would leave a task
  /// suspended at the end of every test for no purpose.
  func changes() -> AsyncStream<MusicAvailability> {
    AsyncStream { continuation in continuation.finish() }
  }
}
