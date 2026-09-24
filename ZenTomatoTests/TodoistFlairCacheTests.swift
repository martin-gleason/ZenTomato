import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// Tests for the two Todoist fields `F13` mirrors — a project's colour and a
/// task's priority.
///
/// **A file of its own, and not by preference.** These belong beside
/// `TodoistCacheTests`, which is where the same boundary is tested for every
/// other field, and they were written there first — the 400-line cap in
/// `.swiftlint.yml` is what moved them. The suite name keeps them findable.
///
/// THE CLAIM UNDER TEST, AND THE ONE IT DELIBERATELY DOES NOT MAKE
/// Both fields arrive over the wire, are decoded, and reach the mirrored row.
/// Neither is interpreted: the colour stays the name Todoist sent and the
/// priority stays the number, because which end of Todoist's priority range is
/// urgent is not settled by reading. `F13-T5` step 1 settles it against a real
/// account. Nothing in this file asserts a level, and a test here that named one
/// would be asserting a prediction.
///
/// THE TOLERANCE IS THE POINT, AND IT IS ASSERTED ON THE PAGE. A required field
/// does not fail one row — the decoder fails the element, `TodoistPage` fails
/// with it, and the refresh returns nothing at all. That presents as an empty
/// picker on somebody's phone and a green suite everywhere else, which is why
/// every absent-field test below puts a populated row *after* an empty one and
/// asserts that all of them arrived.
///
/// `@MainActor` on the whole suite: everything that touches the database in this
/// app is main-thread only.
@Suite("TodoistFlair")
@MainActor
struct TodoistFlairCacheTests {
  private let container: ModelContainer

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  private var context: ModelContext {
    container.mainContext
  }

  /// The colour reaches the local copy, from the one place it enters the app.
  ///
  /// Shaped on `recurrenceReachesTheMirroredRow`, deliberately: `D21` moved one
  /// field across the same boundary and this is the same argument with the same
  /// table. The assertion reads the MIRRORED ROW rather than the DTO, because a
  /// field that decodes and is then dropped by the writer is exactly the defect
  /// `F13-M7` applies.
  @Test("aProjectColourReachesTheMirroredRow")
  func aProjectColourReachesTheMirroredRow() async throws {
    let stub = StubTodoistTransport(answers: [
      .page(rows: [
        ["id": "p-berry", "name": "Dissertation", "child_order": 0, "color": "berry_red"],
        ["id": "p-olive", "name": "Household", "child_order": 1, "color": "olive_green"]
      ]),
      .page(rows: []),
      .page(rows: [])
    ])
    let store = TodoistCacheStore(context: context, client: Self.client(stub))

    try await store.refresh(now: Date(timeIntervalSince1970: 1_000_000))

    let projects = try Self.rows(CachedProject.self, in: context).sorted { $0.id < $1.id }
    #expect(projects.map(\.id) == ["p-berry", "p-olive"])
    #expect(projects.map(\.colorName) == ["berry_red", "olive_green"])
    // And the names Todoist sent resolve to two different tints, which is the
    // whole point of the feature — two projects a reader can tell apart.
    let tints = projects.map { TodoistTint(todoistName: $0.colorName) }
    #expect(tints == [.berryRed, .oliveGreen])
    #expect(tints[0].value(dark: false) != tints[1].value(dark: false))
  }

  /// A workspace project carries no `color` key, and **its whole page must
  /// survive** — not merely its own row.
  ///
  /// THE ASSERTION IS ON THE PAGE ON PURPOSE. A required `color` does not fail
  /// one project: Swift's decoder fails the element, `TodoistPage` fails with it,
  /// and the refresh returns nothing at all — an empty picker on somebody's phone
  /// and a green suite everywhere else. So the fixture puts a coloured project
  /// AFTER an uncoloured one and asserts both arrive, which is a case a
  /// row-shaped assertion cannot distinguish. `F13-M1`.
  @Test("aWorkspaceProjectWithNoColourKeyStillDecodes")
  func aWorkspaceProjectWithNoColourKeyStillDecodes() async throws {
    let stub = StubTodoistTransport(answers: [
      .page(rows: [
        // No `color` key at all — the workspace shape.
        ["id": "p-workspace", "name": "Shared", "child_order": 0],
        // An explicit null, which is the other way Todoist can decline to say.
        ["id": "p-null", "name": "Unset", "child_order": 1, "color": NSNull()],
        ["id": "p-berry", "name": "Dissertation", "child_order": 2, "color": "berry_red"]
      ]),
      .page(rows: []),
      .page(rows: [])
    ])
    let store = TodoistCacheStore(context: context, client: Self.client(stub))

    try await store.refresh(now: Date(timeIntervalSince1970: 1_000_000))

    let projects = try Self.rows(CachedProject.self, in: context).sorted { $0.childOrder < $1.childOrder }
    #expect(projects.map(\.id) == ["p-workspace", "p-null", "p-berry"])
    #expect(projects.map(\.colorName) == [nil, nil, "berry_red"])
    // Both ways of saying nothing land on Todoist's own default rather than
    // skipping the project.
    #expect(TodoistTint(todoistName: projects[0].colorName) == .unknown)
    #expect(TodoistTint(todoistName: projects[1].colorName) == .unknown)
  }

  /// The priority reaches the local copy **as the number on the wire**.
  ///
  /// It asserts the raw value and says nothing about which end is urgent. That
  /// reading is `F13-T5` step 1's to establish against a real account, and
  /// `F13-T4`'s to draw; a test here that named a level would be asserting a
  /// prediction.
  @Test("aTaskPriorityReachesTheMirroredRow")
  func aTaskPriorityReachesTheMirroredRow() async throws {
    let stub = StubTodoistTransport(answers: [
      .page(rows: [StubTodoistTransport.projectRow(id: "p1", name: "Admin")]),
      .page(rows: []),
      .page(rows: [
        ["id": "t-top", "content": "File the form", "project_id": "p1",
         "section_id": NSNull(), "child_order": 0, "priority": 4],
        ["id": "t-low", "content": "Water the plant", "project_id": "p1",
         "section_id": NSNull(), "child_order": 1, "priority": 1]
      ])
    ])
    let store = TodoistCacheStore(context: context, client: Self.client(stub))

    try await store.refresh(now: Date(timeIntervalSince1970: 1_000_000))

    let tasks = try Self.rows(CachedTask.self, in: context).sorted { $0.childOrder < $1.childOrder }
    #expect(tasks.map(\.id) == ["t-top", "t-low"])
    #expect(tasks.map(\.priority) == [4, 1])
  }

  /// Most tasks on most accounts have no `priority` key, and the whole page must
  /// survive that too. Same shape and same reasoning as the project case.
  /// `F13-M2`.
  @Test("aTaskWithNoPriorityKeyStillDecodes")
  func aTaskWithNoPriorityKeyStillDecodes() async throws {
    let stub = StubTodoistTransport(answers: [
      .page(rows: [StubTodoistTransport.projectRow(id: "p1", name: "Admin")]),
      .page(rows: []),
      .page(rows: [
        StubTodoistTransport.taskRow(id: "t-plain", content: "Draft the summary", projectID: "p1", order: 0),
        ["id": "t-null", "content": "Unset", "project_id": "p1",
         "section_id": NSNull(), "child_order": 1, "priority": NSNull()],
        ["id": "t-flagged", "content": "File the form", "project_id": "p1",
         "section_id": NSNull(), "child_order": 2, "priority": 4]
      ])
    ])
    let store = TodoistCacheStore(context: context, client: Self.client(stub))

    try await store.refresh(now: Date(timeIntervalSince1970: 1_000_000))

    let tasks = try Self.rows(CachedTask.self, in: context).sorted { $0.childOrder < $1.childOrder }
    #expect(tasks.map(\.id) == ["t-plain", "t-null", "t-flagged"])
    #expect(tasks.map(\.priority) == [nil, nil, 4])
  }

  // MARK: Helpers

  private static func client(_ transport: StubTodoistTransport) -> TodoistClient {
    TodoistClient(
      transport: transport,
      tokens: FakeTokenStore(),
      waiting: RecordingRetryWaiting())
  }

  private static func rows<Row: PersistentModel>(
    _ type: Row.Type,
    in context: ModelContext) throws -> [Row] {
    try context.fetch(FetchDescriptor<Row>())
  }
}
