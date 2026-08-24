import Foundation

// **These three types are `internal` rather than `private` only because they
// live in a file of their own.** They were `private` while they shared a file
// with `StatsQuery`, and moving them was forced by the 400-line file limit
// rather than chosen. Nothing outside `StatsQuery` uses them and nothing
// should: they are the counting rule's own scaffolding, and a second caller
// would be a second counting path — the one thing F6 exists to prevent.
//
// Note what did NOT move: `StatsQuery` is still the only file under `Stats/`
// that imports SwiftData. The buckets take rows that have already been fetched,
// which is what keeps the database in one place.

// MARK: - CountedBlock

/// One block that counts, and `nil` for every block that does not.
///
/// **This `init?` is the entire counting rule, in one place, with no second
/// copy anywhere in the app.** It used to be `fileprivate`, which made that
/// structural: no other file could hold one, so no other file could build a
/// total from one. It stopped being `fileprivate` when the 400-line limit forced
/// this type out of `StatsQuery.swift`, so the guarantee is now enforced by
/// `StatsFenceTests` rather than by the compiler — which is weaker, and worth
/// saying plainly rather than leaving a comment that claims a protection the
/// language is no longer providing.
struct CountedBlock {
  /// The day the block began.
  let day: StatsDay

  /// How long it actually ran, in whole seconds.
  let seconds: Int

  /// The task's title as it read when the block began, or nothing.
  let taskTitle: String?

  /// The project's name as it read when the block began, or nothing.
  let projectTitle: String?

  /// Todoist's identifier for the project, or nothing.
  ///
  /// **D22: this is what the export groups by, and it never leaves this file.**
  /// Grouping by the name splits one project into two headings when it is
  /// renamed part way through a fortnight, and each heading then under-reports —
  /// in a document whose whole purpose is aggregation. Grouping by the id merges
  /// them. The id stops here: `StatsProjectRow` and everything downstream carry
  /// a resolved *title* only, so no identifier can reach the page.
  let projectID: String?

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
    projectID = session.projectID
  }
}

// MARK: - BlockAttribution

/// Where a block sat and what it was attached to — kept for **every** block
/// fetched: the breaks, the stopped ones, and the ones from the extra day
/// before the span. This is how a tap inside a block that was later stopped
/// keeps its task and its day even though the block counts for nothing.
struct BlockAttribution {
  let day: StatsDay
  let taskTitle: String?
  let projectTitle: String?
  let projectID: String?

  init(_ session: PomodoroSession, calendar: Calendar) {
    day = StatsDay.containing(session.startedAt, in: calendar)
    taskTitle = session.taskTitle
    projectTitle = session.projectTitle
    projectID = session.projectID
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
struct PeriodAssembly {
  /// - Parameter liveNames: `project id -> current name`, read from the mirror
  ///   once so the whole answer is labelled from a single reading.
  init(liveNames: [String: String]) {
    self.liveNames = liveNames
  }

  // MARK: Adding

  /// A block that counted: one pomodoro, on one day, against one task.
  mutating func add(_ counted: CountedBlock) {
    days[counted.day, default: DayBucket()].pomodoros += 1
    days[counted.day, default: DayBucket()].seconds += counted.seconds
    let key = LeafKey(
      projectID: counted.projectID, projectTitle: counted.projectTitle, taskTitle: counted.taskTitle)
    note(project: key.projectKey, id: counted.projectID, snapshot: counted.projectTitle)
    leaves[key, default: Leaf()].pomodoros += 1
    leaves[key, default: Leaf()].seconds += counted.seconds
  }

  /// Remembers what a project group is called, so `finished` can label it.
  ///
  /// First writing wins for the snapshot, which makes the label deterministic
  /// rather than dependent on the order rows came back from the database.
  private mutating func note(project key: String?, id: String?, snapshot: String?) {
    guard names[key] == nil else { return }
    names[key] = ProjectNames(id: id, snapshot: snapshot)
  }

  /// A tap. Kept in the order it arrives, which is the order it happened.
  ///
  /// Taps are counted against the task they were tapped against **even when
  /// their block was later stopped**. The tap is a finished fact of its own,
  /// and the block you bailed out of is the most interesting one in the log.
  mutating func add(_ entry: StatsDistractionEntry, projectID: String?) {
    days[entry.day, default: DayBucket()].taps.append(entry)
    let key = LeafKey(
      projectID: projectID, projectTitle: entry.projectTitle, taskTitle: entry.taskTitle)
    note(project: key.projectKey, id: projectID, snapshot: entry.projectTitle)
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

  /// What to print at the head of a project group.
  ///
  /// The mirror's current name if the id still resolves there, otherwise the
  /// name recorded when the block ran, otherwise nothing — which the page prints
  /// as *No project*.
  private func label(for key: String?) -> String? {
    guard let names = names[key] else { return key }
    if let id = names.id, let live = liveNames[id] { return live }
    return names.snapshot
  }

  /// Turns the buckets into the finished answer.
  func finished(for range: StatsRange) -> StatsPeriod {
    var byProject: [String?: [StatsTaskRow]] = [:]
    for (key, leaf) in leaves {
      let label = label(for: key.projectKey)
      byProject[label, default: []].append(StatsTaskRow(
        title: key.taskTitle,
        projectTitle: label,
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
  ///
  /// **D22: the project half is an identifier, not a name.** Two blocks against
  /// the same project belong in one group even if it was renamed between them.
  /// `projectKey` falls back to the recorded name when there is no id, which is
  /// what every block written before D22 looks like — those rows have neither,
  /// so they group together under *no project* exactly as they did.
  private struct LeafKey: Hashable {
    let projectKey: String?
    let taskTitle: String?

    init(projectID: String?, projectTitle: String?, taskTitle: String?) {
      projectKey = projectID ?? projectTitle
      self.taskTitle = taskTitle
    }
  }

  /// What each project group should be called, and what it was called.
  ///
  /// **D22: the live name wins, the snapshot is the fallback.** A project keeps
  /// its identity when it is renamed, so a fortnight that spans a rename reads
  /// under the name the reader will recognise in their own sidebar. The snapshot
  /// is what answers when the id no longer resolves — and that is not a rare
  /// case: deleting a project in Todoist deletes it and all of its tasks, and the
  /// id then dangles for ever with no endpoint that will ever name it again.
  /// Without the snapshot, every block in a deleted project would degrade to
  /// *no project*, which is the very defect D22 exists to fix, arriving later by
  /// a different door.
  private struct ProjectNames {
    /// Todoist's id for the group, when it has one.
    var id: String?
    /// The name recorded on the row when the block ran.
    var snapshot: String?
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

  /// What each project group was called on the rows that formed it.
  private var names: [String?: ProjectNames] = [:]

  /// `project id -> the name it has in Todoist right now`, as mirrored on this
  /// device. Handed in when the assembly is made, so the whole answer is built
  /// from one reading of the mirror and two groups cannot disagree about a name.
  private let liveNames: [String: String]
  private var completions: [StatsCompletion] = []
  private var stops: [StatsStop] = []

  /// Makes a day exist without changing any of its numbers, so that a day whose
  /// only evidence is a stop or a completion still appears with its zeroes.
  private mutating func touch(_ day: StatsDay) {
    if days[day] == nil { days[day] = DayBucket() }
  }
}
