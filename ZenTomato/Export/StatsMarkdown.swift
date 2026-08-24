import Foundation

/// The exported page: a pure function from one finished value to one string.
///
/// WHAT THIS FEATURE IS ACTUALLY FOR
/// `SPEC.md`'s acceptance criterion for F6 is unusually subjective and it is the
/// real bar: *"the export of one real study day is readable in the Rhodia
/// without translation."* Not "the export is valid Markdown". If a line needs
/// decoding, it fails. That is why there are no identifiers on this page, no ISO
/// timestamps with timezone offsets, no seconds, no am/pm, no relative dates
/// like "yesterday" — a document read in a fortnight cannot use a word that
/// means something different when it is read — and no column that exists because
/// it was easy to compute.
///
/// WHY IT IS A FUNCTION AND NOT A SCREEN
/// `document(for:)` takes a value, returns a string, and touches nothing else.
/// No store, no disk, no clock, no reader's region setting. That is what makes a
/// committed golden file possible, and a golden file is the strongest evidence
/// available for an acceptance criterion that is a human judgement about
/// readability: a person reads the page once and agrees with it, and a machine
/// then defends that agreement forever.
///
/// The purity is structural rather than promised. `StatsQuery` has already
/// turned every instant into whole numbers, so there is no date type in this
/// directory to misuse — see `StatsWords`.
///
/// THE SECTION ORDER IS AN ORDER OF QUESTIONS (D15)
/// Not five buckets of data:
///
/// | Section | The question |
/// |---|---|
/// | summary line | how did the fortnight go |
/// | `## Days` | when |
/// | `## Projects` | where the time went |
/// | `## Completed` | what came out of it |
/// | `## Repeating` | the habits |
/// | `## Distractions` | what interrupted me, by task |
/// | `## Stopped early` | where I bailed, and why |
///
/// WHITESPACE IS PART OF THE CONTRACT
/// `\n` throughout, never `\r\n`. Exactly one blank line between blocks, never
/// two. No trailing spaces on any line. Exactly one newline at the end. These
/// are invisible on a rendered page and they are the commonest reason a golden
/// file starts failing, so they are stated rather than left to habit.
enum StatsMarkdown {
  // MARK: The document

  /// The whole page, as one string.
  static func document(for period: StatsPeriod) -> String {
    let opening = "# \(title(for: period.range))"

    // THE SHORT DOCUMENT, AND WHERE ITS BOUNDARY IS.
    // A range with nothing in it at all becomes three lines rather than a
    // skeleton of six absent headings — `F6.md` asks for "one clear sentence,
    // not empty tables". The boundary is exact and worth stating: *empty* means
    // no finished pomodoro, no tap, no completion and no stop. A range holding
    // three stops and no finished blocks is NOT empty. It renders a header
    // saying `0 pomodoros` and a `## Stopped early` section, because a fortnight
    // in which you started four things and finished none is the most worth
    // reading there is.
    guard period.isEmpty == false else {
      return "\(opening)\n\n\(nothingRecorded)\n"
    }

    let sections = [
      StatsMarkdownSections.days(period.days),
      StatsMarkdownSections.projects(period.projects),
      StatsMarkdownSections.completed(period.oneOffCompletions),
      StatsMarkdownSections.repeating(period.repeatingCompletions),
      StatsMarkdownSections.distractions(period.distractionsByTask),
      StatsMarkdownSections.stoppedEarly(period.stops)
    ]

    let blocks = [opening, summary(for: period)] + sections.compactMap { $0 }
    return "\(blocks.joined(separator: "\n\n"))\n"
  }

  /// The one sentence a range with nothing in it gets.
  ///
  /// Read by `emptyRangeIsReadable`, and by the screen, so that the page and the
  /// glass say the same thing about the same fortnight.
  static let nothingRecorded = "No pomodoros in this range."

  /// The document's own name for a span of days:
  /// `ZenTomato — 2026-08-08 to 2026-08-21`.
  ///
  /// **This is the one place inside the document where a sortable date is used**,
  /// and it is a deliberate exception to everything `StatsWords` argues for. The
  /// reason is the same as the filename's: a page that has been in a notebook for
  /// a month has to say without ambiguity which fortnight it covers, and a year
  /// is what carries that. Every date the reader's eye actually lands on inside
  /// the page reads `Wed 19 Aug`.
  ///
  /// A single-day range prints one date rather than a span of one.
  static func title(for range: StatsRange) -> String {
    guard range.isSingleDay == false else {
      return "ZenTomato — \(StatsWords.isoDate(range.first))"
    }
    return "ZenTomato — \(StatsWords.isoDate(range.first)) to \(StatsWords.isoDate(range.last))"
  }

  // MARK: The file

  /// `ZenTomato-2026-08-08-to-2026-08-21.md`, or `ZenTomato-2026-08-23.md` for
  /// one day.
  ///
  /// No spaces, no colons, no slashes — nothing a filesystem, a mail attachment
  /// or a Shortcuts action has to sanitise, and nothing that would arrive in
  /// Files as `Untitled.txt`. Sortable dates, so a folder holding a year of these
  /// is in order by name.
  static func filename(for range: StatsRange) -> String {
    guard range.isSingleDay == false else {
      return "ZenTomato-\(StatsWords.isoDate(range.first)).md"
    }
    return "ZenTomato-\(StatsWords.isoDate(range.first))-to-\(StatsWords.isoDate(range.last)).md"
  }

  // MARK: Private

  /// `42 pomodoros · 17 hours 30 minutes · 23 distractions (14 internal / 9 external)`
  ///
  /// First, so the top of the page answers *"how did the fortnight go"* before
  /// anything has to be read across.
  ///
  /// **`42 pomodoros` means blocks you finished.** Abandoned blocks are in no
  /// count anywhere in this document; they have a section of their own at the
  /// bottom. **The abandoned rate is deliberately not here** — D15 rejected
  /// `42 pomodoros · 3 abandoned` by name, because it would make the first thing
  /// you read every fortnight a measure of how often you gave up, which is a
  /// different document from the one this is meant to be.
  ///
  /// The duration is the sum of each counted block's real length, so a block cut
  /// short by the clock is not counted at its nominal twenty-five minutes.
  ///
  /// Separator is a middle dot with a space either side, matching
  /// `DistractionTally`'s own separator — the vocabulary this app already speaks.
  private static func summary(for period: StatsPeriod) -> String {
    let blocks = StatsWords.count(period.pomodoroCount, "pomodoro", "pomodoros")
    let time = StatsWords.duration(seconds: period.focusedSeconds)
    let taps = StatsWords.distractionClause(
      internalCount: period.internalCount,
      externalCount: period.externalCount)

    return "\(blocks) · \(time) · \(taps)"
  }
}
