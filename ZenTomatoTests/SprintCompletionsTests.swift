import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// D21b: a task ticked off during a sprint does not come back into it.
///
/// The rule is small and the ways of getting it wrong are asymmetric.
/// **Over-clearing is harmless** — the worst it does is offer back a task you
/// finished five minutes before a long break. **Under-clearing is the bug the
/// whole thing exists to fix**: you are handed work you have already done. So
/// every resting state the timer can reach has its own test here, and the
/// tests drive the real engine rather than asserting on a boolean somebody
/// wrote down.
///
/// `@MainActor`: the engine, the plan and the set are all main-thread only.
@Suite("SprintCompletions")
@MainActor
struct SprintCompletionsTests {
  private let container: ModelContainer
  private let clock: TestClock
  private let alarms: SpyAlarmScheduler
  private let engine: TimerEngine
  private let completed: SprintCompletions
  private let observer: SprintBoundaryObserver

  init() throws {
    let clock = TestClock()
    let alarms = SpyAlarmScheduler()
    let container = try TestStore.inMemoryContainer()
    let completed = SprintCompletions()
    let engine = TimerEngine(context: container.mainContext, clock: clock, alarms: alarms)
    self.clock = clock
    self.alarms = alarms
    self.container = container
    self.completed = completed
    self.engine = engine
    observer = SprintBoundaryObserver(engine: engine, completions: completed)
  }

  private var context: ModelContext {
    container.mainContext
  }

  // MARK: The set itself

  /// Recording, asking and emptying, and nothing else.
  @Test("theSetHoldsWhatWasRecordedAndNothingMore")
  func theSetHoldsWhatWasRecordedAndNothingMore() {
    #expect(completed.contains("t1") == false)

    completed.record(taskID: "t1")
    completed.record(taskID: "t1")

    #expect(completed.contains("t1"))
    #expect(completed.contains("t2") == false)
    #expect(completed.taskIDs == ["t1"])

    completed.clear()
    #expect(completed.taskIDs.isEmpty)
    // Clearing an empty set is a no-op rather than a failure, because the thing
    // watching the timer may see the same resting state more than once.
    completed.clear()
    #expect(completed.taskIDs.isEmpty)
  }

  /// Nothing about D21b is saved.
  ///
  /// A second store of the same fact is a second thing that can disagree with
  /// the first, and `CompletedTaskRecord` is already the history. So a fresh
  /// instance — which is what a new launch produces — knows nothing.
  @Test("nothingAboutD21bIsSaved")
  func nothingAboutD21bIsSaved() throws {
    completed.record(taskID: "t1")
    try context.save()

    #expect(SprintCompletions().taskIDs.isEmpty)
    // And no new kind of row appeared in the database to hold it.
    #expect(try context.fetch(FetchDescriptor<SessionPlanItem>()).isEmpty)
  }

  // MARK: What ends a sprint

  /// A long break ending empties the set.
  ///
  /// Driven through the real cycle with a sprint of one: focus block, long
  /// break, and the engine comes to rest with the sprint over.
  @Test("theSetEmptiesWhenALongBreakEnds")
  func theSetEmptiesWhenALongBreakEnds() async throws {
    let settings = try AppSettings.current(in: context)
    settings.pomodorosPerSprint = 1
    try context.save()

    await engine.start()
    completed.record(taskID: "t1")
    #expect(completed.contains("t1"))

    // The focus block runs out, and the long break it earned begins.
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()
    #expect(engine.kind == .longBreak)
    observer.evaluate()
    // Still mid-sprint: a break is part of the sprint it ends.
    #expect(completed.contains("t1"))

    await engine.start()
    clock.advance(by: 15 * 60)
    await engine.boundaryReached()

    #expect(engine.isRunning == false)
    #expect(engine.completedInSprint == 0)
    observer.evaluate()
    #expect(completed.taskIDs.isEmpty)
  }

  /// Stopping empties the set, because stopping ends the sprint.
  @Test("stoppingEmptiesTheSet")
  func stoppingEmptiesTheSet() async throws {
    await engine.start()
    completed.record(taskID: "t1")

    await engine.stop(reason: "too tired to take any of it in")

    #expect(engine.isRunning == false)
    #expect(engine.completedInSprint == 0)
    observer.evaluate()
    #expect(completed.taskIDs.isEmpty)
  }

  /// A boundary in the middle of a sprint does **not** empty the set.
  ///
  /// This is the one that matters. With auto-start switched off the timer comes
  /// to rest between two blocks of a live sprint — at rest, but mid-sprint —
  /// and a rule that only asked whether the timer was running would clear here
  /// and hand back the task you finished ten minutes ago. What tells the two
  /// apart is that a finished focus block has already been counted.
  @Test("aBoundaryMidSprintDoesNotEmptyTheSet")
  func aBoundaryMidSprintDoesNotEmptyTheSet() async throws {
    let settings = try AppSettings.current(in: context)
    settings.pomodorosPerSprint = 4
    settings.autoStartNextBlock = false
    try context.save()

    await engine.start()
    completed.record(taskID: "t1")

    clock.advance(by: 25 * 60)
    await engine.boundaryReached()

    #expect(engine.isRunning == false)
    #expect(engine.kind == .shortBreak)
    #expect(engine.completedInSprint == 1)
    observer.evaluate()
    #expect(completed.contains("t1"))
  }

  /// A timer that has never been started is not in a sprint, so evaluating is
  /// harmless.
  @Test("aTimerThatHasNeverRunClearsHarmlessly")
  func aTimerThatHasNeverRunClearsHarmlessly() {
    #expect(SprintBoundaryObserver.sprintHasEnded(isRunning: false, completedInSprint: 0))
    #expect(SprintBoundaryObserver.sprintHasEnded(isRunning: false, completedInSprint: 2) == false)
    #expect(SprintBoundaryObserver.sprintHasEnded(isRunning: true, completedInSprint: 0) == false)
    #expect(SprintBoundaryObserver.sprintHasEnded(isRunning: true, completedInSprint: 3) == false)
  }

  /// The live subscription really does follow the timer, with nothing waiting
  /// and nothing polled.
  ///
  /// `evaluate()` is what the other tests drive, because it is the rule. This
  /// one exercises the plumbing around it once: start following, stop a sprint,
  /// and let the observation loop deliver on its own.
  @Test("theLiveSubscriptionClearsWithoutBeingAsked")
  func theLiveSubscriptionClearsWithoutBeingAsked() async {
    observer.start()
    defer { observer.stop() }

    await engine.start()
    completed.record(taskID: "t1")
    #expect(completed.contains("t1"))

    await engine.stop(reason: "fire alarm")
    await settle(until: { completed.taskIDs.isEmpty })

    #expect(completed.taskIDs.isEmpty)
  }

  // MARK: How it reaches the plan

  /// The plan steps over a task ticked off this sprint and hands over the next
  /// one.
  ///
  /// The cursor moves; the item is not removed, not marked and not reordered.
  /// That is the existing step-over, which is what keeps `SessionPlanItem` at
  /// four columns — D17's fence, and exactly the fence D21b would erode if it
  /// were built as a flag on an item.
  @Test("thePlanStepsOverATaskCompletedThisSprint")
  func thePlanStepsOverATaskCompletedThisSprint() throws {
    let plan = SessionPlanStore(context: context, completedThisSprint: completed)
    plan.replacePlan(with: [
      .init(todoistID: "t1", titleSnapshot: "Ch.3 draft", kind: .task),
      .init(todoistID: "t2", titleSnapshot: "Reading", kind: .task),
      .init(todoistID: "t3", titleSnapshot: "Lab report", kind: .task)
    ])

    completed.record(taskID: "t1")
    completed.record(taskID: "t2")

    let attachment = plan.takeNextAttachment()

    #expect(attachment?.taskTitle == "Lab report")
    // Everything up to and including the item taken is behind the cursor now.
    #expect(plan.currentIndex == 3)
    // And nothing was deleted: the plan is still a record of what was intended.
    #expect(plan.items.map(\.titleSnapshot) == ["Ch.3 draft", "Reading", "Lab report"])

    // Read back from the database, so the moved cursor really was written.
    let reread = SessionPlanStore(context: context, completedThisSprint: completed)
    #expect(reread.currentIndex == 3)
  }

  /// A whole plan already ticked off leaves the block with nothing attached,
  /// which is an ordinary block.
  @Test("aPlanEntirelyCompletedThisSprintAttachesNothing")
  func aPlanEntirelyCompletedThisSprintAttachesNothing() throws {
    let plan = SessionPlanStore(context: context, completedThisSprint: completed)
    plan.replacePlan(with: [.init(todoistID: "t1", titleSnapshot: "Ch.3 draft", kind: .task)])
    completed.record(taskID: "t1")

    #expect(plan.takeNextAttachment() == nil)
    #expect(plan.currentIndex == 1)
  }

  /// A **project** is never stepped over. D21b is about tasks, and only a task
  /// can be ticked off.
  ///
  /// Todoist's identifiers are opaque, so a project id and a task id are
  /// indistinguishable — which is exactly why the plan records which of the two
  /// each item is, and why this test exists: a rule that matched on the string
  /// alone would silently skip a project that happened to share an id with a
  /// completed task.
  @Test("aProjectIsNeverSteppedOver")
  func aProjectIsNeverSteppedOver() throws {
    let plan = SessionPlanStore(context: context, completedThisSprint: completed)
    plan.replacePlan(with: [.init(todoistID: "t1", titleSnapshot: "Admin", kind: .project)])
    completed.record(taskID: "t1")

    let attachment = plan.takeNextAttachment()

    #expect(attachment?.projectTitle == "Admin")
    #expect(attachment?.taskTitle == nil)
  }

  /// A new plan drops anything already ticked off this sprint.
  ///
  /// Belt and braces: the picker does not offer those tasks in the first place.
  /// It is one line so that the rule belongs to the store rather than to a
  /// screen, and a second way into the plan added later cannot quietly
  /// reintroduce work already done.
  @Test("anewPlanDropsWhatWasAlreadyCompleted")
  func anewPlanDropsWhatWasAlreadyCompleted() throws {
    completed.record(taskID: "t1")
    let plan = SessionPlanStore(context: context, completedThisSprint: completed)

    plan.replacePlan(with: [
      .init(todoistID: "t1", titleSnapshot: "Ch.3 draft", kind: .task),
      .init(todoistID: "t2", titleSnapshot: "Reading", kind: .task)
    ])

    #expect(plan.items.map(\.titleSnapshot) == ["Reading"])
    #expect(plan.items.map(\.position) == [0])
  }

  // MARK: Helpers

  /// Lets any work the observation loop started finish, without sleeping.
  private func settle(until isSettled: () -> Bool, limit: Int = 10_000) async {
    for _ in 0..<limit where !isSettled() {
      await Task.yield()
    }
  }

  // MARK: The two places the rule actually takes effect

  /// `theOnlyWriteAndTheOnlyReadAreBothStillWiredUp` — D21b's set is written from
  /// the completion path and read by the picker, and neither line may quietly go
  /// away.
  ///
  /// **WHY A SEARCH OF THE SOURCE, AND NOT A BEHAVIOURAL TEST.** Both ends of
  /// this rule live inside SwiftUI views — a `case .closed` in `TimerView` and a
  /// `filter` inside a computed `PickerScreenModel` in `PlanBuilderView`. Neither
  /// is reachable from a test without standing up a view with a live `@Query`,
  /// and a rule defended by nothing is worse than one defended crudely.
  ///
  /// That is not a hypothetical worry. Deleting the picker's filter outright, and
  /// replacing the `record` call with a discard, each left the entire suite green:
  /// every existing test in this file exercises `SprintCompletions` and
  /// `SprintBoundaryObserver` — the backstop — and nothing at all exercised the
  /// rule's entry point or the surface it is supposed to change.
  ///
  /// Both call sites are also *optional* environment lookups, which fail open and
  /// silently: with the environment missing, `record` becomes a no-op and
  /// `nil?.contains(id) != true` is `true`, so every task is kept. That is the
  /// same shape of silent-always-false failure D21 was careful to defend against,
  /// and it is why these two lines are worth pinning by name.
  @Test("theOnlyWriteAndTheOnlyReadAreBothStillWiredUp")
  func theOnlyWriteAndTheOnlyReadAreBothStillWiredUp() throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()

    let timerView = try String(contentsOf: root.appending(path: "ZenTomato/Views/TimerView.swift"))
    #expect(
      timerView.contains("completedThisSprint?.record(taskID:"),
      "D21b's only write is gone: a task ticked off mid-sprint would be offered again.")

    // And that write is gated on a sprint actually being in progress. Without
    // the gate an id recorded while the timer is at rest is cleared by nothing
    // until the *next* sprint ends, because the observer clears on the
    // transition into rest and nothing re-fires afterwards.
    #expect(
      timerView.contains("SprintBoundaryObserver.sprintHasEnded("),
      "D21b's write is not gated on a live sprint: an id recorded at rest withholds that task for an extra sprint.")

    let planBuilder = try String(contentsOf: root.appending(path: "ZenTomato/Views/PlanBuilderView.swift"))
    #expect(
      planBuilder.contains("completedThisSprint?.contains("),
      "D21b's only read is gone: the picker would offer back work already done.")
  }

  /// `aRecordedTaskIsWithheldAndTheRestAreNot` — the rule itself, over a list.
  ///
  /// The picker's line is `tasks.filter { completedThisSprint?.contains($0.id) != true }`.
  /// This is that expression, over the same set, asserting both halves: the
  /// recorded task disappears and every other task survives. A filter that
  /// withheld everything would satisfy "the completed one is absent" on its own,
  /// which is why the second half is stated separately.
  @Test("aRecordedTaskIsWithheldAndTheRestAreNot")
  func aRecordedTaskIsWithheldAndTheRestAreNot() {
    let completions = SprintCompletions()
    completions.record(taskID: "td-mits")

    let everyTask = ["td-mits", "td-ynab", "td-chapter"]
    let offered = everyTask.filter { completions.contains($0) != true }

    #expect(offered == ["td-ynab", "td-chapter"])
    #expect(offered.contains("td-mits") == false)
  }

  /// `nothingIsRecordedWhileNoSprintIsRunning` — the gate above, as a rule.
  ///
  /// `SprintBoundaryObserver` clears the set when the timer *becomes* idle with
  /// no pomodoros behind it. It is driven by change, so an id arriving after that
  /// moment is never swept: the next clear is the end of the following sprint,
  /// and the task is withheld through all of it. The four states below are the
  /// same table the observer documents, read from the other direction — the two
  /// that mean "no sprint is running" are exactly the two where a completion must
  /// not be recorded.
  @Test("nothingIsRecordedWhileNoSprintIsRunning")
  func nothingIsRecordedWhileNoSprintIsRunning() {
    // At rest with nothing behind it: no sprint. A completion here belongs to no
    // sprint and must not be withheld from the next one.
    #expect(SprintBoundaryObserver.sprintHasEnded(isRunning: false, completedInSprint: 0))

    // A block is running: a sprint is live, whether or not it has finished a
    // pomodoro yet. The first pomodoro of a sprint has none behind it.
    #expect(SprintBoundaryObserver.sprintHasEnded(isRunning: true, completedInSprint: 0) == false)
    #expect(SprintBoundaryObserver.sprintHasEnded(isRunning: true, completedInSprint: 2) == false)

    // Idle with pomodoros behind it — paused between blocks inside a sprint that
    // has not ended. Still live, so a completion still counts.
    #expect(SprintBoundaryObserver.sprintHasEnded(isRunning: false, completedInSprint: 2) == false)
  }
}
