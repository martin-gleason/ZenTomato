import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// What the Complete button is a button *about*, and why that has to be frozen.
///
/// THE FAILURE THIS SUITE EXISTS FOR
/// By D4 the end-of-block sheet is presented over a break that has **already
/// started**, and nothing closes that sheet at a block boundary. With
/// `autoStartNextBlock` on, the break can finish while somebody is still writing
/// their notes, the next focus block begins behind the open sheet, and the plan
/// hands that block the next item. Anything on the sheet that asks the plan "what
/// was I working on?" at that moment gets the *new* answer.
///
/// For a label that is a cosmetic bug. For the Complete button it is not: it is
/// the one irreversible write this app can make, aimed at a task the person has
/// never worked on, while the task they did finish stays open — and reopening a
/// task is not on the allowlist and never will be. The log this app exists to
/// produce would then say they worked A and completed B.
///
/// WHAT IS ACTUALLY TESTED HERE
/// A view's own state cannot be driven from a test bundle, so this proves the
/// two halves that can be:
///
///   * **the hazard is real** — after the next focus block starts, the plan's
///     answer really has changed;
///   * **a frozen subject still closes the right task** — the identifier taken
///     when the sheet opened is what reaches Todoist, and the record written
///     locally names that task and no other.
///
/// `TimerView` freezes exactly that value at exactly that moment, and carries it
/// with the request rather than looking it up when the write runs.
@Suite("CompletionSubject")
@MainActor
struct CompletionSubjectTests {
  // MARK: Lifecycle

  init() throws {
    container = try TestStore.inMemoryContainer()
    clock = TestClock()
  }

  // MARK: The whole failure, played out

  @Test("theSheetClosesTheTaskItWasOpenedFor")
  func theSheetClosesTheTaskItWasOpenedFor() async throws {
    let plan = SessionPlanStore(context: context)
    plan.replacePlan(with: [
      SessionPlanStore.Selection(todoistID: "t1", titleSnapshot: "Draft the Q3 summary", kind: .task),
      SessionPlanStore.Selection(todoistID: "t2", titleSnapshot: "Reply to Anna", kind: .task)
    ])

    let engine = TimerEngine(
      context: context,
      clock: clock,
      alarms: SpyAlarmScheduler(),
      attachments: plan)

    // Block one works the first item.
    await engine.start()
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()

    // The sheet opens here, over the break. This is the value `TimerView`
    // freezes.
    let frozen = try #require(plan.attachmentForTheBlockJustWorked())
    #expect(frozen.taskID == "t1")
    #expect(frozen.taskTitle == "Draft the Q3 summary")

    // The break runs out and the next focus block begins — behind the sheet,
    // which nothing has closed.
    await engine.start()
    clock.advance(by: 5 * 60)
    await engine.boundaryReached()
    await engine.start()
    #expect(engine.kind == .work)

    // THE HAZARD, STATED AS AN ASSERTION. Asked again now, the plan names the
    // task the *new* block took. A live read on the open sheet would aim the one
    // write this app can make at this.
    let liveAnswer = try #require(plan.attachmentForTheBlockJustWorked())
    #expect(liveAnswer.taskID == "t2")

    // The button is tapped. It uses the frozen subject.
    let stub = StubTodoistTransport(answers: [.bare(status: 200)])
    let completion = TaskCompletion(
      context: context,
      client: TodoistClient(transport: stub, tokens: FakeTokenStore(), waiting: RecordingRetryWaiting()))

    let subject = TaskCompletionSection.Subject(
      taskID: try #require(frozen.taskID),
      title: try #require(frozen.taskTitle))
    let outcome = await completion.complete(taskID: subject.taskID, titleSnapshot: subject.title)

    #expect(outcome == .closed)

    // ONE close, and it names the task that was worked.
    let writes = stub.requestsThatWereNotReads
    #expect(writes.count == 1)
    #expect(writes.first?.url?.path() == Self.expectedPath(forClosing: "t1"))
    #expect(writes.first?.url?.path() != Self.expectedPath(forClosing: "t2"))

    // And so does the record. The log says what happened.
    let records = try context.fetch(FetchDescriptor<CompletedTaskRecord>())
    #expect(records.count == 1)
    #expect(records.first?.taskID == "t1")
    #expect(records.first?.titleSnapshot == "Draft the Q3 summary")
  }

  /// Completing does not move the plan on, so the block that has just started
  /// keeps the item it was given.
  ///
  /// It is the same fact from the other side: the two are independent, which is
  /// why a task needing three pomodoros can have three.
  @Test("completingTheFrozenTaskLeavesTheRunningBlockAlone")
  func completingTheFrozenTaskLeavesTheRunningBlockAlone() async throws {
    let plan = SessionPlanStore(context: context)
    plan.replacePlan(with: [
      SessionPlanStore.Selection(todoistID: "t1", titleSnapshot: "Draft the Q3 summary", kind: .task),
      SessionPlanStore.Selection(todoistID: "t2", titleSnapshot: "Reply to Anna", kind: .task)
    ])
    _ = plan.takeNextAttachment()
    let cursorBefore = plan.currentIndex

    let stub = StubTodoistTransport(answers: [.bare(status: 200)])
    let completion = TaskCompletion(
      context: context,
      client: TodoistClient(transport: stub, tokens: FakeTokenStore(), waiting: RecordingRetryWaiting()))

    #expect(await completion.complete(taskID: "t1", titleSnapshot: "Draft the Q3 summary") == .closed)
    #expect(plan.currentIndex == cursorBefore)
  }

  // MARK: Private

  private let container: ModelContainer
  private let clock: TestClock

  private var context: ModelContext {
    container.mainContext
  }

  /// Built from the endpoint table rather than written out, so no Todoist
  /// address with a real identifier in it appears in this file.
  private static func expectedPath(forClosing id: String) -> String {
    TodoistAPI.baseURL.appending(path: TodoistAPI.closeTask(id: id).path).path()
  }
}
