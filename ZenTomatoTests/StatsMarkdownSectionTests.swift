import Foundation
import Testing

@testable import ZenTomato

/// The rules the golden file cannot state.
///
/// The golden defends the *whole page* against any change at all, which is
/// exactly what it is for and also its one weakness: it says nothing about
/// **why** a line is the way it is. These tests name the decisions, one at a
/// time, so that a future change breaks a test whose name says what was decided
/// rather than only a byte comparison.
///
/// Everything here is a pure function of a hand-built value. No store, no clock,
/// no calendar, no network, and nothing that sleeps.
@Suite("StatsMarkdownSections")
struct StatsMarkdownSectionTests {
  // MARK: Notes and reasons

  /// `skippedNoteRendersMarker` — a tap with no sentence renders `*(no note)*`.
  ///
  /// Never a blank. A tap with no sentence **is** data: somebody noticed the
  /// interruption and only declined to describe it. Three concrete reasons a
  /// blank would be wrong, all of them real — a blank line says nothing
  /// happened; the lines in this section are counted against the `## Days`
  /// table's I and E columns, so a line rendering as trailing whitespace would
  /// make two sections of one page disagree; and a Markdown line ending in an em
  /// dash renders as a dangling dash, which reads as a rendering bug.
  @Test("skippedNoteRendersMarker")
  func skippedNoteRendersMarker() {
    let document = StatsMarkdown.document(for: StatsPeriodFixture.fortnight, producedBy: .forGoldens)

    #expect(document.contains("- Sat 8 Aug, 10:14 — **E** — *(no note)*"))
    // And the line it belongs to still ends in something, not in an em dash.
    #expect(document.contains("— **E** — \n") == false)
  }

  /// A stop with no written reason says so rather than showing empty quotes.
  ///
  /// Possible for rows written before D13, and for a stop taken through the
  /// alarm's own button. `""` on the page would read as a person who typed
  /// nothing, which is a different and untrue claim.
  @Test("aStopWithNoReasonSaysSo")
  func aStopWithNoReasonSaysSo() {
    let document = StatsMarkdown.document(for: StatsPeriodFixture.fortnight, producedBy: .forGoldens)

    #expect(document.contains("- Thu 13 Aug, 11:02 — short break — *(no reason recorded)*"))
    #expect(document.contains("\"\"") == false)
  }

  /// A person's own words reach the page unaltered: a middle dot inside a task
  /// title is not mistaken for the app's separator, and an apostrophe is not
  /// escaped into `&#39;` or a backslash.
  @Test("somebodysOwnWordsAreReproducedNotEdited")
  func somebodysOwnWordsAreReproducedNotEdited() {
    let document = StatsMarkdown.document(for: StatsPeriodFixture.fortnight, producedBy: .forGoldens)

    #expect(document.contains("Reading · notes"))
    #expect(document.contains("Marta's feedback"))
    #expect(document.contains("\\") == false, "Nothing on this page is backslash-escaped.")
  }

  /// Newlines pasted into a sentence collapse to one space rather than breaking
  /// a list item in half and orphaning the rest of somebody's words.
  @Test("aPastedNewlineDoesNotBreakALine")
  func aPastedNewlineDoesNotBreakALine() {
    #expect(StatsWords.clean("  two\n\nlines   here \t") == "two lines here")
    #expect(StatsWords.clean("").isEmpty)
  }

  // MARK: Two different absences

  /// A block worked under a project with no task chosen gets a `No task`
  /// sub-row; a block that recorded no project groups under `No project`.
  ///
  /// **They are different words because they are different facts**, and today
  /// the second is the common case: the session plan hands the timer a task's
  /// title alone, so most task-attached blocks carry no project name. A heading
  /// called `No task` with named tasks under it would be a plain untruth.
  ///
  /// The sub-row exists rather than vanishing into the heading's total so that
  /// the lines under a heading always add up to the heading. A number that
  /// disagrees with another number on the same page is how a page stops being
  /// believed.
  @Test("noTaskRowsGroupUnderTheirProjectAndAddUp")
  func noTaskRowsGroupUnderTheirProjectAndAddUp() {
    let document = StatsMarkdown.document(for: StatsPeriodFixture.fortnight, producedBy: .forGoldens)

    #expect(document.contains("- **Thesis** — 7 pomodoros (I 3 / E 2)"))
    #expect(document.contains("  - No task — 1"))
    #expect(document.contains("- **No project** — 2 pomodoros (I 0 / E 1)"))
    #expect(document.contains("  - Marta's feedback — 2"))
  }

  /// A group of taps with a project but no task is named for the project and
  /// says so, rather than being merged with a task that happens to share the
  /// name or dumped into `No task`.
  @Test("aProjectOnlyGroupOfTapsSaysNoTask")
  func aProjectOnlyGroupOfTapsSaysNoTask() {
    let group = StatsDistractionGroup(
      taskTitle: nil,
      projectTitle: "Thesis",
      entries: StatsPeriodFixture.days[0].distractions)
    let section = StatsMarkdownSections.distractions([group])

    #expect(section?.contains("### Thesis (no task)") == true)
  }

  // MARK: The sections that are there, and the ones that are not

  /// An empty section is omitted entirely — never a heading with nothing under
  /// it and never an empty table.
  @Test("anEmptySectionIsOmittedRatherThanLeftBlank")
  func anEmptySectionIsOmittedRatherThanLeftBlank() {
    #expect(StatsMarkdownSections.days([]) == nil)
    #expect(StatsMarkdownSections.projects([]) == nil)
    #expect(StatsMarkdownSections.completed([]) == nil)
    #expect(StatsMarkdownSections.repeating([]) == nil)
    #expect(StatsMarkdownSections.distractions([]) == nil)
    #expect(StatsMarkdownSections.stoppedEarly([]) == nil)
  }

  /// A fortnight where nothing was finished but three blocks were stopped is
  /// **not** an empty range.
  ///
  /// It is the most worth reading there is: it renders `0 pomodoros` and a
  /// `## Stopped early` section, and no other section. The short document is
  /// reserved for a range in which genuinely nothing happened.
  @Test("aFortnightOfNothingButStopsIsNotAnEmptyRange")
  func aFortnightOfNothingButStopsIsNotAnEmptyRange() {
    let period = StatsPeriod(
      range: StatsPeriodFixture.range,
      days: [],
      projects: [],
      completions: [],
      stops: StatsPeriodFixture.stops)
    let document = StatsMarkdown.document(for: period, producedBy: .forGoldens)

    #expect(document.contains("0 pomodoros · 0 minutes · no distractions"))
    #expect(document.contains("## Stopped early"))
    #expect(document.contains("## Days") == false)
    #expect(document.contains(StatsMarkdown.nothingRecorded) == false)
  }

  /// D15: the sections appear in one fixed order, because that order is a
  /// sequence of questions rather than five buckets of data.
  @Test("theSectionsAreInD15sOrder")
  func theSectionsAreInD15sOrder() {
    let document = StatsMarkdown.document(for: StatsPeriodFixture.fortnight, producedBy: .forGoldens)
    let headings = document
      .components(separatedBy: "\n")
      .filter { $0.hasPrefix("## ") }

    #expect(headings == [
      "## Days", "## Projects", "## Completed", "## Repeating", "## Distractions", "## Stopped early"
    ])
  }

  /// Abandoned blocks appear in `## Stopped early` and nowhere else, and the
  /// abandoned **rate** appears nowhere at all.
  ///
  /// D15 rejected `42 pomodoros · 3 abandoned` by name: it would make the first
  /// thing you read every fortnight a measure of how often you gave up.
  @Test("theAbandonedRateIsNowhereOnThePage")
  func theAbandonedRateIsNowhereOnThePage() {
    let document = StatsMarkdown.document(for: StatsPeriodFixture.fortnight, producedBy: .forGoldens)

    for word in ["abandoned", "rate", "%", "average", "streak", "best"] {
      #expect(
        document.range(of: word, options: .caseInsensitive) == nil,
        "The page contains “\(word)”.")
    }
  }

  // MARK: Words and arithmetic

  /// Singulars and plurals, and a duration read the way it is said aloud.
  @Test("theWordsAreTheWordsAPersonWouldSay")
  func theWordsAreTheWordsAPersonWouldSay() {
    #expect(StatsWords.count(1, "pomodoro", "pomodoros") == "1 pomodoro")
    #expect(StatsWords.count(0, "pomodoro", "pomodoros") == "0 pomodoros")
    #expect(StatsWords.duration(seconds: 63_000) == "17 hours 30 minutes")
    #expect(StatsWords.duration(seconds: 3660) == "1 hour 1 minute")
    #expect(StatsWords.duration(seconds: 2700) == "45 minutes")
    #expect(StatsWords.duration(seconds: 7200) == "2 hours")
    #expect(StatsWords.duration(seconds: 0) == "0 minutes")
    // Seconds are discarded, not rounded: the page must never claim a minute
    // that was not spent.
    #expect(StatsWords.duration(seconds: 119) == "1 minute")
    // A clock that jumped backwards cannot put a negative length in the header.
    #expect(StatsWords.duration(seconds: -60) == "0 minutes")
  }

  /// A kind with no taps is left out of the parenthetical; nothing at all
  /// replaces the whole clause.
  @Test("theDistractionClauseNeverPrintsAZero")
  func theDistractionClauseNeverPrintsAZero() {
    #expect(StatsWords.distractionClause(internalCount: 0, externalCount: 0) == "no distractions")
    #expect(StatsWords.distractionClause(internalCount: 14, externalCount: 0) == "14 distractions (14 internal)")
    #expect(StatsWords.distractionClause(internalCount: 0, externalCount: 1) == "1 distraction (1 external)")
    #expect(
      StatsWords.distractionClause(internalCount: 14, externalCount: 9)
        == "23 distractions (14 internal / 9 external)")
  }

  /// The time is twenty-four hour on every device, and a date is never zero
  /// padded.
  @Test("aTimeIsTwentyFourHourAndADateIsNotPadded")
  func aTimeIsTwentyFourHourAndADateIsNotPadded() {
    #expect(StatsWords.time(StatsClockTime(hour: 14, minute: 32)) == "14:32")
    #expect(StatsWords.time(StatsClockTime(hour: 0, minute: 5)) == "00:05")
    #expect(StatsWords.date(StatsDay(year: 2026, month: 9, day: 3, weekday: 5)) == "Thu 3 Sep")
    #expect(StatsWords.spokenDate(StatsDay(year: 2026, month: 9, day: 3, weekday: 5)) == "Thursday 3 September")
  }

  // MARK: The filename

  /// A file sitting in Files a month later still sorts, and still says what it
  /// is.
  @Test("theFilenameSortsAndSaysWhatItIs")
  func theFilenameSortsAndSaysWhatItIs() {
    #expect(StatsMarkdown.filename(for: StatsPeriodFixture.range) == "ZenTomato-2026-08-08-to-2026-08-21.md")
    #expect(
      StatsMarkdown.filename(for: StatsRange.day(StatsPeriodFixture.friday21)) == "ZenTomato-2026-08-21.md")

    for filename in [
      StatsMarkdown.filename(for: StatsPeriodFixture.range),
      StatsMarkdown.filename(for: StatsRange.day(StatsPeriodFixture.friday21))
    ] {
      for awkward in [" ", ":", "/", "\\", "?", "*"] {
        #expect(filename.contains(awkward) == false, "\(filename) contains \(awkward).")
      }
    }
  }

  /// A single day is a day, not a span of one.
  @Test("aSingleDayReadsAsADay")
  func aSingleDayReadsAsADay() {
    let title = StatsMarkdown.title(for: StatsRange.day(StatsPeriodFixture.friday21))

    #expect(title == "ZenTomato — 2026-08-21")
    #expect(title.contains(" to ") == false)
  }

  // MARK: Repeating

  /// D21: a habit closed twice on one Monday still lists Monday once, and the
  /// weekdays read in the order a week is read.
  ///
  /// **This is the known limitation, and it ships as specified.** Over a
  /// fortnight two Mondays collapse into one `Mon`, which is exactly `F6.md`'s
  /// ratified sample. `F6.md` predicts one or two format revisions once real
  /// data is read on paper, and this is the likeliest of them; the golden makes
  /// that revision cheap.
  @Test("aHabitListsEachWeekdayOnceInWeekOrder")
  func aHabitListsEachWeekdayOnceInWeekOrder() {
    let section = StatsMarkdownSections.repeating(StatsPeriodFixture.fortnight.repeatingCompletions)

    #expect(section?.contains("- Pick 1–3 MITs — Mon, Wed, Thu, Sat") == true)
  }

  /// A recurring completion never appears in `## Completed`, and a one-off never
  /// appears in `## Repeating`.
  ///
  /// Closing a recurring task in Todoist advances it rather than finishing it.
  /// Without the split, one habit lands on eight days of fourteen in
  /// `## Completed` with nothing to explain why, and the chapter you actually
  /// finished disappears among them.
  @Test("habitsAndFinishedThingsAreNeverInTheSameList")
  func habitsAndFinishedThingsAreNeverInTheSameList() throws {
    let completed = try #require(StatsMarkdownSections.completed(StatsPeriodFixture.fortnight.oneOffCompletions))
    let repeating = try #require(StatsMarkdownSections.repeating(StatsPeriodFixture.fortnight.repeatingCompletions))

    #expect(completed.contains(StatsPeriodFixture.habit) == false)
    #expect(repeating.contains("Reading list for week 3") == false)
    #expect(completed.contains("Reading list for week 3"))
  }
}
