import Foundation
import Security
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
///
/// **IT IS CALLED `Fake` BECAUSE THE SECRET SCANNER SAYS SO, AND THAT IS NOT A
/// WORKAROUND.** `scripts/check-secrets.sh` looks for a credential-shaped name
/// beside a long opaque value. This used to be called `InMemoryTokenStore`,
/// which is eighteen opaque characters — so passing one as the `tokens:`
/// argument read to the scanner as a credential being assigned in source, and
/// the whole feature's test files failed the gate. The script publishes a
/// convention for exactly this: *"If you need a fake credential anywhere in this
/// repository, name it that way."* So it is named that way. The alternative was
/// a five-line apology at nine call sites explaining why a check the whole
/// project relies on is wrong about them, which is how a check ends up switched
/// off.
final class FakeTokenStore: TokenStore {
  private let token: Mutex<String?>

  /// Whether `clear()` refuses.
  ///
  /// A Keychain that will not delete is a real state — and it is the one that
  /// decides whether signing out leaves a credential on the phone. It cannot be
  /// provoked from a test any other way.
  private let refusesToClear: Bool

  init(token: String? = "not-a-real-token", refusesToClear: Bool = false) {
    self.token = Mutex(token)
    self.refusesToClear = refusesToClear
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
    if refusesToClear { throw KeychainTokenStore.Failure.unexpectedStatus(errSecInteractionNotAllowed) }
    token.withLock { $0 = nil }
  }

  /// Whether anything is stored. Read by the tests that check a rejected token
  /// is thrown away.
  var holdsAToken: Bool {
    token.withLock { $0 != nil }
  }
}
