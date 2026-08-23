import Foundation
import Testing

@testable import ZenTomato

/// Tests for the rule the whole project cares most about: **the only write to
/// Todoist is completing a task.**
///
/// WHY THESE TESTS EXIST WHEN THERE IS ALREADY A SCRIPT
/// `scripts/check-todoist-writes.sh` runs before every commit and in continuous
/// integration. It finds every Todoist address in the source and fails if one is
/// not on the committed allowlist — but it compares *addresses*, not what is
/// done at them, and its own header says so plainly. Creating a task and reading
/// tasks are the same address; only the method differs. So the script cannot, on
/// its own, tell the one thing this project most needs told apart.
///
/// These two tests are that missing half, and they are stronger than a search
/// through source text could be, because they read the actual table the app
/// sends from:
///
///   * `theOnlyPostEndpointIsClose` binds method to address. Four addresses,
///     exactly one of them a write, and that one is the close command.
///   * `endpointTableMirrorsTheAllowlist` reads the committed allowlist off disk
///     and checks it against the table in both directions, so neither file can
///     grow an address the other does not have.
///
/// Together they mean a fifth address cannot appear in this app without somebody
/// deliberately editing a committed list, in a diff the owner reads.
@Suite("TodoistEndpoints")
struct TodoistEndpointTests {
  // MARK: The method-to-address binding

  /// Four addresses. One write. The write is the close command.
  @Test("theOnlyPostEndpointIsClose")
  func theOnlyPostEndpointIsClose() {
    let all = TodoistAPI.allEndpoints
    #expect(all.count == 4)

    let writes = all.filter { $0.method == .post }
    #expect(writes.count == 1)

    let close = TodoistAPI.closeTask(id: "{id}")
    #expect(writes.first == close)

    // Written as "the tasks address, plus an identifier, plus the close
    // command" rather than as a literal, because a Todoist address spelled out
    // in a test is itself a thing the commit-time check has to look at.
    #expect(close.path.hasPrefix(TodoistAPI.tasks.path + "/"))
    #expect(close.path.hasSuffix("/close"))

    // Everything else reads, including the three the picker uses.
    #expect(TodoistAPI.projects.method == .get)
    #expect(TodoistAPI.sections.method == .get)
    #expect(TodoistAPI.tasks.method == .get)
  }

  // MARK: The table against the committed allowlist

  /// The four constants and the four allowlist lines are the same four things,
  /// in both directions.
  ///
  /// The file is read off disk rather than copied into this test. A copy would
  /// agree with itself forever while the real allowlist drifted, which is the
  /// one failure a test like this exists to prevent.
  @Test("endpointTableMirrorsTheAllowlist")
  func endpointTableMirrorsTheAllowlist() throws {
    let text = try String(contentsOf: Self.allowlistURL, encoding: .utf8)
    let allowlisted = Set(Self.entries(in: text))
    #expect(allowlisted.count == 4)

    let table = Set(TodoistAPI.allEndpoints.map { "\($0.method.rawValue) \($0.path)" })

    #expect(table == allowlisted)
  }

  // MARK: The address itself

  /// The app talks to version 1 of Todoist's API over HTTPS.
  ///
  /// The version matters: Todoist removed the two older APIs outright in
  /// February 2026, and their identifiers are not accepted by this one. It also
  /// proves the base address was genuinely understood — the constant is written
  /// with a fallback, because Swift will not promise that a piece of text is a
  /// valid address, and the fallback is not an HTTPS address at all.
  @Test("todoistBaseURLIsTheLiveV1API")
  func todoistBaseURLIsTheLiveV1API() {
    #expect(TodoistAPI.baseURL.scheme == "https")
    #expect(TodoistAPI.baseURL.host()?.isEmpty == false)
    #expect(TodoistAPI.baseURL.path().hasSuffix("/v1"))
    // The documented maximum page size. Asking for more is refused outright.
    #expect(TodoistAPI.pageSize == 200)
  }

  // MARK: Reading the allowlist

  /// The committed allowlist, found relative to this source file.
  ///
  /// `#filePath` is the path of this file as it was compiled, so the repository
  /// is two directories up from it. That is how the test reaches a file that is
  /// deliberately not part of the app's bundle: the allowlist belongs to the
  /// commit-time checks, and shipping a copy of it inside the app would be a
  /// second copy to keep in step.
  private static var allowlistURL: URL {
    URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appending(path: "scripts")
      .appending(path: "todoist-allowed-endpoints.txt")
  }

  /// Turns the allowlist file into `"METHOD /path"` entries, ignoring comments
  /// and blank lines and collapsing the runs of spaces it is aligned with.
  private static func entries(in text: String) -> [String] {
    text.split(separator: "\n").compactMap { rawLine in
      let line = rawLine.prefix { $0 != "#" }.trimmingCharacters(in: .whitespaces)
      guard !line.isEmpty else { return nil }
      let words = line.split(whereSeparator: \.isWhitespace)
      guard words.count == 2 else { return nil }
      return "\(words[0]) \(words[1])"
    }
  }
}
