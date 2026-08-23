import Foundation

/// Every address this app is allowed to contact at Todoist, and nothing else.
///
/// WHAT THIS FILE IS, FOR A READER WHO DOES NOT WRITE SWIFT
/// It is a list of four addresses. Three of them read (projects, sections,
/// tasks) and one of them writes — completing a task. That is the whole of the
/// app's contact with Todoist, and this file is deliberately the only place in
/// the codebase where any of those addresses is written down.
///
/// WHY ONE FILE, AND WHY IT MATTERS MORE THAN IT LOOKS
/// The project's hardest rule is that the only write to Todoist is *complete a
/// task* — never create, never edit, never comment. A rule like that is worth
/// nothing if it is enforced by everybody remembering it, so it is enforced by
/// a check instead: `scripts/check-todoist-writes.sh` reads every Todoist
/// address it can find in the source and fails the build if one of them is not
/// in `scripts/todoist-allowed-endpoints.txt`. Adding an address therefore
/// means editing a committed file, which shows up in the pull request. That
/// visibility *is* the control.
///
/// Three properties below exist to keep that control working:
///
///   * every address is a plain piece of text written out in full, because a
///     web address assembled at run time out of pieces is invisible to a check
///     that reads source code;
///   * `Endpoint`'s initialiser cannot be called from outside this file, so no
///     fifth address can be brought into existence anywhere else — not in a
///     screen, not at run time, not in a test;
///   * an address carries its own method (read or write), so no caller ever
///     decides that. Todoist's create-a-task address — the one thing the app's
///     no-capture rule exists to forbid — is not merely "not called": it cannot
///     be named, because there is no constant for it and no way to make one.
///
/// `enum` with no cases is Swift's way of writing "a namespace, not a thing":
/// there is never an instance of `TodoistAPI`.
enum TodoistAPI {
  // MARK: The pinned facts about the API itself

  // TODOIST API v1 — verified against https://developer.todoist.com/api/v1/ on 2026-08-23.
  //
  //   Base            the one address literal in this tree, `baseURL` below.
  //   Auth            Authorization: Bearer <personal API token>   (D18)
  //   Ids             opaque STRINGS. v9/v2 numeric ids are not accepted (Migrating from v9).
  //   Pagination      {"results": [...], "next_cursor": String?}; cursor + limit query params;
  //                   limit default 50, MAXIMUM 200; stop only when next_cursor is null.
  //   Rate limits     Todoist publishes numbers for the SYNC endpoints only: 1000 partial-sync and
  //                   100 full-sync requests per user per 15 minutes. NO separate published ceiling
  //                   exists for the four endpoints below. We assume the strictest published number
  //                   applies and stay far under it by design: a refresh on foreground and on an
  //                   explicit pull, never per keystroke. Search filters the local cache.
  //   Also published  15s standard request timeout; 1 MiB POST body; 65 KiB headers.
  //   429 / 401       honour the Retry-After header; error_extra.retry_after carries the same number.
  //   v9 / v2         superseded by v1 (D5). Their docs remain online for reference only; no v9 or
  //                   v2 URL may appear anywhere in this tree.

  /// The API's address, and the only one in the whole codebase.
  ///
  /// WHY THE `??` IS NOT A MISTAKE
  /// Swift refuses to promise that a piece of text is a valid web address, so
  /// reading one always produces "an address, or nothing". This project forbids
  /// the shorthand that says "trust me, it worked" — it crashes the app on the
  /// day it is wrong — so the constant below is paired with a fallback that can
  /// never actually be reached, because the text beside it is a constant and is
  /// valid. `todoistBaseURLIsTheLiveV1API` asserts that the fallback was not
  /// taken, which is what stops this from being a promise.
  static let baseURL = URL(string: "https://api.todoist.com/api/v1") ?? URL(filePath: "/")

  /// How many rows to ask for in one page.
  ///
  /// 200 is the documented maximum. Asking for the maximum means fewer round
  /// trips for a large account — a 5,000-task account is 25 pages rather than
  /// 100 — which is the cheapest thing we can do about a rate ceiling Todoist
  /// does not publish for these endpoints.
  static let pageSize = 200

  // MARK: What a request may be

  /// The two HTTP methods that exist in this app.
  ///
  /// There is no `put`, no `patch`, no `delete`, and there is exactly one value
  /// here whose text is `POST`. Searching the source for that word finds this
  /// line and nothing else.
  enum Method: String, Sendable, Equatable {
    case get = "GET"
    case post = "POST"
  }

  /// One address, together with the method used against it.
  ///
  /// The method travels with the address rather than being chosen by whoever
  /// makes the call, so there is no call site anywhere that could send a create
  /// request to a read address.
  struct Endpoint: Sendable, Equatable {
    /// Read or write. Only one `Endpoint` in this file is a write.
    let method: Method

    /// The address, beginning with a slash and written out in full. Where an
    /// identifier is substituted in, it is substituted into the middle of this
    /// text so that the checking script still sees a complete address.
    let path: String

    /// Deliberately `fileprivate`: only this file may bring an `Endpoint` into
    /// existence.
    ///
    /// The build contract asks for a `private` initialiser. `fileprivate` is
    /// the spelling that expresses it here, because Swift's `private` would put
    /// the initialiser out of reach of the four constants below — they sit in
    /// the enclosing namespace, not inside `Endpoint` itself. The guarantee is
    /// the same one either way, and it is the guarantee that matters: **no code
    /// outside this file can construct a fifth endpoint**, so the list below is
    /// exhaustive by construction rather than by convention.
    fileprivate init(method: Method, path: String) {
      self.method = method
      self.path = path
    }
  }

  // MARK: The four addresses

  /// Every project, in Todoist's own order. Active projects only.
  static let projects = Endpoint(method: .get, path: "/projects")

  /// Every section of every project. Active sections only.
  static let sections = Endpoint(method: .get, path: "/sections")

  /// Every open task. Completed and deleted tasks are simply not returned,
  /// which is why the app can never tell those two apart — see the plan screen.
  static let tasks = Endpoint(method: .get, path: "/tasks")

  /// **The only write this app can make.** Closes one task.
  ///
  /// Todoist's own words for what this does: *"Closes a task. … Regular tasks
  /// are marked complete and moved to history, along with their subtasks. Tasks
  /// with recurring due dates will be scheduled to their next occurrence."*
  ///
  /// - Parameter id: the task's Todoist identifier — an opaque string such as
  ///   `6XGgmFVcrG5RRjVr`. Never a number: v1 changed the old numeric
  ///   identifiers and will not accept them.
  /// - Returns: the address of that one task's close command.
  static func closeTask(id: String) -> Endpoint {
    Endpoint(method: .post, path: "/tasks/\(id)/close")
  }

  /// Every address this app may ever contact, as one list.
  ///
  /// It exists to be read by two tests: one asserts that exactly one of these
  /// four is a write and that the write is the close command, and the other
  /// compares this list against the committed allowlist so the two cannot drift
  /// apart. Nothing in the shipping app reads it, and it is a reader rather
  /// than a lever — it cannot cause a request.
  static var allEndpoints: [Endpoint] {
    [projects, sections, tasks, closeTask(id: "{id}")]
  }
}
