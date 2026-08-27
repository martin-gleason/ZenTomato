import Foundation

/// Everything the pomodoro history screen shows, as finished values, and every
/// sentence it can say.
///
/// THE ONE RULE THIS TYPE EXISTS TO KEEP
/// **It never counts anything.** Every number arrives already counted, inside a
/// `StatsPeriod`, from the single `StatsQuery` the export also uses. There is no
/// store and no predicate below — the only thing it can ask for is an answer.
///
/// That matters more here than anywhere else. The likeliest way this app's one
/// important number stops being trusted is not a wrong query — it is *"today's
/// count"* computed on the screen because it is one line, then quietly
/// disagreeing with the page the fortnightly review is read from. So today's
/// number is `periods(.day(today)).pomodoroCount`, the same function asked for
/// one day, and there is deliberately no shorter way to get it.
///
/// WHY THE SEAM IS A CLOSURE
/// A preview and a test can hand this type a *finished* `StatsPeriod` without
/// opening a database. It is not a second counting path and cannot become one:
/// whoever calls that initialiser arrives already holding every total.
///
/// WHEN THE WORK HAPPENS
/// `load()` is called from `.task` and `use(range:)` from a control. **Neither is
/// ever called from a `body`**, because a query inside `body` runs on every
/// redraw and no amount of speed saves it. `load()` answers today *first* and
/// publishes it before it looks at the range — the ratified design, and the
/// reason a long range cannot delay the one thing somebody opened this for.
@MainActor
@Observable
final class StatsScreenModel {
  // MARK: Lifecycle

  /// - Parameters:
  ///   - periods: the only way this screen gets a number. In the app, and only
  ///     there, this is `StatsQuery.period(_:)`.
  ///   - today: the day the screen opens on, injected so a test is not at the
  ///     mercy of the day it runs.
  ///   - calendar: turns the range control's two dates into days and back. It
  ///     counts nothing.
  init(
    periods: @escaping @MainActor (StatsRange) -> StatsPeriod,
    today: StatsDay,
    calendar: Calendar = .current) {
    self.periods = periods
    self.today = today
    self.calendar = calendar
    range = StatsRange.trailing14Days(endingOn: today, in: calendar)
  }

  /// The app's initialiser: the same store the timer writes to.
  convenience init(query: StatsQuery, today: StatsDay, calendar: Calendar = .current) {
    self.init(periods: { query.period($0) }, today: today, calendar: calendar)
  }

  // MARK: Internal

  /// The day the screen opens on. Never governed by the range control — today is
  /// today, and if the range could change the top number then the first question
  /// the owner ever asked would silently become a different question.
  let today: StatsDay

  /// Today's answer, and the range's answer. `nil` for the one frame before
  /// `load()` runs; the screen draws a dash rather than a zero there, because a
  /// zero is a claim and a dash is an absence.
  private(set) var todayPeriod: StatsPeriod?

  private(set) var rangePeriod: StatsPeriod?

  /// True when the database refused the range.
  var couldNotBeRead: Bool { rangePeriod?.couldNotBeRead == true }

  private(set) var range: StatsRange

  /// Answers today, publishes it, then looks at the range.
  func load() {
    todayPeriod = periods(.day(today))
    rangePeriod = periods(range)
  }

  /// The range control moved. Today's number is left exactly where it is.
  func use(range newRange: StatsRange) {
    range = newRange
    rangePeriod = periods(newRange)
  }

  /// Back to the fortnight the Rhodia review runs on.
  func resetRange() {
    use(range: StatsRange.trailing14Days(endingOn: today, in: calendar))
  }

  /// The instant a date picker should sit on, or `nil` if the calendar cannot
  /// build one. Optional rather than force-unwrapped: a control that opens
  /// somewhere odd is a great deal better than a crash.
  func instant(for day: StatsDay) -> Date? { day.start(in: calendar) }

  /// The day a date picker's value falls on.
  func day(for instant: Date) -> StatsDay { StatsDay.containing(instant, in: calendar) }

  // MARK: Private

  private let periods: @MainActor (StatsRange) -> StatsPeriod

  private let calendar: Calendar
}

// MARK: - The number at the top

extension StatsScreenModel {
  /// Today's count, drawn. Never padded, never `04`.
  var todayNumeral: String {
    guard let todayPeriod else { return Self.missingReading }
    return "\(todayPeriod.pomodoroCount)"
  }

  /// **A count of zero is a reading and is drawn**, in the quiet ink — the
  /// treatment `TimerScreen` gives an idle countdown. Shown, not shouted. Only
  /// the frame before anything has been asked is not a reading.
  var todayIsAReading: Bool {
    todayPeriod != nil
  }

  /// `pomodoros`, or `pomodoro · 25 minutes`, or `pomodoros · 1 hour 40 minutes`.
  ///
  /// The word carries the singular; the numeral above carries the number, so the
  /// count is never printed twice. With nothing finished there is no duration to
  /// state, so the line is the unit alone.
  var todayUnitLine: String {
    guard let todayPeriod, todayPeriod.pomodoroCount > 0 else { return "pomodoros" }
    let unit = todayPeriod.pomodoroCount == 1 ? "pomodoro" : "pomodoros"
    return "\(unit) · \(StatsWords.duration(seconds: todayPeriod.focusedSeconds))"
  }

  /// `2 internal · 1 external`, or `No distractions`, or nothing at all.
  ///
  /// `DistractionTally.summary(of:)` verbatim — the owner's own file, which this
  /// feature may not modify and does not re-word.
  ///
  /// Omitted on a day with no blocks *and* no taps: `No distractions` under a
  /// zero reads as a verdict on a morning rather than as a fact about it.
  var todayTallyLine: String? {
    guard let todayPeriod else { return nil }
    let taps = todayPeriod.internalCount + todayPeriod.externalCount
    guard todayPeriod.pomodoroCount > 0 || taps > 0 else { return nil }
    return DistractionTally.summary(of: todayPeriod.distractionKinds)
  }

  /// What VoiceOver says instead of a 48-point numeral and three fragments read
  /// in whatever order it finds them.
  var todaySpoken: String {
    guard let todayPeriod else { return Self.missingSpokenReading }
    var parts = [StatsWords.count(todayPeriod.pomodoroCount, "pomodoro", "pomodoros")]
    if todayPeriod.pomodoroCount > 0 {
      parts.append(StatsWords.duration(seconds: todayPeriod.focusedSeconds))
    }
    if let todayTallyLine {
      parts.append(todayTallyLine.spokenTally)
    }
    return parts.joined(separator: ", ")
  }
}

// MARK: - The lists

extension StatsScreenModel {
  /// One row of the Days, Projects or Tasks list. A finished value: strings,
  /// two flags, and — for a day — the day itself so the sheet knows what to
  /// open. Nothing countable travels on it.
  struct Row: Identifiable, Equatable {
    let id: String
    let title: String
    let titleIsAbsence: Bool
    let secondLine: String
    let count: String
    let spokenTitle: String
    let spokenValue: String
    let day: StatsDay?
    let isOpenable: Bool
  }

  /// Days, **descending** — a screen you check today, so today is at the top.
  /// The export orders days ascending because a document is read like a diary.
  /// That divergence is deliberate: it is ordering, not counting, and both
  /// surfaces get every number from the one `StatsQuery`.
  var dayRows: [Row] {
    guard let rangePeriod else { return [] }
    return rangePeriod.days.sorted { $0.day > $1.day }.map { row in
      // The real taps, handed straight to the owner's own summary — not two
      // integers rebuilt into an array.
      let tally = DistractionTally.summary(of: row.distractionKinds)
      return Row(
        id: StatsWords.isoDate(row.day),
        title: StatsWords.date(row.day),
        titleIsAbsence: false,
        secondLine: tally,
        count: "\(row.pomodoroCount)",
        spokenTitle: StatsWords.spokenDate(row.day),
        spokenValue: Self.spokenValue(count: row.pomodoroCount, tally: tally),
        day: row.day,
        // A day with nothing behind it is not a dead button — it is not a
        // button. `TimerScreen.attachmentLine` learned this the hard way: an
        // affordance drawn on an inert row is a lie.
        isOpenable: row.distractions.isEmpty == false)
    }
  }

  var projectRows: [Row] {
    guard let rangePeriod else { return [] }
    return rangePeriod.projects.sorted(by: StatsPeriod.projectIsBefore).map { row in
      let tally = Self.tally(internalCount: row.internalCount, externalCount: row.externalCount)
      return Row(
        id: "project-\(row.title ?? StatsWords.noProject)",
        title: row.title ?? StatsWords.noProject,
        titleIsAbsence: row.title == nil,
        secondLine: tally,
        count: "\(row.pomodoroCount)",
        spokenTitle: row.title ?? StatsWords.noProject,
        spokenValue: Self.spokenValue(count: row.pomodoroCount, tally: tally),
        day: nil,
        isOpenable: false)
    }
  }

  var taskRows: [Row] {
    guard let rangePeriod else { return [] }
    return rangePeriod.taskRows.map { row in
      let tally = Self.tally(internalCount: row.internalCount, externalCount: row.externalCount)
      let title = row.title ?? StatsWords.noTask
      return Row(
        id: "task-\(row.projectTitle ?? "")-\(title)",
        title: title,
        titleIsAbsence: row.title == nil,
        // The project name first, then the tally, so a task title that appears
        // in two projects is still readable as two rows rather than as a
        // duplicate.
        secondLine: [row.projectTitle, tally].compactMap { $0 }.joined(separator: " · "),
        count: "\(row.pomodoroCount)",
        spokenTitle: title,
        spokenValue: Self.spokenValue(count: row.pomodoroCount, tally: tally),
        day: nil,
        isOpenable: false)
    }
  }

  /// Whether the three lists have nothing to draw.
  var rangeIsEmpty: Bool {
    guard let rangePeriod else { return false }
    return rangePeriod.isEmpty
  }
}

// MARK: - The export

extension StatsScreenModel {
  /// The page itself, built from the range's own period.
  var document: String {
    guard let rangePeriod else { return "" }
    return StatsMarkdown.document(for: rangePeriod, producedBy: .current)
  }

  var filename: String {
    StatsMarkdown.filename(for: range)
  }

  var sharePreviewTitle: String {
    StatsMarkdown.title(for: range)
  }

  /// `Export 10 – 23 Aug`, or `Export 23 Aug` for a single day.
  ///
  /// The button states the exact span leaving the app, so the range control's
  /// effect is legible in two places at once. A bare share glyph would say
  /// nothing about what is being handed over, and the document *is* this
  /// feature.
  var exportButtonTitle: String {
    "Export \(Self.shortSpan(range))"
  }

  var exportSpokenTitle: String {
    guard range.isSingleDay == false else {
      return "Export \(StatsWords.spokenDate(range.first))"
    }
    return "Export \(StatsWords.spokenDate(range.first)) to \(StatsWords.spokenDate(range.last))"
  }

  /// The sentence under the range control. Load-bearing twice: it resolves the
  /// two pickers into the document's own dialect, and it says that the number
  /// above is not governed by them — the one thing about this screen a reader
  /// could otherwise get wrong.
  var rangeFooter: String {
    "\(Self.shortSpan(range)). \(Self.todayIsAlwaysToday)"
  }
}

// MARK: - Copy

extension StatsScreenModel {
  static let screenTitle = "Pomodoros"
  static let todayKicker = "Today"
  static let daysHeader = "Days"
  static let projectsHeader = "Projects"
  static let tasksHeader = "Tasks"
  static let rangeHeader = "Range"
  static let rangeStartLabel = "From"
  static let rangeEndLabel = "To"
  static let rangeResetLabel = "Last 14 days"
  static let doneLabel = "Done"

  static let todayIsAlwaysToday = "Today's count above is always today, whatever range you choose."

  // MARK: Private

  /// Drawn where there is no reading yet — the same dash `TimerScreen` shows
  /// when there is no settings row to read a length from.
  fileprivate static let missingReading = "—"

  fileprivate static let missingSpokenReading = "No reading yet"

  /// `10 – 23 Aug`, `28 Jul – 10 Aug`, `23 Aug`. En dash, spaced. The month is
  /// repeated only across a month boundary: `10 Aug – 23 Aug` makes a reader
  /// stop and check whether the two months are the same.
  fileprivate static func shortSpan(_ range: StatsRange) -> String {
    guard range.isSingleDay == false else {
      return "\(range.first.day) \(StatsWords.monthAbbreviation(range.first))"
    }
    let firstMonth = StatsWords.monthAbbreviation(range.first)
    let lastMonth = StatsWords.monthAbbreviation(range.last)
    let opening = firstMonth == lastMonth
      ? "\(range.first.day)"
      : "\(range.first.day) \(firstMonth)"
    return "\(opening) – \(range.last.day) \(lastMonth)"
  }

  /// `DistractionTally.summary(of:)`, reached from two integers.
  ///
  /// The tally takes the taps themselves — the right shape for a block that has
  /// just ended. A counted row has totals rather than taps, so they are rebuilt
  /// to ask the question. A handful of values, and it buys **one vocabulary**,
  /// written once, in the owner's own file.
  fileprivate static func tally(internalCount: Int, externalCount: Int) -> String {
    let kinds = Array(repeating: DistractionKind.internalInterruption, count: max(0, internalCount))
      + Array(repeating: DistractionKind.externalInterruption, count: max(0, externalCount))
    return DistractionTally.summary(of: kinds)
  }

  fileprivate static func spokenValue(count: Int, tally: String) -> String {
    let blocks = StatsWords.count(count, "pomodoro", "pomodoros")
    return "\(blocks), \(tally.spokenTally)"
  }
}

// MARK: - String + spoken tally

extension String {
  /// `DistractionTally`'s line, said rather than drawn. Two changes and no
  /// others: the middle dot becomes a comma, because VoiceOver reads `·` as
  /// nothing and the halves run together; and the first letter drops to lower
  /// case, because `No distractions` is right as a line and wrong mid-sentence.
  /// Nobody's own words pass through here — the tally is generated.
  fileprivate var spokenTally: String {
    let commas = replacingOccurrences(of: " · ", with: ", ")
    guard let first = commas.first else { return commas }
    return first.lowercased() + commas.dropFirst()
  }
}
