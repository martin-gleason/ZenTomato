import Foundation

/// What one focus block is attached to: a task, or a project, or nothing.
///
/// WHY THIS SMALL VALUE EXISTS AT ALL
/// It is the seam that keeps the timer from knowing Todoist exists. The engine
/// asks for one of these at the start of a focus block and copies the four
/// strings onto its own rows; it never sees a plan, a cache, a network client,
/// or a Todoist identifier it has to understand. Everything on the other side of
/// this value can change without touching the timer.
///
/// It is a plain immutable value rather than a database row — nothing here is
/// stored, and nothing here can be edited. `Sendable` marks it safe to hand
/// between threads, which a database row would not be.
///
/// **The shape follows the spec's own sentence**: a pomodoro is attached to
/// exactly one Todoist task, or, if no task was chosen, to a project. So either
/// the task pair is filled in or the project pair is, and a block with no plan
/// has neither. The four values are held separately, rather than as one "either
/// this or that", because that is how they are stored: four plain columns on the
/// finished-block row, readable by anybody opening the database file.
struct SessionAttachment: Sendable, Equatable {
  /// Todoist's identifier for the attached task, or `nil` when a project was
  /// planned instead.
  let taskID: String?

  /// The task's title, frozen at the moment the block began.
  ///
  /// A frozen copy for the same reason the plan keeps one: renaming a task in
  /// Todoist during a 25-minute block must not change what the record says you
  /// were working on.
  let taskTitle: String?

  /// Todoist's identifier for the project — of the attached task, or of the
  /// planned project itself.
  let projectID: String?

  /// The project's name, frozen at the moment the block began.
  let projectTitle: String?

  /// Creates an attachment. Both pairs are optional because a plan may hold a
  /// project on its own, and because a block may have no attachment at all.
  init(
    taskID: String? = nil,
    taskTitle: String? = nil,
    projectID: String? = nil,
    projectTitle: String? = nil) {
    self.taskID = taskID
    self.taskTitle = taskTitle
    self.projectID = projectID
    self.projectTitle = projectTitle
  }
}
