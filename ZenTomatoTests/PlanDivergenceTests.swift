import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// What happens to a plan when the world moves underneath it.
///
/// THE CLAIM UNDER TEST
/// D17: *"The plan is a record of intent, and intent is not invalidated by the
/// world moving."* A task planned at nine and deleted in Todoist at eleven does
/// not disappear from the plan, does not blank out, and does not take the
/// session with it. It shows the title it had when it was planned, says quietly
/// that it is not in Todoist any more, and can be stepped over.
///
/// THE FAILURE THIS SUITE EXISTS TO CATCH
/// The state of an item is **derived every time it is drawn**, never stored. If
/// it were ever stored, a planned item would have acquired a piece of local
/// state — and a planned item with local state is the beginning of the local
/// copy of Todoist this project forbids. So these tests deliberately never look
/// for a column; they hand the rule the facts and read the answer.
///
/// AND THE ONE THAT WOULD HURT MOST
/// `nothingIsMarkedGoneBeforeTheFirstRefresh`. Absent from an empty copy is not
/// evidence. Getting this wrong would strike out somebody's entire plan the
/// first time they opened the app on a train.
@Suite("PlanDivergence")
@MainActor
struct PlanDivergenceTests {
  // MARK: Lifecycle

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  // MARK: A task that has left Todoist

  /// The plan keeps the item, keeps its snapshot title, still hands it to a
  /// pomodoro, and says what is known about it — which is that it is not there
  /// any more, and **not** that it is finished.
  @Test("planSurvivesATaskVanishingFromTodoist")
  func planSurvivesATaskVanishingFromTodoist() throws {
    // A copy that has been filled at least once, holding one of the two tasks.
    context.insert(CachedProject(id: "p1", name: "Deep work", childOrder: 0, syncedAt: .now))
    context.insert(CachedTask(
      id: "item-reply",
      content: "Reply to Anna",
      projectID: "p1",
      sectionID: nil,
      childOrder: 0,
      syncedAt: .now))
    try context.save()

    let plan = SessionPlanStore(context: context)
    plan.replacePlan(with: [Self.draft, Self.reply])

    #expect(plan.isStillInTodoist(try #require(plan.items.first)) == .absent)

    let rows = SessionPlanScreenModel.rows(
      items: plan.items,
      currentIndex: plan.currentIndex,
      completions: [:],
      planCreatedAt: plan.createdAt,
      isStillInTodoist: { plan.isStillInTodoist($0) })

    #expect(rows[0].state == .gone)
    #expect(rows[0].item.titleSnapshot == "Draft the Q3 summary")
    #expect(rows[0].note == "Not in Todoist any more")
    #expect(rows[1].state == .planned)

    // Still attachable. A missing item is still worked; the pomodoro takes it
    // with the title it was planned under.
    #expect(plan.takeNextAttachment()?.taskTitle == "Draft the Q3 summary")
  }

  /// **The train case.** With no copy of Todoist at all, nothing is marked gone
  /// — because nothing is known.
  @Test("nothingIsMarkedGoneBeforeTheFirstRefresh")
  func nothingIsMarkedGoneBeforeTheFirstRefresh() {
    let plan = SessionPlanStore(context: context)
    plan.replacePlan(with: [Self.draft, Self.reply])

    let rows = SessionPlanScreenModel.rows(
      items: plan.items,
      currentIndex: plan.currentIndex,
      completions: [:],
      planCreatedAt: plan.createdAt,
      isStillInTodoist: { plan.isStillInTodoist($0) })

    #expect(rows.allSatisfy { $0.state == .planned })
  }

  /// A task this app closed reads as finished, and it says so with a time
  /// rather than with a strikethrough — because this is the one case where
  /// "done" is a fact rather than a guess.
  @Test("aCompletionFromThisAppIsShownAsOne")
  func aCompletionFromThisAppIsShownAsOne() throws {
    let plan = SessionPlanStore(context: context)
    plan.replacePlan(with: [Self.draft])
    let closedAt = try #require(plan.createdAt).addingTimeInterval(60)

    let rows = SessionPlanScreenModel.rows(
      items: plan.items,
      currentIndex: plan.currentIndex,
      completions: [Self.draft.todoistID: closedAt],
      planCreatedAt: plan.createdAt,
      isStillInTodoist: { _ in .absent })

    #expect(rows[0].state == .completedHere(at: closedAt))
    #expect(rows[0].note?.hasPrefix("Completed at") == true)
  }

  /// A completion older than the plan belongs to an earlier session and says
  /// nothing about this one. The item is drawn as gone, which is all that is
  /// honestly known.
  @Test("aCompletionFromBeforeThisPlanIsNotThisPlansCompletion")
  func aCompletionFromBeforeThisPlanIsNotThisPlansCompletion() throws {
    let plan = SessionPlanStore(context: context)
    plan.replacePlan(with: [Self.draft])
    let yesterday = try #require(plan.createdAt).addingTimeInterval(-86_400)

    let rows = SessionPlanScreenModel.rows(
      items: plan.items,
      currentIndex: plan.currentIndex,
      completions: [Self.draft.todoistID: yesterday],
      planCreatedAt: plan.createdAt,
      isStillInTodoist: { _ in .absent })

    #expect(rows[0].state == .gone)
  }

  // MARK: Stepping over

  /// Stepping over moves the cursor and does nothing else: the item stays, the
  /// list keeps its order, and nothing is marked.
  @Test("steppingOverMovesTheCursorAndNothingElse")
  func steppingOverMovesTheCursorAndNothingElse() {
    let plan = SessionPlanStore(context: context)
    plan.replacePlan(with: [Self.draft, Self.reply])

    plan.stepOver()

    #expect(plan.currentIndex == 1)
    #expect(plan.items.map(\.titleSnapshot) == ["Draft the Q3 summary", "Reply to Anna"])
    #expect(plan.takeNextAttachment()?.taskTitle == "Reply to Anna")
  }

  /// Stepping over at the end of the plan is harmless.
  @Test("steppingOverPastTheEndDoesNothing")
  func steppingOverPastTheEndDoesNothing() {
    let plan = SessionPlanStore(context: context)
    plan.replacePlan(with: [Self.draft])
    plan.stepOver()
    plan.stepOver()

    #expect(plan.currentIndex == 1)
  }

  /// Removing an item shortens the plan and keeps the same thing at the front
  /// of the queue. **Nothing in Todoist changes** — which is why the control
  /// that calls this is labelled Remove rather than Delete.
  @Test("removingAnItemKeepsTheCursorOnTheSameThing")
  func removingAnItemKeepsTheCursorOnTheSameThing() throws {
    let plan = SessionPlanStore(context: context)
    plan.replacePlan(with: [Self.draft, Self.reply, Self.deepWork])
    _ = plan.takeNextAttachment()
    #expect(plan.currentItem?.titleSnapshot == "Reply to Anna")

    plan.remove(try #require(plan.items.first))

    #expect(plan.items.map(\.titleSnapshot) == ["Reply to Anna", "Deep work"])
    #expect(plan.items.map(\.position) == [0, 1])
    #expect(plan.currentItem?.titleSnapshot == "Reply to Anna")
  }

  // MARK: What the end-of-block sheet is allowed to offer

  /// **The defect this reader exists to prevent.** A plan that has been worked
  /// through leaves the cursor one past the end — and so does the block that has
  /// just taken the last item. The plan alone cannot tell those two apart, so
  /// the answer is read from what the timer actually wrote down.
  ///
  /// Getting it wrong would put the last planned task above the Complete button
  /// at the end of a block that was attached to nothing, and one tap would then
  /// close a task nobody had been working on. It is a **write**, against the
  /// wrong thing, and it is the one kind of mistake this feature must not make.
  @Test("anExhaustedPlanOffersNothingToComplete")
  func anExhaustedPlanOffersNothingToComplete() throws {
    let plan = SessionPlanStore(context: context)
    plan.replacePlan(with: [Self.draft])

    // With nothing finished and nothing running there is nothing to offer.
    #expect(plan.attachmentForTheBlockJustWorked() == nil)

    // The block that took the last item: its row carries the attachment, and
    // the sheet after it may offer to tick that task off.
    context.insert(PomodoroSession(
      id: UUID(),
      kind: .work,
      startedAt: Date(timeIntervalSince1970: 1_787_400_000),
      endedAt: Date(timeIntervalSince1970: 1_787_401_500),
      wasAbandoned: false,
      taskID: "item-draft",
      taskTitle: "Draft the Q3 summary"))
    try context.save()

    #expect(plan.attachmentForTheBlockJustWorked()?.taskID == "item-draft")
    // The cursor is where an exhausted plan leaves it, and it is not what
    // decided the answer above.
    _ = plan.takeNextAttachment()
    #expect(plan.currentIndex == 1)

    // The NEXT focus block ran with the plan already worked through, so its row
    // carries nothing — and the sheet after it must offer nothing.
    context.insert(PomodoroSession(
      id: UUID(),
      kind: .work,
      startedAt: Date(timeIntervalSince1970: 1_787_403_000),
      endedAt: Date(timeIntervalSince1970: 1_787_404_500),
      wasAbandoned: false))
    try context.save()

    #expect(plan.attachmentForTheBlockJustWorked() == nil)
  }

  /// A break is never the block a sheet is about, so a break's row — which
  /// carries four empty columns by construction — must not be mistaken for a
  /// focus block that had nothing attached.
  @Test("aBreakIsNotTheBlockTheSheetIsAbout")
  func aBreakIsNotTheBlockTheSheetIsAbout() throws {
    let plan = SessionPlanStore(context: context)

    context.insert(PomodoroSession(
      id: UUID(),
      kind: .work,
      startedAt: Date(timeIntervalSince1970: 1_787_400_000),
      endedAt: Date(timeIntervalSince1970: 1_787_401_500),
      wasAbandoned: false,
      taskID: "item-draft",
      taskTitle: "Draft the Q3 summary"))
    // The break that followed it, which is what the reflection sheet is drawn
    // over — and which is attached to nothing, always.
    context.insert(PomodoroSession(
      id: UUID(),
      kind: .shortBreak,
      startedAt: Date(timeIntervalSince1970: 1_787_401_500),
      endedAt: Date(timeIntervalSince1970: 1_787_401_800),
      wasAbandoned: false))
    try context.save()

    #expect(plan.attachmentForTheBlockJustWorked()?.taskTitle == "Draft the Q3 summary")
  }

  // MARK: Projects

  /// A project chosen with no task attaches as a **project**: the project
  /// columns are filled and the task ones are empty.
  ///
  /// `SPEC.md`: *"A pomodoro is attached to exactly one Todoist task (or, if no
  /// task is chosen, to a project)."* Todoist's identifiers are opaque strings,
  /// so nothing but the stored kind can tell one from the other — and only a
  /// task can be ticked off.
  @Test("projectAttachedWhenNoTaskChosen")
  func projectAttachedWhenNoTaskChosen() throws {
    let plan = SessionPlanStore(context: context)
    plan.replacePlan(with: [Self.deepWork])

    let attachment = try #require(plan.takeNextAttachment())

    #expect(attachment.projectID == "project-deep-work")
    #expect(attachment.projectTitle == "Deep work")
    #expect(attachment.taskID == nil)
    #expect(attachment.taskTitle == nil)
  }

  // MARK: Private

  private let container: ModelContainer

  private var context: ModelContext { container.mainContext }

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
