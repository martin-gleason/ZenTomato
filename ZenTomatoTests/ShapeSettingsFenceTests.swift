import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// Ruling B, as a fence: **running a shape never writes the settings.**
///
/// **THIS FENCE IS NEW, NOT AN AMENDMENT, AND THAT IS WORTH SAYING PLAINLY.** `docs/plans/F8.md`
/// describes it as a fence that *"changes shape but does not go away"*; it did not exist. Nothing
/// anywhere in this suite asserted that a code path leaves `AppSettings` unwritten. The nearest
/// neighbours assert something else entirely: `SettingsLockTests` locks the settings *screen* while
/// a block runs, and `PolishFenceTests` pins the column *count*. Neither says a word about who
/// writes the columns that exist. So `F8-M2` proves a fence that has never existed rather than
/// re-proving one that has.
///
/// **The behavioural half is the half with teeth.** A source grep for an assignment can be
/// satisfied by moving the assignment — the correction `noNewStoredShape` already had to make once
/// — so the load-bearing test runs a shaped sprint end to end against a real store and reads all
/// seven columns back. The source half asserts something a grep genuinely can: the shape layer
/// cannot reach the settings row at all, because it does not name it.
@Suite("ShapeSettingsFence")
@MainActor
struct ShapeSettingsFenceTests {
  private let container: ModelContainer

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  private var context: ModelContext { container.mainContext }

  /// Every stored settings column, as one comparable value.
  ///
  /// **Read off the row rather than off a snapshot of it.** A snapshot is what the engine works
  /// with, and a test that compared snapshots would be asking whether the engine changed its mind —
  /// not whether the database changed. The question here is about the database.
  private struct Columns: Equatable {
    let workMinutes: Int
    let shortBreakMinutes: Int
    let longBreakMinutes: Int
    let pomodorosPerSprint: Int
    let soundEnabled: Bool
    let alertSoundRawValue: String?
    let autoStartNextBlock: Bool

    init(_ settings: AppSettings) {
      workMinutes = settings.workMinutes
      shortBreakMinutes = settings.shortBreakMinutes
      longBreakMinutes = settings.longBreakMinutes
      pomodorosPerSprint = settings.pomodorosPerSprint
      soundEnabled = settings.soundEnabled
      alertSoundRawValue = settings.alertSoundRawValue
      autoStartNextBlock = settings.autoStartNextBlock
    }
  }

  private func columns() throws -> Columns {
    Columns(try AppSettings.current(in: context))
  }

  /// **A whole shaped sprint leaves every settings column exactly where it was.**
  ///
  /// The shape is a two-hour one, whose poms are twenty-two minutes against a twenty-five minute
  /// setting and whose long break is seventeen against fifteen — so a path that wrote a resolved
  /// value back would move a number this test can see. A shape whose lengths matched the settings
  /// would pass whatever the code did.
  @Test("aShapedSprintWritesNoSetting")
  func aShapedSprintWritesNoSetting() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    let stored = try AppSettings.current(in: context)
    stored.autoStartNextBlock = true
    try context.save()
    let before = try columns()

    let live = TimerSettingsSnapshot(clamping: try AppSettings.current(in: context))
    let shape = try #require(SprintShaper.shape(budgetMinutes: 120, settings: live))
    harness.store.start(shape)
    let engine = TimerEngine(context: context, clock: clock, alarms: SpyAlarmScheduler(), shapes: harness.store)
    await engine.start()
    for _ in shape.blocks {
      let endsAt = try #require(engine.endsAt)
      clock.advance(by: endsAt.timeIntervalSince(clock.now))
      await engine.boundaryReached()
    }

    #expect(try columns() == before)
    // And the shape really did run, so the assertion above is about a sprint that happened rather
    // than about one that never started.
    #expect(harness.store.runningShape() == nil)
    #expect(try context.fetch(FetchDescriptor<PomodoroSession>()).count == shape.blocks.count)
  }

  /// Starting one shaped block and stopping writes nothing either — the path a person most easily
  /// takes by accident.
  @Test("startingAndStoppingAShapeWritesNoSetting")
  func startingAndStoppingAShapeWritesNoSetting() async throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock()
    let before = try columns()
    let live = TimerSettingsSnapshot(clamping: try AppSettings.current(in: context))
    harness.store.start(try #require(SprintShaper.shape(budgetMinutes: 120, settings: live)))
    let engine = TimerEngine(context: context, clock: clock, alarms: SpyAlarmScheduler(), shapes: harness.store)

    await engine.start()
    await engine.stop(reason: "Something came up.")

    #expect(try columns() == before)
  }

  /// The shape layer does not name the settings row, so it cannot write it.
  ///
  /// A statement about reach rather than about intent: the store, the format and the calculator are
  /// three files that between them decide how time is cut up, and none of them can so much as read
  /// the row that decides what the app's defaults are. Comments are stripped, because `ShapeStore`
  /// carries a paragraph explaining why it is not `AppSettings`.
  @Test("theShapeLayerCannotReachTheSettings")
  func theShapeLayerCannotReachTheSettings() throws {
    #expect(try Self.usesInShapeLayer("AppSettings") == 0)
    #expect(try Self.usesInShapeLayer("ModelContext") == 0)
    #expect(try Self.usesInShapeLayer("import SwiftData") == 0)
  }

  // MARK: Private

  private static let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()

  private static func usesInShapeLayer(_ pattern: String) throws -> Int {
    var total = 0
    let directory = root.appending(path: "ZenTomato").appending(path: "Shape")
    guard let walk = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
    else { return 0 }
    for case let url as URL in walk where url.pathExtension == "swift" {
      guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
      let code = text
        .components(separatedBy: "\n")
        .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") == false }
        .joined(separator: "\n")
      guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
      total += expression.numberOfMatches(
        in: code, range: NSRange(code.startIndex..<code.endIndex, in: code))
    }
    return total
  }
}
