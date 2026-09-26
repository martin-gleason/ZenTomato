import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// A session plan replaced by a list the test wrote, so the plan's own answers are not the subject.
///
/// The count is half the point, exactly as it is in `SessionAttachmentTests`: *"a break is never
/// attached"* cannot be proved from a break's row alone, because a break could be unattached only
/// because the plan happened to be empty. Counting the questions proves the timer never asked.
@MainActor
private final class StubPlan: SessionAttaching {
  var queue: [SessionAttachment]
  private(set) var timesAsked = 0

  init(queue: [SessionAttachment]) {
    self.queue = queue
  }

  func takeNextAttachment() -> SessionAttachment? {
    timesAsked += 1
    return queue.isEmpty ? nil : queue.removeFirst()
  }
}

/// `F8-T5` — **the log survives a shaped sprint.** The task that protects the reason the app exists.
///
/// > *"Every pomodoro in a shaped sprint must attach to its Todoist item exactly as an ordinary one
/// > does; distraction taps and notes must record against the right block; the stats counts and the
/// > Markdown export must be unchanged in shape."* … *"If a scope decision ever threatens the log, the
/// > log wins."*
///
/// **THE WHOLE SUITE IS ONE COMPARISON, AND THAT IS THE DESIGN.** Every test below runs the *same*
/// sprint twice — once with a shape in the store and once with nothing in it — through the real engine
/// into a real store, and then asks whether the two records differ anywhere they should not. Asserting
/// the shaped run alone would prove that a shaped sprint produces *a* record; it would say nothing
/// about whether that record is the one an ordinary sprint produces, which is the entire claim.
///
/// **The two sprints are structurally identical and numerically different, on purpose.** A shape
/// fitted to 120 minutes is `22·5·22·5·22·5·22·17`; the shipped settings give `25·5·25·5·25·5·25·15`.
/// Eight blocks either way, four pomodoros either way — and 88 minutes of focus against 100. So a
/// difference in *shape* is a defect and a difference in *number* is the feature working, and no
/// assertion here can confuse the two.
@Suite("ShapedLog")
@MainActor
struct ShapedLogTests {
  // MARK: The two runs

  /// One finished block, as plain values.
  ///
  /// **THE ROWS ARE COPIED OUT AND THE `@Model` OBJECTS ARE NOT CARRIED, AND THAT IS NOT TIDINESS.**
  /// The first draft of this suite returned `[PomodoroSession]` from `run(_:)`. Every test then
  /// **crashed the test process** — `This model instance was destroyed by calling ModelContext.reset
  /// and is no longer usable` — because the container that owns those objects goes out of scope when
  /// `run(_:)` returns, and a SwiftData model instance is a live handle into a store rather than a
  /// value. Worse than the crash was what the harness then said: xcodebuild restarted, and reported
  /// **"1 test in 1 suite passed"** for a suite of four. That is this project's own recorded failure
  /// — `F13-M13`, where a crash was scored as a pass and three passing tests were named as failures —
  /// and a crashing test is therefore not a test that needs debugging, it is a test that has switched
  /// the instrument off.
  ///
  /// So the row is read out of the store while the store is alive, which is also the discipline
  /// `conventions.md` asks for anyway: read the output where it leaves the system.
  private struct BlockRow: Equatable {
    let id: UUID
    let kind: BlockKind
    let taskID: String?
    let taskTitle: String?
    let startedAt: Date
    let endedAt: Date
  }

  /// One distraction tap, as plain values. Same reason as `BlockRow`.
  private struct TapRow: Equatable {
    let sessionID: UUID
    let timestamp: Date
  }

  /// What one sprint left behind. Every field is a value; nothing here points into a closed store.
  private struct Record {
    let sessions: [BlockRow]
    let taps: [TapRow]
    let period: StatsPeriod
    let export: String
    let timesPlanAsked: Int
  }

  /// **A fixed instant in the fixture's own calendar**, so the exported page is the same on a laptop
  /// in London, on a build server in another zone, and in a simulator somebody has set to Tokyo.
  /// `StatsStoreFixture` states that rule for its own rows; this borrows both the rule and the
  /// calendar rather than keeping a second opinion about time.
  private static let startedAt = StatsStoreFixture.at(2026, 8, 10, 9, 0)

  private static let plannedTasks = [
    SessionAttachment(
      taskID: "t1", taskTitle: "Ch.3 draft", projectID: "p1", projectTitle: "Thesis"),
    SessionAttachment(
      taskID: "t2", taskTitle: "Reading · notes", projectID: "p1", projectTitle: "Thesis"),
    SessionAttachment(
      taskID: "t3", taskTitle: "Marta's feedback", projectID: nil, projectTitle: nil),
    SessionAttachment(
      taskID: "t4", taskTitle: "Ch.3 draft", projectID: "p1", projectTitle: "Thesis")
  ]

  /// Runs one whole sprint and reads back everything it wrote.
  ///
  /// - Parameter shape: the budget to fit a shape to, or `nil` for an ordinary sprint on the settings.
  ///
  /// The tap is recorded **inside the first focus block**, a third of the way in, so it lands on a
  /// block whose length differs between the two runs — a tap placed in the first minute would be
  /// inside both and would not exercise the thing that changed.
  private func run(shape budget: Int?) async throws -> Record {
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let clock = TestClock(now: Self.startedAt)
    let plan = StubPlan(queue: Self.plannedTasks)

    let settings = try AppSettings.current(in: context)
    settings.autoStartNextBlock = true
    try context.save()

    if let budget { harness.store.start(try ShapeFixture.shape(budget)) }
    let engine = TimerEngine(
      context: context, clock: clock, alarms: SpyAlarmScheduler(),
      attachments: plan, shapes: harness.store)

    // Eight blocks, each run to its own end. The first is started by hand, the way a person taps
    // Start; `boundaryReached()` is what the armed task would have called, and auto-start carries the
    // sprint from one block to the next after that.
    await engine.start()
    let blockCount = 8
    var tapped = false
    for _ in 0..<blockCount {
      let endsAt = try #require(engine.endsAt, "the sprint stopped before it had run \(blockCount) blocks")
      if !tapped {
        clock.advance(by: endsAt.timeIntervalSince(clock.now) / 3)
        #expect(engine.recordDistraction(.internalInterruption), "the tap was refused")
        tapped = true
      }
      clock.advance(by: endsAt.timeIntervalSince(clock.now))
      await engine.boundaryReached()
    }

    let query = StatsQuery(context: context, calendar: StatsStoreFixture.calendar)
    let period = query.period(.day(StatsStoreFixture.day(2026, 8, 10)))
    let blocks = try context.fetch(
      FetchDescriptor<PomodoroSession>(sortBy: [SortDescriptor(\.startedAt)]))
    let taps = try context.fetch(FetchDescriptor<Distraction>())
    return Record(
      sessions: blocks.map {
        BlockRow(
          id: $0.id, kind: $0.kind, taskID: $0.taskID, taskTitle: $0.taskTitle,
          startedAt: $0.startedAt, endedAt: $0.endedAt)
      },
      taps: taps.map { TapRow(sessionID: $0.sessionID, timestamp: $0.timestamp) },
      period: period,
      export: StatsMarkdown.document(for: period, producedBy: .forGoldens),
      timesPlanAsked: plan.timesAsked)
  }

  // MARK: The record is the same record

  /// **Every pomodoro in a shaped sprint attaches exactly as an ordinary one does**, and the plan is
  /// asked exactly as often.
  ///
  /// The titles are compared **as a list, in order**, rather than counted. A seam that attached the
  /// right number of blocks to the wrong items would pass a count and fail a person reading their own
  /// week back.
  @Test("everyPomodoroInAShapedSprintIsAttachedLikeAnOrdinaryOne")
  func everyPomodoroInAShapedSprintIsAttachedLikeAnOrdinaryOne() async throws {
    let shaped = try await run(shape: 120)
    let ordinary = try await run(shape: nil)

    func attachedTitles(_ record: Record) -> [String?] {
      record.sessions.filter { $0.kind == .work }.map(\.taskTitle)
    }
    #expect(attachedTitles(shaped) == attachedTitles(ordinary))
    #expect(attachedTitles(shaped) == ["Ch.3 draft", "Reading · notes", "Marta's feedback", "Ch.3 draft"])

    // A break is never attached, and the plan is never even asked about one — four questions for
    // four pomodoros, in both runs.
    #expect(shaped.timesPlanAsked == 4)
    #expect(shaped.timesPlanAsked == ordinary.timesPlanAsked)
    #expect(shaped.sessions.filter { $0.kind != .work }.allSatisfy { $0.taskID == nil })
  }

  /// **A tap taken inside a shaped block is filed against that block**, by the same rule an ordinary
  /// one follows: *a tap belongs to the block that owns the instant it happened, or to no block at all.*
  ///
  /// The tap goes in a third of the way through the first focus block, which is 7m20s into a shaped
  /// one and 8m20s into an ordinary one — inside a block whose length is the thing that differs.
  @Test("aTapInAShapedBlockIsFiledAgainstThatBlock")
  func aTapInAShapedBlockIsFiledAgainstThatBlock() async throws {
    let shaped = try await run(shape: 120)

    let tap = try #require(shaped.taps.first)
    #expect(shaped.taps.count == 1)
    let firstFocus = try #require(shaped.sessions.first { $0.kind == .work })
    #expect(tap.sessionID == firstFocus.id, "the tap is on the block that was running")
    // And it is genuinely inside that block rather than merely pointing at it, which a wrong
    // `sessionID` written from a stale variable would also do.
    #expect(tap.timestamp >= firstFocus.startedAt)
    #expect(tap.timestamp <= firstFocus.endedAt)
  }

  /// **The counts are what happened, not what the settings say.**
  ///
  /// This is the assertion that cannot pass for the wrong reason: four pomodoros either way, and
  /// **88 minutes of focus against 100**, because a shaped pomodoro is twenty-two minutes long and the
  /// log records the clock rather than the nominal length. `StatsMarkdown`'s own header says as much —
  /// *"a block cut short by the clock is not counted at its nominal twenty-five minutes."*
  @Test("theCountsAreWhatHappenedAndNotWhatTheSettingsSay")
  func theCountsAreWhatHappenedAndNotWhatTheSettingsSay() async throws {
    let shaped = try await run(shape: 120)
    let ordinary = try await run(shape: nil)

    #expect(shaped.period.pomodoroCount == 4)
    #expect(shaped.period.pomodoroCount == ordinary.period.pomodoroCount)
    #expect(shaped.period.focusedSeconds == 88 * 60)
    #expect(ordinary.period.focusedSeconds == 100 * 60)
    // Named rather than implied: the whole sprint fitted the budget it was given.
    let span = try #require(shaped.sessions.last).endedAt.timeIntervalSince(Self.startedAt)
    #expect(span == 120 * 60)
  }

  // MARK: The page is the same page

  /// **The shaped sprint's exported page has the same shape as an ordinary sprint's**, line for line,
  /// with only the numbers differing.
  ///
  /// **How the comparison works, and why it is not a golden file.** `StatsMarkdownGoldenTests` holds
  /// one page still against a committed file, and that is the right instrument for *"is this page
  /// readable"*. It is the wrong one here: these two pages are supposed to differ, in every number on
  /// them. So each is reduced to its skeleton — every run of digits becomes `N` — and the skeletons
  /// are compared. A page that grew a section, lost a table row, changed a heading, or started
  /// rendering a title differently fails; a page whose pomodoro ran 22 minutes instead of 25 does not.
  ///
  /// **THE FIXTURE'S PREMISE IS ASSERTED RATHER THAN ASSUMED, AND IT IS A REAL TRAP.**
  /// `StatsWords.duration` changes *shape* with the value: under an hour it says `"88 minutes"`, over
  /// one `"1 hour 28 minutes"`, and on the hour `"2 hours"`. Masking digits does not hide that — so a
  /// fixture whose two focus totals fell in different branches, or on different sides of a plural,
  /// would fail this test for a reason that is not a defect. 88 and 100 minutes both render as *one
  /// hour and some plural minutes*, which is why they were chosen; the two expectations below fail
  /// loudly if a later edit moves either total out of that branch, instead of leaving somebody to read
  /// a confusing diff.
  @Test("theShapedExportHasTheSameShapeAsAnOrdinaryOne")
  func theShapedExportHasTheSameShapeAsAnOrdinaryOne() async throws {
    let shaped = try await run(shape: 120)
    let ordinary = try await run(shape: nil)

    // The premise. Both totals must land in `duration`'s hours-and-minutes branch, plural on both
    // sides, or the skeletons differ for a reason that has nothing to do with the log.
    #expect(StatsWords.duration(seconds: shaped.period.focusedSeconds) == "1 hour 28 minutes")
    #expect(StatsWords.duration(seconds: ordinary.period.focusedSeconds) == "1 hour 40 minutes")

    let shapedSkeleton = Self.skeleton(shaped.export)
    let ordinarySkeleton = Self.skeleton(ordinary.export)
    #expect(
      shapedSkeleton == ordinarySkeleton,
      Comment(rawValue: Self.difference(shapedSkeleton, ordinarySkeleton)))

    // And the skeleton is not vacuous: a comparison of two blank strings would also pass.
    #expect(shapedSkeleton.contains("## "))
    #expect(shapedSkeleton.contains("Ch.N draft"), "the titles survive the masking")
    #expect(shaped.export != ordinary.export, "the two pages do differ — in their numbers")
  }

  /// Every run of digits replaced by one `N`, so two pages can be compared by structure.
  private static func skeleton(_ page: String) -> String {
    var out = ""
    var inDigits = false
    for character in page {
      if character.isNumber {
        if !inDigits { out.append("N") }
        inDigits = true
      } else {
        inDigits = false
        out.append(character)
      }
    }
    return out
  }

  /// The first line that differs, named, because a diff between two multi-line documents is unreadable
  /// as an equality failure. The same service `StatsMarkdownGoldenTests.difference` performs.
  private static func difference(_ produced: String, _ expected: String) -> String {
    let left = produced.split(separator: "\n", omittingEmptySubsequences: false)
    let right = expected.split(separator: "\n", omittingEmptySubsequences: false)
    for index in 0..<max(left.count, right.count) {
      let mine = index < left.count ? String(left[index]) : "<past the end>"
      let theirs = index < right.count ? String(right[index]) : "<past the end>"
      if mine != theirs { return "line \(index + 1)\n  shaped:   \(mine)\n  ordinary: \(theirs)" }
    }
    return "the two pages are identical"
  }
}
