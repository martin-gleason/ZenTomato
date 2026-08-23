import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// A session plan, replaced by a list the test wrote.
///
/// The real plan reads the database and the local copy of Todoist. None of that
/// is what these tests are about: they are about what the *timer* does with the
/// answer, so the answer is handed over directly and the number of times it was
/// asked for is counted.
///
/// That count is half the point. "A break is never attached" is not provable by
/// looking at the break's row alone — a break could be unattached because the
/// plan happened to be empty. Counting the questions proves the timer never even
/// asked.
@MainActor
private final class StubAttachments: SessionAttaching {
  /// What to hand back, in order. When it runs out, the plan is exhausted.
  var queue: [SessionAttachment]

  /// How many times the timer asked. **Exactly one per focus block, and never
  /// for a break.**
  private(set) var timesAsked = 0

  init(queue: [SessionAttachment]) {
    self.queue = queue
  }

  func takeNextAttachment() -> SessionAttachment? {
    timesAsked += 1
    return queue.isEmpty ? nil : queue.removeFirst()
  }
}

/// Tests for the seam between the timer and the session plan.
///
/// WHAT THE SEAM IS FOR
/// The timer must not know Todoist exists. It asks one question — "what is the
/// next focus block attached to?" — receives four pieces of text or nothing, and
/// writes them onto its own rows. These tests check the three things that can go
/// wrong on the timer's side of that question:
///
///   * a break gets attached to something (it is not a pomodoro, and a plan that
///     advanced on breaks would consume itself twice as fast);
///   * an app with no plan at all stops working (the timer shipped before this
///     feature and must still run untouched without it);
///   * the recorded title follows a rename in Todoist, instead of being the
///     frozen copy taken when the block began.
///
/// `@MainActor`: the engine and the database are both main-thread only.
@Suite("SessionAttachment")
@MainActor
struct SessionAttachmentTests {
  private let container: ModelContainer
  private let clock: TestClock
  private let alarms: SpyAlarmScheduler

  init() throws {
    container = try TestStore.inMemoryContainer()
    clock = TestClock()
    alarms = SpyAlarmScheduler()
  }

  private var context: ModelContext {
    container.mainContext
  }

  private func engine(_ attachments: StubAttachments?) -> TimerEngine {
    TimerEngine(context: context, clock: clock, alarms: alarms, attachments: attachments)
  }

  private func sessions() throws -> [PomodoroSession] {
    try context.fetch(FetchDescriptor<PomodoroSession>(sortBy: [SortDescriptor(\.endedAt)]))
  }

  // MARK: Breaks

  /// A break is never attached to anything, and the plan is never asked about
  /// one.
  ///
  /// A break is not a pomodoro. If the timer took a plan item for every block,
  /// a four-block sprint would eat eight items and half of them would be
  /// recorded against rows nobody was working during.
  @Test("breaksAreNeverAttached")
  func breaksAreNeverAttached() async throws {
    let plan = StubAttachments(queue: [
      SessionAttachment(
        taskID: "t1",
        taskTitle: "Draft the summary",
        projectID: "p1",
        projectTitle: "Deep work"),
      SessionAttachment(
        taskID: "t2",
        taskTitle: "Reply to Anna",
        projectID: "p1",
        projectTitle: "Deep work")
    ])
    let engine = engine(plan)

    await engine.start()
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()

    // The break, started deliberately, exactly as the screen starts it.
    await engine.start()
    #expect(engine.kind == .shortBreak)
    clock.advance(by: 5 * 60)
    await engine.boundaryReached()

    let rows = try sessions()
    #expect(rows.count == 2)

    let focus = try #require(rows.first)
    #expect(focus.kind == .work)
    #expect(focus.taskID == "t1")
    #expect(focus.taskTitle == "Draft the summary")

    let rest = try #require(rows.last)
    #expect(rest.kind == .shortBreak)
    #expect(rest.taskID == nil)
    #expect(rest.taskTitle == nil)
    #expect(rest.projectID == nil)
    #expect(rest.projectTitle == nil)

    // One focus block, one question. The break did not ask, so the second plan
    // item is still waiting.
    #expect(plan.timesAsked == 1)
  }

  // MARK: No plan at all

  /// A timer built with no plan behaves exactly as it did before this feature
  /// existed: it runs, it records, and the four columns are empty.
  ///
  /// This is not a hypothetical configuration. It is every launch before
  /// somebody connects Todoist, and every launch of somebody who never does.
  @Test("noPlanMeansNoAttachment")
  func noPlanMeansNoAttachment() async throws {
    let engine = engine(nil)

    await engine.start()
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()

    let row = try #require(try sessions().first)
    #expect(row.kind == .work)
    #expect(row.wasAbandoned == false)
    #expect(row.taskID == nil)
    #expect(row.taskTitle == nil)
    #expect(row.projectID == nil)
    #expect(row.projectTitle == nil)
  }

  /// A plan that has been worked through attaches nothing, and does not repeat
  /// its last item.
  @Test("exhaustedPlanAttachesNothing")
  func exhaustedPlanAttachesNothing() async throws {
    let plan = StubAttachments(queue: [
      SessionAttachment(taskID: "t1", taskTitle: "Draft the summary")
    ])
    let engine = engine(plan)

    await engine.start()
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()
    await engine.start()                      // the break
    clock.advance(by: 5 * 60)
    await engine.boundaryReached()
    await engine.start()                      // the second focus block
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()

    let focusRows = try sessions().filter { $0.kind == .work }
    #expect(focusRows.count == 2)
    #expect(focusRows.first?.taskID == "t1")
    #expect(focusRows.last?.taskID == nil)
    #expect(focusRows.last?.taskTitle == nil)
    #expect(plan.timesAsked == 2)
  }

  // MARK: A project on its own

  /// With a project planned and no task chosen, the block records the project
  /// and no task.
  ///
  /// The spec's own sentence: a pomodoro is attached to exactly one Todoist
  /// task, or, if no task is chosen, to a project. A project has nothing to tick
  /// off, which is why the sheet's Complete button is absent rather than
  /// disabled for one.
  @Test("projectAttachedWhenNoTaskChosen")
  func projectAttachedWhenNoTaskChosen() async throws {
    let plan = StubAttachments(queue: [
      SessionAttachment(projectID: "p1", projectTitle: "Deep work")
    ])
    let engine = engine(plan)

    await engine.start()
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()

    let row = try #require(try sessions().first)
    #expect(row.projectID == "p1")
    #expect(row.projectTitle == "Deep work")
    #expect(row.taskID == nil)
    #expect(row.taskTitle == nil)
  }

  // MARK: The snapshot

  /// Renaming the task in Todoist afterwards does not change what the block
  /// recorded.
  ///
  /// The words are copied when the block begins, and that copy is what the
  /// record keeps. Otherwise a rename — or the two-week-later export reading the
  /// live copy — would quietly rewrite what somebody did last Tuesday.
  @Test("titleSnapshotTakenAtAttach")
  func titleSnapshotTakenAtAttach() async throws {
    let cached = CachedTask(
      id: "t1",
      content: "Draft the summary",
      projectID: "p1",
      sectionID: nil,
      childOrder: 0,
      syncedAt: .now)
    context.insert(cached)
    try context.save()

    let plan = StubAttachments(queue: [
      SessionAttachment(
        taskID: cached.id,
        taskTitle: cached.content,
        projectID: "p1",
        projectTitle: "Deep work")
    ])
    let engine = engine(plan)

    await engine.start()

    // The world moves: the task is renamed in Todoist and the next refresh
    // brings the new name in.
    cached.content = "Draft the Q3 summary and send it"
    try context.save()

    clock.advance(by: 25 * 60)
    await engine.boundaryReached()

    let row = try #require(try sessions().first)
    #expect(row.taskTitle == "Draft the summary")
  }

  // MARK: Surviving a relaunch

  /// A block that ends while the app is closed still records what it was
  /// attached to.
  ///
  /// THIS IS WHY THE ATTACHMENT IS WRITTEN TO THE DATABASE RATHER THAN HELD IN
  /// MEMORY. iOS suspends the app within seconds of the phone being locked, and
  /// the block's row is written on the next return to the foreground from the
  /// saved timer row alone. Held in memory, the attachment would be gone by
  /// then — and every block ended with the phone in a pocket, which is most of
  /// them, would be recorded with nothing against it. A second engine on the
  /// same store is what a relaunch looks like from the outside.
  @Test("attachmentSurvivesARelaunch")
  func attachmentSurvivesARelaunch() async throws {
    let plan = StubAttachments(queue: [
      SessionAttachment(
        taskID: "t1",
        taskTitle: "Draft the summary",
        projectID: "p1",
        projectTitle: "Deep work")
    ])
    let first = engine(plan)
    await first.start()

    // The app is closed, the block runs out, and a fresh engine opens the same
    // store — with no plan handed to it at all, so nothing can be re-read.
    clock.advance(by: 25 * 60)
    let second = engine(nil)
    await second.synchronize()

    let row = try #require(try sessions().first)
    #expect(row.kind == .work)
    #expect(row.wasAbandoned == false)
    #expect(row.taskID == "t1")
    #expect(row.taskTitle == "Draft the summary")
    #expect(row.projectID == "p1")
    #expect(row.projectTitle == "Deep work")
  }
}
