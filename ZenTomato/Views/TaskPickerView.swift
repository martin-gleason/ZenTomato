import SwiftUI

/// One project's tasks: its sections, each with the tasks inside it, then the
/// tasks that sit loose in the project.
///
/// EXACTLY THREE LEVELS ARE DRAWN — PROJECT, SECTION, TASK — AND NOTHING DEEPER
/// Anything Todoist nests below a task appears here as an ordinary task in the
/// same list, in the order the API returned it, with no indentation and no
/// disclosure triangle. Drawing a hierarchy that the plan is forbidden to hold
/// is how a plan starts becoming a task model one reasonable step at a time.
///
/// A TASK ROW CARRIES ONLY ITS TITLE
/// No due date, no priority, no labels, no flag, and above all no checkbox that
/// writes anything. The mirror does not hold those fields, which is deliberate:
/// a column that cannot be stored cannot be drawn, and a column that cannot be
/// drawn cannot start an argument about sorting by it.
///
/// AN EMPTY PROJECT OFFERS NOTHING
/// One sentence — *"No tasks in this project."* — and no control of any kind.
/// Not a button, not a greyed button, not a placeholder row. `CLAUDE.md` calls
/// the no-capture rule a standing rule from the owner's productivity system
/// rather than a feature gap, and this is the screen where the difference shows.
struct TaskPickerView: View {
  // MARK: Internal

  let projectID: String
  let projectName: String

  /// Everything mirrored from Todoist, as plain values.
  let picker: PickerScreenModel

  /// How old the mirror is.
  let freshness: PlanBuilderView.Freshness

  /// The plan being built, in the order it was chosen.
  @Binding var selections: [SessionPlanStore.Selection]

  let onOpenPlan: () -> Void
  let onRefresh: () async -> Void

  var body: some View {
    List {
      if case .stale(let note) = freshness {
        StaleMirrorBanner(note: note)
      }

      if rows.isEmpty {
        emptyProject
      } else {
        content
      }
    }
    .scrollContentBackground(.hidden)
    .background(Color(.surfacePrimary).ignoresSafeArea())
    .refreshable { await onRefresh() }
    .navigationTitle(projectName)
    .navigationBarTitleDisplayMode(.inline)
    .safeAreaInset(edge: .bottom, spacing: Spacing.none) {
      PlanBar(selections: selections, onOpen: onOpenPlan)
    }
  }

  // MARK: Private

  private var rows: [PickerScreenModel.Row] {
    picker.rows(inProject: projectID)
  }

  /// Sections become headed groups; tasks not in a section sit under a heading
  /// of their own, in Todoist's order throughout.
  ///
  /// The rows arrive already ordered from the model, so this only decides where
  /// a heading starts. Nothing is sorted here — inventing an order is exactly
  /// what the mirror exists to avoid.
  @ViewBuilder
  private var content: some View {
    ForEach(groups) { group in
      Section {
        ForEach(group.tasks) { task in
          PickerRowView(
            title: task.title,
            ordinal: ordinal(for: task.id),
            isSelected: isSelected(task.id),
            onToggle: { toggle(.init(todoistID: task.id, titleSnapshot: task.title, kind: .task)) })
        }
      } header: {
        Text(group.name)
          .font(Typography.kicker)
          .textCase(.uppercase)
          .foregroundStyle(Color(.textMuted))
      }
      .listRowBackground(Color(.surfaceRaised))
    }
  }

  /// The sections of this project that have anything in them, then everything
  /// loose in the project under a heading of its own.
  ///
  /// Nothing is sorted here. The sections and the tasks arrive in Todoist's own
  /// order, which the mirror copied and this screen keeps — inventing an order
  /// is exactly what mirroring exists to avoid.
  private var groups: [TaskGroup] {
    let mine = picker.tasks.filter { $0.projectID == projectID }
    let mySections = picker.sections.filter { $0.projectID == projectID }

    var groups: [TaskGroup] = []
    for section in mySections {
      let inSection = mine.filter { $0.sectionID == section.id }
      guard inSection.isEmpty == false else { continue }
      groups.append(TaskGroup(id: section.id, name: section.name, tasks: inSection))
    }

    let sectionIDs = Set(mySections.map(\.id))
    let loose = mine.filter { task in
      guard let sectionID = task.sectionID else { return true }
      // A task whose section was not mirrored is drawn loose rather than
      // dropped. Losing a task from a picker is worse than filing it oddly.
      return sectionIDs.contains(sectionID) == false
    }
    if loose.isEmpty == false {
      groups.append(TaskGroup(id: Self.looseGroupID, name: "Not in a section", tasks: loose))
    }
    return groups
  }

  /// An identity for the one heading that is not a Todoist section. It is not a
  /// Todoist id and could never collide with one — Todoist's are opaque strings
  /// with no spaces in them.
  private static let looseGroupID = "not in a section"

  private var emptyProject: some View {
    Text(PickerScreenModel.emptyProjectMessage)
      .font(Typography.body)
      .foregroundStyle(Color(.textMuted))
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, Spacing.md)
      .listRowBackground(Color(.surfaceRaised))
  }

  private func isSelected(_ id: String) -> Bool {
    selections.contains { $0.todoistID == id }
  }

  private func ordinal(for id: String) -> Int? {
    selections.firstIndex { $0.todoistID == id }.map { $0 + 1 }
  }

  private func toggle(_ selection: SessionPlanStore.Selection) {
    if let index = selections.firstIndex(where: { $0.todoistID == selection.todoistID }) {
      selections.remove(at: index)
    } else {
      selections.append(selection)
    }
  }
}

// MARK: - TaskGroup

/// One heading and the tasks under it, for the list to draw.
///
/// A layout value and nothing more: it is built when the screen is drawn,
/// thrown away when it is not, and never stored. It defines no hierarchy the
/// plan could inherit.
struct TaskGroup: Identifiable {
  let id: String
  let name: String
  let tasks: [PickerScreenModel.TaskItem]
}
