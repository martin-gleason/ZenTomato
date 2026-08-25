import Foundation

/// Every English word the export is allowed to spell, and the arithmetic that
/// turns a number into one.
///
/// WHY THIS FILE EXISTS AT ALL, AND WHY IT LOOKS LIKE A PHRASEBOOK
/// The acceptance criterion for this whole feature is that the exported page is
/// *"readable in the Rhodia without translation"*. The strongest evidence
/// available for a claim like that is a committed golden file that a person read
/// once and a machine defends forever — and a golden file is only worth having
/// if it is byte-identical on every machine that runs it.
///
/// A system date formatter cannot give that. Ask one for `"HH:mm"` on a phone set to a
/// twelve-hour clock and it returns `2:32 PM`, because iOS treats the pattern as
/// a *request* and the reader's region setting as the *answer*. Ask one for a
/// weekday and it answers in the reader's language. Ask `String` to compare two
/// task titles the locale-aware way and the ordering differs between
/// a laptop in London and a build machine in Oregon. Each of those turns a
/// stable document into one that churns for reasons that have nothing to do with
/// readability, and each of them would be discovered as a mystery test failure
/// rather than as a decision.
///
/// So there is no formatter here, and there is no formatter anywhere under
/// `ZenTomato/Export/`. There are two tables of English words and some integer
/// arithmetic. `StatsQuery` has already reduced every instant to whole numbers —
/// a `StatsDay` is a year, a month, a day and a weekday; a `StatsClockTime` is an
/// hour and a minute — so by the time anything reaches this file there is no date
/// left to get wrong.
///
/// THE DOCUMENT IS ENGLISH, DELIBERATELY
/// The tables below are English literals and are not localised. `SPEC.md` names
/// one reader and one paper notebook. A localised export cannot have a
/// byte-identical golden file, and losing the golden costs more than translating
/// a page nobody has asked to translate. This is a decision, not an oversight.
enum StatsWords {
  // MARK: Dates and times

  /// A date as the document writes it: `Wed 19 Aug`.
  ///
  /// No zero padding on the day — `Wed 3 Sep`, never `Wed 03 Sep`. A padded day
  /// is a machine's habit, and the one thing this page may not read like is
  /// machine output.
  static func date(_ day: StatsDay) -> String {
    "\(weekdayAbbreviation(day)) \(day.day) \(monthAbbreviation(day))"
  }

  /// A date as VoiceOver should say it: `Wednesday 19 August`.
  ///
  /// Drawn short and spoken in full, which is the pattern `SettingsView` already
  /// keeps for its minute rows. An abbreviation is a reading convenience on a
  /// small screen; read aloud it becomes `wed`, which is a different word.
  static func spokenDate(_ day: StatsDay) -> String {
    "\(weekdayName(day)) \(day.day) \(monthName(day))"
  }

  /// A time as the document writes it: `14:32`.
  ///
  /// Twenty-four hour, always, on every device, whatever the reader's clock is
  /// set to. Two digits either side so a column of times lines up when the page
  /// is read in a plain text editor.
  static func time(_ clock: StatsClockTime) -> String {
    "\(twoDigits(clock.hour)):\(twoDigits(clock.minute))"
  }

  /// A date in the one dialect the document is otherwise forbidden: `2026-08-19`.
  ///
  /// **Used in exactly two places** — the title line and the filename — and for
  /// the same reason in both: a file sitting in Files a month later has to sort
  /// correctly and still say what it is. Everywhere a person actually *reads* a
  /// date, `date(_:)` above is what is used.
  static func isoDate(_ day: StatsDay) -> String {
    "\(day.year)-\(twoDigits(day.month))-\(twoDigits(day.day))"
  }

  /// The three-letter weekday: `Mon`.
  ///
  /// `StatsDay.weekday` follows the platform calendar's own numbering, where 1 is Sunday.
  /// That numbering is converted here, once, rather than being reasoned about at
  /// four call sites.
  static func weekdayAbbreviation(_ day: StatsDay) -> String {
    Self.weekdayAbbreviations[safe: day.weekday - 1] ?? Self.unknownWord
  }

  /// The three-letter month: `Aug`.
  ///
  /// Internal rather than private because the screen's Export button names the
  /// same span the document's title names, and one table of month names is what
  /// keeps the button and the page from spelling a month two ways.
  static func monthAbbreviation(_ day: StatsDay) -> String {
    Self.monthAbbreviations[safe: day.month - 1] ?? Self.unknownWord
  }

  /// Where a weekday sits in a week that begins on Monday: `Mon` is 0, `Sun` is 6.
  ///
  /// `## Repeating` lists the days a habit was closed on, and it lists them in
  /// the order a week is read rather than in the order they happened to occur.
  /// Sunday is 1 in that numbering and last in a working week, which is
  /// the whole of the arithmetic below.
  static func weekOrder(_ day: StatsDay) -> Int {
    (day.weekday + 5) % 7
  }

  // MARK: Counting

  /// `1 pomodoro`, `42 pomodoros`, `0 pomodoros`.
  ///
  /// The singular is spelled out rather than reached for with an `s`, because
  /// English is not that regular and the next noun this is asked for might not
  /// be either.
  static func count(_ number: Int, _ singular: String, _ plural: String) -> String {
    "\(number) \(number == 1 ? singular : plural)"
  }

  /// A length of time in words: `17 hours 30 minutes`, `1 hour 1 minute`,
  /// `45 minutes`, `2 hours`, `0 minutes`.
  ///
  /// Spelled out because this line is read aloud to yourself at the top of the
  /// page. Never `17h 30m`, never a decimal, never seconds.
  ///
  /// **Seconds are discarded, not rounded.** Two blocks of twenty-five minutes
  /// and fifty-nine seconds are fifty-one minutes of work, not fifty-two: the
  /// page must never claim a minute that was not spent.
  ///
  /// **Negative input is clamped to zero.** F5 found and fixed a backward clock
  /// jump that could write a block's start after its end. A negative duration in
  /// the header would be the loudest possible symptom of the next one, and this
  /// clamp is what keeps it from being an absurdity instead.
  static func duration(seconds: Int) -> String {
    let total = max(0, seconds)
    let hours = total / 3600
    let minutes = (total % 3600) / 60

    if hours == 0 {
      return count(minutes, "minute", "minutes")
    }
    if minutes == 0 {
      return count(hours, "hour", "hours")
    }
    return "\(count(hours, "hour", "hours")) \(count(minutes, "minute", "minutes"))"
  }

  /// The distraction clause in the summary line.
  ///
  /// | Given | Returns |
  /// |---|---|
  /// | nothing | `no distractions` |
  /// | 14 internal, 9 external | `23 distractions (14 internal / 9 external)` |
  /// | 14 internal only | `14 distractions (14 internal)` |
  /// | 1 external only | `1 distraction (1 external)` |
  ///
  /// A kind with no taps is left out of the parenthetical entirely rather than
  /// printed as a zero — the same rule `DistractionTally` keeps, for the same
  /// reason: `14 internal / 0 external` is noise a reader has to subtract back
  /// out every time.
  ///
  /// **Zero replaces the whole clause with `no distractions`**, lower case,
  /// because it is mid-sentence. It does not borrow `DistractionTally`'s
  /// capitalised `No distractions`, which is a line on its own on a screen.
  static func distractionClause(internalCount: Int, externalCount: Int) -> String {
    let total = internalCount + externalCount
    guard total > 0 else {
      return "no distractions"
    }

    var pieces: [String] = []
    if internalCount > 0 { pieces.append("\(internalCount) internal") }
    if externalCount > 0 { pieces.append("\(externalCount) external") }

    return "\(count(total, "distraction", "distractions")) (\(pieces.joined(separator: " / ")))"
  }

  /// The I/E figures beside a project: `(I 7 / E 2)`.
  ///
  /// **Zeros are printed here**, unlike in the summary line above, and the
  /// difference is deliberate: this is a list you read *down*, comparing one
  /// project against the next, and a clause that changes shape between rows
  /// cannot be compared at a glance. `F6.md`'s own sample prints
  /// `- **Admin** — 3 pomodoros (I 1 / E 0)`.
  static func projectTally(internalCount: Int, externalCount: Int) -> String {
    "(I \(internalCount) / E \(externalCount))"
  }

  // MARK: Person-written text

  /// Somebody's own words, made safe to put on a line without changing them.
  ///
  /// Every run of whitespace — including a newline pasted in from somewhere else
  /// — collapses to one space, and the result is trimmed. A stop reason with a
  /// line break in it would otherwise end a Markdown list item halfway through
  /// and silently orphan the rest of the sentence.
  ///
  /// **Nothing else is escaped, and that is the decision.** A backslash in front
  /// of an asterisk is noise in a paper notebook, and these are the person's own
  /// words: the page reproduces them, it does not edit them.
  static func clean(_ text: String) -> String {
    escaped(text.split(whereSeparator: \.isWhitespace).joined(separator: " "))
  }

  /// A Todoist title is somebody's prose, and the page is Markdown.
  ///
  /// **A task called `**Thesis**` rendered as bold "Thesis" and lost its asterisks**; one
  /// containing a `|` broke the Days table it landed in. Neither is a crash and neither shows
  /// up in a test that reads the fixture — the fixture's titles are all well-behaved — but the
  /// whole bar for this feature is that the page reads without translation, and a title that
  /// silently changes shape fails it.
  ///
  /// **Only the characters that actually do something here.** Markdown has a long list of
  /// metacharacters and escaping all of them would put backslashes in front of ordinary
  /// punctuation — an apostrophe or a full stop is far commoner in a task title than an
  /// asterisk, and `Ch.3 draft` must not become `Ch\.3 draft`. So: emphasis, code, links,
  /// headings at the start of a line, and the pipe that would break a table.
  private static func escaped(_ text: String) -> String {
    var out = ""
    out.reserveCapacity(text.count)
    for character in text {
      if "*_`[]|".contains(character) { out.append("\\") }
      out.append(character)
    }
    // A leading # would make a title into a heading and swallow the line it sits on.
    return out.hasPrefix("#") ? "\\" + out : out
  }

  /// A name for something that has none: `No task`.
  ///
  /// One string, used by the export and by the screen, so that a block attached
  /// to nothing is called the same thing on paper as it is on glass. `F6.md`
  /// requires these rows to be *"rendered plainly, not as an error state"* — so
  /// it is a name, not a dash, not an icon, and not amber.
  static let noTask = "No task"

  /// A name for a project that was never recorded: `No project`.
  ///
  /// A different absence from `noTask` above, and the two are not
  /// interchangeable. Today most task-attached blocks land here — the session
  /// plan hands the timer a task's title alone and holds no project for it — so
  /// this heading routinely has named tasks underneath it. `No task` on that
  /// heading would be a plain untruth.
  static let noProject = "No project"

  // MARK: Private

  /// Printed where a weekday or month number is outside the range a calendar can
  /// produce. Unreachable through `StatsDay.containing(_:in:)`; the branch exists
  /// so that a hand-built value in a test or a fixture fails visibly on the page
  /// rather than crashing, which is what a force unwrap here would do instead.
  private static let unknownWord = "?"

  private static let weekdayAbbreviations = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

  private static let weekdayNames = [
    "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
  ]

  private static let monthAbbreviations = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
  ]

  private static let monthNames = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ]

  private static func weekdayName(_ day: StatsDay) -> String {
    Self.weekdayNames[safe: day.weekday - 1] ?? Self.unknownWord
  }

  private static func monthName(_ day: StatsDay) -> String {
    Self.monthNames[safe: day.month - 1] ?? Self.unknownWord
  }

  /// `07`, `14`, `00`.
  ///
  /// Written as arithmetic rather than as `String(format:)` for one reason worth
  /// naming: `String(format:)` reads the current locale for its digits, and in a
  /// locale that uses Eastern Arabic numerals it returns `٠٧`. That is a real
  /// bug, it only appears on somebody else's phone, and it cannot happen here.
  private static func twoDigits(_ number: Int) -> String {
    number < 10 && number >= 0 ? "0\(number)" : "\(number)"
  }
}

// MARK: - Array + safe subscript

extension Array {
  /// The element at an index, or `nil` if the index is outside the array.
  ///
  /// Exists so that the word tables above can be read without a force unwrap and
  /// without a range check written four times. `StatsDay` carries integers that
  /// came from a calendar, so out of range is unreachable in the app — but a
  /// fixture is a hand-written value and this file is the last thing between one
  /// and a crash.
  fileprivate subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
