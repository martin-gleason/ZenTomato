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

  /// The store under test, over the private suite, reading the real clock.
  var store: ShapeStore { ShapeStore(medium: defaults) }

  /// The same store with the 36-hour grace measured against a fixed instant.
  ///
  /// **A constant rather than a movable clock, deliberately.** Nothing in the store's own behaviour
  /// depends on time passing *during* a call; what the grace needs is a known "now" to subtract a
  /// stored date from. A test that wanted the clock to move would be asserting something this rule
  /// does not have.
  func store(at instant: Date) -> ShapeStore {
    ShapeStore(medium: defaults, now: { instant })
  }

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

/// The settings a shaped block has to visibly differ from, and the shapes fitted to them.
///
/// **Shared by the two suites that read the seam, rather than typed into each.** The whole force of
/// these fixtures is that 120 minutes produces a 22-minute pomodoro against a 25-minute setting, so
/// the right answer and the wrong one differ by three minutes. A second copy of the numbers is a
/// second chance for one of them to drift into agreeing with the settings, at which point the suite
/// that holds it asserts nothing while still reading as though it did.
enum ShapeFixture {
  /// Today's shipped defaults: 25 / 5 / 15, four pomodoros to a sprint.
  static let settings = TimerSettingsSnapshot(
    workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15,
    pomodorosPerSprint: 4, soundEnabled: true, alertSound: .systemDefault, autoStartNextBlock: false)

  static func shape(_ budget: Int, endsWithLongBreak: Bool = true) throws -> SprintShape {
    try #require(
      SprintShaper.shape(
        budgetMinutes: budget, settings: settings, endsWithLongBreak: endsWithLongBreak))
  }
}
