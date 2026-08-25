import SwiftUI

// Previews for `StatsScreen`, in a file of their own because that one reached the 400-line
// limit and a seam beats a raised limit. Every state the screen has, at the default text size
// and at the largest, in both appearances — the empty states included, because those are the
// ones nobody looks at until somebody new opens the app.

#Preview("A fortnight, light") {
  StatsScreen(model: StatsPreview.model())
    .preferredColorScheme(.light)
}

/// With the light preview above: a fixed colour would make these two identical.
#Preview("A fortnight, dark") {
  StatsScreen(model: StatsPreview.model())
    .preferredColorScheme(.dark)
}

#Preview("A fortnight, largest text") {
  StatsScreen(model: StatsPreview.model()).dynamicTypeSize(.accessibility5)
}

/// A first morning, and also four hundred pomodoros with February chosen.
#Preview("Nothing in these days") {
  StatsScreen(model: StatsPreview.model(empty: true)).preferredColorScheme(.light)
}

#Preview("Nothing in these days, dark") {
  StatsScreen(model: StatsPreview.model(empty: true)).preferredColorScheme(.dark)
}

#Preview("Nothing in these days, largest text") {
  StatsScreen(model: StatsPreview.model(empty: true)).dynamicTypeSize(.accessibility5)
}

// MARK: - StatsPreview

/// A fortnight, by hand, for the previews. Never part of what ships, and not the
/// golden-file fixture — that one lives in the test bundle and is far longer.
private enum StatsPreview {
  /// `@MainActor` because `StatsScreenModel` is: it is the same type the app
  /// builds, handed a finished period instead of a database.
  @MainActor
  static func model(empty: Bool = false) -> StatsScreenModel {
    let model = StatsScreenModel(
      periods: { asked in empty ? StatsPeriod.empty(for: asked) : fortnight },
      today: wednesday)
    model.load()
    return model
  }

  // MARK: Private

  private static let wednesday = StatsDay(year: 2026, month: 8, day: 19, weekday: 4)
  private static let thursday = StatsDay(year: 2026, month: 8, day: 20, weekday: 5)

  private static let taps = [
    tap(hour: 14, minute: 32, kind: .internalInterruption, note: "kept re-reading the same paragraph"),
    tap(hour: 14, minute: 41, kind: .externalInterruption, note: "roommate came in"),
    tap(hour: 16, minute: 5, kind: .internalInterruption, note: nil)
  ]

  private static let fortnight = StatsPeriod(
    range: StatsRange(first: StatsDay(year: 2026, month: 8, day: 6, weekday: 5), last: thursday),
    days: [
      StatsDayRow(day: wednesday, pomodoroCount: 6, focusedSeconds: 9000, distractions: taps),
      // A day with nothing behind it: no chevron, and not a button.
      StatsDayRow(day: thursday, pomodoroCount: 4, focusedSeconds: 6000, distractions: [])
    ],
    projects: [
      StatsProjectRow(
        title: "Thesis",
        tasks: [
          StatsTaskRow(
            title: "Ch.3 draft", projectTitle: "Thesis", pomodoroCount: 14,
            focusedSeconds: 21_000, internalCount: 5, externalCount: 3),
          // A block worked under the project with no task chosen: the plain
          // "No task" wording is visible in a preview rather than only in a
          // fortnight nobody has yet.
          StatsTaskRow(
            title: nil, projectTitle: "Thesis", pomodoroCount: 4,
            focusedSeconds: 6000, internalCount: 1, externalCount: 0)
        ]),
      StatsProjectRow(
        title: nil,
        tasks: [
          StatsTaskRow(
            title: "Reading", projectTitle: nil, pomodoroCount: 2,
            focusedSeconds: 3000, internalCount: 1, externalCount: 1)
        ])
    ],
    completions: [StatsCompletion(day: wednesday, title: "Ch.3 draft", wasRecurring: false)],
    stops: [])

  private static func tap(
    hour: Int,
    minute: Int,
    kind: DistractionKind,
    note: String?) -> StatsDistractionEntry {
    StatsDistractionEntry(
      day: wednesday,
      time: StatsClockTime(hour: hour, minute: minute),
      kind: kind,
      note: note,
      taskTitle: "Ch.3 draft",
      projectTitle: "Thesis")
  }
}
