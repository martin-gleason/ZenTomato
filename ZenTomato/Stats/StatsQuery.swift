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
    var assembly = PeriodAssembly()
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
      assembly.add(entry)
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

// MARK: - CountedBlock

/// One block that counts, and `nil` for every block that does not.
///
/// **This `init?` is the entire counting rule, in one place, with no second
/// copy anywhere in the app.** It is `fileprivate` — visible only inside
/// `StatsQuery.swift` — so no other file can hold one, and therefore no other
/// file can build a total from one.
private struct CountedBlock {
  /// The day the block began.
  let day: StatsDay

  /// How long it actually ran, in whole seconds.
  let seconds: Int

  /// The task's title as it read when the block began, or nothing.
  let taskTitle: String?

  /// The project's name as it read when the block began, or nothing.
  let projectTitle: String?

  /// Decides whether a recorded block is a pomodoro, and where it belongs.
  ///
  /// The three rules `F6.md` states, in the order it states them:
  ///
  ///   * **Breaks are not pomodoros.** A rest is not work, however dutifully
  ///     it was taken.
  ///   * **Abandoned blocks count for nothing.** A sprint you bailed on is not
  ///     four pomodoros. They stay fully visible under *Stopped early*, with
  ///     the sentence the person wrote, and in no count anywhere.
  ///   * **A day is the local calendar day of the block's start.** A block
  ///     beginning at 23:50 and ending at 00:15 belongs entirely to the day it
  ///     began. `endedAt` is never handed to `StatsDay`, here or anywhere else.
  ///
  /// The length is measured rather than assumed, so a block genuinely cut short
  /// by the clock is counted at what it ran. It is clamped at zero because F5
  /// found and fixed a backward clock jump that could write a start after an
  /// end, and a negative number in the header would be the loudest possible
  /// symptom of the next one.
  init?(_ session: PomodoroSession, calendar: Calendar) {
    guard session.kind == .work else { return nil }
    guard session.wasAbandoned == false else { return nil }
    day = StatsDay.containing(session.startedAt, in: calendar)
    seconds = max(0, Int(session.endedAt.timeIntervalSince(session.startedAt)))
    taskTitle = session.taskTitle
    projectTitle = session.projectTitle
  }
}

// MARK: - BlockAttribution

/// Where a block sat and what it was attached to — kept for **every** block
/// fetched: the breaks, the stopped ones, and the ones from the extra day
/// before the span. This is how a tap inside a block that was later stopped
/// keeps its task and its day even though the block counts for nothing.
private struct BlockAttribution {
  let day: StatsDay
  let taskTitle: String?
  let projectTitle: String?

  init(_ session: PomodoroSession, calendar: Calendar) {
    day = StatsDay.containing(session.startedAt, in: calendar)
    taskTitle = session.taskTitle
    projectTitle = session.projectTitle
  }
}

// MARK: - PeriodAssembly

/// The buckets the answer is built up in, and the one place they are turned
/// into rows.
///
/// **Days and projects are filled from the same blocks and the same taps**, so
/// the two can only agree. Nothing here counts anything a second time: a block
/// adds one to a day and one to a task, and the totals on `StatsPeriod` are
/// sums over those rows rather than a third tally kept alongside them.
private struct PeriodAssembly {
  // MARK: Adding

  /// A block that counted: one pomodoro, on one day, against one task.
  mutating func add(_ counted: CountedBlock) {
    days[counted.day, default: DayBucket()].pomodoros += 1
    days[counted.day, default: DayBucket()].seconds += counted.seconds
    let key = LeafKey(projectTitle: counted.projectTitle, taskTitle: counted.taskTitle)
    leaves[key, default: Leaf()].pomodoros += 1
    leaves[key, default: Leaf()].seconds += counted.seconds
  }

  /// A tap. Kept in the order it arrives, which is the order it happened.
  ///
  /// Taps are counted against the task they were tapped against **even when
  /// their block was later stopped**. The tap is a finished fact of its own,
  /// and the block you bailed out of is the most interesting one in the log.
  mutating func add(_ entry: StatsDistractionEntry) {
    days[entry.day, default: DayBucket()].taps.append(entry)
    let key = LeafKey(projectTitle: entry.projectTitle, taskTitle: entry.taskTitle)
    switch entry.kind {
    case .internalInterruption: leaves[key, default: Leaf()].internalTaps += 1
    case .externalInterruption: leaves[key, default: Leaf()].externalTaps += 1
    }
  }

  /// A block somebody stopped. It joins no count — it only makes its day a day
  /// that has something on it, and adds one line to its own section.
  ///
  /// The day is the day the block **began**; the time is the moment it was
  /// stopped. One day rule everywhere beats a second rule that reads slightly
  /// better in one rare case.
  mutating func add(stop session: PomodoroSession, at placement: BlockAttribution, in calendar: Calendar) {
    stops.append(StatsStop(
      day: placement.day,
      time: StatsClockTime.at(session.endedAt, in: calendar),
      kind: session.kind,
      taskTitle: placement.taskTitle,
      projectTitle: placement.projectTitle,
      reason: session.abandonReason))
    touch(placement.day)
  }

  /// A task ticked off. Not a pomodoro, and never counted as one — it only
  /// makes its day a day that has something on it.
  mutating func add(_ completion: StatsCompletion) {
    completions.append(completion)
    touch(completion.day)
  }

  // MARK: Finishing

  /// Turns the buckets into the finished answer.
  func finished(for range: StatsRange) -> StatsPeriod {
    var byProject: [String?: [StatsTaskRow]] = [:]
    for (key, leaf) in leaves {
      byProject[key.projectTitle, default: []].append(StatsTaskRow(
        title: key.taskTitle,
        projectTitle: key.projectTitle,
        pomodoroCount: leaf.pomodoros,
        focusedSeconds: leaf.seconds,
        internalCount: leaf.internalTaps,
        externalCount: leaf.externalTaps))
    }

    return StatsPeriod(
      range: range,
      days: days
        .map {
          StatsDayRow(
            day: $0.key,
            pomodoroCount: $0.value.pomodoros,
            focusedSeconds: $0.value.seconds,
            distractions: $0.value.taps)
        }
        .sorted { $0.day < $1.day },
      projects: byProject
        .map { StatsProjectRow(title: $0.key, tasks: $0.value.sorted(by: StatsPeriod.taskRowIsBefore)) }
        .sorted(by: StatsPeriod.projectIsBefore),
      // Oldest first, then by title. Only the date is ever printed, so ordering
      // the same day's completions by name is both deterministic and the order
      // a reader would put them in themselves.
      completions: completions.sorted {
        $0.day == $1.day ? StatsPeriod.compareNames($0.title, $1.title) < 0 : $0.day < $1.day
      },
      // Left in the order the blocks were fetched, which is oldest first by the
      // moment each block began — the same order their printed days are in, and
      // a total order, so two stops in the same minute cannot swap places
      // between one run and the next.
      stops: stops)
  }

  // MARK: Private

  /// What a project and task pair is keyed by. Both halves may be absent, and
  /// the pair with neither is the group for blocks attached to nothing.
  private struct LeafKey: Hashable {
    let projectTitle: String?
    let taskTitle: String?
  }

  /// One task's running totals.
  private struct Leaf {
    var pomodoros = 0
    var seconds = 0
    var internalTaps = 0
    var externalTaps = 0
  }

  /// One day's running totals, and its taps in the order they happened.
  private struct DayBucket {
    var pomodoros = 0
    var seconds = 0
    var taps: [StatsDistractionEntry] = []
  }

  private var days: [StatsDay: DayBucket] = [:]
  private var leaves: [LeafKey: Leaf] = [:]
  private var completions: [StatsCompletion] = []
  private var stops: [StatsStop] = []

  /// Makes a day exist without changing any of its numbers, so that a day whose
  /// only evidence is a stop or a completion still appears with its zeroes.
  private mutating func touch(_ day: StatsDay) {
    if days[day] == nil { days[day] = DayBucket() }
  }
}
