import Foundation

/// Everything the picker draws, worked out from the local mirror of Todoist and
/// from nothing else.
///
/// WHY THIS IS A PLAIN VALUE WITH NO DATABASE AND NO NETWORK IN IT
/// The picker is the sharpest place in this app where the standing no-capture
/// rule could be broken by accident, so the rule is expressed as the *shape of a
/// type* rather than as a condition somebody has to remember inside a view.
/// This model can produce exactly three kinds of row — a project, a section, a
/// task — and there is no fourth. A row that offered to make something would
/// have to be a new case in `Row`, which is a visible change to a closed list
/// that the tests switch over exhaustively.
///
/// It also means the search can be tested without a store, without a screen and
/// without a single request: hand it a handful of values, ask it what matches,
/// and read the answer.
///
/// **THE SEARCH NEVER REACHES TODOIST.** It filters what has already been
/// mirrored. That is not only a performance decision: a search field that makes
/// a request on every keystroke reads as a lookup that might *mint* something,
/// which is precisely the impression this screen has to avoid. There is no
/// transport here to reach the network with, so this is a property of the code
/// rather than a promise about it.
struct PickerScreenModel: Sendable {
  // MARK: Nested types

  /// One project, as the picker needs it.
  struct Project: Identifiable, Hashable, Sendable {
    /// Todoist's own identifier — an opaque string in API v1, never a number.
    let id: String
    let name: String

    /// How many tasks the mirror holds for this project.
    ///
    /// A count of what was copied, never a number this app maintains. The three
    /// Todoist endpoints return active objects only, so it is a count of open
    /// tasks by construction rather than by filtering.
    let openTaskCount: Int
  }

  /// One section inside a project.
  struct Section: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let projectID: String
  }

  /// One task. It carries its project's name so a search result is never
  /// ambiguous — titles repeat across projects, and a plan built from rows you
  /// cannot tell apart is a plan you cannot trust.
  struct TaskItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let projectID: String
    let projectName: String

    /// Which section it sits in, or `nil` when it is loose in the project.
    let sectionID: String?
  }

  /// Every kind of row the picker can draw. **There are three, and a fourth
  /// would be a change to this list.**
  ///
  /// The tests switch over this without a catch-all clause, so adding a case
  /// stops the test bundle compiling. That is the enforcement; this paragraph
  /// is only the explanation.
  enum Row: Identifiable, Hashable, Sendable {
    case project(Project)
    case section(Section)
    case task(TaskItem)

    var id: String {
      switch self {
      case .project(let project): "project-\(project.id)"
      case .section(let section): "section-\(section.id)"
      case .task(let task): "task-\(task.id)"
      }
    }
  }

  // MARK: The words this screen may say

  /// The search field's own prompt.
  ///
  /// A verb that **reads**, never one that makes. Not "Search or add", not
  /// "Find or create", not a bare "Search" — *your* Todoist names a corpus that
  /// already exists and either contains the answer or does not.
  static let searchPrompt = "Search your Todoist tasks"

  /// A project with nothing in it.
  ///
  /// This sentence and nothing else. No button, no placeholder row, no greyed
  /// control, no "nothing here yet — why not…". An empty project is a fact
  /// about Todoist, and this screen's whole job is to report facts about
  /// Todoist rather than to offer to change them.
  static let emptyProjectMessage = "No tasks in this project."

  /// A search that found nothing.
  ///
  /// **This is the single most likely place in the app for the no-capture rule
  /// to be broken**, because an empty result is exactly where every other app
  /// on the phone offers to create the thing you just typed. It offers nothing:
  /// not a button, not a disabled button, not a footer, not a row.
  static let noMatchHeading = "No tasks match that."

  /// The line that sits where every other app puts a create button.
  ///
  /// It is a statement of where tasks come from, in the quiet ink, with no tap
  /// target of any kind. **The third line is the whole design.**
  static let noMatchOrigin = "Tasks are created in Todoist, not here."

  /// Names what was searched, so the reader can see the app understood them.
  ///
  /// The query is echoed rather than paraphrased, and the screen truncates it —
  /// arbitrary typed text may not be allowed to set the layout.
  static func noMatchDetail(for query: String) -> String {
    "Nothing in your projects or tasks matches “\(query.trimmed)”."
  }

  // MARK: Lifecycle

  /// - Parameters:
  ///   - projects: every mirrored project, in Todoist's own order.
  ///   - sections: every mirrored section, in Todoist's own order.
  ///   - tasks: every mirrored task, in Todoist's own order.
  init(projects: [Project], sections: [Section], tasks: [TaskItem]) {
    self.projects = projects
    self.sections = sections
    self.tasks = tasks
  }

  // MARK: What was mirrored

  /// **All** of them. `SPEC.md` locks it: *"All projects, sections, and tasks
  /// are visible in the picker."* Nothing is filtered at any level, here or at
  /// the request.
  let projects: [Project]
  let sections: [Section]
  let tasks: [TaskItem]

  // MARK: The root screen

  /// Every project, in Todoist's own order.
  var projectRows: [Row] {
    projects.map(Row.project)
  }

  // MARK: Inside one project

  /// The sections of a project, each followed by its tasks, then the tasks that
  /// sit loose in the project.
  ///
  /// **Exactly three levels are drawn and nothing deeper.** Anything Todoist
  /// nests below a task appears here as an ordinary task in the same list, in
  /// the order the API returned it, with no indentation and no disclosure
  /// triangle. Drawing a hierarchy the plan is forbidden to hold is how a plan
  /// starts becoming a task model one reasonable step at a time.
  func rows(inProject projectID: String) -> [Row] {
    let mine = tasks.filter { $0.projectID == projectID }
    var rows: [Row] = []

    for section in sections where section.projectID == projectID {
      let inSection = mine.filter { $0.sectionID == section.id }
      guard inSection.isEmpty == false else { continue }
      rows.append(.section(section))
      rows.append(contentsOf: inSection.map(Row.task))
    }

    let sectionIDs = Set(sections.filter { $0.projectID == projectID }.map(\.id))
    let loose = mine.filter { task in
      guard let sectionID = task.sectionID else { return true }
      // A task whose section was not mirrored is drawn loose rather than
      // dropped. Losing a task from a picker is worse than filing it oddly.
      return sectionIDs.contains(sectionID) == false
    }
    rows.append(contentsOf: loose.map(Row.task))

    return rows
  }

  // MARK: Search

  /// Everything whose title contains the query, tasks first and then projects.
  ///
  /// Case- and accent-insensitive, so "reply to anna" finds "Reply to Anna" and
  /// "cafe" finds "Café". Sections are deliberately not searched: a section is a
  /// place rather than a thing to work on, and it cannot be planned.
  ///
  /// An empty or whitespace-only query matches nothing at all rather than
  /// everything — the unfiltered list is what the screen already shows.
  func rows(matching query: String) -> [Row] {
    let needle = query.trimmed
    guard needle.isEmpty == false else { return [] }

    let matchingTasks = tasks.filter { $0.title.contains(needle, caseAndAccentInsensitively: true) }
    let matchingProjects = projects.filter { $0.name.contains(needle, caseAndAccentInsensitively: true) }

    return matchingTasks.map(Row.task) + matchingProjects.map(Row.project)
  }
}

// MARK: - String helpers

private extension String {
  /// Trimmed of the whitespace and newlines a paste tends to arrive with.
  var trimmed: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// A search that ignores capitals and accents.
  ///
  /// The parameter exists so the call site says what it is asking for. Written
  /// out rather than reached for inline, because the option set is the sort of
  /// thing that gets quietly dropped in a tidy-up and nobody notices until
  /// somebody's task with an accent in it stops being findable.
  func contains(_ other: String, caseAndAccentInsensitively: Bool) -> Bool {
    guard caseAndAccentInsensitively else { return contains(other) }
    return range(of: other, options: [.caseInsensitive, .diacriticInsensitive]) != nil
  }
}
