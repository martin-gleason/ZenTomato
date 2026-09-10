import SwiftUI

// Every state the shape screen has, at the default text size and at the largest, in both
// appearances — the two hard states included, because those are the ones nobody looks at until
// somebody is in them.
//
// **AX5 IS ASSERTED BY A READER'S EYE ON THESE, AND BY NOTHING ELSE.** There is no test in this
// project that renders a screen at `accessibility5`; the previews are the deliverable rather than
// decoration, and a preview nobody opens proves nothing. The device read named in `F8`'s checkpoint
// is the evidence.
//
// **Every largest-text preview names its appearance explicitly.** `O35` is an open item filed for
// exactly the omission of `.preferredColorScheme(.light)` from one AX5 preview, and two previews in
// `StatsScreenPreviews.swift` are themselves the loose form — so copying that file verbatim would
// have reproduced the defect. `O35` itself is not fixed here; it is a `P2` item of its own.

#Preview("Two hours, light") {
  ShapePreview.view(budgetMinutes: 120)
    .preferredColorScheme(.light)
}

#Preview("Two hours, dark") {
  ShapePreview.view(budgetMinutes: 120)
    .preferredColorScheme(.dark)
}

#Preview("Two hours, largest text") {
  ShapePreview.view(budgetMinutes: 120)
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}

#Preview("An hour — the minimum, not under it") {
  ShapePreview.view(budgetMinutes: 60)
    .preferredColorScheme(.light)
}

#Preview("Under the minimum, light") {
  ShapePreview.view(budgetMinutes: 45)
    .preferredColorScheme(.light)
}

#Preview("Under the minimum, dark") {
  ShapePreview.view(budgetMinutes: 45)
    .preferredColorScheme(.dark)
}

#Preview("Under the minimum, largest text") {
  ShapePreview.view(budgetMinutes: 45)
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}

#Preview("Twenty minutes — one pomodoro") {
  ShapePreview.view(budgetMinutes: 20)
    .preferredColorScheme(.light)
}

#Preview("Nothing fits, light") {
  ShapePreview.view(budgetMinutes: 5)
    .preferredColorScheme(.light)
}

#Preview("Nothing fits, dark") {
  ShapePreview.view(budgetMinutes: 5)
    .preferredColorScheme(.dark)
}

#Preview("Nothing fits, largest text") {
  ShapePreview.view(budgetMinutes: 5)
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}

#Preview("Three hours, balanced") {
  ShapePreview.view(budgetMinutes: 180, preset: .balanced)
    .preferredColorScheme(.light)
}

#Preview("Three hours, more focus") {
  ShapePreview.view(budgetMinutes: 180, preset: .moreFocus)
    .preferredColorScheme(.light)
}

#Preview("Three hours, more rest") {
  ShapePreview.view(budgetMinutes: 180, preset: .moreRest)
    .preferredColorScheme(.light)
}

#Preview("No long break, largest text") {
  ShapePreview.view(budgetMinutes: 55, endsWithLongBreak: false)
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}

/// Preview scaffolding, never part of what ships.
///
/// **Every fixture is derived by running the calculator, never hand-typed.** A hand-written
/// `SprintShape` is a state the app cannot actually produce, and a preview of an impossible state
/// is worse than no preview: it is reviewed, approved, and describes nothing. This also means the
/// screen's own arithmetic is exercised whenever somebody opens the canvas.
///
/// Nothing here opens a database or a defaults suite. `ShapeView` takes finished values, so a
/// preview needs neither.
private enum ShapePreview {
  /// The settings a first run has, which is what these budgets were verified against.
  static let settings = TimerSettingsSnapshot(
    workMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    pomodorosPerSprint: 4,
    soundEnabled: true,
    alertSound: .systemDefault,
    autoStartNextBlock: false)

  @MainActor
  static func view(
    budgetMinutes: Int,
    preset: AbsorptionPreset = .balanced,
    endsWithLongBreak: Bool = true
  ) -> some View {
    NavigationStack {
      ShapeView(
        model: model(budgetMinutes: budgetMinutes, preset: preset, endsWithLongBreak: endsWithLongBreak),
        budgetChoices: Array(stride(from: 5, through: 240, by: 5)),
        savedNote: nil)
        .navigationTitle(ShapeScreenModel.title)
        .navigationBarTitleDisplayMode(.inline)
    }
  }

  static func model(
    budgetMinutes: Int,
    preset: AbsorptionPreset,
    endsWithLongBreak: Bool
  ) -> ShapeScreenModel {
    ShapeScreenModel(
      budgetMinutes: budgetMinutes,
      preset: preset,
      endsWithLongBreak: endsWithLongBreak,
      shape: SprintShaper.shape(
        budgetMinutes: budgetMinutes,
        settings: settings,
        preset: preset,
        endsWithLongBreak: endsWithLongBreak),
      fullSprintMinutes: ShapeBudgets.fullSprintBudgetMinutes(
        settings: settings, endsWithLongBreak: endsWithLongBreak),
      shortestShapeMinutes: ShapeBudgets.smallestBudgetMinutes(
        settings: settings, endsWithLongBreak: endsWithLongBreak),
      startingAt: Date())
  }
}
