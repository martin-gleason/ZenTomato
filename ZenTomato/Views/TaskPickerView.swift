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
///
/// AN EMPTY SECTION IS STILL DRAWN
/// `SPEC.md` locks that all projects, sections and tasks are visible. A section
/// somebody has just cleared is still one of their sections, and quietly
/// dropping it would be the app disagreeing with Todoist about what is in
/// somebody's account. It is drawn as a heading with nothing under it — a
/// heading is text, so this adds no control anywhere.
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

  /// What the line along the bottom says — the selection being built, or the
  /// plan that already exists when nothing new has been chosen.
  let planBar: PlanBar.Contents

  let onOpenPlan: () -> Void
  let onRefresh: () async -> Void

  var body: some View {
    List {
      if case .stale(let note) = freshness {
        StaleMirrorBanner(note: note)
      }

      // The sentence and the headings are not alternatives. A project with two
      // emptied sections has nothing to work on *and* two sections, and both are
      // facts about Todoist that this screen reports.
      if hasNothingToWorkOn {
        emptyProject
      }
      content
    }
    .scrollContentBackground(.hidden)
    .background(Color(.surfacePrimary).ignoresSafeArea())
    .refreshable { await onRefresh() }
    .navigationTitle(projectName)
    .navigationBarTitleDisplayMode(.inline)
    .safeAreaInset(edge: .bottom, spacing: Spacing.none) {
      PlanBar(contents: planBar, onOpen: onOpenPlan)
    }
  }

  // MARK: Private

  /// The headings and their tasks, **worked out by the model** rather than here.
  ///
  /// The screen draws exactly what `PickerScreenModelTests` examines. This was
  /// once computed twice — once in the model and once in this file — which meant
  /// the tested implementation was not the shipped one and the two could drift
  /// apart with the suite still green.
  private var groups: [PickerScreenModel.TaskGroup] {
    picker.groups(inProject: projectID)
  }

  /// Whether this project holds no open task at all.
  ///
  /// Counted from the groups rather than from whether there are any rows,
  /// because a project can now draw headings and still have nothing in it.
  private var hasNothingToWorkOn: Bool {
    groups.allSatisfy { $0.tasks.isEmpty }
  }

  /// Sections become headed groups; tasks not in a section sit under a heading
  /// of their own, in Todoist's order throughout.
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
