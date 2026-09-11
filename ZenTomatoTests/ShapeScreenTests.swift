import Foundation
import Testing

@testable import ZenTomato

/// `F8-T3` — what the screen says about a shape, and the two states it has to say honestly.
///
/// **Every fixture here is a budget from `T1`'s shipped tests, run through the shipped calculator.**
/// No `SprintShape` in this file is hand-typed: a hand-built one is a state the app cannot produce,
/// and a fixture that satisfies both the right and the wrong implementation distinguishes nothing.
@Suite("ShapeScreen")
struct ShapeScreenTests {
  /// Today's shipped defaults: 25 / 5 / 15, four pomodoros to a sprint. The same row
  /// `SprintShapeTests` uses, so the two suites cannot come to disagree about the settings.
  static let settings = TimerSettingsSnapshot(
    workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15,
    pomodorosPerSprint: 4, soundEnabled: true, alertSound: .systemDefault, autoStartNextBlock: false)

  /// A model built by THE SAME FUNCTION THE SCREEN CALLS, not by re-deriving what it should say.
  /// Building one here with its own `SprintShaper` call is what let two control-wiring mutations
  /// walk past 626 green tests. The clock is pinned so the finish time is a fact rather than a moving target.
  static func model(
    _ budget: Int, preset: AbsorptionPreset = .balanced, longBreak: Bool = true
  ) -> ShapeScreenModel {
    .forControls(
      budgetMinutes: budget,
      preset: preset,
      endsWithLongBreak: longBreak,
      settings: settings,
      startingAt: Self.nineInTheMorning)
  }

  static let nineInTheMorning = Date(timeIntervalSince1970: 1_757_494_800)

  // MARK: The shape, drawn

  /// The owner's two-hour example, read back off the screen model rather than off the calculator.
  @Test("theTwoHourShapeIsDrawnBlockByBlock")
  func theTwoHourShapeIsDrawnBlockByBlock() throws {
    let model = Self.model(120)

    #expect(model.state == .ok)
    #expect(model.underMinimumLine == nil)
    // Four pomodoros, three short breaks, one long break.
    #expect(model.rows.count == 8)
    #expect(model.rows.filter { $0.kind == .work }.allSatisfy { $0.drawn == "22 min" })
    #expect(model.rows.filter { $0.kind == .work }.allSatisfy { $0.spokenValue == "22 minutes" })
    #expect(model.rows.filter { $0.kind == .work }.allSatisfy { $0.spokenLabel == "Pomodoro" })
    #expect(model.rows.last?.drawn == "17 min")

    let summary = try #require(model.summaryLine)
    #expect(summary.hasPrefix("4 pomodoros, 88 minutes of focus, finishing at "))
  }

  /// Positions, not values, are the identity. Two five-minute short breaks are equal values and
  /// would collide as identities — a `ForEach` over colliding ids draws one row where there are two.
  @Test("everyRowHasItsOwnIdentity")
  func everyRowHasItsOwnIdentity() {
    let ids = Self.model(120).rows.map(\.id)
    #expect(Set(ids).count == ids.count)
  }

  /// The finish is the budget out from the start, to the second, and it is asserted as a `Date` —
  /// never as a formatted string, which would make this a test of the machine's locale.
  @Test("theFinishIsTheBudgetOut")
  func theFinishIsTheBudgetOut() throws {
    let finish = try #require(Self.model(120).finishesAt)
    #expect(finish.timeIntervalSince(Self.nineInTheMorning) == 120 * 60)
    #expect(Self.model(14).finishesAt == nil)
  }

  // MARK: Nothing fits

  /// **Fourteen minutes draws no blocks and says why.**
  ///
  /// This is the assertion `F8-M7` is written against. Rendering `nil` as an empty shape would tell
  /// somebody they have no time at all, which is a different and worse claim than *"that is too
  /// short"* — so the state, the absence of rows and the absence of a summary are all checked, and
  /// so is the sentence.
  @Test("nothingFitsSaysSoAndDrawsNoBlocks")
  func nothingFitsSaysSoAndDrawsNoBlocks() {
    let model = Self.model(14)

    #expect(model.shape == nil)
    #expect(model.state == .nothingFits)
    #expect(model.rows.isEmpty)
    #expect(model.summaryLine == nil)
    #expect(model.finishTime == nil)
    #expect(model.settingsWrite == nil)
    #expect(
      ShapeScreenModel.nothingFitsBody(shortestMinutes: model.shortestShapeMinutes)
        == "The shortest shape these controls can make is 15 minutes.")
  }

  /// **The shortest workable budget is not fifteen; it is fifteen with the long break on and ten
  /// with it off.** A sentence that hardcoded fifteen would tell somebody with twelve minutes and
  /// the toggle off that nothing fits, while the calculator directly beneath it shaped their time.
  @Test("theShortestShapeMovesWithTheLongBreakToggle")
  func theShortestShapeMovesWithTheLongBreakToggle() {
    #expect(ShapeBudgets.smallestBudgetMinutes(settings: Self.settings, endsWithLongBreak: true) == 15)
    #expect(ShapeBudgets.smallestBudgetMinutes(settings: Self.settings, endsWithLongBreak: false) == 10)

    #expect(Self.model(12, longBreak: true).state == .nothingFits)
    #expect(Self.model(12, longBreak: false).state != .nothingFits)
  }

  // MARK: Under the suggested minimum

  /// **The warning appears, and it is arithmetic rather than a verdict.**
  ///
  /// This is the assertion `F8-M8` is written against. Both budgets come from `T1`'s table: 45
  /// holds three pomodoros and 20 holds one, and both still run.
  @Test("underTheSuggestedMinimumIsSaidInNumbers")
  func underTheSuggestedMinimumIsSaidInNumbers() throws {
    let short = Self.model(45)
    #expect(short.state == .underSuggestedMinimum)
    #expect(short.pomCount == 3)
    #expect(
      try #require(short.underMinimumLine)
        == "45 minutes fits 3 pomodoros. A full sprint needs 60 minutes.")

    let shorter = Self.model(20)
    #expect(shorter.state == .underSuggestedMinimum)
    #expect(
      try #require(shorter.underMinimumLine)
        == "20 minutes fits 1 pomodoro. A full sprint needs 60 minutes.")

    // Not a verdict, and not a nudge.
    for banned in ["only", "just", "unfortunately", "try", "!"] {
      #expect(try #require(short.underMinimumLine).contains(banned) == false)
    }
  }

  /// Sixty minutes is the minimum, not under it — so nothing is warned about at all.
  @Test("sixtyMinutesIsTheMinimumAndSaysNothing")
  func sixtyMinutesIsTheMinimumAndSaysNothing() {
    let model = Self.model(60)
    #expect(model.state == .ok)
    #expect(model.underMinimumLine == nil)
    #expect(model.pomCount == 4)
  }

  /// **`SprintShaper.suggestedMinimumMinutes(for:)` always counts a long break, and quoting it with
  /// the toggle off would be a number the shape on screen contradicts.**
  ///
  /// With the toggle off a full four-pomodoro sprint fits in fifty-five minutes while that function
  /// still reports sixty. `ShapeBudgets` is what the screen quotes instead, and this is the test
  /// that says the two genuinely differ rather than agreeing by luck.
  @Test("theQuotedMinimumMovesWithTheLongBreakToggle")
  func theQuotedMinimumMovesWithTheLongBreakToggle() throws {
    #expect(SprintShaper.suggestedMinimumMinutes(for: Self.settings) == 60)
    #expect(ShapeBudgets.fullSprintBudgetMinutes(settings: Self.settings, endsWithLongBreak: true) == 60)
    #expect(ShapeBudgets.fullSprintBudgetMinutes(settings: Self.settings, endsWithLongBreak: false) == 55)

    // And the shape at fifty-five with the toggle off really does hold a full sprint, so the
    // number is the calculator's answer rather than this suite's arithmetic.
    let model = Self.model(55, longBreak: false)
    #expect(model.pomCount == 4)
    #expect(model.state == .ok)
    #expect(
      try #require(Self.model(50, longBreak: false).underMinimumLine)
        == "50 minutes fits 3 pomodoros. A full sprint needs 55 minutes.")
  }

  // MARK: The presets, at a budget where they do something

  /// **Three hours, not one, and the choice of budget is the whole point of the test.**
  ///
  /// At sixty minutes every block is already squeezed to its floor, so all three presets return an
  /// identical shape and an assertion placed there passes no matter what the absorption code does.
  /// The second half of this test is that claim, checked — so that nobody "simplifies" the budget
  /// back to sixty and leaves a green tick over a rule nothing exercises.
  @Test("thePresetsDivergeAtThreeHours")
  func thePresetsDivergeAtThreeHours() {
    #expect(Self.model(180, preset: .balanced).focusMinutes == 120)
    #expect(Self.model(180, preset: .moreFocus).focusMinutes == 150)
    #expect(Self.model(180, preset: .moreRest).focusMinutes == 102)

    // The reason 180 was chosen: at 60 the three are the same shape.
    let atSixty = AbsorptionPreset.allCases.map { Self.model(60, preset: $0).rows.map(\.minutes) }
    #expect(Set(atSixty.map { $0.map(String.init).joined(separator: "-") }).count == 1)
  }

  // MARK: What Save to settings would write

  /// The button's sentence is built from the value that is written, not from the model that
  /// generated it — so the screen cannot promise one set of numbers and write another.
  @Test("saveDescribesExactlyTheNumbersItWouldWrite")
  func saveDescribesExactlyTheNumbersItWouldWrite() throws {
    let model = Self.model(120)
    let write = try #require(model.settingsWrite)

    #expect(write == ShapeScreenModel.SettingsWrite(
      workMinutes: 22, shortBreakMinutes: 5, longBreakMinutes: 17))

    let detail = try #require(model.saveDetail)
    #expect(detail.contains("focus blocks to 22 min"))
    #expect(detail.contains("short breaks to 5 min"))
    #expect(detail.contains("the long break to 17 min"))
  }

  /// **A shape's pomodoros are not always all the same length, and the screen says so.**
  ///
  /// Leftover minutes go one at a time to the earliest pomodoros, so 181 minutes comes out as one
  /// of 31 and three of 30 while `AppSettings` holds a single `workMinutes`.
  ///
  /// **RULED 2026-09-10 by the owner: the initial pomodoro's length is what gets written.** Because
  /// the odd minutes go to the earliest blocks, the first pomodoro is always the longest — and it is
  /// the one the person actually sits through first, which makes it the least surprising thing to
  /// save. The draft wrote the shortest; 31 and 30 are one apart, which is exactly the size of
  /// difference a fixture like 120 cannot see, since it divides evenly and the two rules agree.
  @Test("aShapeWhosePomodorosDifferSaysSoBeforeItWrites")
  func aShapeWhosePomodorosDifferSaysSoBeforeItWrites() throws {
    let model = Self.model(181)
    let poms = model.rows.filter { $0.kind == .work }.map(\.minutes)

    #expect(poms == [31, 30, 30, 30])
    #expect(model.pomodorosDiffer)
    #expect(try #require(model.settingsWrite).workMinutes == 31, "the initial pomodoro, not the shortest")
    #expect(try #require(model.saveDetail).contains("aren't all the same length"))

    // And the even case does not carry the caveat.
    #expect(Self.model(120).pomodorosDiffer == false)
    #expect(try #require(Self.model(120).saveDetail).contains("aren't all the same length") == false)
  }

  /// With the trailing long break off there is no long break to copy, and the sentence must not
  /// claim one.
  @Test("withNoLongBreakThereIsNoLongBreakToWrite")
  func withNoLongBreakThereIsNoLongBreakToWrite() throws {
    let write = try #require(Self.model(120, longBreak: false).settingsWrite)
    #expect(write.longBreakMinutes == nil)
    #expect(try #require(Self.model(120, longBreak: false).saveDetail).contains("long break") == false)
  }
}
