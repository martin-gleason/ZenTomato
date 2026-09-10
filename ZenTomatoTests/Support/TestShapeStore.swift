import Foundation
import Testing

@testable import ZenTomato

/// A shape store nobody else can see, and the raw access two tests need.
///
/// **NO TEST TOUCHES THE REAL DEFAULTS**, which is `TestStore`'s rule one layer down and holds for
/// the same reason: the unit tests are hosted in the app, so the app's own preferences domain is
/// reachable from a test, and a shape left behind by somebody running the app on the same simulator
/// would arrive in an unrelated suite as a block of the wrong length. Every store handed out here
/// lives in a suite named for a fresh identifier and is deleted by `remove()`.
///
/// **`write(raw:)` exists because `F8-M4` cannot be proved with a round trip.** A test that hands
/// the store a value it built with the app's own encoder tests the encoder and distinguishes
/// nothing: the right implementation and the wrong one both read it back. The input has to be bytes
/// no build has ever written, which is what this puts in.
struct TestShapeStore {
  let suiteName: String
  let defaults: UserDefaults

  /// The store under test, over the private suite.
  var store: ShapeStore { ShapeStore(medium: defaults) }

  /// A private, empty defaults suite for one test's exclusive use.
  static func make() throws -> TestShapeStore {
    let suiteName = "ZenTomatoTests-shape-\(UUID().uuidString)"
    let defaults = try #require(
      UserDefaults(suiteName: suiteName),
      "The test suite could not be opened, so this test would have run against the app's own.")
    return TestShapeStore(suiteName: suiteName, defaults: defaults)
  }

  /// Deletes the suite and everything in it. Call it from a `defer`, so a test that fails part-way
  /// through still leaves nothing behind.
  func remove() {
    defaults.removePersistentDomain(forName: suiteName)
  }

  /// Puts bytes under the store's key without going through the app's encoder.
  func write(raw json: String) {
    defaults.set(Data(json.utf8), forKey: ShapeStore.key)
  }

  /// What is actually stored, for a test that needs to see the absence of a value rather than be
  /// told about it.
  var storedBytes: Data? {
    defaults.data(forKey: ShapeStore.key)
  }
}
