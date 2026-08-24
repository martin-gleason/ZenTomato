import Foundation

@testable import ZenTomato

/// A fortnight, built by hand: no store, no clock, no calendar, no time zone.
///
/// WHY IT IS BUILT THIS WAY
/// This is the input to the golden-file test, and a golden file is only worth
/// having if it is byte-identical on every machine. A fixture assembled from
/// `Date`s would carry the machine's time zone into the document through the
/// back door; this one carries whole numbers that were decided here, in this
/// file, once.
///
/// IT IS ALSO ONE HALF OF THE SEAM BETWEEN THE TWO ENGINEERS
/// `theFixtureStoreProducesTheFixturePeriod` builds the *same* fortnight as real
/// rows in a real store, runs `StatsQuery` over it, and asserts the answer equals
/// `fortnight` below. That is what makes the golden file evidence about the app
/// rather than evidence about a string function: it ties the page a person reads
/// to rows a timer actually wrote. So every number here is internally consistent
/// — the day totals, the project totals and the tap counts all agree — because a
/// store cannot produce a fortnight that does not add up.
///
/// WHAT IT DELIBERATELY CONTAINS
/// Every case the format could get wrong, in one page:
///
/// | Case | Where |
/// |---|---|
/// | A block spanning midnight | Thu 20 Aug: begun at 23:50, its tap at `00:05`, both filed on the day it started |
/// | An abandoned block with a reason | Wed 12 Aug, and Tue 18 Aug |
/// | An abandoned block without one | Thu 13 Aug — renders `*(no reason recorded)*` |
/// | A break that was stopped | Thu 13 Aug — named by its kind, `short break` |
/// | A tap with a note, and one without | Sat 8 Aug — the second renders `*(no note)*` |
/// | Taps inside a block that was later stopped | Tue 18 Aug: nought pomodoros, one tap, one stop |
/// | A task-attached block | `Ch.3 draft` |
/// | A project-only block | the untitled task row under `Thesis` |
/// | A block attached to neither | `Marta's feedback` under `No project` |
/// | A recurring completion on several days, twice on one | `Pick 1–3 MITs` |
/// | Two one-off completions | Mon 10 Aug and Thu 20 Aug |
/// | A title with a middle dot | `Reading · notes` |
/// | A title with an apostrophe | `Marta's feedback` |
///
/// **No identifier of any kind appears anywhere in it.** Not a Todoist id, not a
/// `UUID`, not a session id — none of the value types can hold one, which is the
/// structural half of what `noIdentifiersInOutput` asserts.
enum StatsPeriodFixture {
  // MARK: The days

  static let saturday8 = StatsDay(year: 2026, month: 8, day: 8, weekday: 7)
  static let monday10 = StatsDay(year: 2026, month: 8, day: 10, weekday: 2)
  static let wednesday12 = StatsDay(year: 2026, month: 8, day: 12, weekday: 4)
  static let thursday13 = StatsDay(year: 2026, month: 8, day: 13, weekday: 5)
  static let tuesday18 = StatsDay(year: 2026, month: 8, day: 18, weekday: 3)
  static let thursday20 = StatsDay(year: 2026, month: 8, day: 20, weekday: 5)
  static let friday21 = StatsDay(year: 2026, month: 8, day: 21, weekday: 6)

  static let range = StatsRange(first: saturday8, last: friday21)

  // MARK: The names

  static let thesis = "Thesis"
  static let chapterDraft = "Ch.3 draft"
  /// A middle dot inside a person's own title. It must survive to the page
  /// unescaped, and it must not be mistaken for the app's own separator.
  static let readingNotes = "Reading · notes"
  /// An apostrophe inside a person's own title.
  static let martasFeedback = "Marta's feedback"
  static let habit = "Pick 1–3 MITs"

  // MARK: The whole fortnight

  static let fortnight = StatsPeriod(
    range: range,
    days: days,
    projects: projects,
    completions: completions,
    stops: stops)

  /// The same range with nothing in it, for the short document.
  static let emptyFortnight = StatsPeriod.empty(for: range)

  // MARK: The parts

  static let days = [
    StatsDayRow(
      day: saturday8,
      pomodoroCount: 2,
      focusedSeconds: 3000,
      distractions: [
        tap(
          saturday8,
          StatsClockTime(hour: 9, minute: 20),
          .internalInterruption,
          "kept re-reading the same paragraph",
          chapterDraft),
        // No sentence was written for this one. The tap is still data.
        tap(
          saturday8,
          StatsClockTime(hour: 10, minute: 14),
          .externalInterruption,
          nil,
          chapterDraft)
      ]),
    StatsDayRow(
      day: monday10,
      pomodoroCount: 3,
      focusedSeconds: 4500,
      distractions: [
        tap(
          monday10,
          StatsClockTime(hour: 11, minute: 2),
          .internalInterruption,
          "went to look up a reference and ended up in email",
          readingNotes)
      ]),
    // A finished block under a project with no task chosen, and a stop.
    StatsDayRow(day: wednesday12, pomodoroCount: 1, focusedSeconds: 1500, distractions: []),
    StatsDayRow(
      day: thursday13,
      pomodoroCount: 2,
      focusedSeconds: 3000,
      distractions: [
        tap(
          thursday13,
          StatsClockTime(hour: 15, minute: 41),
          .externalInterruption,
          "flatmate wanted the kitchen",
          martasFeedback, project: nil)
      ]),
    // NOUGHT POMODOROS, ONE TAP, ONE STOP. The day still appears, and the tap
    // still counts: a tap is a finished fact wherever it was tapped, including
    // in a block that was later stopped.
    StatsDayRow(
      day: tuesday18,
      pomodoroCount: 0,
      focusedSeconds: 0,
      distractions: [
        tap(
          tuesday18,
          StatsClockTime(hour: 14, minute: 33),
          .externalInterruption,
          "someone knocked",
          chapterDraft)
      ]),
    // THE MIDNIGHT BLOCK. It began at 23:50 on Thursday and ended at 00:15 on
    // Friday, and it belongs entirely to Thursday — the local calendar day of
    // the block's *start*. Its tap therefore reads `Thu 20 Aug, 00:05`, which
    // looks wrong for a moment and is exactly right: the tap happened inside
    // Thursday's block.
    StatsDayRow(
      day: thursday20,
      pomodoroCount: 1,
      focusedSeconds: 1500,
      distractions: [
        tap(
          thursday20,
          StatsClockTime(hour: 0, minute: 5),
          .internalInterruption,
          "worrying about the deadline instead of writing",
          chapterDraft)
      ])
  ]

  static let projects = [
    StatsProjectRow(
      title: thesis,
      tasks: [
        StatsTaskRow(
          title: chapterDraft,
          projectTitle: thesis,
          pomodoroCount: 3,
          focusedSeconds: 4500,
          internalCount: 2,
          externalCount: 2),
        StatsTaskRow(
          title: readingNotes,
          projectTitle: thesis,
          pomodoroCount: 3,
          focusedSeconds: 4500,
          internalCount: 1,
          externalCount: 0),
        // A block worked under the project with no task chosen. It gets a row of
        // its own rather than vanishing into the heading, so the lines under a
        // heading always add up to the heading.
        StatsTaskRow(
          title: nil,
          projectTitle: thesis,
          pomodoroCount: 1,
          focusedSeconds: 1500,
          internalCount: 0,
          externalCount: 0)
      ]),
    StatsProjectRow(
      title: nil,
      tasks: [
        StatsTaskRow(
          title: martasFeedback,
          projectTitle: nil,
          pomodoroCount: 2,
          focusedSeconds: 3000,
          internalCount: 0,
          externalCount: 1)
      ])
  ]

  static let completions = [
    StatsCompletion(day: saturday8, title: habit, wasRecurring: true),
    // Twice on one day. Both are real completions; the fortnight still counts
    // Monday once when it lists the weekdays this habit was kept on.
    StatsCompletion(day: monday10, title: habit, wasRecurring: true),
    StatsCompletion(day: monday10, title: habit, wasRecurring: true),
    StatsCompletion(day: monday10, title: "Reading list for week 3", wasRecurring: false),
    StatsCompletion(day: wednesday12, title: habit, wasRecurring: true),
    StatsCompletion(day: thursday20, title: habit, wasRecurring: true),
    StatsCompletion(day: thursday20, title: "Send Marta the outline", wasRecurring: false)
  ]

  static let stops = [
    StatsStop(
      day: wednesday12,
      time: StatsClockTime(hour: 16, minute: 20),
      kind: .work,
      taskTitle: chapterDraft,
      projectTitle: thesis,
      reason: "supervisor called and it ran long"),
    // A stop taken during a break. It cost a written sentence too — except this
    // one has none, because it was taken through the alarm's own Stop button.
    StatsStop(
      day: thursday13,
      time: StatsClockTime(hour: 11, minute: 2),
      kind: .shortBreak,
      taskTitle: nil,
      projectTitle: nil,
      reason: nil),
    StatsStop(
      day: tuesday18,
      time: StatsClockTime(hour: 14, minute: 40),
      kind: .work,
      taskTitle: chapterDraft,
      projectTitle: thesis,
      reason: "couldn't settle at all")
  ]

  // MARK: Private

  /// One tap, written the way it reads on the page: a day, a time, a kind, the
  /// sentence, and what was being worked on.
  ///
  /// The time arrives as a `StatsClockTime` rather than as an hour and a minute
  /// so that the helper stays at five arguments — a function nobody can read the
  /// call site of is its own small defect, and a lint rule saying so is right.
  private static func tap(
    _ day: StatsDay,
    _ time: StatsClockTime,
    _ kind: DistractionKind,
    _ note: String?,
    _ task: String?,
    project: String? = thesis) -> StatsDistractionEntry {
    StatsDistractionEntry(
      day: day,
      time: time,
      kind: kind,
      note: note,
      taskTitle: task,
      projectTitle: project)
  }
}
