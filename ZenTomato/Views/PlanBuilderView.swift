import SwiftData
import SwiftUI

/// The Todoist sheet: one navigation stack, three screens, and the state that
/// is shared between them.
///
/// WHAT IS ON IT
/// The token screen when there is no token; otherwise the picker, a project's
/// tasks, and the session plan. It is presented from the timer screen's
/// attachment line and from one row in Settings.
///
/// IT IS DISMISSIBLE, AND THAT IS A DECISION
/// Nothing on this sheet is undecided, so swiping it away costs nothing — the
/// same rule the end-of-block sheet follows, and the opposite of the stop sheet,
/// which refuses to be swiped away because a block would otherwise be left with
/// no answer.
///
/// WHERE THE PLAN IS ACTUALLY WRITTEN
/// Choosing things builds a **selection** in this view's own state. That
/// selection becomes the plan at one of two moments: opening the session plan,
/// or finishing with the sheet. It is written as a *replacement*, because D17
/// says a plan is replaced when a new one is made and is never appended to —
/// and choosing nothing writes nothing at all, so opening the picker and
/// changing your mind leaves a plan in progress exactly as it was.
///
/// **Nothing on this sheet writes to Todoist.** Every request behind it is a
/// read. The only thing that can ever be written to Todoist lives on the
/// end-of-block sheet, behind a button that names its destination.
struct PlanBuilderView: View {
  // MARK: Lifecycle

  /// - Parameters:
  ///   - tokens: where the credential lives.
  ///   - cache: the local mirror, and the one thing here that starts a request.
  ///   - plan: the plan and its cursor.
  ///   - opensOnThePlan: open straight onto the session plan rather than the
  ///     picker. Set when somebody taps a timer screen that already has a plan.
  init(
    tokens: any TokenStore,
    cache: TodoistCacheStore,
    plan: SessionPlanStore,
    opensOnThePlan: Bool = false) {
    self.tokens = tokens
    self.cache = cache
    self.plan = plan
    self.opensOnThePlan = opensOnThePlan
    // Built here rather than lazily, so a half-pasted credential survives every
    // redraw and there is never a frame with nothing on the screen.
    _signIn = State(initialValue: SignInScreenModel(tokens: tokens, cache: cache))
  }

  // MARK: Internal

  /// The two screens below the root. A closed list: there is nowhere else to go
  /// from this sheet, and in particular nowhere that makes anything.
  enum Route: Hashable {
    case project(id: String, name: String)
    case sessionPlan
  }

  /// What the last refresh found, which decides what sits above the list.
  enum Freshness: Equatable {
    /// The mirror was filled just now.
    case fresh
    /// The mirror could not be filled, but there is something in it to use.
    case stale(String)
    /// The mirror could not be filled and there is nothing in it at all.
    case nothingYet
  }

  var body: some View {
    NavigationStack(path: $path) {
      root
        .navigationTitle("Todoist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { finish() }
              .accessibilityHint(Text("Saves your plan and closes."))
          }
        }
        .navigationDestination(for: Route.self) { route in
          destination(for: route)
        }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .task {
      readToken()
      // `force: false`: opening the sheet is not the same as asking for a
      // refresh, and opening the app straight into it used to fire this and the
      // foreground sweep together.
      await refresh(force: false)
      // NOT PAST THE TOKEN SCREEN. If the refresh just found a revoked
      // credential, the root of this stack is now the screen that says so —
      // and pushing the session plan on top of it would hide the single most
      // important sentence this feature can say behind a list, leaving somebody
      // to discover it later as a Complete button that does not work.
      if opensOnThePlan, plan.isEmpty == false, hasToken, signIn.banner == nil {
        path = [.sessionPlan]
      }
    }
  }

  /// What the banner above the list should say, given what went wrong and how
  /// old the mirror is.
  ///
  /// **Neither wording is amber.** From where the reader is standing nothing has
  /// failed: every project is there, the search works, and a plan can be built.
  /// Amber would be the loudest thing on a screen where nothing is wrong, and it
  /// would spend the screen's one warning.
  ///
  /// A mirror that has never been filled is a different situation and gets the
  /// whole screen — see `ProjectPickerView`.
  static func freshness(after error: any Error, syncedAt: Date?) -> Freshness {
    guard let todoist = error as? TodoistError else {
      return syncedAt == nil ? .nothingYet : .stale(cacheAge(syncedAt))
    }

    switch todoist {
    case .rateLimited(let retryAfter):
      // "Asked us to slow down" — the "us" is correct and is the whole point.
      // This is the app's traffic, not the reader's behaviour. No "you", no
      // "too many requests", no status code.
      //
      // **It does not claim the app is trying again**, because it is not. There
      // is no timer and no scheduled retry behind this screen — the pull is the
      // retry, and it is held back until the wait is over. A sentence promising
      // an automatic attempt with a number that never counts down is the kind of
      // small untruth that teaches a reader to stop believing the quiet lines.
      guard let seconds = retryAfter.map({ Int($0.components.seconds) }), seconds > 0 else {
        return .stale("Todoist asked us to slow down. Pull down to try again shortly — nothing is lost.")
      }
      return .stale(
        "Todoist asked us to slow down. Pull down to try again in \(seconds) seconds — nothing is lost.")

    case .offline, .server, .malformedResponse, .paginationDidNotTerminate, .notSignedIn, .tokenRejected:
      return syncedAt == nil ? .nothingYet : .stale(cacheAge(syncedAt))
    }
  }

  // MARK: Private

  private let tokens: any TokenStore
  private let cache: TodoistCacheStore
  private let plan: SessionPlanStore
  private let opensOnThePlan: Bool

  @Environment(\.dismiss) private var dismiss

  /// Every mirrored project, in Todoist's own order. **All of them** —
  /// `SPEC.md` locks that the picker shows everything, with no filtering at any
  /// level.
  @Query(sort: [SortDescriptor(\CachedProject.childOrder)]) private var projects: [CachedProject]

  @Query(sort: [SortDescriptor(\CachedSection.sectionOrder)]) private var sections: [CachedSection]

  @Query(sort: [SortDescriptor(\CachedTask.childOrder)]) private var tasks: [CachedTask]

  /// The tasks ticked off since this sprint began (D21b).
  ///
  /// Optional so this sheet can be looked at in a preview with nothing behind
  /// it. `@Observable`, so the picker redraws the instant a task leaves the set
  /// — no notification, no manual refresh.
  @Environment(SprintCompletions.self) private var completedThisSprint: SprintCompletions?

  @State private var path: [Route] = []

  /// The plan being built, in the order it was chosen. Not yet written down.
  @State private var selections: [SessionPlanStore.Selection] = []

  @State private var freshness: Freshness = .fresh

  /// Until when Todoist has asked us to stop asking, or `nil`.
  ///
  /// It exists so the banner's sentence is true. The copy used to say the app
  /// was trying again when nothing was, and a pull during the stated wait went
  /// straight out to Todoist — which is the one thing a rate limit asks you not
  /// to do.
  @State private var rateLimitedUntil: Date?

  /// Whether there is a credential. Read rather than watched, because the
  /// Keychain does not publish changes.
  @State private var hasToken = false

  /// The token screen's state, kept across redraws.
  @State private var signIn: SignInScreenModel

  /// What the picker is built from, as plain values with no database rows in
  /// them. Rebuilt when the mirror changes, which is what `@Query` is for.
  private var picker: PickerScreenModel {
    let namesByProject = Dictionary(projects.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    // Counted once, in one pass. Asking each project how many tasks it has
    // would be one scan of the whole list per project, on every redraw — which
    // on a five-thousand-task account is a quarter of a million comparisons to
    // draw a line that says "3 tasks".
    let countsByProject = tasks.reduce(into: [String: Int]()) { counts, task in
      counts[task.projectID, default: 0] += 1
    }
    return PickerScreenModel(
      projects: projects.map { project in
        PickerScreenModel.Project(
          id: project.id,
          name: project.name,
          openTaskCount: countsByProject[project.id] ?? 0)
      },
      sections: sections.map {
        PickerScreenModel.Section(id: $0.id, name: $0.name, projectID: $0.projectID)
      },
      // D21b: A TASK THIS APP TICKED OFF DURING THIS SPRINT IS NOT OFFERED AGAIN
      // UNTIL THE SPRINT ENDS.
      //
      // Closing a recurring task in Todoist advances it to its next occurrence
      // rather than finishing it, so the mirror still holds it and the picker
      // would otherwise offer it back the same afternoon. The rule holds for
      // every task, not only recurring ones, so it needs no recurrence knowledge
      // and cannot be wrong about one it guessed at.
      //
      // **Nothing is drawn to explain the absence** — no "already done" row, no
      // strikethrough, no dimmed entry, no badge. `PickerScreenModel` gains no
      // reference to the set and no new field: it is a pure value built from
      // whatever rows it is given, and it is simply given fewer.
      //
      // This is not a filter on what Todoist holds. `SPEC.md`'s "all projects,
      // sections and tasks are visible" is about the mirror, and the mirror is
      // untouched; this is one sprint's worth of work you have already done.
      tasks: tasks.filter { completedThisSprint?.contains($0.id) != true }.map { task in
        PickerScreenModel.TaskItem(
          id: task.id,
          title: task.content,
          projectID: task.projectID,
          projectName: namesByProject[task.projectID] ?? "",
          sectionID: task.sectionID)
      })
  }

  /// What the line along the bottom of the picker says.
  ///
  /// **With nothing newly chosen it reports the plan that already exists**, and
  /// that is not cosmetic. This bar is the only route to the session plan, so a
  /// bar that said "Nothing planned yet" over a three-item plan was both untrue
  /// and a dead end: back out of the plan screen and there was no way back to
  /// it, and no way to reach Skip or Remove without destroying the plan to get
  /// there. Choosing anything switches it to the selection being built, which is
  /// what will replace the plan when the sheet is finished with.
  private var planBarContents: PlanBar.Contents {
    guard selections.isEmpty else {
      return PlanBar.Contents(count: selections.count, nextTitle: selections.first?.titleSnapshot)
    }
    return PlanBar.Contents(count: plan.items.count, nextTitle: plan.currentItem?.titleSnapshot)
  }

  /// The token screen, or the picker.
  @ViewBuilder
  private var root: some View {
    if hasToken, signIn.banner == nil {
      ProjectPickerView(
        picker: picker,
        freshness: freshness,
        selections: $selections,
        planBar: planBarContents,
        onOpenProject: { path.append(.project(id: $0.id, name: $0.name)) },
        onOpenPlan: openPlan,
        onRefresh: { await refresh() })
    } else {
      TodoistSignInView(model: signIn, onConnected: connected)
    }
  }

  @ViewBuilder
  private func destination(for route: Route) -> some View {
    switch route {
    case .project(let id, let name):
      TaskPickerView(
        projectID: id,
        projectName: name,
        picker: picker,
        freshness: freshness,
        selections: $selections,
        planBar: planBarContents,
        onOpenPlan: openPlan,
        onRefresh: { await refresh() })

    case .sessionPlan:
      SessionPlanView(plan: plan, onDone: finish)
    }
  }

  private func readToken() {
    do {
      hasToken = try tokens.read()?.isEmpty == false
    } catch {
      // A Keychain that cannot be read is, from where the reader is standing,
      // the same as one holding nothing: the screen asks for a token.
      hasToken = false
    }
  }

  private func connected() {
    signIn = SignInScreenModel(tokens: tokens, cache: cache)
    hasToken = true
  }

  /// Fills the mirror, and decides what the picker says about its own age.
  ///
  /// **No request is made per keystroke and none is made on a timer.** This runs
  /// when the sheet opens and when somebody pulls the list down, and that is the
  /// whole of this feature's traffic apart from one close.
  private func refresh(force: Bool = true) async {
    guard hasToken else { return }
    // HAMMERING THE LIST MUST NOT EXTEND THE LOCKOUT. Todoist has said how long
    // to wait; a pull-to-refresh inside that window re-shows the banner and
    // re-announces it, and sends nothing. Swallowing the gesture silently would
    // read as the app being frozen, which is why the banner is posted again
    // rather than the pull being ignored.
    if let until = rateLimitedUntil, Date() < until {
      freshness = Self.stillWaiting(until: until, now: Date())
      return
    }
    rateLimitedUntil = nil
    do {
      try await cache.refresh(force: force)
      freshness = .fresh
    } catch {
      freshness = Self.freshness(after: error, syncedAt: cache.lastSyncedAt)
      if case TodoistError.tokenRejected = error {
        // The credential was taken out of the Keychain by the client. Nothing
        // else is: the mirror, the plan and everything recorded stay exactly as
        // they were. A stale credential is not a decision to disconnect.
        signIn = SignInScreenModel(tokens: tokens, cache: cache, banner: .revoked)
        // Said in both places, so nothing downstream can conclude there is still
        // a usable token — the timer screen does the same thing on its own
        // refresh.
        hasToken = false
      }
      if case TodoistError.rateLimited(let retryAfter) = error {
        rateLimitedUntil = Self.deadline(after: retryAfter, from: Date())
      }
    }
  }

  /// Writes the plan being built, if there is one, and shows it.
  private func openPlan() {
    commit()
    path.append(.sessionPlan)
  }

  private func finish() {
    commit()
    dismiss()
  }

  /// Turns the selection into the plan.
  ///
  /// Choosing nothing writes nothing, so opening the picker, looking around and
  /// closing it again leaves a plan in progress untouched. Choosing anything
  /// replaces the plan outright — D17: a plan is not appended to, and a new plan
  /// is a new intention, so it starts at the front.
  private func commit() {
    guard selections.isEmpty == false else { return }
    plan.replacePlan(with: selections)
    selections = []
  }

  /// When the wait Todoist asked for is over.
  ///
  /// With no stated wait there is nothing to count, so nothing is held back: the
  /// next pull goes out. Guessing a number Todoist did not give would be the app
  /// inventing a rule on somebody's behalf.
  static func deadline(after retryAfter: Duration?, from now: Date) -> Date? {
    guard let retryAfter else { return nil }
    let seconds = Double(retryAfter.components.seconds)
    guard seconds > 0 else { return nil }
    return now.addingTimeInterval(seconds)
  }

  /// The same sentence, with the time that is actually left on it.
  static func stillWaiting(until deadline: Date, now: Date) -> Freshness {
    let seconds = max(1, Int(deadline.timeIntervalSince(now).rounded(.up)))
    return .stale(
      "Todoist asked us to slow down. Pull down to try again in \(seconds) seconds — nothing is lost.")
  }

  /// "Can't reach Todoist. This is your list as it was at 14:02 — pick from it
  /// as normal."
  ///
  /// The time is formatted by the reader's own clock setting, never a hard-coded
  /// `HH:mm` — a timestamp in a format somebody does not use is a piece of the
  /// screen they have to translate every time.
  private static func cacheAge(_ syncedAt: Date?) -> String {
    guard let syncedAt else {
      return "Can't reach Todoist. This is your list as it was — pick from it as normal."
    }
    let when = Calendar.current.isDateInToday(syncedAt)
      ? "at \(syncedAt.formatted(date: .omitted, time: .shortened))"
      : "on \(syncedAt.formatted(date: .abbreviated, time: .shortened))"
    return "Can't reach Todoist. This is your list as it was \(when) — pick from it as normal."
  }
}
