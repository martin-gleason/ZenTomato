import Foundation

/// One page of results, as Todoist's paginated endpoints wrap them.
///
/// Todoist never hands back a bare list. It hands back an object with the rows
/// in `results` and a marker in `next_cursor` — a piece of text meaning "ask
/// again with this to get the rest", or nothing at all when there is no rest.
///
/// **The end of a list is `next_cursor` being absent, and nothing else.** The
/// documentation says so in as many words: *"Do not depend on the number of
/// results being fewer than the limit value to indicate that your query reached
/// the end … use the absence of next instead."* A short page is not the end;
/// the loop that reads these pages must never assume it is.
struct TodoistPage<Element: Decodable & Sendable>: Decodable, Sendable {
  /// The rows in this page.
  let results: [Element]

  /// The marker to send back for the next page, or `nil` at the end.
  ///
  /// It is opaque: the docs say *"do not attempt to decode, parse, or modify
  /// cursors — pass them as-is"*, so this app treats it as a piece of text it
  /// is carrying between two requests and never looks inside it. It is also
  /// never saved to disk — cursors are short-lived by design.
  let nextCursor: String?

  private enum CodingKeys: String, CodingKey {
    case results
    case nextCursor = "next_cursor"
  }
}

// MARK: - The three things this app reads

/// One Todoist project, reduced to the three fields this app mirrors.
///
/// WHY EXACTLY THESE THREE, AND WHY ADDING A FOURTH IS A REAL RISK
/// Todoist's answer for projects is a *union* of two shapes — a personal
/// project and a workspace project — and only some fields appear in both. A
/// type that insisted on a field belonging to just one of them would fail to
/// read the answer at all on any account that has a workspace, and would do it
/// on that person's phone rather than in anybody's test. `id`, `name` and
/// `child_order` are present in both, and they are also exactly what the cache
/// mirrors. **Do not add a field here.**
struct TodoistProjectDTO: Decodable, Sendable, Equatable {
  /// Todoist's identifier — an opaque string, never a number.
  let id: String

  /// The project's name, as drawn in the picker.
  let name: String

  /// Todoist's own position for this project among its siblings. Copied so the
  /// picker can show projects in the order the person arranged them, rather
  /// than in an order this app invented.
  let childOrder: Int

  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case childOrder = "child_order"
  }
}

/// One section inside a project.
struct TodoistSectionDTO: Decodable, Sendable, Equatable {
  /// Todoist's identifier — an opaque string.
  let id: String

  /// The section's name.
  let name: String

  /// Which project it belongs to. A copied identifier, not a link: this app
  /// stores no relationships between its rows, for the same reason the
  /// distraction rows carry a copied block identifier.
  let projectID: String

  /// Todoist's own position for this section within its project.
  let sectionOrder: Int

  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case projectID = "project_id"
    case sectionOrder = "section_order"
  }
}

/// One open task.
///
/// Todoist calls the task's title `content`, and this type keeps that name so
/// that anybody comparing this file with Todoist's documentation is reading the
/// same word in both places.
struct TodoistTaskDTO: Decodable, Sendable, Equatable {
  /// Todoist's identifier — an opaque string. This is the value the close
  /// command is addressed to, and the value a plan item stores.
  let id: String

  /// The task's title. This is what a plan item and a finished block keep a
  /// snapshot of.
  let content: String

  /// Which project it belongs to.
  let projectID: String

  /// Which section it sits in, or `nil` when it is loose in the project.
  let sectionID: String?

  /// Todoist's own position for this task.
  let childOrder: Int

  private enum CodingKeys: String, CodingKey {
    case id
    case content
    case projectID = "project_id"
    case sectionID = "section_id"
    case childOrder = "child_order"
  }
}
