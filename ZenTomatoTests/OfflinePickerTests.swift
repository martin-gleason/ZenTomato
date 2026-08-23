import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// What the Todoist screens do when Todoist cannot be reached.
///
/// TWO ANSWERS, AND WHICH ONE APPLIES IS THE WHOLE DESIGN
///
///   * **Reading still works.** The copy is served exactly as it was, the search
///     still filters it, and a plan can still be built. Nothing is broken from
///     where the reader is standing, so the screen says how old its list is in
///     the quiet ink rather than in amber — amber would be the loudest thing on
///     a screen where nothing is wrong.
///   * **The one write is switched off.** A completion is a write, and *a write
///     we cannot see is the one thing forbidden*. So the Complete button is
///     disabled with a plain sentence rather than queued for later. There is no
///     outgoing queue anywhere in this app, and this test is half of why.
///
/// AND THE STATE THAT MATTERS MOST IS THE ONE WITH NO COPY AT ALL: a first run
/// on a train. That gets the whole screen and an honest retry, because the
/// picker genuinely has nothing to show — and, critically, nothing in the plan
/// is marked as missing from Todoist, because absent from an empty copy is not
/// evidence.
@Suite("OfflinePicker")
@MainActor
struct OfflinePickerTests {
  // MARK: Lifecycle

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  // MARK: The headline

  @Test("offlineServesCacheAndDisablesComplete")
  func offlineServesCacheAndDisablesComplete() async throws {
    let credentials = InMemoryTokenStore()
    let stub = StubTodoistTransport(
      answers: [.failure(URLError(.notConnectedToInternet))],
      repeatingLastAnswer: true)
    let cache = TodoistCacheStore(
      context: context,
      client: TodoistClient(transport: stub, tokens: credentials, waiting: RecordingRetryWaiting()))

    try insertACopyFromEarlierInTheDay()

    // The refresh fails.
    var failure: (any Error)?
    do {
      try await cache.refresh()
    } catch {
      failure = error
    }
    #expect(failure as? TodoistError == .offline)

    // THE COPY IS UNTOUCHED. A refresh that fails leaves what was there.
    let projects = try context.fetch(FetchDescriptor<CachedProject>())
    let tasks = try context.fetch(FetchDescriptor<CachedTask>())
    #expect(projects.count == 1)
    #expect(tasks.count == 1)

    // AND IT IS STILL A WORKING PICKER.
    let picker = Self.picker(projects: projects, tasks: tasks)
    #expect(picker.projectRows.count == 1)
    #expect(picker.rows(inProject: "p1").count == 1)
    #expect(picker.rows(matching: "draft").count == 1)

    // THE BANNER SAYS HOW OLD THE LIST IS, AND IS NOT AMBER.
    let freshness = PlanBuilderView.freshness(after: try #require(failure), syncedAt: cache.lastSyncedAt)
    guard case .stale(let note) = freshness else {
      Issue.record("A failed refresh with a copy to serve is a stale list, not an empty screen.")
      return
    }
    #expect(note.hasPrefix("Can't reach Todoist."))
    #expect(note.contains("pick from it as normal"))

    // AND THE ONE WRITE IS SWITCHED OFF, WITH A PLAIN SENTENCE.
    let control = TaskCompletionSection.restingControl(
      hasToken: true,
      todoistIsReachable: false,
      taskIsInTodoist: .present)
    guard case .unavailable(let sentence) = control else {
      Issue.record("Offline, the Complete button must be switched off rather than offered.")
      return
    }
    #expect(sentence == "Can't reach Todoist right now, so this can't be ticked off. The break is running either way.")

    // Nothing was queued for later. The only requests were the reads that
    // failed, and not one of them was a write.
    #expect(stub.requestsThatWereNotReads.isEmpty)
  }

  // MARK: A first run on a train

  /// Nothing copied and nothing reachable: the picker gets the whole screen
  /// rather than an empty list, and the copy count is what decides it.
  @Test("noCopyAtAllIsAScreenOfItsOwn")
  func noCopyAtAllIsAScreenOfItsOwn() {
    let freshness = PlanBuilderView.freshness(after: TodoistError.offline, syncedAt: nil)

    #expect(freshness == .nothingYet)
  }

  /// Being asked to slow down is not the same as being offline, and it does not
  /// borrow the offline wording. The "us" is deliberate: this is the app's
  /// traffic, not the reader's behaviour.
  @Test("beingAskedToSlowDownSaysSoInItsOwnWords")
  func beingAskedToSlowDownSaysSoInItsOwnWords() throws {
    let counted = PlanBuilderView.freshness(
      after: TodoistError.rateLimited(retryAfter: .seconds(30)),
      syncedAt: Date(timeIntervalSince1970: 1_787_400_000))
    guard case .stale(let withSeconds) = counted else {
      Issue.record("A rate limit with a copy to serve is a stale list.")
      return
    }
    #expect(withSeconds == "Todoist asked us to slow down. Trying again in 30 seconds — nothing is lost.")

    let uncounted = PlanBuilderView.freshness(
      after: TodoistError.rateLimited(retryAfter: nil),
      syncedAt: Date(timeIntervalSince1970: 1_787_400_000))
    guard case .stale(let withoutSeconds) = uncounted else {
      Issue.record("A rate limit with a copy to serve is a stale list.")
      return
    }
    #expect(withoutSeconds == "Todoist asked us to slow down. Trying again shortly — nothing is lost.")

    // No status code, no jargon, and no "you".
    for note in [withSeconds, withoutSeconds] {
      #expect(note.contains("429") == false)
      #expect(note.range(of: "rate limit", options: .caseInsensitive) == nil)
      #expect(note.range(of: " you ", options: .caseInsensitive) == nil)
    }
  }

  // MARK: The Complete button in its other unavailable state

  /// A task that has left Todoist cannot be ticked off, and the button says that
  /// rather than failing on the tap.
  @Test("aTaskThatHasLeftTodoistCannotBeTickedOff")
  func aTaskThatHasLeftTodoistCannotBeTickedOff() {
    let control = TaskCompletionSection.restingControl(
      hasToken: true,
      todoistIsReachable: true,
      taskIsInTodoist: .absent)

    guard case .unavailable(let sentence) = control else {
      Issue.record("A task that is no longer in Todoist must not offer a button that cannot succeed.")
      return
    }
    #expect(sentence.contains("no longer in Todoist"))
  }

  /// With no copy ever made, the button is **offered** rather than refused —
  /// because "not in an empty copy" is not evidence that anything is missing.
  @Test("anUnfilledCopyDoesNotSwitchTheButtonOff")
  func anUnfilledCopyDoesNotSwitchTheButtonOff() {
    let control = TaskCompletionSection.restingControl(
      hasToken: true,
      todoistIsReachable: true,
      taskIsInTodoist: .unknown)

    #expect(control == .ready)
  }

  /// No credential, no button. There is nothing to tick off with.
  @Test("noCredentialMeansNoButton")
  func noCredentialMeansNoButton() {
    let control = TaskCompletionSection.restingControl(
      hasToken: false,
      todoistIsReachable: true,
      taskIsInTodoist: .present)

    guard case .unavailable = control else {
      Issue.record("With no credential there is nothing to complete with.")
      return
    }
  }

  // MARK: Private

  private let container: ModelContainer

  private var context: ModelContext { container.mainContext }

  /// A copy of Todoist made at ten past two, which is what "as it was at 14:10"
  /// in the banner is talking about.
  private func insertACopyFromEarlierInTheDay() throws {
    let earlier = Date(timeIntervalSince1970: 1_787_400_000)
    context.insert(CachedProject(id: "p1", name: "Deep work", childOrder: 0, syncedAt: earlier))
    context.insert(CachedTask(
      id: "t1",
      content: "Draft the Q3 summary",
      projectID: "p1",
      sectionID: nil,
      childOrder: 0,
      syncedAt: earlier))
    try context.save()
  }

  /// Turns saved rows into the plain values the picker draws from, which is
  /// exactly what the screen does when it is handed a copy.
  private static func picker(projects: [CachedProject], tasks: [CachedTask]) -> PickerScreenModel {
    PickerScreenModel(
      projects: projects.map {
        PickerScreenModel.Project(id: $0.id, name: $0.name, openTaskCount: 1)
      },
      sections: [],
      tasks: tasks.map {
        PickerScreenModel.TaskItem(
          id: $0.id,
          title: $0.content,
          projectID: $0.projectID,
          projectName: "Deep work",
          sectionID: $0.sectionID)
      })
  }
}
