import Foundation

@testable import ZenTomato

/// A medium that is not `UserDefaults`, and the only thing that makes the medium protocol more than
/// a decoration.
///
/// **WHY THIS EXISTS.** `KeyValueMedium` was added to buy sync-readiness — so that
/// `NSUbiquitousKeyValueStore` can be dropped in for v2.0 without rewriting the store. That is a
/// claim, and a claim about a seam nobody has ever driven through anything but the original
/// implementation is a claim nobody has tested. Every other shape-store test hands the real store a
/// disposable `UserDefaults` suite, which exercises the *concrete* path; this one is the only
/// evidence that the store speaks to the protocol rather than to `UserDefaults` wearing a hat.
///
/// It is deliberately dumb: a dictionary, no versioning, no failure modes. Its whole job is to be a
/// *different* conformer.
final class InMemoryMedium: KeyValueMedium {
  private var storage: [String: Data] = [:]

  /// How many writes have landed. Lets a test assert that a save actually reached the medium rather
  /// than being swallowed by an encode that quietly failed.
  private(set) var writes = 0

  func data(forKey key: String) -> Data? { storage[key] }

  func write(_ data: Data, forKey key: String) {
    storage[key] = data
    writes += 1
  }

  func removeValue(forKey key: String) { storage.removeValue(forKey: key) }
}
