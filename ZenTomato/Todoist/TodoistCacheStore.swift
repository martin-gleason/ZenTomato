import Foundation
import SwiftData

/// Keeps the local copy of Todoist up to date.
///
/// WHAT A REFRESH IS
/// Fetch all the projects, all the sections and all the tasks; then throw away
/// every row of the local copy and write the new ones. That is the whole
/// algorithm, and its simplicity is the feature.
///
/// **WHY A FULL REPLACE RATHER THAN A MERGE.** A merge would have to decide,
/// row by row, whether the local copy or Todoist's answer wins — and the moment
/// this app is in the business of deciding that, it has a copy of somebody's
/// tasks with opinions of its own, which is the exact thing it is forbidden to
/// have. Replacing everything makes the question unaskable: no local row
/// survives a refresh, so there is nothing to reconcile, ever. It also disposes
/// of a problem Todoist's own documentation warns about — that editing Todoist
/// while pages are being fetched can hand back the same row twice — because the
/// rows are keyed by identifier on the way in and two copies collapse into one.
///
/// **WHY NOTHING IS WRITTEN UNTIL ALL THREE FETCHES HAVE SUCCEEDED.** A refresh
/// that failed halfway would leave a project on screen whose tasks had been
/// deleted — a half-replaced copy is worse than an old one, because an old one
/// is at least a consistent photograph of a moment. So all three lists are
/// collected first, and only then does anything touch the database. A failure
/// before that point leaves the previous copy exactly as it was.
///
/// It is `@MainActor` — main-thread only — because everything that touches this
/// app's database is. The fetching is not: the client it calls runs off the main
/// thread for the duration of the network work and hands back plain values.
@MainActor
final class TodoistCacheStore {
  // MARK: What it is built with

  private let context: ModelContext
  private let client: TodoistClient

  /// Whether a sweep is already under way. Nothing waits on this — a second
  /// caller simply gets the copy the first one is about to write.
  private var isRefreshing = false

  /// How recent the copy has to be for an automatic refresh to skip.
  ///
  /// A minute. It is far shorter than anybody's working rhythm and far longer
  /// than the burst of triggers that happens when an app is opened, which is the
  /// only thing it exists to absorb.
  private static let floorBetweenAutomaticRefreshes: TimeInterval = 60

  init(context: ModelContext, client: TodoistClient) {
    self.context = context
    self.client = client
  }

  // MARK: Refreshing

  /// Fetches everything and replaces the local copy.
  ///
  /// THREE THINGS ASK FOR THIS, AND TWO OF THEM ARE NOT A PERSON
  /// The app coming to the foreground, the Todoist sheet opening, and somebody
  /// pulling the list down. **Never on a timer, never as somebody types, and
  /// never at launch before a screen has asked for it** — Todoist publishes no
  /// request ceiling for these four addresses at all, so the app has to stay
  /// under whatever it is by design.
  ///
  /// "By design" used to mean nothing but this comment. It now means two rules:
  ///
  ///   * **one at a time.** Opening the app straight into the Todoist sheet
  ///     fires the foreground refresh and the sheet's refresh together, which
  ///     was two full sweeps of three paginated lists for one gesture;
  ///   * **the two automatic triggers have a floor.** A phone picked up forty
  ///     times in a quarter of an hour was forty sweeps — on a five-thousand-task
  ///     account, over a thousand requests, past the strictest number Todoist
  ///     publishes anywhere. A pull is never held back: that one is somebody
  ///     asking.
  ///
  /// - Parameters:
  ///   - now: the moment to stamp the copy with. Defaults to the real clock.
  ///   - force: whether to fetch regardless of how recently the copy was filled.
  ///     `true` by default, because most callers are somebody asking; the
  ///     foreground and sheet-opening refreshes pass `false`.
  /// - Throws: whatever stopped it — `TodoistError.offline`, `.tokenRejected`
  ///   and the rest. When it throws, nothing in the database has changed.
  func refresh(now: Date = Date(), force: Bool = true) async throws {
    guard isRefreshing == false else { return }
    if force == false,
       let filledAt = lastSyncedAt,
       now.timeIntervalSince(filledAt) < Self.floorBetweenAutomaticRefreshes {
      return
    }

    isRefreshing = true
    defer { isRefreshing = false }

    // Everything is fetched before anything is written. See the note above:
    // this ordering is the whole of the all-or-nothing guarantee.
    let projects = try await client.fetchProjects()
    let sections = try await client.fetchSections()
    let tasks = try await client.fetchTasks()

    try replaceEverything(projects: projects, sections: sections, tasks: tasks, syncedAt: now)
  }

  /// Empties the local copy. Used when somebody signs out of Todoist.
  ///
  /// It removes this app's copy of somebody else's data and nothing else. The
  /// record of what this app itself completed is deliberately untouched: that is
  /// its own history, not a copy of Todoist's.
  /// Drops one task from the mirror, because Todoist has just said it is not there.
  ///
  /// **Not a Todoist write and not a guess.** `TaskCompletion` reports `.alreadyGone` when the
  /// close request comes back saying the task was already finished or deleted somewhere else —
  /// so the mirror is out of date, and this is the mirror catching up. Nothing is sent
  /// anywhere; the app's one permitted write is unchanged.
  ///
  /// **Why not add it to D21b's set instead**, which would also hide it from the picker: D21b
  /// means *"you completed this during this sprint"*, and this task was completed somewhere
  /// else, possibly weeks ago. Widening that rule to cover it would change its meaning from
  /// *completed* to *believed gone*, and the two want different lifetimes — D21b's set clears
  /// at the end of a sprint, and a task deleted in Todoist should not come back then.
  ///
  /// Silent when the row is not there. A task the mirror never held is already forgotten.
  func forget(taskID: String) {
    let identity = taskID
    var descriptor = FetchDescriptor<CachedTask>(
      predicate: #Predicate<CachedTask> { $0.id == identity })
    descriptor.fetchLimit = 1
    guard let row = (try? context.fetch(descriptor))?.first else { return }
    context.delete(row)
    try? context.save()
  }

  func clear() throws {
    try context.delete(model: CachedProject.self)
    try context.delete(model: CachedSection.self)
    try context.delete(model: CachedTask.self)
    try context.save()
  }

  // MARK: Freshness

  /// When the local copy was last refreshed, or `nil` if it never has been.
  ///
  /// **Read by one line of the interface** — the one that says how old the list
  /// is while the phone is offline. It is never compared between rows and never
  /// used to decide anything.
  ///
  /// It also answers a question that matters more than it looks: with no
  /// refresh ever having happened, the plan screen must not mark anything as
  /// missing from Todoist, because "absent from an empty copy" is not evidence.
  var lastSyncedAt: Date? {
    var descriptor = FetchDescriptor<CachedProject>(
      sortBy: [SortDescriptor(\.syncedAt, order: .reverse)])
    descriptor.fetchLimit = 1
    do {
      return try context.fetch(descriptor).first?.syncedAt
    } catch {
      // A database that cannot be read has already stopped the app at its
      // failure screen. Reporting "never refreshed" here is the safe answer in
      // any case: it is the one that makes the plan screen mark nothing as
      // missing, which is the mistake worth avoiding.
      return nil
    }
  }

  // MARK: The one write to the database

  /// Deletes every mirrored row and inserts the new ones, in one pass, and
  /// saves once at the end.
  ///
  /// Saving once rather than per row is not a micro-optimisation: a large
  /// account is thousands of rows, this runs on the main thread, and a save
  /// between each one would be felt as a stutter by the person holding the
  /// phone.
  private func replaceEverything(
    projects: [TodoistProjectDTO],
    sections: [TodoistSectionDTO],
    tasks: [TodoistTaskDTO],
    syncedAt: Date) throws {
    try context.delete(model: CachedProject.self)
    try context.delete(model: CachedSection.self)
    try context.delete(model: CachedTask.self)

    for project in Self.deduplicated(projects, by: \.id) {
      context.insert(CachedProject(
        id: project.id,
        name: project.name,
        childOrder: project.childOrder,
        syncedAt: syncedAt))
    }

    for section in Self.deduplicated(sections, by: \.id) {
      context.insert(CachedSection(
        id: section.id,
        name: section.name,
        projectID: section.projectID,
        sectionOrder: section.sectionOrder,
        syncedAt: syncedAt))
    }

    for task in Self.deduplicated(tasks, by: \.id) {
      context.insert(CachedTask(
        id: task.id,
        content: task.content,
        projectID: task.projectID,
        sectionID: task.sectionID,
        childOrder: task.childOrder,
        syncedAt: syncedAt,
        // D21, and the one place this boolean enters the app. Todoist puts it
        // inside the due object, and a task with no due date has no object at
        // all — which is an ordinary task, and not recurring.
        isRecurring: task.due?.isRecurring ?? false))
    }

    do {
      try context.save()
    } catch {
      // A failed save leaves the deletions and the insertions uncommitted, which
      // is the same outcome as a failed fetch: the previous copy is what
      // remains. Discarding them explicitly says so, rather than leaving a
      // half-changed context for the next screen to trip over, and the failure
      // is passed on rather than hidden.
      context.rollback()
      throw error
    }
  }

  /// Keeps the first row for each identifier and drops later copies.
  ///
  /// Todoist's documentation warns that editing an account while its pages are
  /// being fetched can produce the same row on two pages. This is the one place
  /// that is dealt with, so the rule lives in a single readable line instead of
  /// being guarded against three times.
  private static func deduplicated<Row>(_ rows: [Row], by id: KeyPath<Row, String>) -> [Row] {
    var seen: Set<String> = []
    return rows.filter { seen.insert($0[keyPath: id]).inserted }
  }
}
