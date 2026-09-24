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
/// mirrors.
///
/// **`color` IS THE FOURTH FIELD, AND IT IS OPTIONAL FOR EXACTLY THE REASON
/// ABOVE** (`F13`). The heading of this comment used to end *"Do not add a field
/// here"*, and that instruction was right about the risk and is kept as the test a
/// fifth field has to pass: a field is only safe here if it is present in both
/// shapes **or** declared optional. `color` is declared optional, so a workspace
/// project that carries no `color` key decodes exactly as it did before — and so
/// does its whole page, which is the failure that matters. `F13-M1` is that
/// tolerance removed, and the test it must break asserts on the page and not on
/// the row.
///
/// Adding a *required* field here is still the real risk, and it is still
/// forbidden.
struct TodoistProjectDTO: Decodable, Sendable, Equatable {
  /// Todoist's identifier — an opaque string, never a number.
  let id: String

  /// The project's name, as drawn in the picker.
  let name: String

  /// Todoist's own position for this project among its siblings. Copied so the
  /// picker can show projects in the order the person arranged them, rather
  /// than in an order this app invented.
  let childOrder: Int

  /// The project's colour, as the name Todoist sends — `berry_red`, `olive_green`.
  ///
  /// **A name, never a number and never a hex.** Todoist's API sends the key from
  /// its own colour table; what that key looks like is `TodoistTint`'s business
  /// and this type does not know. Kept as the raw string rather than decoded into
  /// a tint here, so that a colour Todoist adds tomorrow survives the decoder
  /// untouched and is interpreted — or not — one layer up.
  ///
  /// `nil` is ordinary: a workspace project has no `color` key at all. Optional,
  /// so Swift asks for it with *decode if present* and neither a missing key nor
  /// an explicit `null` can fail the task, the row, or the page.
  ///
  /// **WHAT OPTIONALITY DOES NOT BUY, because the first version of this comment
  /// implied it did.** It tolerates an ABSENT value, not a wrong TYPE. A `color`
  /// arriving as a number still raises `typeMismatch` and still refuses the whole
  /// page. `Due` above has a hand-written lenient `init(from:)` for precisely that
  /// reason and this field does not; `O49` is the decision, because new tolerance
  /// on a shipped decode path is not a comment fix.
  let color: String?

  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case childOrder = "child_order"
    case color
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
///
/// **The `due` object is read for one boolean and nothing else** (D21). See
/// `TodoistTaskDTO.Due`, and `CachedTask.isRecurring` for why that is a visible
/// argument with the build contract's not-mirrored table rather than a small
/// reasonable commit.
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

  /// Todoist's due information, reduced to the one fact D21 needs.
  ///
  /// **`nil` is the ordinary case, not a failure.** A task with no due date has
  /// no `due` object at all, and most tasks in most accounts do not have one.
  /// Because this property is optional, Swift's generated decoder asks for it
  /// with *decode if present* — so both a missing key and an explicit `null`
  /// produce `nil` rather than making the whole task fail to read. That
  /// tolerance is not decoration: a required field here would make **every task
  /// on the account fail to decode** the day Todoist ships a shape this app did
  /// not anticipate, which presents as an empty picker on a real phone and in
  /// nobody's test.
  let due: Due?

  /// Todoist's priority for this task, **as the number on the wire and nothing
  /// else**.
  ///
  /// **Deliberately uninterpreted here.** Which end of the range is urgent, and
  /// how the number relates to the `P1`–`P4` labels Todoist's own app draws, is
  /// not settled by reading and is not settled in this file. `F13-T5` step 1
  /// settles it against the owner's real account, and `F13-T4` is what maps it
  /// for the screen. Storing the wire value verbatim is what lets that mapping be
  /// decided later without re-fetching anything, and it is why no line of `F13-T2`
  /// contains a prediction.
  ///
  /// `nil` is the ordinary case on most accounts — **except that it is not: all 50
  /// tasks on the account `CLAIM 4` was run against carried this key.** There is no
  /// "no priority" on the wire; the unflagged state is the value `1`. The optional
  /// is the shape of a mirrored column, not Todoist declining to answer.
  ///
  /// Optional for the same reason `due` is: a required field would fail the whole
  /// page the day Todoist ships a shape this app did not anticipate. `F13-M2` is
  /// that tolerance removed. **It tolerates an absent value and not a wrong type** —
  /// a `priority` arriving as a string still refuses the page. `O49`.
  let priority: Int?

  /// The one thing this app reads out of a due date.
  ///
  /// Verified against Doist's own API v1 client library before a line of this
  /// was written, because D21 says in as many words that *"a boolean read from
  /// the wrong key is silently always false"*. The vendor's own decoder for the
  /// endpoint this app calls declares `is_recurring: bool = False` **inside**
  /// the `Due` object — not on the task — and the field is optional there too.
  ///
  /// Nothing else is taken from it: no date, no schedule string, no time zone,
  /// no language. D21: *"It is not a recurrence rule, a schedule, a due date,
  /// or anything that could reconstruct one."*
  struct Due: Decodable, Sendable, Equatable {
    /// Whether the task repeats.
    let isRecurring: Bool

    private enum CodingKeys: String, CodingKey {
      case isRecurring = "is_recurring"
    }

    /// Reads the flag, and treats its absence as *not recurring*.
    ///
    /// Written by hand rather than generated, for one reason: the generated
    /// version would make `is_recurring` **required**, and a due object that
    /// arrived without it would fail to decode — taking its whole task with it,
    /// and with it the whole page of tasks. Missing means no, which is both the
    /// safe answer and the one Doist's own client uses as its default.
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      isRecurring = try container.decodeIfPresent(Bool.self, forKey: .isRecurring) ?? false
    }
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case content
    case projectID = "project_id"
    case sectionID = "section_id"
    case childOrder = "child_order"
    case due
    case priority
  }
}
