import Foundation
import Testing

@testable import ZenTomato

/// What the history screen shows, and the one guarantee it exists to keep.
///
/// **The screen and the page must never disagree.** That is not a nicety: it is
/// D15's stated fear about the one number the whole app exists to produce. If
/// the count at the top of the screen and the count at the top of the exported
/// page can differ, then neither is trusted and the feature has failed even
/// though every test about *counting* still passes.
///
/// The mechanism is structural — the screen is handed a finished `StatsPeriod`
/// and has nothing left to count — and `statsScreenMatchesExport` below is the
/// executed proof.
@Suite("StatsScreenModel")
@MainActor
struct StatsScreenModelTests {
  // MARK: The seam that matters

  /// `statsScreenMatchesExport` — both surfaces read the same period, and every
  /// number they print agrees.
  ///
  /// The screen's figures are pulled out of its own drawn strings rather than
  /// recomputed here, so this compares *what a person sees* on glass with *what
  /// a person reads* on paper.
  /// `theExportedPageFollowsTheChosenRangeAndNotToday` — the page is built from
  /// the *range* the reader picked, not from today.
  ///
  /// **WHY THIS TEST EXISTS, AND WHY `statsScreenMatchesExport` BELOW CANNOT
  /// REPLACE IT.** That test hands the model a source that answers every question
  /// with the same finished period, which is right for what it checks — that the
  /// screen and the page agree about a period — but it means the two are compared
  /// while both are holding the identical value. So it passes even if `document`
  /// is wired to the wrong period entirely.
  ///
  /// That is not hypothetical. Changing `document` to read `todayPeriod` instead
  /// of `rangePeriod` — which silently turns the Rhodia fortnight into a one-day
  /// page — left the whole suite green. Exporting the wrong span is the single
  /// worst thing this feature can do, because the export *is* the deliverable and
  /// a wrong one is not obviously wrong: it is a plausible document about the
  /// wrong dates.
  ///
  /// The fix is for the seam to answer *differently* depending on what it is
  /// asked, so that "which period did you use" becomes an observable question.
  @Test("theExportedPageFollowsTheChosenRangeAndNotToday")
  func theExportedPageFollowsTheChosenRangeAndNotToday() {
    // Today is a single day and answers with one pomodoro; any longer range
    // answers with the nine-pomodoro fortnight. The two are now distinguishable
    // from the outside, which is the whole point.
    let model = StatsScreenModel(
      periods: { $0.isSingleDay ? Self.oneDay : StatsPeriodFixture.fortnight },
      today: StatsPeriodFixture.friday21)
    model.load()

    // The number at the top is today's: one.
    #expect(model.todayNumeral == "1")

    // The page is the fortnight's: nine. If `document` ever reads `todayPeriod`,
    // this is the line that fails.
    #expect(model.document.contains("9 pomodoros"))
    #expect(model.document.contains("1 pomodoro ·") == false)

    // And it follows the range when the range changes, rather than being fixed
    // at load. A single-day range must produce the one-day page.
    model.use(range: .day(StatsPeriodFixture.thursday20))
    #expect(model.document.contains("9 pomodoros") == false)

    // Today's number is unmoved by the range control — the ratified behaviour,
    // and the reason the two are separate stored periods in the first place.
    #expect(model.todayNumeral == "1")
  }

  @Test("statsScreenMatchesExport")
  func statsScreenMatchesExport() {
    let model = Self.model(for: StatsPeriodFixture.fortnight)
    let document = StatsMarkdown.document(for: StatsPeriodFixture.fortnight)

    // The page's summary line, verbatim, is built from the same four figures the
    // screen draws — so if either drifts, this line stops matching.
    #expect(document.contains("9 pomodoros · 3 hours 45 minutes · 6 distractions (3 internal / 3 external)"))

    // Every day the screen lists appears in the page's table with the same
    // count in the same row.
    #expect(model.dayRows.isEmpty == false)
    for row in model.dayRows {
      let padded = row.title.padding(toLength: 10, withPad: " ", startingAt: 0)
      #expect(
        document.contains("| \(padded) | \(row.count)"),
        "The page and the screen disagree about \(row.title).")
    }

    // Every project the screen lists appears on the page with the same count.
    for row in model.projectRows {
      #expect(
        document.contains("- **\(row.title)** — \(row.count) pomodoro"),
        "The page and the screen disagree about \(row.title).")
    }
  }

  /// Today's number comes from `period(.day(today))` and from nowhere else.
  ///
  /// The test drives that through the seam: the model is handed a source that
  /// records what it was asked for. A "count today" shortcut on the screen would
  /// not ask for a single-day range, and this is what would notice.
  @Test("todayIsAskedForAsASingleDay")
  func todayIsAskedForAsASingleDay() {
    let asked = Recorder()
    let model = StatsScreenModel(
      periods: { range in
        asked.ranges.append(range)
        return range.isSingleDay ? Self.oneDay : StatsPeriodFixture.fortnight
      },
      today: StatsPeriodFixture.thursday20)
    model.load()

    // Today first, then the range — the ratified order, and the reason a long
    // range cannot delay the one number somebody opened the screen to see.
    #expect(asked.ranges.first == StatsRange.day(StatsPeriodFixture.thursday20))
    #expect(asked.ranges.count == 2)
    #expect(model.todayNumeral == "1")
  }

  // MARK: The number at the top

  /// Before anything has been asked, the screen shows a dash rather than a zero.
  /// A zero is a claim; a dash is an absence.
  @Test("theNumeralIsADashUntilSomethingHasBeenAsked")
  func theNumeralIsADashUntilSomethingHasBeenAsked() {
    let model = StatsScreenModel(periods: { _ in StatsPeriodFixture.fortnight }, today: StatsPeriodFixture.saturday8)

    #expect(model.todayNumeral == "—")
    #expect(model.todayIsAReading == false)
    #expect(model.todayTallyLine == nil)
  }

  /// A count of zero is a real reading and is drawn — quietly, never hidden.
  @Test("zeroIsDrawnAndIsAReading")
  func zeroIsDrawnAndIsAReading() {
    let model = Self.model(for: StatsPeriod.empty(for: StatsRange.day(StatsPeriodFixture.friday21)))

    #expect(model.todayNumeral == "0")
    #expect(model.todayIsAReading)
    #expect(model.todayUnitLine == "pomodoros")
    // Nothing finished and nothing tapped: there is nothing to summarise, and
    // "No distractions" under a zero would read as a verdict on a morning.
    #expect(model.todayTallyLine == nil)
  }

  /// The supporting lines say the unit, the length, and what interrupted — in
  /// the owner's own vocabulary.
  @Test("theLinesUnderTheNumeralUseTheTallysOwnWords")
  func theLinesUnderTheNumeralUseTheTallysOwnWords() {
    let model = Self.model(for: Self.oneDay)

    #expect(model.todayNumeral == "1")
    #expect(model.todayUnitLine == "pomodoro · 25 minutes")
    // `DistractionTally.summary(of:)` verbatim — not a second wording.
    #expect(model.todayTallyLine == "1 internal")
    #expect(model.todaySpoken == "1 pomodoro, 25 minutes, 1 internal")
  }

  /// A day with blocks and no taps says so in the tally's own zero string.
  @Test("aDayWithNoTapsSaysNoDistractions")
  func aDayWithNoTapsSaysNoDistractions() {
    let day = StatsDayRow(day: StatsPeriodFixture.friday21, pomodoroCount: 4, focusedSeconds: 6000, distractions: [])
    let period = StatsPeriod(
      range: StatsRange.day(StatsPeriodFixture.friday21),
      days: [day],
      projects: [],
      completions: [],
      stops: [])

    #expect(Self.model(for: period).todayTallyLine == "No distractions")
  }

  // MARK: The range

  /// `defaultRangeIsTrailing14Days` — the screen opens on the Rhodia cadence.
  @Test("defaultRangeIsTrailing14Days")
  func defaultRangeIsTrailing14Days() {
    let model = StatsScreenModel(
      periods: { _ in StatsPeriodFixture.fortnight },
      today: StatsPeriodFixture.friday21)

    #expect(model.range.last == StatsPeriodFixture.friday21)
    #expect(model.range.first == StatsPeriodFixture.saturday8)
  }

  /// **Moving the range never moves today's number.** If it could, the first
  /// question the owner ever asked would silently become a different question.
  @Test("theRangeDoesNotGovernTodaysNumber")
  func theRangeDoesNotGovernTodaysNumber() {
    let model = StatsScreenModel(
      periods: { range in range.isSingleDay ? Self.oneDay : StatsPeriodFixture.fortnight },
      today: StatsPeriodFixture.thursday20)
    model.load()
    let before = model.todayNumeral

    model.use(range: StatsRange.day(StatsPeriodFixture.saturday8))

    #expect(model.todayNumeral == before)
    #expect(model.range == StatsRange.day(StatsPeriodFixture.saturday8))
  }

  /// The reset always goes back to the fortnight, whatever was chosen.
  @Test("theResetGoesBackToTheFortnight")
  func theResetGoesBackToTheFortnight() {
    let model = StatsScreenModel(
      periods: { _ in StatsPeriodFixture.fortnight },
      today: StatsPeriodFixture.friday21)
    model.use(range: StatsRange.day(StatsPeriodFixture.saturday8))

    model.resetRange()

    #expect(model.range.first == StatsPeriodFixture.saturday8)
    #expect(model.range.last == StatsPeriodFixture.friday21)
  }

  /// The footer resolves the range into the document's own dialect and says the
  /// one thing about this screen a reader could otherwise get wrong.
  @Test("theRangeFooterSaysTodayIsAlwaysToday")
  func theRangeFooterSaysTodayIsAlwaysToday() {
    let model = Self.model(for: StatsPeriodFixture.fortnight)

    #expect(model.rangeFooter.contains("8 – 21 Aug"))
    #expect(model.rangeFooter.contains("always today"))
  }

  /// The Export button names the exact span leaving the app, and repeats the
  /// month only when the two ends fall in different ones.
  @Test("theExportButtonNamesTheSpan")
  func theExportButtonNamesTheSpan() {
    #expect(Self.model(for: StatsPeriodFixture.fortnight).exportButtonTitle == "Export 8 – 21 Aug")

    let acrossMonths = StatsScreenModel(
      periods: { _ in StatsPeriodFixture.fortnight },
      today: StatsPeriodFixture.saturday8)
    acrossMonths.use(range: StatsRange(
      first: StatsDay(year: 2026, month: 7, day: 28, weekday: 3),
      last: StatsPeriodFixture.monday10))

    #expect(acrossMonths.exportButtonTitle == "Export 28 Jul – 10 Aug")
    #expect(acrossMonths.exportSpokenTitle == "Export Tuesday 28 July to Monday 10 August")
  }

  // MARK: The lists

  /// Days run newest first on glass and oldest first on paper. That divergence
  /// is deliberate — a screen is checked today, a document is read like a diary
  /// — and it is ordering, not counting.
  @Test("daysRunNewestFirstOnScreenAndOldestFirstOnPaper")
  func daysRunNewestFirstOnScreenAndOldestFirstOnPaper() {
    let model = Self.model(for: StatsPeriodFixture.fortnight)
    let document = StatsMarkdown.document(for: StatsPeriodFixture.fortnight)

    #expect(model.dayRows.first?.title == "Thu 20 Aug")
    #expect(model.dayRows.last?.title == "Sat 8 Aug")

    guard
      let oldest = document.range(of: "| Sat 8 Aug"),
      let newest = document.range(of: "| Thu 20 Aug")
    else {
      Issue.record("The page is missing one of the two days.")
      return
    }
    #expect(oldest.lowerBound < newest.lowerBound)
  }

  /// Only a day with something behind it is a button. A day with nothing is not
  /// a dead button — it is not a button.
  @Test("onlyADayWithTapsCanBeOpened")
  func onlyADayWithTapsCanBeOpened() {
    let model = Self.model(for: StatsPeriodFixture.fortnight)

    let wednesday = model.dayRows.first { $0.title == "Wed 12 Aug" }
    let saturday = model.dayRows.first { $0.title == "Sat 8 Aug" }

    #expect(wednesday?.isOpenable == false)
    #expect(saturday?.isOpenable == true)
    #expect(model.entries(on: StatsPeriodFixture.saturday8).count == 2)
    #expect(model.entries(on: StatsPeriodFixture.wednesday12).isEmpty)
  }

  /// The two absences keep their two different words on glass, exactly as on
  /// paper.
  @Test("theScreenSaysNoProjectAndNoTaskInTheSamePlacesThePageDoes")
  func theScreenSaysNoProjectAndNoTaskInTheSamePlacesThePageDoes() {
    let model = Self.model(for: StatsPeriodFixture.fortnight)

    #expect(model.projectRows.contains { $0.title == "No project" && $0.titleIsAbsence })
    #expect(model.taskRows.contains { $0.title == "No task" && $0.titleIsAbsence })
    #expect(model.projectRows.contains { $0.title == "No task" } == false)
  }

  /// A row says its count and its tally aloud in one sentence, spelled out.
  @Test("aRowIsSpokenInFull")
  func aRowIsSpokenInFull() {
    let model = Self.model(for: StatsPeriodFixture.fortnight)
    let saturday = model.dayRows.first { $0.title == "Sat 8 Aug" }

    #expect(saturday?.spokenTitle == "Saturday 8 August")
    #expect(saturday?.spokenValue == "2 pomodoros, 1 internal, 1 external")
  }

  /// The empty state is a fact, never a verdict, and never says "you have
  /// nothing".
  @Test("theEmptyStateIsAFactAndNotAVerdict")
  func theEmptyStateIsAFactAndNotAVerdict() {
    let model = Self.model(for: StatsPeriod.empty(for: StatsPeriodFixture.range))

    #expect(model.rangeIsEmpty)
    #expect(StatsScreenModel.emptyHeading(for: StatsPeriodFixture.range) == "Nothing in these days")
    #expect(
      StatsScreenModel.emptyHeading(for: StatsRange.day(StatsPeriodFixture.friday21)) == "Nothing on Fri 21 Aug")

    let copy = [
      StatsScreenModel.emptyHeading(for: StatsPeriodFixture.range),
      StatsScreenModel.emptyDetail,
      StatsScreenModel.emptyOrigin
    ]
    for sentence in copy {
      #expect(sentence.contains("!") == false, "“\(sentence)” encourages rather than states.")
      for scolding in ["you have", "you haven't", "get started", "why not", "yet again"] {
        #expect(sentence.range(of: scolding, options: .caseInsensitive) == nil, "“\(sentence)”")
      }
    }
    // The load-bearing line answers the question this state provokes.
    #expect(StatsScreenModel.emptyOrigin.contains("stop early"))
  }

  // MARK: The file that leaves the app

  /// The share hands over a real `.md` file with a real name, and the last one
  /// is swept away first.
  ///
  /// **The file is the deliverable.** F6 exists to produce the page a fortnightly
  /// review is read from, and a `String` handed to `ShareLink` arrives in Files
  /// as `Untitled.txt`. This is the one piece of I/O in the feature, which is why
  /// it lives outside `ZenTomato/Export/` — that directory stays a pure function
  /// so the golden file keeps meaning something.
  @Test("theShareHandsOverARealFile")
  func theShareHandsOverARealFile() throws {
    let model = Self.model(for: StatsPeriodFixture.fortnight)

    let url = try StatsExportFile.write(document: model.document, filename: model.filename)

    #expect(url.lastPathComponent == "ZenTomato-2026-08-08-to-2026-08-21.md")
    #expect(try String(contentsOf: url, encoding: .utf8) == model.document)

    // A second export sweeps the first away rather than leaving a fortnight
    // behind in the temporary directory on every tap.
    let previous = url
    model.use(range: StatsRange.day(StatsPeriodFixture.friday21))
    let second = try StatsExportFile.write(document: model.document, filename: model.filename)

    #expect(second.lastPathComponent == "ZenTomato-2026-08-21.md")
    #expect(FileManager.default.fileExists(atPath: previous.path) == false)

    try? FileManager.default.removeItem(at: second)
  }

  // MARK: Private

  /// Records what the screen asked for.
  ///
  /// A class rather than a captured `var`, so the closure the model holds and
  /// this test look at one list rather than at two copies.
  @MainActor
  private final class Recorder {
    var ranges: [StatsRange] = []
  }

  private static let oneDay = StatsPeriod(
    range: StatsRange.day(StatsPeriodFixture.thursday20),
    days: [StatsPeriodFixture.days[5]],
    projects: [],
    completions: [],
    stops: [])

  /// A model that answers every question with the same finished period, loaded.
  private static func model(for period: StatsPeriod) -> StatsScreenModel {
    let model = StatsScreenModel(periods: { _ in period }, today: StatsPeriodFixture.friday21)
    model.load()
    return model
  }
}
