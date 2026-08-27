import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// D22 — how a block learns which project it was for, and how the page labels it.
///
/// **The defect this feature started from.** A block attached to a *task*
/// recorded no project at all, so the export's `## Projects` section — the one
/// that answers "where did the time go" — collapsed into a single `No project`
/// heading with everything underneath. The golden page hid it, because the
/// fixture set the project name by hand.
///
/// **The two halves, tested here together because they only work together.**
/// One: the attachment reads the task's project out of the local Todoist mirror,
/// so it gets written down at all. Two: the export groups by the project's *id*
/// and labels the group from the mirror's current name, falling back to the name
/// recorded on the row when the id no longer resolves — which is what happens
/// when a project is deleted, since Todoist deletes its tasks with it and the id
/// then names nothing for ever.
@Suite("StatsProjectGrouping")
@MainActor
struct StatsProjectGroupingTests {
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

  /// `aRenamedProjectStaysOneHeadingUnderItsCurrentName` — the whole point of
  /// grouping by id.
  ///
  /// Somebody renames "Client work" to "Acme Corp" on the Wednesday. The blocks
  /// either side of that carry different name snapshots and the same id. Grouped
  /// by name they would be two headings of one pomodoro each, and both would
  /// under-report — in the one section of the document whose entire purpose is
  /// adding things up. Grouped by id they are one heading of two, labelled with
  /// the name the reader will recognise in their own Todoist sidebar.
  @Test("aRenamedProjectStaysOneHeadingUnderItsCurrentName")
  func aRenamedProjectStaysOneHeadingUnderItsCurrentName() throws {
    // What Todoist calls it now.
    context.insert(CachedProject(
      id: "p1", name: "Acme Corp", childOrder: 0,
      syncedAt: StatsStoreFixture.at(2026, 8, 19, 8, 0)))

    // Monday, under the old name. Wednesday, under the new one. Same project.
    for (number, day, snapshot) in [(1, 17, "Client work"), (2, 19, "Acme Corp")] {
      context.insert(PomodoroSession(
        id: StatsStoreFixture.identity(number),
        kind: .work,
        startedAt: StatsStoreFixture.at(2026, 8, day, 9, 0),
        endedAt: StatsStoreFixture.at(2026, 8, day, 9, 25),
        wasAbandoned: false,
        taskID: "t\(number)",
        taskTitle: "Draft",
        projectID: "p1",
        projectTitle: snapshot))
    }
    try context.save()

    let period = query.period(StatsRange(first: day(2026, 8, 17), last: day(2026, 8, 21)))

    #expect(period.pomodoroCount == 2)
    #expect(period.projects.count == 1)
    #expect(period.projects.first?.title == "Acme Corp")
    #expect(period.projects.first?.pomodoroCount == 2)

    // AND THE TASK ROWS MERGE, WHICH IS THE HALF THAT ACTUALLY PINS THE RULE.
    // Grouping by name and grouping by id both give ONE heading here, because
    // both leaves resolve to the same live label and the heading is keyed by the
    // label. The difference shows one level down: keyed by name there are two
    // "Draft" rows of one pomodoro each, and a reader adding up their own task
    // list sees the work split in half. Keyed by id there is one row of two.
    // Without these two lines this test passes with the rule removed — it was
    // written that way first, and the mutation went unnoticed.
    #expect(period.projects.first?.tasks.count == 1)
    #expect(period.projects.first?.tasks.first?.title == "Draft")
    #expect(period.projects.first?.tasks.first?.pomodoroCount == 2)
  }

  /// `aProjectTheMirrorNoLongerKnowsKeepsTheNameItWasGiven` — the fallback, and
  /// why the snapshot is still written down.
  ///
  /// Deleting a project in Todoist deletes it and all of its tasks, and the id
  /// then dangles for ever: no endpoint will name it again. Without the recorded
  /// name every block in a deleted project would collapse to *no project*, which
  /// is precisely the defect D22 exists to fix, arriving later by another door.
  @Test("aProjectTheMirrorNoLongerKnowsKeepsTheNameItWasGiven")
  func aProjectTheMirrorNoLongerKnowsKeepsTheNameItWasGiven() throws {
    // No CachedProject row at all — the project has been deleted in Todoist.
    context.insert(PomodoroSession(
      id: StatsStoreFixture.identity(1),
      kind: .work,
      startedAt: StatsStoreFixture.at(2026, 8, 19, 9, 0),
      endedAt: StatsStoreFixture.at(2026, 8, 19, 9, 25),
      wasAbandoned: false,
      taskID: "t1",
      taskTitle: "Draft",
      projectID: "p-gone",
      projectTitle: "Wound up in July"))
    try context.save()

    let period = query.period(.day(day(2026, 8, 19)))

    #expect(period.projects.map(\.title) == ["Wound up in July"])
    #expect(period.projects.first?.pomodoroCount == 1)
  }

  /// `noProjectIdEverReachesTheExportedPage` — D22 must not erode F6's fence.
  ///
  /// The grouping key is an identifier, and identifiers must not appear on a
  /// page somebody prints. The structural guarantee is that the id stops inside
  /// `StatsQuery`: every value type the document is built from carries a
  /// resolved title and nothing else. This is the executed half.
  @Test("noProjectIdEverReachesTheExportedPage")
  func noProjectIdEverReachesTheExportedPage() throws {
    context.insert(CachedProject(
      id: "td-project-distinctive-0001", name: "Thesis", childOrder: 0,
      syncedAt: StatsStoreFixture.at(2026, 8, 19, 8, 0)))
    context.insert(PomodoroSession(
      id: StatsStoreFixture.identity(1),
      kind: .work,
      startedAt: StatsStoreFixture.at(2026, 8, 19, 9, 0),
      endedAt: StatsStoreFixture.at(2026, 8, 19, 9, 25),
      wasAbandoned: false,
      taskID: "td-task-distinctive-0002",
      taskTitle: "Ch.3 draft",
      projectID: "td-project-distinctive-0001",
      projectTitle: "Thesis"))
    try context.save()

    let document = StatsMarkdown.document(for: query.period(.day(day(2026, 8, 19))), producedBy: .forGoldens)

    #expect(document.contains("Thesis"))
    #expect(document.contains("td-project-distinctive-0001") == false)
    #expect(document.contains("td-task-distinctive-0002") == false)
  }

  /// `aTaskCarriesItsProjectWhenTheMirrorKnowsIt` — D22, the case that matters.
  ///
  /// The plan holds one identifier and one title, and D17 fixes it at four
  /// stored properties. It does not need more: the picker only offers tasks that
  /// are in the local Todoist mirror, and `CachedTask.projectID` is
  /// non-optional, so the mirror already knows which project a task belongs to.
  /// This is the path a real phone takes, and it is the one no test covered when
  /// the defect was found.
  @Test("aTaskCarriesItsProjectWhenTheMirrorKnowsIt")
  func aTaskCarriesItsProjectWhenTheMirrorKnowsIt() throws {
    let synced = StatsStoreFixture.at(2026, 8, 19, 8, 0)
    context.insert(CachedProject(id: "p1", name: "Thesis", childOrder: 0, syncedAt: synced))
    context.insert(CachedTask(
      id: "t1", content: "Ch.3 draft", projectID: "p1",
      sectionID: nil, childOrder: 0, syncedAt: synced))
    try context.save()

    let plan = SessionPlanStore(context: context)
    plan.replacePlan(with: [.init(todoistID: "t1", titleSnapshot: "Ch.3 draft", kind: .task)])
    let attachment = try #require(plan.takeNextAttachment())

    #expect(attachment.taskID == "t1")
    #expect(attachment.taskTitle == "Ch.3 draft")
    #expect(attachment.projectID == "p1")
    #expect(attachment.projectTitle == "Thesis")

    // And it survives the journey onto a counted row, which is the whole point:
    // the export groups by the id and labels from the name.
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
    #expect(period.projects.map(\.title) == ["Thesis"])
    #expect(period.projects.first?.tasks.map(\.title) == ["Ch.3 draft"])
  }

  /// `theIdIsRecordedEvenWhenTheProjectNameIsNotMirroredYet` — a half-synced
  /// mirror still records the thing the export groups by.
  ///
  /// Projects and tasks are mirrored by separate paginated reads, so there is a
  /// window in which a task's row exists and its project's row does not. The id
  /// is worth writing down regardless: it is the durable key, a name can arrive
  /// with the next refresh, and recording neither would lose the grouping for
  /// good over a timing accident.
  @Test("theIdIsRecordedEvenWhenTheProjectNameIsNotMirroredYet")
  func theIdIsRecordedEvenWhenTheProjectNameIsNotMirroredYet() throws {
    context.insert(CachedTask(
      id: "t9", content: "Reading", projectID: "p9",
      sectionID: nil, childOrder: 0,
      syncedAt: StatsStoreFixture.at(2026, 8, 19, 8, 0)))
    try context.save()

    let plan = SessionPlanStore(context: context)
    plan.replacePlan(with: [.init(todoistID: "t9", titleSnapshot: "Reading", kind: .task)])
    let attachment = try #require(plan.takeNextAttachment())

    #expect(attachment.projectID == "p9")
    #expect(attachment.projectTitle == nil)
  }
}
