import Foundation
import Testing

/// The deltas file, checked against the tree that cites it.
///
/// **WHY THIS EXISTS.** `00-deltas.md` is the ratification surface: the only place a change to the
/// contract is recorded, and the thing every plan, review and doc comment defers to. Nothing checked
/// it. So `D14` — the merged stop sheet — was decided, built, cited by name in five production files,
/// and never written down. `ReflectionFieldList.swift` opens with *"Ratified decision D14 is that…"*
/// against a decision that existed nowhere.
///
/// That is not a filing error. A decision nobody wrote down cannot be reviewed, cannot be found by
/// the next reader, and cannot be checked against the code that claims to implement it. `D15`'s own
/// preamble says it: *"it was decided, described in conversation, and never recorded, which is how a
/// decision becomes a thing nobody can check."* D15 was caught by a person, once. This catches it on
/// every run.
///
/// **The tree is read through `#filePath`**, the same technique `StatsFenceTests` and
/// `LaunchBackgroundTests` already use, so no build setting and no bundled resource is involved.
@Suite("DeltaIntegrity")
struct DeltaIntegrityTests {
  // MARK: Every citation resolves

  /// `everyCitedDeltaIsDefined` — nothing may claim authority from a decision that was never
  /// recorded.
  ///
  /// This is the assertion that would have fired the day `D14`'s first citation was written, in the
  /// same commit that wrote it, instead of two features later.
  @Test("everyCitedDeltaIsDefined")
  func everyCitedDeltaIsDefined() throws {
    let defined = try Self.definedDeltas()
    var undefined: [String: [String]] = [:]

    for file in try Self.citingFiles() {
      let text = try String(contentsOf: file, encoding: .utf8)
      for id in Self.deltaIDs(in: text) where defined.contains(id) == false {
        undefined[id, default: []].append(file.lastPathComponent)
      }
    }

    #expect(
      undefined.isEmpty,
      Comment(rawValue: Self.describe(undefined)))
  }

  // MARK: Every delta says where it stands

  /// `everyDeltaCarriesAStatus` — proposed, ratified, or rejected, stated within a few lines of the
  /// heading.
  ///
  /// `D1`–`D5` and `D9`–`D11` were ratified under a single dated heading further up the file rather
  /// than individually, which is a second convention in one document and means a reader has to know
  /// the file's history to read a delta. Each now points at that heading explicitly.
  @Test("everyDeltaCarriesAStatus")
  func everyDeltaCarriesAStatus() throws {
    let lines = try Self.deltaFileLines()
    var unstamped: [String] = []

    for (index, line) in lines.enumerated() where line.hasPrefix("## D") {
      guard let id = Self.headingID(line) else { continue }
      let window = lines[index..<min(index + 6, lines.count)].joined(separator: "\n")
      let stamped = window.contains("Ratified")
        || window.contains("REJECTED")
        || window.contains("Proposed 2")
        || window.contains("RESOLVED")
      if stamped == false { unstamped.append(id) }
    }

    #expect(
      unstamped.isEmpty,
      Comment(rawValue: "Deltas with no status within 6 lines of the heading: \(unstamped.joined(separator: ", "))"))
  }

  // MARK: The sequence has no holes

  /// `theDeltaSequenceHasNoGaps` — a missing number is caught before anything cites it.
  ///
  /// `D14` was a hole in the sequence for a day before its first citation. Numbering here is *not*
  /// monotonic in the file — `D6b` sits after `D8`, `D15` after `D20` — because deltas are appended
  /// as they are taken and renumbering would break citations across production code. So the check is
  /// on the *set*, not the order.
  @Test("theDeltaSequenceHasNoGaps")
  func theDeltaSequenceHasNoGaps() throws {
    let numbers = try Self.definedDeltas()
      .compactMap { Int($0.dropFirst().prefix { $0.isNumber }) }
      .reduce(into: Set<Int>()) { $0.insert($1) }
    guard let highest = numbers.max() else {
      Issue.record("No deltas found at all — the file moved or the parser is wrong.")
      return
    }

    let missing = (1...highest).filter { numbers.contains($0) == false }
    #expect(
      missing.isEmpty,
      Comment(rawValue: "Gaps in the delta sequence: \(missing.map { "D\($0)" }.joined(separator: ", "))"))
  }

  // MARK: Private

  private static let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()

  /// The deltas file with fenced code blocks blanked out.
  ///
  /// **Blanking rather than deleting**, so line numbers still line up with the file a reader opens.
  /// D15 quotes the export's own section headings inside a fence — `## Days`, `## Distractions` —
  /// and a parser that cannot tell a heading from a sample of one reported them as deltas with no
  /// status. A fence check that cannot tell content from illustration is worse than none, because
  /// somebody eventually silences the noise it makes.
  private static func deltaFileLines() throws -> [String] {
    let raw = try String(contentsOf: repositoryRoot.appending(path: "docs/plans/00-deltas.md"), encoding: .utf8)
      .components(separatedBy: "\n")
    var inFence = false
    return raw.map { line in
      if line.hasPrefix("```") {
        inFence.toggle()
        return ""
      }
      return inFence ? "" : line
    }
  }

  /// Every `D<n>` that has a heading of its own.
  private static func definedDeltas() throws -> Set<String> {
    Set(try deltaFileLines().compactMap { $0.hasPrefix("## D") ? headingID($0) : nil })
  }

  /// `## D21b — …` becomes `D21b`.
  private static func headingID(_ line: String) -> String? {
    let body = line.dropFirst(3)
    let id = body.prefix { $0.isNumber || $0.isLetter }
    return id.isEmpty ? nil : "D" + id.drop { $0 == "D" }
  }

  /// Every `D<n>` mentioned in a body of text, ignoring the deltas file itself.
  ///
  /// Deliberately conservative: it matches a `D` followed by digits at a word boundary, so `D14` is
  /// found and `3D` or `MMDDYY` are not.
  private static func deltaIDs(in text: String) -> Set<String> {
    var found: Set<String> = []
    let pattern = try? NSRegularExpression(pattern: "\\bD([0-9]{1,3}[a-z]?)\\b")
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    pattern?.enumerateMatches(in: text, range: range) { match, _, _ in
      guard let match, let digits = Range(match.range(at: 1), in: text) else { return }
      found.insert("D" + text[digits])
    }
    return found
  }

  /// The files allowed to cite a delta: the app, its tests, and the documents.
  private static func citingFiles() throws -> [URL] {
    let roots = ["ZenTomato", "ZenTomatoTests", "docs"]
    var files: [URL] = []
    for root in roots {
      let base = repositoryRoot.appending(path: root)
      guard let walk = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil)
      else { continue }
      for case let url as URL in walk where ["swift", "md"].contains(url.pathExtension) {
        if url.path.hasSuffix("docs/plans/00-deltas.md") { continue }
        files.append(url)
      }
    }
    return files
  }

  private static func describe(_ undefined: [String: [String]]) -> String {
    undefined
      .sorted { $0.key < $1.key }
      .map {
        let names = $0.value.sorted().joined(separator: ", ")
        return "\($0.key) is cited in \($0.value.count) file(s) — \(names) — but has no heading in 00-deltas.md"
      }
      .joined(separator: "\n")
  }
}
