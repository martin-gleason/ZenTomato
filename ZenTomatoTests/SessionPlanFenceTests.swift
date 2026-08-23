import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// The fence around the session plan, as a test rather than as a promise.
///
/// WHY THIS FILE EXISTS
/// An ordered list of tasks is one field away from being a local copy of Todoist
/// with opinions of its own — the thing this project forbids. The failure never
/// arrives as a bad decision. It arrives as four good ones, on four different
/// afternoons: *the plan should show which ones are done*, *it should sort by
/// what's due first*, *grey out the finished ones*, *remember which I skipped*.
/// Each is one small commit and each is obviously useful.
///
/// A comment asking people not to do that would not survive the year. So the
/// rule is mechanical: this test asks the database layer what columns the type
/// actually has, and fails if the answer is not exactly the four the plan is
/// allowed. A fifth cannot be added quietly — it can only be added by somebody
/// deliberately changing this test as well, in a diff the owner reads.
///
/// The second test here is about a different failure with the same shape: a
/// saved type that is left out of the schema is not a compile error. It is a
/// crash on the first insert, in the app and in every test, with a message
/// naming SwiftData rather than the missing line.
@Suite("SessionPlanFence")
struct SessionPlanFenceTests {
  // MARK: The four columns

  /// A plan item has exactly four columns: the Todoist identifier, the title
  /// snapshot, which of the two kinds of thing it is, and where it sits in the
  /// list.
  ///
  /// The two beyond the identifier and the snapshot are both properties of *the
  /// list* rather than of the thing in Todoist, and both are argued for in the
  /// build contract: an order has to be written down somewhere, and Todoist's
  /// identifiers are opaque, so nothing but a stored kind can tell a project
  /// from a task — and only a task can be ticked off.
  @Test("planItemHasFourStoredProperties")
  func planItemHasFourStoredProperties() throws {
    let entity = try #require(Schema([SessionPlanItem.self]).entities.first)
    let columns = Set(entity.properties.map(\.name))

    #expect(columns == ["todoistID", "titleSnapshot", "kind", "position"])
  }

  /// The plan itself holds the cursor, and holds it exactly once.
  ///
  /// **Where the cursor lives is the load-bearing decision.** "Which one am I
  /// on" is a fact about the list, so it is stored on the list. Move it onto the
  /// items — as a finished flag, or a skipped flag — and each item stops being a
  /// reference to something in Todoist and becomes a small local copy of it with
  /// a state of its own.
  @Test("planHoldsTheCursorAndNothingElse")
  func planHoldsTheCursorAndNothingElse() throws {
    let entity = try #require(Schema([SessionPlan.self]).entities.first)
    let columns = Set(entity.properties.map(\.name))

    #expect(columns == ["createdAt", "currentIndex"])
  }

  /// The completion record is three columns: what, called what, and when.
  ///
  /// No project, no hierarchy, no status. It is a record of something this app
  /// did, and the moment it gains a fourth column describing the task it starts
  /// being a task list.
  @Test("completionRecordIsThreeColumns")
  func completionRecordIsThreeColumns() throws {
    let entity = try #require(Schema([CompletedTaskRecord.self]).entities.first)
    let columns = Set(entity.properties.map(\.name))

    #expect(columns == ["taskID", "titleSnapshot", "completedAt"])
  }

  // MARK: The mirrors mirror, and invent nothing

  /// Every column of the local copy is either a field Todoist sent or the one
  /// timestamp saying when the copy was taken.
  ///
  /// Written out here so that adding a column is an argument with a list
  /// somebody can read, rather than a small commit nobody notices.
  @Test("theLocalCopyHasNoInventedColumns")
  func theLocalCopyHasNoInventedColumns() throws {
    let projects = try #require(Schema([CachedProject.self]).entities.first)
    #expect(Set(projects.properties.map(\.name)) == ["id", "name", "childOrder", "syncedAt"])

    let sections = try #require(Schema([CachedSection.self]).entities.first)
    #expect(Set(sections.properties.map(\.name)) == [
      "id", "name", "projectID", "sectionOrder", "syncedAt"
    ])

    let tasks = try #require(Schema([CachedTask.self]).entities.first)
    #expect(Set(tasks.properties.map(\.name)) == [
      "id", "content", "projectID", "sectionID", "childOrder", "syncedAt"
    ])
  }

  // MARK: Everything the app saves is in the schema

  /// Every saved type can actually be saved.
  ///
  /// Six types were added to this app at once, and a type missing from the
  /// schema fails at run time rather than at compile time — on the first insert,
  /// in the app and in every test, with an error that names SwiftData instead of
  /// the missing line. So each one is inserted here, and the store is asked to
  /// save.
  @Test("everySavedTypeIsInTheSchema")
  @MainActor
  func everySavedTypeIsInTheSchema() throws {
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext

    context.insert(CachedProject(id: "p1", name: "Deep work", childOrder: 0, syncedAt: .now))
    context.insert(CachedSection(id: "s1", name: "Doing", projectID: "p1", sectionOrder: 0, syncedAt: .now))
    context.insert(CachedTask(
      id: "t1",
      content: "Draft the summary",
      projectID: "p1",
      sectionID: "s1",
      childOrder: 0,
      syncedAt: .now))
    context.insert(CompletedTaskRecord(taskID: "t0", titleSnapshot: "Finished", completedAt: .now))
    context.insert(SessionPlan(createdAt: .now))
    context.insert(SessionPlanItem(
      todoistID: "t1",
      titleSnapshot: "Draft the summary",
      kind: .task,
      position: 0))

    try context.save()

    let items = try context.fetch(FetchDescriptor<SessionPlanItem>())
    #expect(items.count == 1)
    // The kind is stored as readable text, so the database can be read off a
    // phone and understood without a decoder ring. F5's review was blocked once
    // by a stored value that could not be read this way.
    #expect(items.first?.kind == .task)
    #expect(PlanItemKind.task.rawValue == "task")
    #expect(PlanItemKind.project.rawValue == "project")
  }
}
