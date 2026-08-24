import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// The counting rules from `docs/plans/F6.md`, one test each.
///
/// **Every test here fails if its rule is broken.** That is the whole standard
/// this file is held to: a test that would pass either way is worse than no
/// test, because it makes the rule look defended. Where the failure would be
/// silent rather than loud — a number that is simply wrong, with nothing to
/// notice — the test says so in its own words.
///
/// The rules, in `F6.md`'s order:
///
///   * a day is the local calendar day of the block's **start**;
///   * a pomodoro counts when it **completed** — stopped blocks count for
///     nothing;
///   * **breaks are not pomodoros**;
///   * a distraction belongs to the block it was tapped in, and through it to
///     that block's task and project;
///   * a completion belongs to the day it was recorded, and is never a
///     pomodoro;
///   * **names come from the snapshot on the row**, never resolved live;
///   * rows with no task group under the project, or under nothing.
///
/// `@MainActor` throughout: the database handle is main-thread only, and so is
/// everything that holds one.
@Suite("StatsCounting")
@MainActor
struct StatsCountingTests {
  private let container: ModelContainer

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  private var context: ModelContext {
    container.mainContext
  }

  private var query: StatsQuery {
    StatsQuery(context: context, calendar: StatsStoreFixture.calendar)
  }

  private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> StatsDay {
    StatsStoreFixture.day(year, month, dayOfMonth)
  }

  // MARK: The day boundary

  /// A block beginning at 23:50 and ending at 00:15 counts **once**, on the day
  /// it began.
  ///
  /// Both halves matter. Counting it on the later day would make an evening's
  /// work land on a day you had not started yet; counting it on both would make
  /// a fortnight's total larger than the number of blocks that were worked.
  /// This is also the reason `endedAt` is never handed to `StatsDay` anywhere
  /// in the tree.
  @Test("dayBoundaryUsesStart")
  func dayBoundaryUsesStart() throws {
    context.insert(StatsStoreFixture.block(
      1,
      from: StatsStoreFixture.at(2026, 8, 10, 23, 50),
      to: StatsStoreFixture.at(2026, 8, 11, 0, 15),
      task: "Ch.3 draft"))
    try context.save()

    let period = query.period(StatsRange(first: day(2026, 8, 10), last: day(2026, 8, 11)))

    #expect(period.pomodoroCount == 1)
    #expect(period.days.map(\.day) == [day(2026, 8, 10)])
    #expect(period.days.first?.pomodoroCount == 1)
    // Twenty-five minutes, measured across the midnight it crossed.
    #expect(period.focusedSeconds == 25 * 60)
  }

  /// A tap after midnight belongs to the day its **block** began, not to the
  /// day the clock said when it was tapped.
  ///
  /// Getting this wrong would put the tap on a day whose pomodoro count does
  /// not include the block it interrupted — so a day would say *one internal*
  /// with nothing to have been internal about, and the day above it would show
  /// a block with a tally that omitted a tap. Two wrong numbers, neither of
  /// them obviously wrong.
  @Test("aTapAfterMidnightBelongsToTheBlocksDay")
  func aTapAfterMidnightBelongsToTheBlocksDay() throws {
    context.insert(StatsStoreFixture.block(
      1,
      from: StatsStoreFixture.at(2026, 8, 10, 23, 50),
      to: StatsStoreFixture.at(2026, 8, 11, 0, 15),
      task: "Ch.3 draft"))
    context.insert(StatsStoreFixture.tap(
      in: 1, at: StatsStoreFixture.at(2026, 8, 11, 0, 5), kind: .internalInterruption, note: "drifted"))
    try context.save()

    let period = query.period(StatsRange(first: day(2026, 8, 10), last: day(2026, 8, 11)))
    let monday = try #require(period.days.first)

    #expect(period.days.count == 1)
    #expect(monday.day == day(2026, 8, 10))
    #expect(monday.internalCount == 1)
    // The printed time is still the time of the tap itself.
    #expect(monday.distractions.first?.time == StatsClockTime(hour: 0, minute: 5))
  }

  // MARK: What counts, and what does not

  /// Stopped blocks are absent from every count.
  ///
  /// `42 pomodoros` means blocks you finished (D15). A stopped block still
  /// appears — under *Stopped early*, with the sentence the person wrote — but
  /// it is in no total anywhere, and it contributes no time.
  @Test("abandonedExcluded")
  func abandonedExcluded() throws {
    context.insert(StatsStoreFixture.block(
      1,
      from: StatsStoreFixture.at(2026, 8, 19, 9, 0),
      to: StatsStoreFixture.at(2026, 8, 19, 9, 25),
      task: "Ch.3 draft"))
    context.insert(StatsStoreFixture.block(
      2,
      from: StatsStoreFixture.at(2026, 8, 19, 10, 0),
      to: StatsStoreFixture.at(2026, 8, 19, 10, 12),
      task: "Ch.3 draft",
      stoppedBecause: "supervisor called and it ran long"))
    try context.save()

    let period = query.period(.day(day(2026, 8, 19)))

    #expect(period.pomodoroCount == 1)
    #expect(period.focusedSeconds == 25 * 60)
    #expect(period.taskRows.first?.pomodoroCount == 1)
    // And it is visible, in the one place it belongs.
    #expect(period.stops.count == 1)
    #expect(period.stops.first?.reason == "supervisor called and it ran long")
    #expect(period.stops.first?.title == "Ch.3 draft")
  }

  /// Breaks are not pomodoros, however dutifully they were taken.
  @Test("breaksNotCounted")
  func breaksNotCounted() throws {
    context.insert(StatsStoreFixture.block(
      1,
      from: StatsStoreFixture.at(2026, 8, 19, 9, 0),
      to: StatsStoreFixture.at(2026, 8, 19, 9, 25),
      task: "Ch.3 draft"))
    context.insert(StatsStoreFixture.block(
      2,
      from: StatsStoreFixture.at(2026, 8, 19, 9, 25),
      to: StatsStoreFixture.at(2026, 8, 19, 9, 30),
      kind: .shortBreak))
    context.insert(StatsStoreFixture.block(
      3,
      from: StatsStoreFixture.at(2026, 8, 19, 12, 0),
      to: StatsStoreFixture.at(2026, 8, 19, 12, 15),
      kind: .longBreak))
    try context.save()

    let period = query.period(.day(day(2026, 8, 19)))

    #expect(period.pomodoroCount == 1)
    // Nor does a break's twenty minutes appear as focused time.
    #expect(period.focusedSeconds == 25 * 60)
  }

  /// A tap recorded inside a block that was later stopped still counts, where
  /// it was tapped.
  ///
  /// **This is a decision `F6.md` does not make**, taken in the build contract
  /// and named in the pull request so the owner can rule otherwise. The tap is
  /// a finished fact of its own; the block you bailed out of is the most
  /// interesting one in the log; and D15's sentence about exclusion is about
  /// the pomodoro count specifically. Excluding them would quietly delete the
  /// taps that most likely explain the stop three sections below.
  ///
  /// If the owner rules the other way this test is what changes, and the whole
  /// change is one line in `StatsQuery`.
  @Test("tapsInsideAStoppedBlockStillCount")
  func tapsInsideAStoppedBlockStillCount() throws {
    context.insert(StatsStoreFixture.block(
      1,
      from: StatsStoreFixture.at(2026, 8, 13, 16, 20),
      to: StatsStoreFixture.at(2026, 8, 13, 16, 32),
      task: "Reading",
      stoppedBecause: "supervisor called and it ran long"))
    context.insert(StatsStoreFixture.tap(
      in: 1, at: StatsStoreFixture.at(2026, 8, 13, 16, 25), kind: .externalInterruption))
    try context.save()

    let period = query.period(.day(day(2026, 8, 13)))

    #expect(period.pomodoroCount == 0)
    #expect(period.externalCount == 1)
    // It keeps the stopped block's task, which is the point of keeping an
    // attribution for blocks that count for nothing.
    #expect(period.taskRows.first?.title == "Reading")
    #expect(period.taskRows.first?.externalCount == 1)
    #expect(period.taskRows.first?.pomodoroCount == 0)
  }

  // MARK: Names

  /// The names in the answer are the ones written down when the block ran, even
  /// when the local copy of Todoist now says something else.
  ///
  /// **The test would pass on an app that resolved names live, were it not for
  /// the cached row.** That row is here on purpose: it says *Chapter three,
  /// final* under the same identifier, so anything that looked the name up
  /// instead of reading it off the block would report the new one and fail.
  /// A fortnight-old review has to show what was true then.
  @Test("snapshotNamesUsed")
  func snapshotNamesUsed() throws {
    context.insert(StatsStoreFixture.block(
      1,
      from: StatsStoreFixture.at(2026, 8, 19, 9, 0),
      to: StatsStoreFixture.at(2026, 8, 19, 9, 25),
      task: "Ch.3 draft"))
    context.insert(CachedTask(
      id: "td-task-block-1",
      content: "Chapter three, final",
      projectID: "td-project-0001",
      sectionID: nil,
      childOrder: 0,
      syncedAt: StatsStoreFixture.at(2026, 8, 23, 9, 0)))
    try context.save()

    let period = query.period(.day(day(2026, 8, 19)))

    #expect(period.taskRows.map(\.title) == ["Ch.3 draft"])
  }

  /// Blocks with no task do not vanish. They group under their project, or
  /// under nothing at all, and they are rendered plainly rather than as an
  /// error.
  ///
  /// Three shapes exist in real data and all three are here: a block attached
  /// to a task, a block attached to a project on its own, and a block attached
  /// to neither — which is every block worked before Todoist was connected.
  @Test("noTaskRowsGroupUnderProject")
  func noTaskRowsGroupUnderProject() throws {
    context.insert(StatsStoreFixture.block(
      1,
      from: StatsStoreFixture.at(2026, 8, 19, 9, 0),
      to: StatsStoreFixture.at(2026, 8, 19, 9, 25),
      task: "Ch.3 draft"))
    context.insert(StatsStoreFixture.block(
      2,
      from: StatsStoreFixture.at(2026, 8, 19, 10, 0),
      to: StatsStoreFixture.at(2026, 8, 19, 10, 25),
      project: "Admin"))
    context.insert(StatsStoreFixture.block(
      3,
      from: StatsStoreFixture.at(2026, 8, 19, 11, 0),
      to: StatsStoreFixture.at(2026, 8, 19, 11, 25)))
    try context.save()

    let period = query.period(.day(day(2026, 8, 19)))

    #expect(period.pomodoroCount == 3)

    // The named project comes first and holds one row, with no task on it.
    let admin = try #require(period.projects.first)
    #expect(admin.title == "Admin")
    #expect(admin.pomodoroCount == 1)
    #expect(admin.tasks.map(\.title) == [nil])

    // The group for blocks that recorded no project holds both of the others,
    // and the unnamed row is last inside it.
    let unattached = try #require(period.projects.last)
    #expect(unattached.title == nil)
    #expect(unattached.pomodoroCount == 2)
    #expect(unattached.tasks.map(\.title) == ["Ch.3 draft", nil])
  }

  /// A task the mirror has never heard of still records what it can.
  ///
  /// **This test used to pin a defect, and its history is worth keeping.** Before
  /// D22, `SessionPlanStore.attachment(for:)` handed over a planned *task* with
  /// its title alone and both project columns empty — so every task-attached
  /// block grouped under *no project*, and the export's `## Projects` section,
  /// whose whole job is "where the time went", read as one unnamed heading with
  /// everything under it. The comment here said the day it was fixed this test
  /// would start failing.
  ///
  /// **It did not fail, and that is the lesson.** The fix reads the project from
  /// the local Todoist mirror, and this test seeds no mirror rows — so it was
  /// never exercising the shipped path at all. It was describing the fallback and
  /// calling it "what the app does today". A test can be honest about the wrong
  /// thing.
  ///
  /// So it is kept, renamed for what it actually covers, and the real case is
  /// tested separately in `aTaskCarriesItsProjectWhenTheMirrorKnowsIt`. What it
  /// still guarantees is worth guaranteeing: a task the mirror cannot resolve —
  /// nothing synced yet, or the row swept after being finished elsewhere — starts
  /// a block anyway, with its own title and no project. A block that records what
  /// it can beats one that refuses to begin.
  @Test("aTaskWithNoMirrorRowRecordsWhatItCan")
  func aTaskWithNoMirrorRowRecordsWhatItCan() throws {
    let plan = SessionPlanStore(context: context)
    plan.replacePlan(with: [.init(todoistID: "t1", titleSnapshot: "Ch.3 draft", kind: .task)])
    let attachment = try #require(plan.takeNextAttachment())

    // The plan's own answer, before the timer copies it onto a row.
    #expect(attachment.taskTitle == "Ch.3 draft")
    #expect(attachment.projectTitle == nil)

    context.insert(PomodoroSession(
      id: StatsStoreFixture.identity(1),
      kind: .work,
      startedAt: StatsStoreFixture.at(2026, 8, 19, 9, 0),
      endedAt: StatsStoreFixture.at(2026, 8, 19, 9, 25),
      wasAbandoned: false,
      taskID: attachment.taskID,
      taskTitle: attachment.taskTitle,
      projectID: attachment.projectID,
      projectTitle: attachment.projectTitle))
    try context.save()

    let period = query.period(.day(day(2026, 8, 19)))

    #expect(period.pomodoroCount == 1)
    #expect(period.projects.map(\.title) == [nil])
    #expect(period.projects.first?.tasks.map(\.title) == ["Ch.3 draft"])
  }

  // MARK: Time

  /// A block is counted at what it ran, not at what it was supposed to run.
  ///
  /// And never at less than nothing: F5 found and fixed a backward clock jump
  /// that could write a start after an end, and a negative number in the header
  /// would be the loudest possible symptom of the next one.
  @Test("focusedTimeIsMeasuredAndNeverNegative")
  func focusedTimeIsMeasuredAndNeverNegative() throws {
    // A block cut short by the clock: nineteen minutes, not twenty-five.
    context.insert(StatsStoreFixture.block(
      1,
      from: StatsStoreFixture.at(2026, 8, 19, 9, 0),
      to: StatsStoreFixture.at(2026, 8, 19, 9, 19),
      task: "Ch.3 draft"))
    // A row whose end is before its start. Nothing writes one today; if
    // anything ever does, it contributes zero rather than subtracting.
    context.insert(StatsStoreFixture.block(
      2,
      from: StatsStoreFixture.at(2026, 8, 19, 14, 0),
      to: StatsStoreFixture.at(2026, 8, 19, 13, 0),
      task: "Ch.3 draft"))
    try context.save()

    let period = query.period(.day(day(2026, 8, 19)))

    #expect(period.pomodoroCount == 2)
    #expect(period.focusedSeconds == 19 * 60)
  }

  // MARK: Completions

  /// A completion is not a pomodoro, and never becomes one.
  @Test("aCompletionIsNeverCountedAsAPomodoro")
  func aCompletionIsNeverCountedAsAPomodoro() throws {
    context.insert(CompletedTaskRecord(
      taskID: "td-task-0001",
      titleSnapshot: "Reading list for week 3",
      completedAt: StatsStoreFixture.at(2026, 8, 19, 17, 0),
      wasRecurring: false))
    try context.save()

    let period = query.period(.day(day(2026, 8, 19)))

    #expect(period.pomodoroCount == 0)
    #expect(period.completions.count == 1)
    #expect(period.days.map(\.day) == [day(2026, 8, 19)])
    #expect(period.days.first?.pomodoroCount == 0)
    #expect(period.isEmpty == false)
  }
}
