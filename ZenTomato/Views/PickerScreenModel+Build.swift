import Foundation

/// Turning the mirror's rows into the plain values the picker draws.
///
/// **Why it is not in `PlanBuilderView`.** It was, and that file sat at the
/// 400-line cap, so `F13` — adding a tint and a priority — could not be written
/// there without shaving comments off unrelated code. The cap prompted the move;
/// it is not what justifies it. Turning database rows into plain values was never a
/// view's job, and here it is reachable from a test with no screen behind it,
/// beside the type it builds.
///
/// Nothing in this file knows a view exists, and nothing in it holds a row: every
/// value it returns is a copy, and the whole model is rebuilt whenever the mirror
/// changes.
extension PickerScreenModel {
  /// The whole picker, from the three mirrored tables.
  ///
  /// - Parameters:
  ///   - projects: every mirrored project, in Todoist's own order. **All of
  ///     them** — `SPEC.md` locks that the picker shows everything, with no
  ///     filtering at any level.
  ///   - completedThisSprint: task ids this app has ticked off since the sprint
  ///     began, which are left out of the result. `nil` when there is no sprint,
  ///     which is also what a preview passes.
  static func build(
    projects: [CachedProject],
    sections: [CachedSection],
    tasks: [CachedTask],
    completedThisSprint: Set<String>?) -> PickerScreenModel {
    let namesByProject = Dictionary(
      projects.map { ($0.id, $0.name) },
      uniquingKeysWith: { first, _ in first })

    // Counted once, in one pass. Asking each project how many tasks it has would
    // be one scan of the whole list per project, on every redraw — which on a
    // five-thousand-task account is a quarter of a million comparisons to draw a
    // line that says "3 tasks".
    let countsByProject = tasks.reduce(into: [String: Int]()) { counts, task in
      counts[task.projectID, default: 0] += 1
    }

    return PickerScreenModel(
      projects: projects.map { project in
        PickerScreenModel.Project(
          id: project.id,
          name: project.name,
          openTaskCount: countsByProject[project.id] ?? 0,
          // F13: the one place the mirror's colour NAME becomes a tint, so no
          // screen ever does the lookup itself.
          tint: TodoistTint(todoistName: project.colorName))
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
          sectionID: task.sectionID,
          // F13: the wire number becomes a level here, once, and never in a view.
          priority: TodoistPriority(wire: task.priority))
      })
  }
}
