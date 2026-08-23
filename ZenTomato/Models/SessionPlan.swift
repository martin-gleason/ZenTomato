import Foundation
import SwiftData

/// The list of things you mean to work through this session, and where you are
/// in it.
///
/// WHAT A PLAN IS
/// Before a sprint, you pick a few things out of the picker — a project, a
/// couple of loose tasks — in the order you will do them. Each pomodoro then
/// takes the next one. The point is that choosing what to work on is a planning
/// act, and doing it eight times an afternoon at the start of each block is the
/// wrong moment for it: you are trying to begin, not decide.
///
/// **There is one plan.** Making a new one replaces the old one. A plan is not
/// history — what actually happened is already written down, block by block, on
/// the finished-block rows, and a plan that outlived its session would be a
/// second, competing account of the same day.
///
/// WHY THE CURSOR LIVES HERE AND NOT ON THE ITEMS
/// This is the load-bearing decision of the whole feature. "Which one am I on"
/// is a fact about the *list*, so it is stored on the list. Put it on the items
/// instead — a `finished` flag, a `skipped` flag — and each item stops being a
/// reference to something in Todoist and starts being a small local copy of it
/// with a state of its own. That is the local task model this version of the
/// app is not allowed to have, and it would arrive one reasonable-looking
/// afternoon at a time. One integer, on the plan, makes it impossible rather
/// than discouraged.
@Model
final class SessionPlan {
  /// When this plan was built. Used to tell "finished before I planned it" from
  /// "finished while working this plan", which is a question answered by a
  /// query and never by a column on an item.
  var createdAt: Date

  /// Which item the next focus block will take, counting from zero.
  ///
  /// It is allowed to run past the end of the list: that is what "the plan is
  /// worked through" looks like, and a block started then simply has nothing
  /// attached to it. Stepping over an item moves this number and does nothing
  /// else — the item is not removed, not marked, and not reordered.
  var currentIndex: Int

  /// Creates a plan. The items are inserted separately, in order.
  init(createdAt: Date, currentIndex: Int = 0) {
    self.createdAt = createdAt
    self.currentIndex = currentIndex
  }
}
