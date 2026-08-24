import Foundation
import SwiftData

/// The one thing in this app that counts.
///
/// **There is exactly one method and it returns a finished answer.** That is
/// the whole design, and it is deliberate. There is no way to ask this type for
/// sessions, for distractions, for a context, or for "just today's number" — so
/// a screen that wanted to count something its own way would have to open the
/// database itself, which the fence in `StatsFenceTests` fails the build for.
/// Today's number on the stats screen is `period(.day(today)).pomodoroCount`,
/// the same function as everything else, because a second method for it is
/// exactly the second counter this file exists to prevent.
///
/// D15: *"Two counters that can disagree is how a number stops being trusted —
/// and this is the number the whole app exists to produce."*
///
/// **The rule itself is one failable initialiser**, `CountedBlock.init?` at the
/// bottom of this file. It is `fileprivate`, so no other file can hold one, so
/// no other file can build a total out of one. Its `nil` *is* the counting
/// rule: breaks are not pomodoros, stopped blocks count for nothing.
///
/// `@MainActor` — main-thread only — because it holds a `ModelContext`, and
/// those are not safe to share between threads. Everything it hands back is a
/// plain immutable value with no database row in it.
@MainActor
struct StatsQuery {
  // MARK: Lifecycle

  /// - Parameters:
  ///   - context: the app's database handle. Held, never copied.
  ///   - calendar: which calendar decides where a day starts. The real one by
  ///     default; a fixed one in tests, so a test asserting that a block
  ///     beginning at 23:50 counts on the day it began does not quietly depend
  ///     on where the machine running it is.
  init(context: ModelContext, calendar: Calendar = .current) {
    self.context = context
    self.calendar = calendar
  }

  // MARK: The only question

  /// Everything recorded in a span of days, counted once.
  ///
  /// Three database reads, each bounded by date in the query itself rather than
  /// by filtering afterwards, and none of them inside a loop. A fortnight is on
  /// the order of a hundred blocks and a few hundred taps.
  ///
  /// - Parameter range: the days to count, both ends included.
  /// - Returns: the finished answer. Empty when the calendar cannot turn the
  ///   range into instants — a wrong-but-visible empty page rather than a
  ///   crash.
  func period(_ range: StatsRange) -> StatsPeriod {
    guard let bounds = range.bounds(in: calendar) else { return .empty(for: range) }

    let blocks = fetchBlocks(in: bounds)
    var assembly = PeriodAssembly(liveNames: fetchProjectNames())
    var attribution: [UUID: BlockAttribution] = [:]

    for block in blocks {
      let placement = BlockAttribution(block, calendar: calendar)
      attribution[block.id] = placement
      // The read reaches one day further back than the span, so that a tap
      // made just after midnight can still find the block it belongs to. Those
      // extra blocks are here to be *recognised*, never to be counted: their
      // day is outside the span, and a span counts its own days.
      guard range.contains(placement.day) else { continue }
      if let counted = CountedBlock(block, calendar: calendar) {
        assembly.add(counted)
      }
      if block.wasAbandoned {
        assembly.add(stop: block, at: placement, in: calendar)
      }
    }

    for tap in fetchTaps(around: blocks, within: bounds) {
      guard let entry = Self.entry(for: tap, attribution: attribution, range: range, in: calendar)
      else { continue }
      // The id travels beside the entry rather than inside it: `StatsDistraction-
      // Entry` is one of the value types the exported page is built from, and
      // none of those may carry an identifier.
      assembly.add(entry, projectID: attribution[tap.sessionID]?.projectID)
    }

    for record in fetchCompletions(in: bounds) {
      assembly.add(StatsCompletion(
        day: StatsDay.containing(record.completedAt, in: calendar),
        title: record.titleSnapshot,
        wasRecurring: record.wasRecurring))
    }

    return assembly.finished(for: range)
  }

  // MARK: Private

  private let context: ModelContext
  private let calendar: Calendar

  /// Every block that began inside the span, **and the day before it**.
  ///
  /// The bound is on `startedAt` and on nothing else, because a block belongs
  /// entirely to the day it began. Half-open — `>= lower`, `< upper` — so a
  /// block beginning exactly at midnight lands in one span and one only.
  ///
  /// **The extra day at the start is the mirror of the widened tap window
  /// below.** A tap at 00:05 on the first day of the span may belong to a block
  /// that began at 23:50 the night before; without that block in hand the tap
  /// matches nothing and would be shown on the wrong day with no task against
  /// it. Those blocks are used to recognise taps and never to count anything —
  /// `period(_:)` drops any whose day is outside the span. A block cannot run
  /// for a whole day, so one day back is enough.
  ///
  /// **Neither `kind` nor `wasAbandoned` is in the predicate.** `BlockKind` is
  /// stored as a value SwiftData splits into marker columns, and F5's review
  /// was blocked once by exactly that on `DistractionKind`. The date bound is
  /// what makes the read cheap; which blocks count is decided in Swift, in
  /// `CountedBlock.init?`, which is where the rule belongs anyway.
  ///
  /// A refused read reads as "nothing recorded". That is visible on the screen
  /// as an empty span rather than being silently mixed into a wrong total, and
  /// it is the same shape every other read in this app takes.
  private func fetchBlocks(in bounds: StatsRange.Bounds) -> [PomodoroSession] {
    let lower = calendar.date(byAdding: .day, value: -1, to: bounds.lower) ?? bounds.lower
    let upper = bounds.upper
    let descriptor = FetchDescriptor<PomodoroSession>(
      predicate: #Predicate { $0.startedAt >= lower && $0.startedAt < upper },
      sortBy: [SortDescriptor(\.startedAt)])
    return (try? context.fetch(descriptor)) ?? []
  }

  /// `project id -> name`, as Todoist is mirrored on this device right now.
  ///
  /// **Read once per answer, so the whole page is labelled from one reading.**
  /// One unfiltered fetch of a table that holds a personal account's projects —
  /// tens of rows, not thousands — which is why it is not narrowed to the ids
  /// actually needed: building that filter would cost more than the fetch.
  ///
  /// A project the mirror has never seen, or one that has been archived and so
  /// no longer comes back when the mirror refreshes, simply has no entry here.
  /// That is not an error: the group falls back to the name recorded on the row,
  /// and the page still reads.
  private func fetchProjectNames() -> [String: String] {
    let mirrored = (try? context.fetch(FetchDescriptor<CachedProject>())) ?? []
    return Dictionary(mirrored.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
  }

  /// Every tap that could belong to one of those blocks.
  ///
  /// **The window is widened to the blocks, not to the calendar.** A tap at
  /// 00:05 belongs to a block that began at 23:50 the day before, so bounding
  /// the read at midnight would drop it — and it is counted on the earlier day,
  /// so dropping it would make the day's tally disagree with the taps listed
  /// under it. The widening is computed from the blocks already in hand, so
  /// this is still one bounded read rather than a scan of the one table in this
  /// app designed to grow for its whole life.
  private func fetchTaps(around blocks: [PomodoroSession], within bounds: StatsRange.Bounds) -> [Distraction] {
    let lower = min(bounds.lower, blocks.first?.startedAt ?? bounds.lower)
    let upper = max(bounds.upper, blocks.map(\.endedAt).max() ?? bounds.upper)
    let descriptor = FetchDescriptor<Distraction>(
      predicate: #Predicate { $0.timestamp >= lower && $0.timestamp < upper },
      sortBy: [SortDescriptor(\.timestamp)])
    return (try? context.fetch(descriptor)) ?? []
  }

  /// Every task ticked off inside the span.
  ///
  /// A completion belongs to the day it was recorded (D11), independently of any
  /// block. Completing a task is not a pomodoro and is never counted as one.
  private func fetchCompletions(in bounds: StatsRange.Bounds) -> [CompletedTaskRecord] {
    let lower = bounds.lower
    let upper = bounds.upper
    let descriptor = FetchDescriptor<CompletedTaskRecord>(
      predicate: #Predicate { $0.completedAt >= lower && $0.completedAt < upper },
      sortBy: [SortDescriptor(\.completedAt)])
    return (try? context.fetch(descriptor)) ?? []
  }

  /// Places one tap on a day and against a name.
  ///
  /// **The day comes from the block, the time comes from the tap.** That is
  /// `F6.md`'s rule — a distraction belongs to the work block it was tapped in,
  /// and through it to that block's task and project.
  ///
  /// A tap whose block is not among the ones fetched is **not dropped**. It is
  /// placed on the day of its own timestamp with no task and no project, which
  /// is what `Distraction.swift` promises: an unmatched row is shown as having
  /// no block rather than treated as an error. The engine has no path that
  /// produces one; the branch exists so that if one ever appears it is visible
  /// instead of deleted. Either way a tap is dropped when the day it lands on
  /// falls outside the span, which is not part of this answer.
  private static func entry(
    for tap: Distraction,
    attribution: [UUID: BlockAttribution],
    range: StatsRange,
    in calendar: Calendar) -> StatsDistractionEntry? {
    let time = StatsClockTime.at(tap.timestamp, in: calendar)
    guard let block = attribution[tap.sessionID] else {
      let day = StatsDay.containing(tap.timestamp, in: calendar)
      guard range.contains(day) else { return nil }
      return StatsDistractionEntry(
        day: day, time: time, kind: tap.kind, note: tap.note, taskTitle: nil, projectTitle: nil)
    }
    // Its block began the night before the span. The tap belongs to that day,
    // and that day is not part of this answer.
    guard range.contains(block.day) else { return nil }
    return StatsDistractionEntry(
      day: block.day,
      time: time,
      kind: tap.kind,
      note: tap.note,
      taskTitle: block.taskTitle,
      projectTitle: block.projectTitle)
  }
}
