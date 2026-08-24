import Foundation

/// The answer to one question about one span of days.
///
/// **This is the only thing anything in this feature is ever handed, and it is
/// the reason there can only be one counting rule.** `StatsQuery` produces one
/// of these and there is nothing else to ask it for. Look at what is stored: a
/// range and four arrays of finished values. There is no `PomodoroSession`
/// here, no `Distraction`, no `CompletedTaskRecord`, no identifier and no
/// database handle — so a screen or an exporter that wanted to count something
/// its own way would have nothing left to count. That is D15's requirement made
/// structural rather than asked for in a comment:
///
/// > *"Two counters that can disagree is how a number stops being trusted — and
/// > this is the number the whole app exists to produce."*
///
/// Every total below is **computed by adding up the rows**, never stored
/// alongside them. A stored total is a second answer, and a second answer can
/// be stale.
///
/// It holds no human-readable prose either. `nil` for a title means *there was
/// no task*, and the words for that belong to whoever is drawing — the screen
/// and the page each say it in their own voice, from one fact.
struct StatsPeriod: Sendable, Equatable {
  // MARK: What was asked

  /// The span of days this covers — as asked for, not as narrowed to the data.
  ///
  /// It stays as asked so that an empty fortnight can still say *which*
  /// fortnight was empty. `recordedSpan` is the other question.
  let range: StatsRange

  // MARK: What was found

  /// One row per day that has something on it, oldest first.
  let days: [StatsDayRow]

  /// One row per project, ordered by pomodoro count descending, then by name.
  let projects: [StatsProjectRow]

  /// Tasks ticked off in the span, oldest first.
  let completions: [StatsCompletion]

  /// Blocks stopped early in the span, oldest first. In no count anywhere.
  let stops: [StatsStop]

  // MARK: Nothing at all

  /// The answer for a span with nothing in it.
  ///
  /// Also what the query returns when a calendar cannot turn the range into
  /// instants — a wrong-but-honest empty page rather than a crash.
  static func empty(for range: StatsRange) -> StatsPeriod {
    StatsPeriod(range: range, days: [], projects: [], completions: [], stops: [])
  }

  /// True when nothing at all was recorded: no finished block, no tap, no
  /// completion and no stop.
  ///
  /// The document has a short form for exactly this case, and the boundary
  /// matters: a span holding three stops and no finished blocks is **not**
  /// empty. It has something to say.
  var isEmpty: Bool {
    days.isEmpty && projects.isEmpty && completions.isEmpty && stops.isEmpty
  }

  // MARK: The totals

  /// Finished focus blocks in the whole span. This is the number the app exists
  /// to produce, and `42 pomodoros` means exactly this.
  var pomodoroCount: Int { days.reduce(0) { $0 + $1.pomodoroCount } }

  /// The seconds those blocks actually ran for.
  ///
  /// Measured rather than assumed: a block genuinely cut short by the clock is
  /// counted at what it ran, not at its nominal length.
  var focusedSeconds: Int { days.reduce(0) { $0 + $1.focusedSeconds } }

  /// Internal taps in the whole span.
  var internalCount: Int { days.reduce(0) { $0 + $1.internalCount } }

  /// External taps in the whole span.
  var externalCount: Int { days.reduce(0) { $0 + $1.externalCount } }

  /// Every tap in the whole span, of either kind.
  var distractionCount: Int { internalCount + externalCount }

  /// The kinds of every tap in the span — what `DistractionTally.summary(of:)`
  /// takes, so the header line speaks the owner's own vocabulary.
  var distractionKinds: [DistractionKind] { days.flatMap(\.distractionKinds) }

  /// The span the data actually occupies, or nothing when there is no data.
  ///
  /// This is how *"everything"* gets a real pair of dates to put in a title and
  /// a filename without a second query being run against the database.
  var recordedSpan: StatsRange? {
    guard let first = days.first?.day, let last = days.last?.day else { return nil }
    return StatsRange(first: first, last: last)
  }

  // MARK: The three other ways to read the same rows

  /// Every task in the span as one flat list, ordered by pomodoro count
  /// descending, then by task title, then by project name.
  ///
  /// The same rows the projects hold, re-ordered. Nothing is recounted.
  var taskRows: [StatsTaskRow] {
    projects.flatMap(\.tasks).sorted(by: Self.taskRowIsBefore)
  }

  /// Every tap in the span, grouped by what was being worked on.
  ///
  /// Ordered by how many taps each group holds, descending, then by name. The
  /// entries inside a group stay in the order they happened.
  var distractionsByTask: [StatsDistractionGroup] {
    var order: [GroupKey] = []
    var entries: [GroupKey: [StatsDistractionEntry]] = [:]
    for day in days {
      for entry in day.distractions {
        let key = GroupKey(taskTitle: entry.taskTitle, projectTitle: entry.projectTitle)
        if entries[key] == nil { order.append(key) }
        entries[key, default: []].append(entry)
      }
    }
    return order
      .map {
        StatsDistractionGroup(
          taskTitle: $0.taskTitle, projectTitle: $0.projectTitle, entries: entries[$0] ?? [])
      }
      .sorted(by: Self.groupIsBefore)
  }

  /// Completions of tasks that were not recurring — things that are now
  /// finished (D21).
  var oneOffCompletions: [StatsCompletion] {
    completions.filter { $0.wasRecurring == false }
  }

  /// Completions of recurring tasks — habits kept, which Todoist has already
  /// scheduled again (D21).
  var repeatingCompletions: [StatsCompletion] {
    completions.filter(\.wasRecurring)
  }

  // MARK: Ordering, in one place

  /// Orders two names that may be missing.
  ///
  /// Present names are compared **by code point**, never by a localised
  /// comparison: code-point order is the same on a laptop, on a phone and on
  /// the build server, and a localised one is not — which would make a
  /// committed golden file churn for reasons that have nothing to do with
  /// readability. A missing name always sorts last, so *no task* is the final
  /// line of a section rather than the first.
  ///
  /// - Returns: a negative number when `lhs` sorts first, zero when they are
  ///   the same, a positive number when `rhs` sorts first.
  static func compareNames(_ lhs: String?, _ rhs: String?) -> Int {
    guard let lhs else { return rhs == nil ? 0 : 1 }
    guard let rhs else { return -1 }
    if lhs == rhs { return 0 }
    return lhs < rhs ? -1 : 1
  }

  /// **A thing with no name always sorts last, whatever its count.**
  ///
  /// This is the one place the order is not simply "busiest first", and it is
  /// deliberate. *No task* is a footnote — it is the residue of blocks worked
  /// before Todoist was connected, blocks attached to a project on its own, and
  /// blocks attached to nothing at all. Sorted by size it would frequently be
  /// the first line of a section, where it reads as the heading's answer rather
  /// than as its remainder. Pushed to the end it reads as what it is.
  ///
  /// - Returns: a negative number when only `lhs` has a name, a positive one
  ///   when only `rhs` does, and zero when they are alike — in which case the
  ///   caller carries on to the counts.
  static func compareNamed(_ lhs: Bool, _ rhs: Bool) -> Int {
    if lhs == rhs { return 0 }
    return lhs ? -1 : 1
  }

  /// Named projects first, busiest first inside that, then by name.
  ///
  /// Used by the query when it builds the rows and never applied a second time.
  static func projectIsBefore(_ lhs: StatsProjectRow, _ rhs: StatsProjectRow) -> Bool {
    let byNamed = compareNamed(lhs.title != nil, rhs.title != nil)
    if byNamed != 0 { return byNamed < 0 }
    if lhs.pomodoroCount != rhs.pomodoroCount { return lhs.pomodoroCount > rhs.pomodoroCount }
    return compareNames(lhs.title, rhs.title) < 0
  }

  /// Named tasks first, busiest first inside that, then by task title, then by
  /// project name.
  ///
  /// The last comparison is what makes the order total rather than nearly
  /// total: two projects can each hold a row with no task, and without it their
  /// order would be whatever the machine happened to do that day — which a
  /// byte-for-byte golden file would notice, on somebody else's machine, a week
  /// later.
  static func taskRowIsBefore(_ lhs: StatsTaskRow, _ rhs: StatsTaskRow) -> Bool {
    let byNamed = compareNamed(lhs.title != nil, rhs.title != nil)
    if byNamed != 0 { return byNamed < 0 }
    if lhs.pomodoroCount != rhs.pomodoroCount { return lhs.pomodoroCount > rhs.pomodoroCount }
    let byTitle = compareNames(lhs.title, rhs.title)
    if byTitle != 0 { return byTitle < 0 }
    return compareNames(lhs.projectTitle, rhs.projectTitle) < 0
  }

  /// Named groups first, most-interrupted first inside that, then by task
  /// title, then by project name.
  ///
  /// A group is unnamed only when it has **neither** a task nor a project. A
  /// group with a project and no task still has something to be called, and is
  /// ordered among the named ones.
  static func groupIsBefore(_ lhs: StatsDistractionGroup, _ rhs: StatsDistractionGroup) -> Bool {
    let lhsNamed = lhs.taskTitle != nil || lhs.projectTitle != nil
    let rhsNamed = rhs.taskTitle != nil || rhs.projectTitle != nil
    let byNamed = compareNamed(lhsNamed, rhsNamed)
    if byNamed != 0 { return byNamed < 0 }
    if lhs.count != rhs.count { return lhs.count > rhs.count }
    let byTitle = compareNames(lhs.taskTitle, rhs.taskTitle)
    if byTitle != 0 { return byTitle < 0 }
    return compareNames(lhs.projectTitle, rhs.projectTitle) < 0
  }

  // MARK: Private

  /// What a distraction group is keyed by: the pair, not one string.
  ///
  /// A task called *Thesis* and a block attached to the *Thesis* project with
  /// no task chosen are two different things that would otherwise collapse into
  /// one heading.
  private struct GroupKey: Hashable {
    let taskTitle: String?
    let projectTitle: String?
  }
}
