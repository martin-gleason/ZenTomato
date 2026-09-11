import Foundation

/// Everything the "fit a sprint" screen draws, as plain values.
///
/// **A pure value, with no observation and no actor** — the same shape as `MusicPickerScreenModel`
/// and `SessionPlanScreenModel`, and for the same reason. Nothing here happens over time: a budget,
/// two controls and a finished `SprintShape?` go in, and finished strings come out. Every state of
/// this screen is therefore a few lines in a test with no database, no screen and no clock.
///
/// **IT NEVER CALLS `SprintShaper` ITSELF, AND THAT IS THE LOAD-BEARING PART.** The shape is handed
/// in, so `nil` — *nothing fits* — is a value a test can pass rather than a path it has to reach by
/// choosing the right budget. The two cases this screen exists to handle honestly are then both
/// one line to set up:
///
/// | What the caller hands in | What the screen says |
/// |---|---|
/// | a shape with `isUnderSuggestedMinimum` | the shape, and the line saying it is short of a sprint |
/// | `nil` | *"No shape this short"*, and never an empty shape |
///
/// **Rendering `nil` as an empty shape is the mistake this type is built to make impossible.** An
/// empty list of blocks tells somebody they have no time at all, which is a different and worse
/// claim than *"that is too short"*. `state` has three cases and no catch-all, so a fourth cannot
/// be added without every reader of it failing to compile.
struct ShapeScreenModel: Equatable, Sendable {
  // MARK: Nested types

  /// Which of the three things the screen is saying. **Exactly three, and no default.**
  enum State: Equatable, Sendable {
    /// A full sprint fits. The blocks are drawn and nothing is warned about.
    case ok

    /// A shape exists but holds fewer pomodoros than a sprint. **It still runs.**
    case underSuggestedMinimum

    /// The calculator returned nothing. The screen says so in words and draws no blocks.
    case nothingFits
  }

  /// One block of the shape, drawn short and spoken in full.
  ///
  /// The split is `SettingsView`'s and `TimerScreen`'s: the eye wants `22 min` and the ear wants
  /// "22 minutes". Nothing on this screen ticks, so there is no coarsening to do — but a bare
  /// column of numerals still reads badly aloud, so each row carries both strings as a pair.
  struct Row: Identifiable, Equatable, Sendable {
    /// The block's position in the shape. Positions are unique and stable; block *values* are not
    /// — two short breaks of five minutes are equal, and would collide as identities.
    let id: Int
    let kind: BlockKind
    let minutes: Int

    /// What the eye reads.
    var drawn: String { "\(minutes) min" }

    /// What VoiceOver reads first: which kind of block this is.
    ///
    /// "Pomodoro", never `BlockKind.displayName`'s "Focus". `F9-T1` fixes this feature's on-screen
    /// word as *pomodoro*, and a screen that counted "4 pomodoros" in its summary and then listed
    /// four "Focus" rows underneath would be spelling one thing two ways.
    var spokenLabel: String { ShapeScreenModel.name(for: kind) }

    /// What VoiceOver reads as the value.
    var spokenValue: String { StatsWords.count(minutes, "minute", "minutes") }
  }

  /// What **Save to settings** would write. `nil` fields are values this shape cannot supply.
  ///
  /// **A value rather than a call, so that what is written can be asserted on as the artefact.** The
  /// sentence drawn under the button is built from this same value, so the screen cannot promise one
  /// set of numbers and write another.
  struct SettingsWrite: Equatable, Sendable {
    let workMinutes: Int

    /// `nil` for a one-pomodoro shape, which contains no short break to copy.
    let shortBreakMinutes: Int?

    /// `nil` when the trailing long break is switched off.
    let longBreakMinutes: Int?
  }

  // MARK: What the caller handed in

  /// The stretch of time being cut up, in minutes.
  let budgetMinutes: Int

  /// Where the leftover minutes go.
  let preset: AbsorptionPreset

  /// Whether the shape ends with the long break a finished sprint earns.
  let endsWithLongBreak: Bool

  /// The calculator's answer. **`nil` is a real answer**, and `state` says so out loud.
  let shape: SprintShape?

  /// The smallest budget that would hold a full sprint under these controls, from `ShapeBudgets`.
  ///
  /// Handed in rather than computed, because it is a fact about the *calculator* and this type does
  /// not talk to the calculator. `nil` only when no budget at all would.
  let fullSprintMinutes: Int?

  /// The smallest budget that would produce any shape at all under these controls.
  let shortestShapeMinutes: Int?

  /// When the shape would begin. The finish time is this plus the budget.
  let startingAt: Date

  // MARK: Lifecycle

  init(
    budgetMinutes: Int,
    preset: AbsorptionPreset = .balanced,
    endsWithLongBreak: Bool = true,
    shape: SprintShape?,
    fullSprintMinutes: Int? = nil,
    shortestShapeMinutes: Int? = nil,
    startingAt: Date = Date()
  ) {
    self.budgetMinutes = budgetMinutes
    self.preset = preset
    self.endsWithLongBreak = endsWithLongBreak
    self.shape = shape
    self.fullSprintMinutes = fullSprintMinutes
    self.shortestShapeMinutes = shortestShapeMinutes
    self.startingAt = startingAt
  }

  // MARK: Which of the three things this is

  var state: State {
    guard let shape else { return .nothingFits }
    return shape.isUnderSuggestedMinimum ? .underSuggestedMinimum : .ok
  }

  // MARK: The blocks

  /// The blocks, in the order they run. **Empty when nothing fits, and `state` is what says so.**
  var rows: [Row] {
    guard let shape else { return [] }
    return shape.blocks.enumerated().map { Row(id: $0.offset, kind: $0.element.kind, minutes: $0.element.minutes) }
  }

  /// How many pomodoros the shape holds, or `nil` when there is no shape.
  var pomCount: Int? { shape?.pomCount }

  /// Minutes of actual work. **Not** the budget — the difference is the rest.
  var focusMinutes: Int? { shape?.focusMinutes }

  // MARK: The finish

  /// The instant the shape would end.
  ///
  /// **A `Date`, not a string, so a test can assert on it without a locale.** The string below is a
  /// rendering of this, and rendering is where the reader's own clock setting has to win.
  var finishesAt: Date? {
    guard let shape else { return nil }
    return startingAt.addingTimeInterval(TimeInterval(shape.budgetMinutes) * 60)
  }

  /// The finish time, on the reader's own clock.
  ///
  /// **Never a hardcoded `HH:mm`.** `StatsWords.time` forces twenty-four hours, and it is right to:
  /// the export is a golden file and has to be byte-identical. A screen is not, and borrowing that
  /// formatter here would show `14:32` to somebody whose phone is set to twelve hours.
  var finishTime: String? {
    finishesAt?.formatted(date: .omitted, time: .shortened)
  }

  // MARK: The two honest states

  /// The line drawn when the budget holds fewer pomodoros than a sprint, or `nil` when it does not.
  ///
  /// **The number it quotes moves with the toggle**, because the shape underneath it does. See
  /// `ShapeBudgets` for why `SprintShaper.suggestedMinimumMinutes(for:)` cannot be quoted directly.
  var underMinimumLine: String? {
    guard state == .underSuggestedMinimum, let shape, let fullSprintMinutes else { return nil }
    return Self.underMinimum(
      budgetMinutes: budgetMinutes, fits: shape.pomCount, fullSprintNeeds: fullSprintMinutes)
  }

  // MARK: What Save to settings would write

  /// The block lengths this shape would put into `AppSettings`, or `nil` when there is no shape.
  ///
  /// **The pomodoros in a shape are not always all the same length.** Leftover minutes go one at a
  /// time to the earliest pomodoros, so a shape can hold blocks of 22 and 23 minutes while
  /// `AppSettings` holds a single `workMinutes`, and a shape's pomodoros need not all be the same
  /// length — 181 minutes yields 31 / 30 / 30 / 30.
  ///
  /// **RULED 2026-09-10 by the owner: write the initial pomodoro's length.** The shipped draft wrote
  /// the shortest, which was a placeholder pending this ruling.
  ///
  /// It is the right answer for a reason the shortest does not have: the remainder is handed out by
  /// giving every pomodoro `remainder / poms` and then one further minute each to the *earliest*
  /// ones, so **the first pomodoro is always the longest**, and it is the one the person actually
  /// sits through first. Saving the length you just watched is less surprising than saving a length
  /// that only some of the later blocks had.
  ///
  /// `pomodorosDiffer` stays true so the screen still says what it is about to write before the
  /// press — the value changed, the obligation to be explicit about it did not.
  var settingsWrite: SettingsWrite? {
    guard let shape else { return nil }
    let poms = shape.blocks.filter { $0.kind == .work }.map(\.minutes)
    // `first`, not `min()`. The two agree whenever the shape divides evenly, which is why a fixture
    // like 120 cannot tell them apart — 181 can, and the tests use it.
    guard let initial = poms.first else { return nil }
    return SettingsWrite(
      workMinutes: initial,
      shortBreakMinutes: shape.blocks.first(where: { $0.kind == .shortBreak })?.minutes,
      longBreakMinutes: shape.blocks.first(where: { $0.kind == .longBreak })?.minutes)
  }

  /// Whether the shape's pomodoros are not all the same length.
  var pomodorosDiffer: Bool {
    guard let shape else { return false }
    let poms = shape.blocks.filter { $0.kind == .work }.map(\.minutes)
    guard let first = poms.first else { return false }
    return poms.contains { $0 != first }
  }
}

extension ShapeScreenModel {
  /// **The one place the screen's controls become a shape.**
  ///
  /// **WHY THIS IS NOT INSIDE `ShapeSheet`, AND THE REASON IS A MUTATION THAT ESCAPED.** The sheet
  /// held a private computed property that called `SprintShaper` itself, and the tests built their
  /// own model by calling `SprintShaper` with the same arguments. Cutting `preset` out of the
  /// sheet's call — so the picker moved and the blocks did not — left all 626 tests green, twice,
  /// once for each control. That is this project's named failure mode in its purest form: *an
  /// assertion that re-derives its expected value cannot see the path that produces the real one.*
  ///
  /// The view and the tests now call this. A mutation to the arithmetic is caught here; a mutation
  /// to what the sheet passes in is caught by `theSheetPassesItsControlsStraightThrough`, because
  /// the two halves fail differently and one test cannot see both.
  static func forControls(
    budgetMinutes: Int,
    preset: AbsorptionPreset,
    endsWithLongBreak: Bool,
    settings: TimerSettingsSnapshot,
    startingAt: Date
  ) -> ShapeScreenModel {
    ShapeScreenModel(
      budgetMinutes: budgetMinutes,
      preset: preset,
      endsWithLongBreak: endsWithLongBreak,
      shape: SprintShaper.shape(
        budgetMinutes: budgetMinutes, settings: settings,
        preset: preset, endsWithLongBreak: endsWithLongBreak),
      fullSprintMinutes: ShapeBudgets.fullSprintBudgetMinutes(
        settings: settings, endsWithLongBreak: endsWithLongBreak),
      shortestShapeMinutes: ShapeBudgets.smallestBudgetMinutes(
        settings: settings, endsWithLongBreak: endsWithLongBreak),
      startingAt: startingAt)
  }
}
