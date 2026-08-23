import Foundation
import Synchronization

@testable import ZenTomato

/// A token store that keeps the token in memory and forgets it when the test
/// ends.
///
/// WHY ALMOST EVERY TEST USES THIS INSTEAD OF THE REAL ONE
/// The real store writes to the iPhone's Keychain, which is shared storage that
/// outlives the app and the test run. A suite that wrote to it would leave
/// rubbish behind on whatever machine it ran on, and would be at the mercy of
/// whatever an earlier run had left there — two ways for a test to pass or fail
/// for a reason that has nothing to do with the code.
///
/// Exactly one test in this bundle exercises the real Keychain store, because
/// exactly one property can only be proved there: that the stored item is locked
/// to the device and not copied to iCloud.
///
/// **The value it is given in tests is the literal `"not-a-real-token"`.** Never
/// forty characters of hexadecimal: that is what a real Todoist token looks
/// like, and it is also exactly what the secret scanner that runs before every
/// commit is built to catch.
final class InMemoryTokenStore: TokenStore {
  private let token: Mutex<String?>

  init(token: String? = "not-a-real-token") {
    self.token = Mutex(token)
  }

  func read() throws -> String? {
    token.withLock { $0 }
  }

  func write(_ token: String) throws {
    // The same trimming rule the real store applies, so a test cannot pass here
    // and fail on the phone.
    let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw KeychainTokenStore.Failure.emptyToken }
    self.token.withLock { $0 = trimmed }
  }

  func clear() throws {
    token.withLock { $0 = nil }
  }

  /// Whether anything is stored. Read by the tests that check a rejected token
  /// is thrown away.
  var holdsAToken: Bool {
    token.withLock { $0 != nil }
  }
}
