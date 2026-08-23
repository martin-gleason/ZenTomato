import Foundation

/// What each row of the session plan says about itself, worked out at the
/// moment it is drawn.
///
/// **NOTHING HERE IS STORED, AND THAT IS THE WHOLE POINT.** D17 allows a planned
/// item two facts — a Todoist id and a title snapshot — and this type is what
/// makes that liveable. "Is it finished?" and "is it still there?" are answered
/// by two queries every time the screen appears, not by a column somebody added
/// one reasonable afternoon. A per-item `isDone` flag is the precise failure
/// D17 names, and the reason it is not needed is written down here.
///
/// THE APP CANNOT TELL A COMPLETED TASK FROM A DELETED ONE, AND MUST NOT PRETEND
/// Todoist's three read endpoints return **active** objects only, so a task that
/// was completed and a task that was deleted both simply stop appearing. The
/// endpoint that would tell them apart is not on the allowlist and is not going
/// on it. So there are exactly two states an absent item can be in, split by
/// what this app actually knows:
///
///   * **Completed from here** — this app recorded closing it, during this
///     session. It is the one case where "done" is a fact rather than a guess.
///   * **Gone** — it is not in a mirror that has been filled at least once, and
///     nothing here recorded closing it. That is all that can honestly be said.
///
/// **Neither is drawn with a strikethrough.** Strikethrough means "done", and
/// for the second case the app does not know that. Drawing a completion state it
/// cannot verify would be a lie in the one dataset this app exists to produce.
///
/// **Nothing here is amber or red.** The world moving on is not an error. D17:
/// *the plan is a record of intent, and intent is not invalidated by the world
/// moving.*
struct SessionPlanScreenModel {
  // MARK: Nested types

  /// What is known about one planned item right now.
  enum ItemState: Equatable, Sendable {
    /// Still in Todoist, or not knowably absent.
    case planned
    /// This app closed it in Todoist, during this session.
    case completedHere(at: Date)
    /// Absent from a mirror that has been filled, with nothing recorded here.
    case gone
  }

  /// One row of the plan screen.
  struct Row: Identifiable, Equatable {
    let item: SessionPlanStore.Item
    let state: ItemState

    /// Whether this is the item a focus block starting now would take.
    let isCurrent: Bool

    /// Whether the cursor has already moved past it.
    let isWorked: Bool

    /// Positions are unique within a plan.
    var id: Int { item.position }

    /// The quiet line under the title, or nothing at all.
    ///
    /// The time is formatted by the reader's own clock setting, never a
    /// hard-coded `HH:mm`.
    var note: String? {
      switch state {
      case .planned:
        nil
      case .completedHere(let instant):
        "Completed at \(instant.formatted(date: .omitted, time: .shortened))"
      case .gone:
        "Not in Todoist any more"
      }
    }
  }

  // MARK: Building the rows

  /// Turns a plan and what is known about the world into rows.
  ///
  /// A pure function of five finished values, which is what lets every state of
  /// this screen be tested with no database, no screen and no account.
  ///
  /// - Parameters:
  ///   - items: the plan, in order.
  ///   - currentIndex: where the cursor is.
  ///   - completions: what this app has recorded closing, as `task id → when`.
  ///   - planCreatedAt: when this plan was made. A completion older than the
  ///     plan belongs to an earlier session and says nothing about this one.
  ///   - isStillInTodoist: whether the mirror still holds an item's Todoist
  ///     object. **`.unknown` means "not knowable"** — a mirror that has never
  ///     been filled, which is a first run or a train. Nothing is marked gone
  ///     then, because absent from an empty mirror is not evidence, and striking
  ///     out somebody's whole plan on a train would be the worst bug this screen
  ///     could ship.
  static func rows(
    items: [SessionPlanStore.Item],
    currentIndex: Int,
    completions: [String: Date],
    planCreatedAt: Date?,
    isStillInTodoist: (SessionPlanStore.Item) -> SessionPlanStore.Presence) -> [Row] {
    items.map { item in
      Row(
        item: item,
        state: state(
          of: item,
          completions: completions,
          planCreatedAt: planCreatedAt,
          isStillInTodoist: isStillInTodoist),
        isCurrent: item.position == currentIndex,
        isWorked: item.position < currentIndex)
    }
  }

  // MARK: Private

  private static func state(
    of item: SessionPlanStore.Item,
    completions: [String: Date],
    planCreatedAt: Date?,
    isStillInTodoist: (SessionPlanStore.Item) -> SessionPlanStore.Presence) -> ItemState {
    // Only a task can be closed, so only a task can carry a completion. A
    // project id could never appear in this table, but the check is written out
    // rather than assumed.
    if item.kind == .task,
       let closedAt = completions[item.todoistID],
       planCreatedAt.map({ closedAt > $0 }) ?? true {
      return .completedHere(at: closedAt)
    }

    return isStillInTodoist(item) == .absent ? .gone : .planned
  }
}
