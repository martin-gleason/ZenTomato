import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// `F8-T3`'s two fences: **Ruling B — a control writes nothing** — and the way in being closed
/// while a block runs.
///
/// **The write half is behavioural, not a grep, and that is deliberate.** There is no UI test
/// target here, so a rule expressed only inside a `View` body is a rule nothing checks; the whole
/// non-drawing surface of the screen is `ShapeSheetActions`, and a test can move a control through
/// it and then read `AppSettings` back to see whether it moved too. The source checks underneath
/// are the second line, not the first.
@MainActor
@Suite("ShapeScreenFence")
struct ShapeScreenFenceTests {
  /// **Moving a control remembers it and writes nothing else.**
  ///
  /// This is the assertion `F8-M9` is written against: the mutation adds a settings write to the
  /// path a control takes, which is the edit a well-meaning person actually makes — *"they picked
  /// a shape, they obviously want these lengths"*.
  @Test("movingAControlWritesNothingToSettings")
  func movingAControlWritesNothingToSettings() throws {
    let container = try TestStore.inMemoryContainer()
    let settings = try AppSettings.current(in: container.mainContext)
    let shapes = try TestShapeStore.make()
    defer { shapes.remove() }

    // **VALUES NOTHING WOULD PLAUSIBLY WRITE, AND THAT IS THE POINT.**
    // This test first ran with the row left at its defaults — 25 / 5 / 15 — and `F8-M9` passed
    // straight through it, because the mutation's obvious form is `settings?.workMinutes = 25` and
    // a fixture that satisfies both the right and the wrong implementation distinguishes nothing.
    // Numbers no default and no shape produces mean any write at all is a change.
    settings.workMinutes = 37
    settings.shortBreakMinutes = 9
    settings.longBreakMinutes = 41

    let before = [settings.workMinutes, settings.shortBreakMinutes, settings.longBreakMinutes]
    let actions = ShapeSheetActions(store: shapes.store, settings: settings)

    actions.remember(preset: .moreRest, endsWithLongBreak: false)

    // The controls were remembered…
    #expect(shapes.store.load()?.preset == .moreRest)
    #expect(shapes.store.load()?.endsWithLongBreak == false)
    // …and the settings row was not touched.
    #expect([settings.workMinutes, settings.shortBreakMinutes, settings.longBreakMinutes] == before)
  }

  /// Remembering a control does not forget the sprint that is running.
  ///
  /// The controls sit beside the run rather than inside it, so a save here has to carry the run
  /// across explicitly. A shape store that lost its run when a preset moved would be a sprint that
  /// silently fell back to `AppSettings` mid-block.
  @Test("rememberingAControlKeepsTheRunningShape")
  func rememberingAControlKeepsTheRunningShape() throws {
    let shapes = try TestShapeStore.make()
    defer { shapes.remove() }

    let shape = try #require(
      SprintShaper.shape(budgetMinutes: 120, settings: ShapeScreenTests.settings))
    shapes.store.start(shape)

    ShapeSheetActions(store: shapes.store, settings: nil)
      .remember(preset: .moreFocus, endsWithLongBreak: false)

    #expect(shapes.store.load()?.preset == .moreFocus)
    #expect(shapes.store.runningShape()?.blocks.count == shape.blocks.count)
  }

  /// **The deliberate press is the one thing that writes**, and it writes exactly the numbers the
  /// screen drew.
  @Test("theDeliberatePressWritesTheNumbersOnScreen")
  func theDeliberatePressWritesTheNumbersOnScreen() throws {
    let container = try TestStore.inMemoryContainer()
    let settings = try AppSettings.current(in: container.mainContext)
    let shapes = try TestShapeStore.make()
    defer { shapes.remove() }

    let model = ShapeScreenTests.model(120)
    let write = try #require(model.settingsWrite)
    let actions = ShapeSheetActions(store: shapes.store, settings: settings)

    #expect(actions.saveToSettings(write))
    #expect(settings.workMinutes == 22)
    #expect(settings.shortBreakMinutes == 5)
    #expect(settings.longBreakMinutes == 17)
    // The store is untouched by a settings write: they are two different presses.
    #expect(shapes.storedBytes == nil)
  }

  /// With no settings row there is nothing to write to, and the screen is told so rather than
  /// drawing a confirmation for a write that did not happen.
  @Test("aSaveWithNoSettingsRowReportsItself")
  func aSaveWithNoSettingsRowReportsItself() throws {
    let shapes = try TestShapeStore.make()
    defer { shapes.remove() }

    let write = ShapeScreenModel.SettingsWrite(
      workMinutes: 22, shortBreakMinutes: 5, longBreakMinutes: 17)
    #expect(ShapeSheetActions(store: shapes.store, settings: nil).saveToSettings(write) == false)
  }

  // MARK: The source half

  /// **Exactly one line in this feature assigns a settings value**, and it is inside the deliberate
  /// press. A second one is what `F8-M9` adds.
  @Test("onlyOnePlaceInThisScreenAssignsASetting")
  func onlyOnePlaceInThisScreenAssignsASetting() throws {
    let assignments = try Self.shapeScreenFiles.reduce(into: 0) { total, file in
      total += try Self.matches("settings\\??\\.(work|shortBreak|longBreak)Minutes = ", in: Self.code(of: file))
    }
    #expect(assignments == 3, "One assignment per block length, all three in saveToSettings.")

    let actions = try Self.code(of: Self.file("ZenTomato/Views/ShapeSheetActions.swift"))
    let press = try #require(actions.range(of: "func saveToSettings"))
    let tail = actions[press.lowerBound...]
    #expect(try Self.matches("settings\\??\\.(work|shortBreak|longBreak)Minutes = ", in: String(tail)) == 3)
  }

  /// **No typed input, and no defaults domain.** The duration is a list of legal values, so the
  /// bounds are the control; and the shape store is handed down rather than reached for.
  @Test("theShapeScreenAcceptsNoTypingAndNamesNoDefaults")
  func theShapeScreenAcceptsNoTypingAndNamesNoDefaults() throws {
    for file in Self.shapeScreenFiles {
      let code = try Self.code(of: file)
      for pattern in ["TextField", "SecureField", "TextEditor", "\\.searchable", "UITextField", "UserDefaults"] {
        #expect(
          try Self.matches(pattern, in: code) == 0,
          "\(file.lastPathComponent) contains \(pattern).")
      }
    }
  }

  /// **The way in is absent while a block runs, and guarded again on the way through.**
  ///
  /// Absence rather than `.disabled`, because the shape store holds one slot: a screen reached
  /// mid-sprint is a screen that can rewrite the blocks of the sprint already going.
  @Test("theWayIntoTheShapeScreenIsClosedWhileABlockRuns")
  func theWayIntoTheShapeScreenIsClosedWhileABlockRuns() throws {
    let screen = try Self.code(of: Self.file("ZenTomato/Views/TimerScreen.swift"))
    #expect(screen.contains("if model.alarmIsRinging == false, case .start = model.controls {"))
    // Absent, never merely switched off.
    let declaration = try #require(screen.range(of: "private var shapeControl"))
    let next = try #require(
      screen.range(of: "private var settingsButton", range: declaration.upperBound..<screen.endIndex))
    #expect(screen[declaration.lowerBound..<next.lowerBound].contains(".disabled(") == false)

    let view = try Self.code(of: Self.file("ZenTomato/Views/TimerView.swift"))
    #expect(view.contains("guard engine.isRunning == false, engine.ringingAlarmID == nil else { return }"))
    // D14: the seventh sheet joins the guard list and calls the offer again on its way out.
    #expect(view.contains("showingShape == false,"))
    #expect(view.contains(".sheet(isPresented: $showingShape, onDismiss: presentReflectionIfPossible)"))
  }

  // MARK: Private

  /// `theSheetPassesItsControlsStraightThrough` — the sheet hands the factory its own controls,
  /// unmodified.
  ///
  /// **THIS EXISTS BECAUSE TWO MUTATIONS WALKED PAST 626 GREEN TESTS.** Replacing `preset: preset`
  /// with `preset: .balanced` in the sheet's call — so the picker moves and the blocks do not —
  /// changed nothing any test could see, and the same was true of the long-break toggle. Both of
  /// the screen's controls could be cut from the calculator in silence.
  ///
  /// The arithmetic half is now covered because the view and the tests call one
  /// `ShapeScreenModel.forControls`. This is the other half, and it has to be a source fence: what
  /// is left in the view is a pass-through, and there is no UI test target to drive it. A rule
  /// expressed only inside a `View` body is a rule nothing checks.
  ///
  /// It asserts the identity mapping by name rather than counting arguments, because a count stays
  /// right while a value goes wrong — which is exactly how these two escaped.
  @Test("theSheetPassesItsControlsStraightThrough")
  func theSheetPassesItsControlsStraightThrough() throws {
    let source = try Self.code(of: Self.file("ZenTomato/Views/ShapeSheet.swift"))
    let call = try #require(
      source.range(of: ".forControls("),
      "ShapeSheet no longer calls the one function that turns controls into a shape.")
    // BOUNDED BY PARENTHESES, NOT BY A CHARACTER COUNT. The first version of this fence took the
    // next 320 characters, and because `code(of:)` strips comment lines that window ran clean past
    // the end of the call and into `remember(preset: preset, endsWithLongBreak: endsWithLongBreak)`
    // below it. The fence then passed while the sheet was drawing `.balanced` — it was reading a
    // different call that happened to contain the strings it was looking for. Verified by mutation
    // both before and after.
    var depth = 1
    var arguments = ""
    for character in source[call.upperBound...] {
      if character == "(" { depth += 1 }
      if character == ")" {
        depth -= 1
        if depth == 0 { break }
      }
      arguments.append(character)
    }

    for identity in ["budgetMinutes: budgetMinutes", "preset: preset", "endsWithLongBreak: endsWithLongBreak"] {
      #expect(
        arguments.contains(identity),
        Comment(rawValue: "ShapeSheet must pass its own \(identity) through unmodified."))
    }
  }

  private static let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()

  private static var shapeScreenFiles: [URL] {
    [
      "ZenTomato/Views/ShapeScreenModel.swift",
      "ZenTomato/Views/ShapeScreenCopy.swift",
      "ZenTomato/Views/ShapeSheet.swift",
      "ZenTomato/Views/ShapeSheetActions.swift",
      "ZenTomato/Views/ShapeSheetPreviews.swift"
    ].map(Self.file)
  }

  private static func file(_ path: String) -> URL {
    repositoryRoot.appending(path: path)
  }

  /// The file with its comments removed, for the reason every other fence in this project gives:
  /// a check that cannot tell a refusal from a violation fires on the sentence stating the rule.
  private static func code(of url: URL) throws -> String {
    try String(contentsOf: url, encoding: .utf8)
      .components(separatedBy: "\n")
      .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") == false }
      .joined(separator: "\n")
  }

  private static func matches(_ pattern: String, in text: String) throws -> Int {
    let expression = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    return expression.numberOfMatches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
  }
}
