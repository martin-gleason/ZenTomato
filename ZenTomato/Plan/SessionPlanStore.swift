import Foundation
import SwiftData

// swiftlint:disable file_length
//
// THE ONLY LINT RULE THIS FILE TURNS OFF, AND WHY.
// `file_length` counts documentation, and this file is more than half of it on
// purpose: it is where D17's fence is held, and the fence is only worth having
// if the next person to open the file can read why each field is absent. The
// same exemption, for the same reason, is already taken by `TimerEngine.swift`.

/// The session plan: an ordered queue of Todoist references, and one cursor.
///
/// WHAT A PLAN IS, FOR A READER WHO DOES NOT WRITE SWIFT
/// Before a sprint you pick the things you mean to work on, in the order you
/// mean to work them. The timer then takes the next one at the start of each
/// focus block, so the choice is made once rather than eight times an
/// afternoon. That is the whole feature.
///
/// WHAT A PLAN IS NOT, WHICH MATTERS MORE
/// It is **not** a list of tasks. Ratified decision D17 draws the line and this
/// type is where the line is held: a planned item stores a Todoist id and a
/// snapshot of the title it had when it was planned, and nothing else. No due
/// date, no priority, no notes, no "done" flag, nothing editable. A queue of
/// references, in the sense a playlist is a queue of references and not a music
/// library.
///
/// The temptation this file exists to resist is a reasonable afternoon's worth
/// of small requests — *show me which ones are finished*, *sort by what is due*,
/// *grey out the ones I have done*. Each is one column, each looks harmless, and
/// the destination is a second task model that nobody designed. Everything of
/// that shape is **derived at the moment it is drawn** instead: see
/// `SessionPlanScreenModel`, which works it out from the cache and from what
/// this app has recorded, and stores not one byte.
///
/// THE CURSOR, AND WHY IT LIVES ON THE PLAN RATHER THAN ON AN ITEM
/// There is exactly one number: `SessionPlan.currentIndex`, the position of the
/// item a focus block starting now would take. Keeping it on the plan is the
/// structural reason no item can ever acquire a state of its own — there is
/// nowhere on an item to put one. A per-item "done" flag is the precise failure
/// D17 names, however reasonable it looks in a mock-up.
///
/// WHAT MOVES THE CURSOR, AND WHAT DELIBERATELY DOES NOT
///   * **The start of a focus block** moves it forward by one, through
///     `takeNextAttachment()`. That is the only automatic movement there is.
///   * **Stepping over** moves it forward by one, by hand, when the thing at
///     the front of the queue is no longer worth doing.
///   * **Completing a task does not move it.** Closing a task in Todoist is a
///     statement about Todoist; the plan is a statement about intent, and the
///     two are independent. `completingDoesNotAdvanceThePlan` locks this.
///
/// A NEW PLAN REPLACES THE OLD ONE
/// There is one plan at a time and no archive of past ones. What actually
/// happened is already on `PomodoroSession`, and a plan that outlived its
/// session would be a second, competing account of the day.
///
/// EVERYTHING HERE IS MAIN-THREAD ONLY, because it holds a `ModelContext` and
/// those are not safe to share between threads. It never touches the network:
/// a plan is built from the local mirror of Todoist and from nothing else.
@MainActor
@Observable
final class SessionPlanStore: SessionAttaching {
  // MARK: Lifecycle

  /// - Parameters:
  ///   - context: the app's database handle. Held, not copied.
  ///   - completedThisSprint: the tasks ticked off since this sprint began
  ///     (D21b). The plan asks it one question — *does it hold this string* —
  ///     and learns nothing about blocks, sprints, breaks or the timer.
  ///
  ///     It has a default so that a plan built for a test or a preview gets an
  ///     empty set of its own rather than every call site having to invent one.
  ///     **The app must pass the shared instance**, or a task completed during
  ///     a sprint would come back into it — which is the whole of what D21b
  ///     exists to prevent.
  init(context: ModelContext, completedThisSprint: SprintCompletions = SprintCompletions()) {
    self.context = context
    self.completedThisSprint = completedThisSprint
    reload()
  }

  // MARK: Nested types

  /// One planned item, as a plain immutable value.
  ///
  /// **No database row ever crosses into a screen**, which is the same rule
  /// `DistractionPrompt` already establishes for the distraction log: a screen
  /// holding one of these has nothing it could use to change what the database
  /// believes. It carries the same four facts the stored row does and adds
  /// nothing.
  struct Item: Identifiable, Hashable, Sendable {
    /// Todoist's own identifier. An opaque string in API v1 — never a number.
    let todoistID: String

    /// The title as it read when the plan was built.
    ///
    /// **A snapshot, not a lookup.** A task renamed in Todoist half way through
    /// a session must not silently change what the plan says you meant to do,
    /// and a task deleted in Todoist must not leave a blank row. This is why
    /// the plan does not chase Todoist.
    let titleSnapshot: String

    /// Whether this is a task or a whole project. `SPEC.md` allows a pomodoro
    /// to be attached to either, and only a task can be ticked off.
    let kind: PlanItemKind

    /// Its place in the queue, counted from zero.
    let position: Int

    /// Positions are unique within a plan, which is what makes them usable as
    /// an identity for a list row.
    var id: Int { position }
  }

  /// Whether the local mirror still holds the Todoist object a planned item
  /// points at.
  ///
  /// **Three answers, not two, and the third is the one that matters.** A
  /// yes/no would force "we have never managed to look" to be reported as
  /// "it is not there" — and marking somebody's whole plan as gone the first
  /// time they open the app on a train would be the worst bug this screen could
  /// ship. Absent from an empty mirror is not evidence.
  enum Presence: Equatable, Sendable {
    /// The mirror holds it.
    case present
    /// The mirror has been filled and does not hold it.
    case absent
    /// The mirror has never been filled, so nothing can be concluded.
    case unknown
  }

  /// One thing chosen in the picker, before it has a place in a queue.
  ///
  /// Separate from `Item` because a selection has no position yet: the position
  /// is decided by the order the picker hands them over in, and inventing one
  /// earlier would mean two places believing they own the order.
  struct Selection: Hashable, Sendable {
    let todoistID: String
    let titleSnapshot: String
    let kind: PlanItemKind
  }

  // MARK: Reading the plan

  /// Every planned item, in the order it will be worked.
  private(set) var items: [Item] = []

  /// The position of the item a focus block starting now would take.
  ///
  /// It may legitimately point one past the end: that is a plan that has been
  /// worked through, and the timer then runs with nothing attached.
  private(set) var currentIndex = 0

  /// When this plan was built. Used by the screen to decide whether a recorded
  /// completion belongs to this session or to an earlier one.
  private(set) var createdAt: Date?

  /// Whether there is a plan at all.
  var isEmpty: Bool { items.isEmpty }

  /// The item at the front of the queue, or `nil` once the plan is worked
  /// through.
  var currentItem: Item? {
    items.indices.contains(currentIndex) ? items[currentIndex] : nil
  }

  /// How many items are still ahead of the cursor.
  var remainingCount: Int { max(0, items.count - currentIndex) }

  // MARK: Building and changing the plan

  /// Throws away the current plan and stores a new one.
  ///
  /// D17: *"The plan is replaced when a new one is made. It is not history."*
  /// There is no appending to a plan in progress and no archive of past plans —
  /// what actually happened is recorded on `PomodoroSession`, which is the
  /// account that has to be trustworthy.
  ///
  /// The cursor is reset to the front, because a new plan is a new intention.
  ///
  /// - Parameter selections: the chosen items, in the order they will be
  ///   worked. An empty list clears the plan entirely.
  /// - Returns: `true` when the change reached the disk.
  @discardableResult
  func replacePlan(with selections: [Selection]) -> Bool {
    deleteEveryRow()

    // D21b, belt and braces. The picker does not offer a task ticked off during
    // this sprint, so this normally removes nothing — it is one line so that the
    // rule is a property of the store rather than of a screen, and a second way
    // into the plan later cannot quietly reintroduce work already done.
    let selections = selections.filter {
      $0.kind == .project || completedThisSprint.contains($0.todoistID) == false
    }

    if selections.isEmpty == false {
      let plan = SessionPlan(createdAt: Date(), currentIndex: 0)
      context.insert(plan)
      for (position, selection) in selections.enumerated() {
        context.insert(SessionPlanItem(
          todoistID: selection.todoistID,
          titleSnapshot: selection.titleSnapshot,
          kind: selection.kind,
          position: position))
      }
    }

    let written = persist()
    reload()
    return written
  }

  /// Moves the cursor past the item at the front of the queue.
  ///
  /// It deletes nothing, marks nothing and reorders nothing — D17 again: the
  /// plan is a record of intent, and an item you decided not to do is still
  /// something you meant to do. The row stays, and the screen draws it behind
  /// the cursor in the quieter ink.
  ///
  /// - Returns: `true` when the change reached the disk.
  @discardableResult
  func stepOver() -> Bool {
    guard let plan, currentIndex < items.count else { return true }
    plan.currentIndex = currentIndex + 1
    let written = persist()
    reload()
    return written
  }

  /// Takes one item out of the plan altogether.
  ///
  /// **Nothing in Todoist changes.** This shortens a private queue on this
  /// phone; the task itself is untouched, which is why the swipe that calls it
  /// is labelled *Remove* in the quiet ink rather than *Delete* in red.
  ///
  /// The remaining items are renumbered so positions stay contiguous, and the
  /// cursor is pulled back by one when the item removed was behind it, so the
  /// same item stays at the front of the queue.
  ///
  /// - Returns: `true` when the change reached the disk.
  @discardableResult
  func remove(_ item: Item) -> Bool {
    let kept = items.filter { $0.position != item.position }
    guard kept.count != items.count else { return true }

    let cursor = item.position < currentIndex ? currentIndex - 1 : currentIndex
    deleteEveryRow()

    if kept.isEmpty == false {
      let plan = SessionPlan(createdAt: createdAt ?? Date(), currentIndex: min(cursor, kept.count))
      context.insert(plan)
      for (position, kept) in kept.enumerated() {
        context.insert(SessionPlanItem(
          todoistID: kept.todoistID,
          titleSnapshot: kept.titleSnapshot,
          kind: kept.kind,
          position: position))
      }
    }

    let written = persist()
    reload()
    return written
  }

  /// Deletes the plan and every item in it. Used by signing out of Todoist,
  /// which also clears the token and the local mirror.
  ///
  /// **What this does not touch:** every `CompletedTaskRecord`. Those are a
  /// record of something this app did, and they belong to the person rather
  /// than to the connection.
  ///
  /// - Returns: `true` when the change reached the disk.
  @discardableResult
  func clear() -> Bool {
    deleteEveryRow()
    let written = persist()
    reload()
    return written
  }

  // MARK: The timer's seam

  /// Hands the next item to a focus block that is starting, and moves the
  /// cursor past it.
  ///
  /// **The timer pulls; no screen pushes.** Blocks begin with nobody looking —
  /// the break starts behind the reflection sheet, and auto-start begins the
  /// next pomodoro on its own — so an attachment handed over by a screen would
  /// simply be missing for most blocks.
  ///
  /// - Returns: what the block is attached to, or `nil` when there is no plan
  ///   or the plan has been worked through. A pomodoro with nothing attached is
  ///   a normal pomodoro; the timer shipped and is in use without Todoist at
  ///   all.
  func takeNextAttachment() -> SessionAttachment? {
    reload()
    guard let plan else { return nil }

    // D21b: step over anything already ticked off in this sprint before taking
    // one. Completing a recurring task in Todoist does not finish it — it
    // advances it to the next occurrence, so it is active again immediately and
    // could otherwise be handed back to the very next block of the same
    // afternoon.
    //
    // **This is the existing step-over, not a new kind of state.** The cursor
    // moves; the item is not removed, not marked, not reordered, and nothing is
    // written on it. Projects are never skipped — D21b is about tasks, and only
    // a task can be ticked off.
    var index = currentIndex
    while items.indices.contains(index),
          items[index].kind == .task,
          completedThisSprint.contains(items[index].todoistID) {
      index += 1
    }

    guard items.indices.contains(index) else {
      // Everything left had already been done. The cursor still moves past it,
      // so the plan screen shows those items behind the cursor in the quieter
      // ink rather than pretending they are still ahead.
      plan.currentIndex = index
      _ = persist()
      reload()
      return nil
    }

    let item = items[index]
    plan.currentIndex = item.position + 1
    _ = persist()
    reload()
    return attachment(for: item)
  }

  /// What a planned item looks like to the timer.
  ///
  /// A task fills the two task columns and leaves the project ones empty; a
  /// project does the opposite. `SPEC.md`: *"A pomodoro is attached to exactly
  /// one Todoist task (or, if no task is chosen, to a project)."* Todoist's ids
  /// are opaque strings, so a project id and a task id are indistinguishable —
  /// which is the whole reason a planned item records which of the two it is.
  /// **D22: A PLANNED TASK CARRIES ITS PROJECT WITH IT.**
  ///
  /// This used to hand back `projectID: nil, projectTitle: nil` for every
  /// planned task, and only a block attached to a whole *project* recorded any
  /// project identity at all. The consequence did not show up until F6 tried to
  /// count: the export's `## Projects` section — the one that answers "where did
  /// the time go" — collapsed into a single `No project` heading with every task
  /// underneath it. The type's own documentation always said `projectID` is "of
  /// the attached task, or of the planned project itself", so this is the
  /// behaviour that was meant all along rather than a new idea.
  ///
  /// **Where the project comes from.** The plan does not carry it — a planned
  /// item holds one identifier and one title and D17 fixes it at four stored
  /// properties, which is a fence worth keeping. It does not need to carry it:
  /// the picker only ever offers tasks that are in the local Todoist mirror, and
  /// `CachedTask.projectID` is non-optional, so the mirror already knows the
  /// answer. This reads it there, at the moment the block begins.
  ///
  /// **Both halves are frozen here, and that is the point.** The id is what the
  /// export groups by, so a project renamed half way through a fortnight stays
  /// one heading instead of splitting into two that each under-report. The name
  /// is the fallback for when the id stops resolving — deleting a project in
  /// Todoist deletes it and all of its tasks, and the id then dangles for ever
  /// with no endpoint that will ever name it again. Without the snapshot every
  /// block in a deleted project would degrade to `No project`, which is exactly
  /// the defect above arriving later by a different door.
  ///
  /// **A missing mirror row is not an error.** If the task is not in the mirror —
  /// nothing synced yet, or it was finished elsewhere and swept — the attachment
  /// is made exactly as it was before, with the task's own title and no project.
  /// A block that records what it can is better than one that refuses to start.
  func attachment(for item: Item) -> SessionAttachment {
    switch item.kind {
    case .task:
      let project = projectOfTask(id: item.todoistID)
      return SessionAttachment(
        taskID: item.todoistID,
        taskTitle: item.titleSnapshot,
        projectID: project?.id,
        projectTitle: project?.name)
    case .project:
      return SessionAttachment(
        taskID: nil,
        taskTitle: nil,
        projectID: item.todoistID,
        projectTitle: item.titleSnapshot)
    }
  }

  /// The project a mirrored task belongs to, or `nil` when either row is absent.
  ///
  /// Two reads rather than a relationship, because the mirror stores Todoist's
  /// shape — a task holds its project's identifier as a plain string — and a
  /// task whose project has not been mirrored yet must not be unreadable. Each
  /// predicate binds a local constant first: a database predicate may only
  /// capture a plain value, never a path through another object.
  private func projectOfTask(id: String) -> (id: String, name: String?)? {
    let todoistID = id
    var taskQuery = FetchDescriptor<CachedTask>(
      predicate: #Predicate<CachedTask> { $0.id == todoistID })
    taskQuery.fetchLimit = 1
    guard let projectID = (try? context.fetch(taskQuery))?.first?.projectID else { return nil }

    let mirroredID = projectID
    var projectQuery = FetchDescriptor<CachedProject>(
      predicate: #Predicate<CachedProject> { $0.id == mirroredID })
    projectQuery.fetchLimit = 1
    // The id is worth recording even when the name is not mirrored: it is what
    // the export groups by, and a name can arrive with the next refresh.
    return (id: projectID, name: (try? context.fetch(projectQuery))?.first?.name)
  }

  // MARK: What a block is actually attached to

  /// What the timer wrote down for the block it is running now, or `nil` when it
  /// is running a break, is running nothing, or is running a focus block with no
  /// attachment.
  ///
  /// **WHY THIS IS READ RATHER THAN DERIVED FROM THE CURSOR.** The cursor cannot
  /// tell *"the last item was handed to the block running now"* from *"the plan
  /// ran out before this block began"* — both leave it one past the end. Guessing
  /// wrong would put the wrong task above the Complete button, which is the one
  /// mistake this feature must not make: it is a write, and it would land on
  /// something nobody worked on.
  ///
  /// Reading what the timer recorded is also the only answer that survives the
  /// app being closed and reopened in the middle of a block.
  func runningBlockAttachment() -> SessionAttachment? {
    guard let state = try? context.fetch(FetchDescriptor<TimerState>()).first,
          state.isRunning, state.kind == .work else { return nil }
    return Self.attachment(of: state.taskID, state.taskTitle, state.projectID, state.projectTitle)
  }

  /// What the block an end-of-block sheet is about was attached to.
  ///
  /// Two cases, and they are different rows:
  ///
  ///   * **The stop sheet** is over a focus block that is still running, so the
  ///     answer is on the timer's own state.
  ///   * **The reflection sheet** is over an already-running break (D4), by which
  ///     time the timer's state describes the break. The answer is then on the
  ///     finished-block row the timer wrote when the focus block ended.
  ///
  /// Either way it is what the timer recorded rather than what the plan would
  /// guess, for the reason above.
  func attachmentForTheBlockJustWorked() -> SessionAttachment? {
    if let state = try? context.fetch(FetchDescriptor<TimerState>()).first,
       state.isRunning, state.kind == .work {
      return Self.attachment(of: state.taskID, state.taskTitle, state.projectID, state.projectTitle)
    }

    // The newest handful of finished blocks, newest first, and the most recent
    // focus block among them. Bounded rather than filtered in the query: a
    // database predicate cannot compare against an enumeration case, and the
    // finished-block table is the one table in this app designed to grow for its
    // whole life — reading all of it on every redraw of a sheet would be a real
    // cost for an answer that is always within the last block or two.
    var descriptor = FetchDescriptor<PomodoroSession>(
      sortBy: [SortDescriptor(\.endedAt, order: .reverse)])
    descriptor.fetchLimit = Self.recentBlocksToLookBackThrough
    let recent = (try? context.fetch(descriptor)) ?? []
    guard let session = recent.first(where: { $0.kind == .work }) else { return nil }
    return Self.attachment(of: session.taskID, session.taskTitle, session.projectID, session.projectTitle)
  }

  /// Four stored columns as one value, or `nil` when the block had no
  /// attachment at all.
  private static func attachment(
    of taskID: String?,
    _ taskTitle: String?,
    _ projectID: String?,
    _ projectTitle: String?) -> SessionAttachment? {
    guard taskID != nil || projectID != nil else { return nil }
    return SessionAttachment(
      taskID: taskID,
      taskTitle: taskTitle,
      projectID: projectID,
      projectTitle: projectTitle)
  }

  /// How far back to look for the most recent focus block.
  ///
  /// A focus block is at most one block behind the break that follows it, so one
  /// or two would do. Eight is a margin for a run of stopped blocks, and it is
  /// still a fixed, tiny read rather than a scan of a table that grows all year.
  private static let recentBlocksToLookBackThrough = 8

  // MARK: Resolving an item against the local mirror

  /// Whether the cache still holds the Todoist object a planned item points at.
  ///
  /// - Returns: `.unknown` when the mirror has never been filled — on a first
  ///   run, or offline before a first fetch.
  func isStillInTodoist(_ item: Item) -> Presence {
    switch item.kind {
    case .task: presenceOfTask(id: item.todoistID)
    case .project: presenceOfProject(id: item.todoistID)
    }
  }

  /// The same question about a bare identifier, for the places that have an
  /// attachment in hand rather than a planned item — the timer's own line, and
  /// the Complete button.
  func presenceOfTask(id: String) -> Presence {
    guard hasEverSynced else { return .unknown }
    // Bound to a local constant first: a database predicate may only capture a
    // plain value, never a path through another object.
    let todoistID = id
    return exists(FetchDescriptor<CachedTask>(
      predicate: #Predicate<CachedTask> { $0.id == todoistID })) ? .present : .absent
  }

  func presenceOfProject(id: String) -> Presence {
    guard hasEverSynced else { return .unknown }
    let todoistID = id
    return exists(FetchDescriptor<CachedProject>(
      predicate: #Predicate<CachedProject> { $0.id == todoistID })) ? .present : .absent
  }

  /// Every completion this app has recorded, as `task id → when`.
  ///
  /// Used by the plan screen to say *"Completed at 14:57"* beside an item this
  /// app ticked off during this session. It is a query, not a column: nothing
  /// about completion is ever stored on a planned item.
  func completionsRecorded() -> [String: Date] {
    let rows = (try? context.fetch(FetchDescriptor<CompletedTaskRecord>())) ?? []
    return rows.reduce(into: [String: Date]()) { table, row in
      // The newest wins. A task genuinely completed twice — closed here,
      // reopened in Todoist, closed here again — is two honest rows, and the
      // later one is what the plan should say.
      if let existing = table[row.taskID], existing >= row.completedAt { return }
      table[row.taskID] = row.completedAt
    }
  }

  // MARK: Private

  private let context: ModelContext

  /// The tasks ticked off since this sprint began (D21b). Asked, never told.
  private let completedThisSprint: SprintCompletions

  /// The single plan row, or `nil` when no plan has been made.
  private var plan: SessionPlan?

  /// Whether the local mirror has ever been filled. Cheaper than reading a date
  /// when only the yes/no is wanted.
  private var hasEverSynced = false

  /// Re-reads everything from the database.
  ///
  /// Called after every change rather than the values being adjusted in place,
  /// so what this type publishes and what is on disk cannot drift apart. The
  /// plan is a handful of rows; re-reading it is cheaper than a bug.
  private func reload() {
    let planRow = try? context.fetch(FetchDescriptor<SessionPlan>()).first
    plan = planRow
    createdAt = planRow?.createdAt

    let rows = (try? context.fetch(FetchDescriptor<SessionPlanItem>(
      sortBy: [SortDescriptor(\.position)]))) ?? []
    items = rows.map {
      Item(
        todoistID: $0.todoistID,
        titleSnapshot: $0.titleSnapshot,
        kind: $0.kind,
        position: $0.position)
    }

    // Clamped rather than trusted. A cursor past the end is a legitimate state
    // — the plan is worked through — but a negative one never is.
    currentIndex = max(0, planRow?.currentIndex ?? 0)

    var descriptor = FetchDescriptor<CachedProject>()
    descriptor.fetchLimit = 1
    hasEverSynced = ((try? context.fetch(descriptor))?.isEmpty == false)
  }

  private func deleteEveryRow() {
    for row in (try? context.fetch(FetchDescriptor<SessionPlanItem>())) ?? [] {
      context.delete(row)
    }
    for row in (try? context.fetch(FetchDescriptor<SessionPlan>())) ?? [] {
      context.delete(row)
    }
  }

  /// Saves, and answers whether it worked.
  ///
  /// The answer is passed back to the screen rather than swallowed: a plan
  /// change that silently did not happen would leave somebody looking at a
  /// queue the timer is not going to follow.
  private func persist() -> Bool {
    do {
      try context.save()
      return true
    } catch {
      return false
    }
  }

  private func exists<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> Bool {
    var bounded = descriptor
    bounded.fetchLimit = 1
    return ((try? context.fetch(bounded))?.isEmpty == false)
  }
}
