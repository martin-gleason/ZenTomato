import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// What signing out of Todoist removes, and — the part worth testing — what it
/// deliberately keeps.
///
/// THREE THINGS GO AND ONE STAYS
/// The credential, this app's copy of somebody's projects and tasks, and the
/// session plan all go. **Every record of a task this app ticked off stays.**
/// Those rows are this app's own history rather than a copy of Todoist's data:
/// they are what the two-week paper review is assembled from, offline, and
/// throwing them away because a connection was ended would destroy the one
/// thing this feature produces that Todoist cannot hand back.
///
/// AND THE DISTINCTION THAT IS EASY TO LOSE
/// Signing out is the **only** thing that empties the copy and the plan. A token
/// that stopped being accepted clears the credential and nothing else — that is
/// Todoist's act rather than a decision to disconnect, and wiping a half-worked
/// plan because a credential went stale would be a punishment for something
/// nobody did. That half of the rule is tested next door, where the client
/// lives; this file tests the deliberate half.
@Suite("SignOut")
@MainActor
struct SignOutTests {
  // MARK: Lifecycle

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  // MARK: The whole of it

  @Test("signOutClearsTokenCacheAndPlanButNotHistory")
  func signOutClearsTokenCacheAndPlanButNotHistory() throws {
    let credentials = FakeTokenStore()
    let cache = TodoistCacheStore(
      context: context,
      client: TodoistClient(transport: StubTodoistTransport(answers: []), tokens: credentials))
    let plan = SessionPlanStore(context: context)

    // A connected account, mid-session: a copy of Todoist, a plan half worked
    // through, and two tasks already ticked off.
    context.insert(CachedProject(id: "p1", name: "Deep work", childOrder: 0, syncedAt: .now))
    context.insert(CachedSection(id: "s1", name: "This week", projectID: "p1", sectionOrder: 0, syncedAt: .now))
    context.insert(CachedTask(
      id: "t1",
      content: "Draft the Q3 summary",
      projectID: "p1",
      sectionID: "s1",
      childOrder: 0,
      syncedAt: .now))
    context.insert(CompletedTaskRecord(
      taskID: "t0",
      titleSnapshot: "Book the room",
      completedAt: Date(timeIntervalSince1970: 1_787_400_000)))
    context.insert(CompletedTaskRecord(
      taskID: "t9",
      titleSnapshot: "Send the invoice",
      completedAt: Date(timeIntervalSince1970: 1_787_403_600)))
    try context.save()

    plan.replacePlan(with: [
      SessionPlanStore.Selection(todoistID: "t1", titleSnapshot: "Draft the Q3 summary", kind: .task),
      SessionPlanStore.Selection(todoistID: "p1", titleSnapshot: "Deep work", kind: .project)
    ])
    _ = plan.takeNextAttachment()

    #expect(credentials.holdsAToken)

    let removedEverything = SettingsView.signOutOfTodoist(tokens: credentials, cache: cache, plan: plan)
    #expect(removedEverything)

    // Gone: the credential.
    #expect(credentials.holdsAToken == false)
    #expect(try credentials.read() == nil)

    // Gone: this app's copy of somebody else's data.
    #expect(try context.fetch(FetchDescriptor<CachedProject>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<CachedSection>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<CachedTask>()).isEmpty)

    // Gone: the plan, its items, and the cursor with them.
    #expect(try context.fetch(FetchDescriptor<SessionPlan>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<SessionPlanItem>()).isEmpty)
    #expect(plan.isEmpty)
    #expect(plan.currentIndex == 0)

    // KEPT: every record of something this app did.
    let history = try context.fetch(FetchDescriptor<CompletedTaskRecord>())
    #expect(history.count == 2)
    #expect(Set(history.map(\.titleSnapshot)) == ["Book the room", "Send the invoice"])
  }

  /// Signing out twice is harmless, which matters because the row that offers it
  /// is only hidden after the first one has been read back.
  @Test("signingOutTwiceIsHarmless")
  func signingOutTwiceIsHarmless() throws {
    let credentials = FakeTokenStore()
    let cache = TodoistCacheStore(
      context: context,
      client: TodoistClient(transport: StubTodoistTransport(answers: []), tokens: credentials))
    let plan = SessionPlanStore(context: context)

    #expect(SettingsView.signOutOfTodoist(tokens: credentials, cache: cache, plan: plan))
    #expect(SettingsView.signOutOfTodoist(tokens: credentials, cache: cache, plan: plan))
    #expect(try credentials.read() == nil)
  }

  /// A Keychain that refuses to delete must not stop the copy being removed.
  ///
  /// The three clears were once inside one `do`, so the first refusal skipped
  /// the rest: the credential still on the phone, a full copy of somebody's
  /// Todoist still on the phone, and the plan gone anyway — while the dialog had
  /// promised all three would go. Of the three, the one with a security meaning
  /// was the one left behind. Each is attempted on its own now, and the failure
  /// is still reported.
  @Test("aKeychainThatRefusesToDeleteStillEmptiesTheCopyAndThePlan")
  func aKeychainThatRefusesToDeleteStillEmptiesTheCopyAndThePlan() throws {
    let credentials = FakeTokenStore(refusesToClear: true)
    let cache = TodoistCacheStore(
      context: context,
      client: TodoistClient(transport: StubTodoistTransport(answers: []), tokens: credentials))
    let plan = SessionPlanStore(context: context)

    context.insert(CachedProject(id: "p1", name: "Deep work", childOrder: 0, syncedAt: .now))
    context.insert(CachedTask(
      id: "t1",
      content: "Draft the Q3 summary",
      projectID: "p1",
      sectionID: nil,
      childOrder: 0,
      syncedAt: .now))
    try context.save()
    plan.replacePlan(with: [
      SessionPlanStore.Selection(todoistID: "t1", titleSnapshot: "Draft the Q3 summary", kind: .task)
    ])

    let removedEverything = SettingsView.signOutOfTodoist(tokens: credentials, cache: cache, plan: plan)

    // It says so, rather than claiming a disconnection that did not happen.
    #expect(removedEverything == false)

    // But the copy and the plan really are gone.
    #expect(try context.fetch(FetchDescriptor<CachedProject>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<CachedTask>()).isEmpty)
    #expect(plan.isEmpty)
  }

  // MARK: Private

  private let container: ModelContainer

  private var context: ModelContext { container.mainContext }
}
