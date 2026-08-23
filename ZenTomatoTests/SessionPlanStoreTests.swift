import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// How the plan behaves: how it is replaced, how its cursor moves, and — most
/// importantly — what does **not** move it.
///
/// WHY THESE ARE SEPARATE FROM THE COLUMN FENCE
/// `SessionPlanFenceTests` asks the database what shape a planned item has.
/// These ask what the plan *does*. Both are needed: a plan with the right
/// columns and the wrong cursor rule would still quietly hand the same task to
/// eight pomodoros, or skip one every time somebody ticked something off.
///
/// THE ONE TO READ FIRST IS `completingDoesNotAdvanceThePlan`.
/// Closing a task in Todoist is a statement about Todoist. The plan is a
/// statement about intent. Tying the two together is the tempting shortcut —
/// "you finished it, so move on" — and it is wrong for the ordinary case the
/// technique is built around: a task that takes three pomodoros gets three, and
/// two of them end without it being finished.
///
/// `@MainActor` on the whole suite: everything that touches the database in this
/// app is main-thread only.
@Suite("SessionPlanStore")
@MainActor
struct SessionPlanStoreTests {
  // MARK: Lifecycle

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  // MARK: Replacing a plan

  /// Building a plan while one already exists **replaces** it. Nothing is
  /// appended, nothing is kept, and the cursor goes back to the front.
  ///
  /// D17: *"The plan is replaced when a new one is made. It is not history."*
  /// A plan that grew would become a second, competing account of the day
  /// alongside the finished-block rows — which are the account that has to be
  /// trustworthy.
  @Test("planIsReplacedNotAppended")
  func planIsReplacedNotAppended() throws {
    let plan = SessionPlanStore(context: context)
    plan.replacePlan(with: [Self.draft, Self.reply])
    _ = plan.takeNextAttachment()
    #expect(plan.currentIndex == 1)

    plan.replacePlan(with: [Self.deepWork])

    #expect(plan.items.map(\.titleSnapshot) == ["Deep work"])
    #expect(plan.currentIndex == 0)
    // And on disk, not only in memory.
    #expect(try context.fetch(FetchDescriptor<SessionPlanItem>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<SessionPlan>()).count == 1)
  }

  /// Choosing nothing empties the plan rather than leaving an empty shell
  /// behind.
  @Test("anEmptySelectionLeavesNoPlanRows")
  func anEmptySelectionLeavesNoPlanRows() throws {
    let plan = SessionPlanStore(context: context)
    plan.replacePlan(with: [Self.draft])
    plan.replacePlan(with: [])

    #expect(plan.isEmpty)
    #expect(try context.fetch(FetchDescriptor<SessionPlan>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<SessionPlanItem>()).isEmpty)
  }

  // MARK: The cursor

  /// One item per focus block, in order, and the cursor stops at the end rather
  /// than running away.
  @Test("eachFocusBlockTakesTheNextItem")
  func eachFocusBlockTakesTheNextItem() {
    let plan = SessionPlanStore(context: context)
    plan.replacePlan(with: [Self.draft, Self.reply])

    #expect(plan.takeNextAttachment()?.taskTitle == "Draft the Q3 summary")
    #expect(plan.takeNextAttachment()?.taskTitle == "Reply to Anna")
    #expect(plan.takeNextAttachment() == nil)
    #expect(plan.currentIndex == 2)
  }

  /// With no plan at all the timer is handed nothing, which is a normal
  /// pomodoro rather than an error.
  @Test("noPlanHandsOverNothing")
  func noPlanHandsOverNothing() {
    let plan = SessionPlanStore(context: context)
    #expect(plan.takeNextAttachment() == nil)
  }

  /// **The one that matters.** A task closed in Todoist leaves the cursor
  /// exactly where it was, so the next pomodoro takes the same item again — and
  /// a task that needs three pomodoros gets three.
  ///
  /// The plan moves on when the next focus block begins and at no other time.
  @Test("completingDoesNotAdvanceThePlan")
  func completingDoesNotAdvanceThePlan() async throws {
    let plan = SessionPlanStore(context: context)
    plan.replacePlan(with: [Self.draft, Self.reply])
    _ = plan.takeNextAttachment()
    let before = plan.currentIndex

    let stub = StubTodoistTransport(answers: [.bare(status: 200)])
    let credentials = InMemoryTokenStore()
    let completion = TaskCompletion(
      context: context,
      client: TodoistClient(transport: stub, tokens: credentials, waiting: RecordingRetryWaiting()))

    let outcome = await completion.complete(taskID: Self.draft.todoistID, titleSnapshot: "Draft the Q3 summary")
    #expect(outcome == .closed)

    // Re-read from the database rather than trusting what is in memory: the
    // question is whether anything wrote a new cursor, not whether this object
    // happens to be holding the old one.
    let reread = SessionPlanStore(context: context)
    #expect(reread.currentIndex == before)
    #expect(reread.items.count == 2)
  }

  // MARK: Private

  private let container: ModelContainer

  private var context: ModelContext { container.mainContext }

  /// Fixture selections. The identifiers are deliberately not credential-shaped
  /// and are not real Todoist identifiers.
  private static let draft = SessionPlanStore.Selection(
    todoistID: "item-draft",
    titleSnapshot: "Draft the Q3 summary",
    kind: .task)

  private static let reply = SessionPlanStore.Selection(
    todoistID: "item-reply",
    titleSnapshot: "Reply to Anna",
    kind: .task)

  private static let deepWork = SessionPlanStore.Selection(
    todoistID: "project-deep-work",
    titleSnapshot: "Deep work",
    kind: .project)
}
