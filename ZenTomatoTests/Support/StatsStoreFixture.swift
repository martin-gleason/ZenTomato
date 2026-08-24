import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// The same fortnight as `StatsPeriodFixture`, written as real rows in a real
/// store.
///
/// WHY THERE ARE TWO FIXTURES FOR ONE FORTNIGHT
/// `StatsPeriodFixture` is the finished answer, built by hand with no clock and
/// no calendar anywhere near it, and it is what the committed golden document
/// is rendered from. This is the same fortnight described as the rows a timer
/// would actually have written: blocks with start and end instants, taps
/// pointing at blocks by identity, completions with real timestamps.
///
/// `theFixtureStoreProducesTheFixturePeriod` runs `StatsQuery` over these rows
/// and asserts the answer equals that one. **That test is what makes the golden
/// file evidence about the app rather than evidence about a string function**:
/// without it, a beautiful document could be rendered from numbers no timer
/// ever produced.
///
/// So the two files have to describe the same fortnight, and the table in
/// `StatsPeriodFixture`'s own documentation is the authority on what it
/// contains. What follows is that fortnight expressed as rows.
///
/// ### The blocks
///
/// | # | Began | Ran | Kind | Task | Project | |
/// |---|---|---|---|---|---|---|
/// | 1 | Sat 8 Aug 09:15 | 25 min | work | `Ch.3 draft` | `Thesis` | |
/// | 2 | Sat 8 Aug 10:00 | 25 min | work | `Ch.3 draft` | `Thesis` | |
/// | 3 | Sat 8 Aug 10:25 | 5 min | short break | — | — | a break that ran to its end |
/// | 4 | Mon 10 Aug 10:45 | 25 min | work | `Reading · notes` | `Thesis` | |
/// | 5 | Mon 10 Aug 11:15 | 25 min | work | `Reading · notes` | `Thesis` | |
/// | 6 | Mon 10 Aug 12:00 | 25 min | work | `Reading · notes` | `Thesis` | |
/// | 7 | Wed 12 Aug 14:00 | 25 min | work | — | `Thesis` | a project with no task chosen |
/// | 8 | Wed 12 Aug 16:05 | 15 min | work | `Ch.3 draft` | `Thesis` | **stopped**, with a reason |
/// | 9 | Thu 13 Aug 10:57 | 5 min | short break | — | — | **stopped**, no reason |
/// | 10 | Thu 13 Aug 15:30 | 25 min | work | `Marta's feedback` | — | |
/// | 11 | Thu 13 Aug 16:10 | 25 min | work | `Marta's feedback` | — | |
/// | 12 | Tue 18 Aug 14:20 | 20 min | work | `Ch.3 draft` | `Thesis` | **stopped**, with a reason |
/// | 13 | Thu 20 Aug 23:50 | 25 min | work | `Ch.3 draft` | `Thesis` | **crosses midnight** |
///
/// ### The taps
///
/// | Block | When | Kind | Note |
/// |---|---|---|---|
/// | 1 | Sat 8 Aug 09:20 | internal | *kept re-reading the same paragraph* |
/// | 2 | Sat 8 Aug 10:14 | external | — |
/// | 4 | Mon 10 Aug 11:02 | internal | *went to look up a reference and ended up in email* |
/// | 10 | Thu 13 Aug 15:41 | external | *flatmate wanted the kitchen* |
/// | 12 | Tue 18 Aug 14:33 | external | *someone knocked* — inside a block that was stopped |
/// | 13 | **Fri 21 Aug 00:05** | internal | *worrying about the deadline instead of writing* |
///
/// The last one is the one to watch. It is tapped after midnight on Friday and
/// is counted on **Thursday**, because the block it was tapped in began on
/// Thursday. It still prints as `00:05`.
///
/// ### The completions
///
/// `Pick 1–3 MITs` is recurring and is closed on the 8th, twice on the 10th, on
/// the 12th and on the 20th. `Reading list for week 3` (10th) and `Send Marta
/// the outline` (20th) are one-offs.
///
/// ### One thing this fixture does that the shipped app does not
///
/// Several blocks here carry **both** a task title and a project title. The
/// timer copies whatever the session plan hands it, and today a planned *task*
/// is handed over with its title alone — `SessionPlanStore.attachment(for:)`
/// leaves both project columns empty for a task. So on real data every
/// task-attached block currently groups under *no project*.
///
/// That is a gap in the attachment path rather than in the counting, and
/// closing it is a change to what gets written down rather than to what gets
/// counted — which is why it is recorded here and in the pull request instead
/// of being quietly fixed inside a stats feature. The fixture is written the
/// way the record is *meant* to read so that the format can be reviewed against
/// a real-looking page; `aTaskAttachedBlockAsTheAppActuallyWritesItToday` in
/// `StatsCountingTests` pins what today's rows really produce.
@MainActor
enum StatsStoreFixture {
  // MARK: The calendar every fixture date is built in

  /// A fixed calendar and a fixed time zone.
  ///
  /// Pinned so that the day boundaries these tests assert on are the same on a
  /// laptop in London, on a build server in another zone, and in a simulator
  /// somebody has set to Tokyo. `StatsQuery` takes its calendar as an argument
  /// precisely so this is possible.
  static let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
    return calendar
  }()

  /// One instant, written the way a person says it.
  ///
  /// A date this calendar cannot build is a mistake in the fixture rather than
  /// something to paper over, so it is reported as a failure instead of being
  /// forced or silently replaced.
  static func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    var parts = DateComponents()
    parts.year = year
    parts.month = month
    parts.day = day
    parts.hour = hour
    parts.minute = minute
    guard let instant = calendar.date(from: parts) else {
      Issue.record("The fixture asked for \(year)-\(month)-\(day) \(hour):\(minute), which is not a date.")
      return Date(timeIntervalSinceReferenceDate: 0)
    }
    return instant
  }

  /// The day an instant falls on, in the fixture's calendar.
  static func day(_ year: Int, _ month: Int, _ day: Int) -> StatsDay {
    StatsDay.containing(at(year, month, day, 12, 0), in: calendar)
  }

  /// The fortnight, both ends included. The same span as
  /// `StatsPeriodFixture.range`.
  static var fortnightRange: StatsRange {
    StatsRange(first: day(2026, 8, 8), last: day(2026, 8, 21))
  }

  // MARK: Writing the fortnight

  /// Writes every row in the tables above into a context, and saves.
  static func writeFortnight(into context: ModelContext) throws {
    for block in fortnightBlocks {
      context.insert(block)
    }
    for tap in fortnightTaps {
      context.insert(tap)
    }
    for completion in fortnightCompletions {
      context.insert(completion)
    }
    try context.save()
  }

  /// The thirteen blocks.
  static var fortnightBlocks: [PomodoroSession] {
    [
      work(1, from: at(2026, 8, 8, 9, 15), task: chapterDraft, project: thesis),
      work(2, from: at(2026, 8, 8, 10, 0), task: chapterDraft, project: thesis),
      block(
        3,
        from: at(2026, 8, 8, 10, 25),
        to: at(2026, 8, 8, 10, 30),
        kind: .shortBreak),
      work(4, from: at(2026, 8, 10, 10, 45), task: readingNotes, project: thesis),
      work(5, from: at(2026, 8, 10, 11, 15), task: readingNotes, project: thesis),
      work(6, from: at(2026, 8, 10, 12, 0), task: readingNotes, project: thesis),
      work(7, from: at(2026, 8, 12, 14, 0), project: thesis),
      block(
        8,
        from: at(2026, 8, 12, 16, 5),
        to: at(2026, 8, 12, 16, 20),
        task: chapterDraft,
        project: thesis,
        stoppedBecause: "supervisor called and it ran long"),
      block(
        9,
        from: at(2026, 8, 13, 10, 57),
        to: at(2026, 8, 13, 11, 2),
        kind: .shortBreak,
        stopped: true),
      work(10, from: at(2026, 8, 13, 15, 30), task: martasFeedback),
      work(11, from: at(2026, 8, 13, 16, 10), task: martasFeedback),
      block(
        12,
        from: at(2026, 8, 18, 14, 20),
        to: at(2026, 8, 18, 14, 40),
        task: chapterDraft,
        project: thesis,
        stoppedBecause: "couldn't settle at all"),
      // The one that crosses midnight, and belongs entirely to Thursday.
      block(
        13,
        from: at(2026, 8, 20, 23, 50),
        to: at(2026, 8, 21, 0, 15),
        task: chapterDraft,
        project: thesis)
    ]
  }

  /// The six taps.
  static var fortnightTaps: [Distraction] {
    [
      tap(
        in: 1, at: at(2026, 8, 8, 9, 20), kind: .internalInterruption,
        note: "kept re-reading the same paragraph"),
      tap(in: 2, at: at(2026, 8, 8, 10, 14), kind: .externalInterruption),
      tap(
        in: 4, at: at(2026, 8, 10, 11, 2), kind: .internalInterruption,
        note: "went to look up a reference and ended up in email"),
      tap(
        in: 10, at: at(2026, 8, 13, 15, 41), kind: .externalInterruption,
        note: "flatmate wanted the kitchen"),
      tap(
        in: 12, at: at(2026, 8, 18, 14, 33), kind: .externalInterruption,
        note: "someone knocked"),
      tap(
        in: 13, at: at(2026, 8, 21, 0, 5), kind: .internalInterruption,
        note: "worrying about the deadline instead of writing")
    ]
  }

  /// The seven completions. The identifiers are deliberately distinctive
  /// strings rather than `"1"`, so that a test asserting no identifier reaches
  /// the exported document is proving something.
  static var fortnightCompletions: [CompletedTaskRecord] {
    let habitDays = [
      at(2026, 8, 8, 7, 30),
      at(2026, 8, 10, 7, 31),
      at(2026, 8, 10, 19, 0),
      at(2026, 8, 12, 7, 30),
      at(2026, 8, 20, 7, 30)
    ]
    return habitDays.map {
      CompletedTaskRecord(
        taskID: "td-task-habit-0001", titleSnapshot: habit, completedAt: $0, wasRecurring: true)
    } + [
      CompletedTaskRecord(
        taskID: "td-task-0002",
        titleSnapshot: "Reading list for week 3",
        completedAt: at(2026, 8, 10, 17, 0),
        wasRecurring: false),
      CompletedTaskRecord(
        taskID: "td-task-0003",
        titleSnapshot: "Send Marta the outline",
        completedAt: at(2026, 8, 20, 10, 0),
        wasRecurring: false)
    ]
  }

  /// A year of realistic rows: four blocks a day, five days a week, with taps
  /// and a daily habit closed on most of them.
  ///
  /// Used for one thing only — measuring how long `period(_:)` takes over a
  /// store the size the owner's phone will reach. The build contract sets the
  /// budget at one frame, sixteen milliseconds, and requires the measured
  /// number in the pull request rather than an assurance.
  ///
  /// - Returns: how many finished focus blocks were written.
  @discardableResult
  static func writeYear(into context: ModelContext, endingOn last: Date) -> Int {
    var written = 0
    var number = 100_000
    for dayOffset in 0..<365 {
      let midnight = calendar.startOfDay(for: last.addingTimeInterval(Double(-dayOffset) * 86_400))
      // Weekends off, which is what makes it realistic rather than uniform.
      let weekday = calendar.component(.weekday, from: midnight)
      guard weekday != 1, weekday != 7 else { continue }
      for slot in 0..<4 {
        number += 1
        let start = midnight.addingTimeInterval(Double(9 * 3600 + slot * 1_800))
        context.insert(block(number, from: start, to: start.addingTimeInterval(1_500), task: chapterDraft,
                             project: thesis))
        written += 1
        if slot.isMultiple(of: 2) {
          context.insert(tap(
            in: number, at: start.addingTimeInterval(600), kind: .internalInterruption, note: "drifted"))
        }
      }
      context.insert(CompletedTaskRecord(
        taskID: "td-task-habit-0001",
        titleSnapshot: habit,
        completedAt: midnight.addingTimeInterval(7 * 3600),
        wasRecurring: true))
    }
    return written
  }

  // MARK: The names, spelled the same way on both sides of the seam

  static let thesis = "Thesis"
  static let chapterDraft = "Ch.3 draft"
  static let readingNotes = "Reading · notes"
  static let martasFeedback = "Marta's feedback"
  static let habit = "Pick 1–3 MITs"

  // MARK: Building single rows

  /// One finished twenty-five minute focus block.
  static func work(
    _ number: Int,
    from start: Date,
    task: String? = nil,
    project: String? = nil) -> PomodoroSession {
    block(number, from: start, to: start.addingTimeInterval(25 * 60), task: task, project: project)
  }

  /// One finished-block row, with a stable identity so a tap can name it.
  ///
  /// The identity is built from a fixed pattern rather than being random, so a
  /// failing test prints something a person can match against the tables above.
  static func block(
    _ number: Int,
    from startedAt: Date,
    to endedAt: Date,
    kind: BlockKind = .work,
    task: String? = nil,
    project: String? = nil,
    stopped: Bool = false,
    stoppedBecause reason: String? = nil) -> PomodoroSession {
    PomodoroSession(
      id: identity(number),
      kind: kind,
      startedAt: startedAt,
      endedAt: endedAt,
      wasAbandoned: stopped || reason != nil,
      abandonReason: reason,
      taskID: task == nil ? nil : "td-task-block-\(number)",
      taskTitle: task,
      projectID: project == nil ? nil : "td-project-block-\(number)",
      projectTitle: project)
  }

  /// One tap, inside the block with that number.
  static func tap(
    in blockNumber: Int,
    at timestamp: Date,
    kind: DistractionKind,
    note: String? = nil) -> Distraction {
    Distraction(kind: kind, timestamp: timestamp, sessionID: identity(blockNumber), note: note)
  }

  /// A repeatable identity for block number `n`.
  ///
  /// Twelve digits, which is exactly the width of a UUID's last group — so the
  /// text is always a real identifier and the fallback below is unreachable. It
  /// is a fallback rather than an exclamation mark because this project bans the
  /// exclamation mark, and a fresh identity here would show up as a tap that
  /// matched no block rather than as a crash.
  static func identity(_ number: Int) -> UUID {
    UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", number))") ?? UUID()
  }
}
