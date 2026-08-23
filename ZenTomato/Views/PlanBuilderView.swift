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
      await refresh()
      if opensOnThePlan, plan.isEmpty == false, hasToken {
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
      guard let seconds = retryAfter.map({ Int($0.components.seconds) }), seconds > 0 else {
        return .stale("Todoist asked us to slow down. Trying again shortly — nothing is lost.")
      }
      return .stale("Todoist asked us to slow down. Trying again in \(seconds) seconds — nothing is lost.")

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

  @State private var path: [Route] = []

  /// The plan being built, in the order it was chosen. Not yet written down.
  @State private var selections: [SessionPlanStore.Selection] = []

  @State private var freshness: Freshness = .fresh

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
      tasks: tasks.map { task in
        PickerScreenModel.TaskItem(
          id: task.id,
          title: task.content,
          projectID: task.projectID,
          projectName: namesByProject[task.projectID] ?? "",
          sectionID: task.sectionID)
      })
  }

  /// The token screen, or the picker.
  @ViewBuilder
  private var root: some View {
    if hasToken, signIn.banner == nil {
      ProjectPickerView(
        picker: picker,
        freshness: freshness,
        selections: $selections,
        onOpenProject: { path.append(.project(id: $0.id, name: $0.name)) },
        onOpenPlan: openPlan,
        onRefresh: refresh)
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
        onOpenPlan: openPlan,
        onRefresh: refresh)

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
  private func refresh() async {
    guard hasToken else { return }
    do {
      try await cache.refresh()
      freshness = .fresh
    } catch {
      freshness = Self.freshness(after: error, syncedAt: cache.lastSyncedAt)
      if case TodoistError.tokenRejected = error {
        // The credential was taken out of the Keychain by the client. Nothing
        // else is: the mirror, the plan and everything recorded stay exactly as
        // they were. A stale credential is not a decision to disconnect.
        signIn = SignInScreenModel(tokens: tokens, cache: cache, banner: .revoked)
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

// MARK: - PlanBar

/// The line pinned along the bottom of the picker and of every project screen.
///
/// **When the plan is empty it is inert, and that is what removes the need for
/// an "Add" button anywhere on this sheet.** The plan is only ever reached from
/// the picker, so the way to put something in it is the picker you are already
/// standing in.
struct PlanBar: View {
  // MARK: Internal

  /// What has been chosen so far, in order.
  let selections: [SessionPlanStore.Selection]

  /// Tapping it opens the session plan. Only called when there is something in
  /// the plan to open.
  let onOpen: () -> Void

  var body: some View {
    content
      .padding(.horizontal, Spacing.md)
      .padding(.vertical, Spacing.xs)
      .frame(maxWidth: .infinity)
      .background(Color(.surfaceRaised))
      .overlay(alignment: .top) {
        // Decoration, and one of the few places the decorative border role is
        // correct. It carries no information, so VoiceOver is told to skip it.
        Rectangle()
          .fill(Color(.border))
          .frame(height: Spacing.borderHairline)
          .accessibilityHidden(true)
      }
  }

  // MARK: Private

  @ViewBuilder
  private var content: some View {
    if let first = selections.first {
      Button(action: onOpen) {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
          Text(Self.summary(count: selections.count))
            .font(Typography.label)
            .foregroundStyle(Color(.textPrimary))
          Text("Next · \(first.titleSnapshot)")
            .font(Typography.label)
            .foregroundStyle(Color(.textMuted))
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: Spacing.controlHeight)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityHint(Text("Opens your session plan."))
    } else {
      Text("Nothing planned yet")
        .font(Typography.label)
        .foregroundStyle(Color(.textMuted))
        .frame(maxWidth: .infinity)
        .frame(minHeight: Spacing.controlHeight)
    }
  }

  /// The singular matters: a plan of one item is the commonest plan there is.
  private static func summary(count: Int) -> String {
    "Plan · \(count) \(count == 1 ? "item" : "items")"
  }
}
