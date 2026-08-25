import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// The exported page, defended byte for byte.
///
/// WHY A GOLDEN FILE IS THE RIGHT TEST HERE, AND WHY IT IS THE CENTREPIECE
/// `SPEC.md`'s acceptance criterion for this whole feature is a human judgement:
/// *"the export of one real study day is readable in the Rhodia without
/// translation."* There is no assertion that can check readability. What a
/// machine *can* do is hold a page still: a person reads
/// `ZenTomatoTests/Goldens/fortnight.md` once, agrees that it needs no decoding,
/// and from then on any change to any of a dozen formatting decisions shows up
/// as a diff in a pull request the owner reads.
///
/// **Nobody may regenerate a golden to make a test pass.** A golden changes only
/// in a commit whose message says which format decision changed and why. That is
/// the whole arrangement; a regenerated golden is a test that asserts the code
/// equals itself.
///
/// WHY THE FILE IS READ FROM THE SOURCE TREE
/// `#filePath` is this file's own path as it was compiled, so the repository is
/// four directories up from it. That is how `LaunchBackgroundTests` already
/// reads the launch colour, and it is the right technique here for two reasons:
/// the golden is a *reviewable artifact* rather than a resource the app ships,
/// and `project.yml` needs no change to make it available — which removes the
/// silent "the resource was not copied into the bundle" failure entirely.
///
/// A missing or empty golden must fail loudly rather than pass vacuously, which
/// is what the `#require` and the emptiness check below are for.
@Suite("StatsMarkdownGolden")
struct StatsMarkdownGoldenTests {
  // MARK: The two documents

  /// `goldenExport` — the fortnight fixture produces the committed page exactly.
  @Test("goldenExport")
  func goldenExport() throws {
    let expected = try Self.golden(named: "fortnight.md")
    let produced = StatsMarkdown.document(for: StatsPeriodFixture.fortnight)

    #expect(produced == expected, Comment(rawValue: Self.difference(produced, expected)))
  }

  /// `emptyRangeIsReadable` — a range with nothing in it is one clear sentence,
  /// not a skeleton of six empty headings.
  ///
  /// `F6.md`: *"Empty range ⇒ a short 'no pomodoros in this range' document
  /// rather than a skeleton of empty tables."*
  @Test("emptyRangeIsReadable")
  func emptyRangeIsReadable() throws {
    let expected = try Self.golden(named: "empty.md")
    let produced = StatsMarkdown.document(for: StatsPeriodFixture.emptyFortnight)

    #expect(produced == expected, Comment(rawValue: Self.difference(produced, expected)))
    // Stated separately from the byte comparison, because the byte comparison
    // would still pass if somebody replaced the sentence *and* the golden.
    #expect(produced.contains("No pomodoros in this range."))
    #expect(produced.contains("##") == false, "An empty range must have no section headings at all.")
    #expect(produced.split(separator: "\n", omittingEmptySubsequences: false).count <= 4)
  }

  // MARK: What may never appear on the page

  /// `noIdentifiersInOutput` — no `UUID`, no Todoist id, nowhere.
  ///
  /// The structural half of this guarantee is that none of the value types the
  /// document is built from can even hold an identifier: `StatsQuery` turns rows
  /// into counts and title snapshots and drops everything else. This test is the
  /// executed half, so that adding such a field later fails here rather than
  /// appearing on a page somebody prints.
  @Test("noIdentifiersInOutput")
  @MainActor
  func noIdentifiersInOutput() throws {
    // BUILT FROM ROWS THAT ACTUALLY CARRY IDENTIFIERS, and that is the whole point of A11's
    // sibling finding. This test used to run against `StatsPeriodFixture`, whose own
    // documentation says "no identifier of any kind appears anywhere in it" — so four of its
    // five assertions were tautologies. It searched a document that could not have contained
    // what it was searching for, and would have kept passing if `StatsTaskRow` gained a
    // `taskID` tomorrow and the page printed it.
    //
    // `StatsStoreFixture` writes real ones: `td-task-habit-0001`, `td-project-thesis`, and a
    // UUID per session. Going through the store and the query means the strings below are
    // genuinely present in the data and genuinely absent from the page.
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext
    try StatsStoreFixture.writeFortnight(into: context)
    let query = StatsQuery(context: context, calendar: StatsStoreFixture.calendar)
    let document = StatsMarkdown.document(for: query.period(StatsStoreFixture.fortnightRange))

    // The page is not empty — otherwise this passes by having nothing to print.
    #expect(document.contains("pomodoro"))

    let uuids = try NSRegularExpression(
      pattern: "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}")
    let range = NSRange(document.startIndex..<document.endIndex, in: document)
    #expect(uuids.numberOfMatches(in: document, range: range) == 0, "A session UUID reached the page.")

    // Todoist's own identifiers are opaque alphanumeric strings. Every shape below is in the
    // store this document was built from.
    for shape in ["td-", "td-task-", "td-project-", "project_id", "task_id", "sessionID"] {
      #expect(document.contains(shape) == false, "The page contains \(shape).")
    }
  }

  /// A page read a fortnight later cannot use a word that means something
  /// different when it is read, and cannot use a dialect that needs decoding.
  @Test("nothingOnThePageNeedsTranslating")
  func nothingOnThePageNeedsTranslating() {
    let document = StatsMarkdown.document(for: StatsPeriodFixture.fortnight)

    for forbidden in ["yesterday", "today", "tomorrow", "ago", "AM", "PM", "GMT", "UTC", "+00:00", "T00:"] {
      #expect(document.contains(forbidden) == false, "The page contains \(forbidden).")
    }
    // Seconds would be the app talking to itself. `14:32:07` never appears.
    let times = try? NSRegularExpression(pattern: "[0-9]{2}:[0-9]{2}:[0-9]{2}")
    let range = NSRange(document.startIndex..<document.endIndex, in: document)
    #expect(times?.numberOfMatches(in: document, range: range) == 0)
  }

  /// The invisible half of the format, stated so a golden failure is never a
  /// mystery about whitespace.
  @Test("theWhitespaceIsExactlyTheContract")
  func theWhitespaceIsExactlyTheContract() {
    let document = StatsMarkdown.document(for: StatsPeriodFixture.fortnight)

    #expect(document.contains("\r") == false, "Line endings must be \\n.")
    #expect(document.hasSuffix("\n"))
    #expect(document.hasSuffix("\n\n") == false, "Exactly one newline at the end.")
    #expect(document.contains("\n\n\n") == false, "Never two blank lines between blocks.")
    for line in document.split(separator: "\n", omittingEmptySubsequences: false) {
      #expect(line.hasSuffix(" ") == false, "Trailing space on: \(line)")
    }
  }

  // MARK: Private

  /// The committed page, read from the source tree.
  ///
  /// Fails loudly when the file is missing or empty. A deleted golden that let
  /// the test pass would be worse than no test at all, because the suite would
  /// still be green.
  private static func golden(named name: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()          // ZenTomatoTests
      .appending(path: "Goldens")
      .appending(path: name)

    let contents = try #require(
      try? String(contentsOf: url, encoding: .utf8),
      "The golden file \(name) is missing. It is committed on purpose; restore it rather than regenerating it.")
    #expect(contents.isEmpty == false, "The golden file \(name) is empty.")
    return contents
  }

  /// The first line that differs, with three lines of context either side.
  ///
  /// A two-thousand-character `#expect(a == b)` failure is unreadable in a CI
  /// log, and an unreadable failure is one somebody force-pushes past. This says
  /// which line, what was expected, and what arrived.
  private static func difference(_ produced: String, _ expected: String) -> String {
    let left = produced.components(separatedBy: "\n")
    let right = expected.components(separatedBy: "\n")

    guard let index = (0..<max(left.count, right.count)).first(where: { line in
      left[safeLine: line] != right[safeLine: line]
    }) else {
      return "The two documents are identical."
    }

    let context = (max(0, index - 3)..<index).map { "    \(right[safeLine: $0] ?? "")" }
    return """
      The exported page differs from the golden at line \(index + 1).

      \(context.joined(separator: "\n"))
        expected: \(right[safeLine: index] ?? "«end of file»")
        produced: \(left[safeLine: index] ?? "«end of file»")

      If this change is intended, it is a format decision: update
      ZenTomatoTests/Goldens/ in a commit whose message says which decision
      changed and why. Never regenerate a golden to make a test pass.
      """
  }
}

// MARK: - Array + line lookup

extension Array where Element == String {
  fileprivate subscript(safeLine index: Int) -> String? {
    indices.contains(index) ? self[index] : nil
  }
}
