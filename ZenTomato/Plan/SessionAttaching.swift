import Foundation

/// How the timer asks the plan for the next thing to work on.
///
/// This is the whole of what the timer knows about Todoist: one method, which
/// hands back four strings or nothing at all. The engine cannot fetch, cannot
/// search, cannot complete, and cannot see a plan — it can only take the next
/// item, once, when a focus block begins.
///
/// **WHY THE TIMER PULLS RATHER THAN A SCREEN PUSHING.** Blocks begin with
/// nobody looking. The break starts behind the end-of-block sheet, and when
/// auto-start is on the next pomodoro begins by itself while the phone is in a
/// pocket. A screen that handed the attachment to the timer would miss both of
/// those, and the record would silently lose the task on exactly the blocks
/// somebody was concentrating hardest during.
///
/// It is `@MainActor` because the only real implementation reads the database,
/// and the database is main-thread only in this app. It is `AnyObject` because
/// the plan is a live thing the engine holds a reference to, not a copy.
@MainActor
protocol SessionAttaching: AnyObject {
  /// Advances the plan and returns what the next focus block is attached to.
  ///
  /// Called once per focus block, at the moment it begins, and never for a
  /// break — a break is not a pomodoro and has nothing to be attached to.
  ///
  /// - Returns: the attachment for this block, or `nil` when there is no plan,
  ///   when the plan has been worked through, or when nobody has connected
  ///   Todoist at all. A block with no attachment is an ordinary block; the
  ///   timer has always run without one and still does.
  func takeNextAttachment() -> SessionAttachment?
}
