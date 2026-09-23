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

  static let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()

  /// The deltas file with fenced code blocks blanked out.
  ///
  /// **Blanking rather than deleting**, so line numbers still line up with the file a reader opens.
  /// D15 quotes the export's own section headings inside a fence — `## Days`, `## Distractions` —
  /// and a parser that cannot tell a heading from a sample of one reported them as deltas with no
  /// status. A fence check that cannot tell content from illustration is worse than none, because
  /// somebody eventually silences the noise it makes.
  static func deltaFileLines() throws -> [String] {
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
  static func definedDeltas() throws -> Set<String> {
    Set(try deltaFileLines().compactMap { $0.hasPrefix("## D") ? headingID($0) : nil })
  }

  /// `## D21b — …` becomes `D21b`.
  static func headingID(_ line: String) -> String? {
    let body = line.dropFirst(3)
    let id = body.prefix { $0.isNumber || $0.isLetter }
    return id.isEmpty ? nil : "D" + id.drop { $0 == "D" }
  }

  /// Every `D<n>` mentioned in a body of text, ignoring the deltas file itself.
  ///
  /// Deliberately conservative: it matches a `D` followed by digits at a word boundary, so `D14` is
  /// found and `3D` or `MMDDYY` are not.
  static func deltaIDs(in text: String) -> Set<String> {
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
  /// The two files whose `D<N>` tokens are not citations of *this* project's register.
  ///
  /// `00-deltas.md` defines the IDs rather than citing them.
  ///
  /// `docs/conventions.md` is the **vendored upstream baseline**, and `D24` is the delta saying this
  /// project never edits it. Upstream keeps its own register, so the file legitimately carries five
  /// decision IDs that mean nothing here — deliberately not named in this comment, because this file
  /// is itself walked and naming them would recreate the failure the exclusion fixes. Checking the
  /// file and pinning it are mutually exclusive, and the pin wins.
  ///
  /// The exclusion stays narrow: `conventions-local.md` is this project's own and stays checked.
  static let notACitationSurface = [
    "docs/plans/00-deltas.md",
    "docs/conventions.md"
  ]

  static func citingFiles() throws -> [URL] {
    let roots = ["ZenTomato", "ZenTomatoTests", "docs"]
    var files: [URL] = []
    for root in roots {
      let base = repositoryRoot.appending(path: root)
      guard let walk = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil)
      else { continue }
      for case let url as URL in walk where ["swift", "md"].contains(url.pathExtension) {
        if Self.notACitationSurface.contains(where: { url.path.hasSuffix($0) }) { continue }
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

  /// Whitespace collapsed to single spaces.
  ///
  /// Load-bearing: `00-deltas.md` wraps its quotations across lines, so a quoted spec line contains a
  /// newline exactly where `SPEC.md` has a space. Comparing raw text finds nothing and the check
  /// silently reports a clean backlog — the worst failure available to a test whose whole job is to
  /// count what is outstanding.
  static func squashed(_ text: String) -> String {
    text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
  }

  /// The quoted fragments of a `**Currently:**` block, long enough to be distinctive.
  ///
  /// Two quoting styles are in use — backticks for a spec line reproduced literally, and
  /// *"italics in quotes"* for one being referred to. Both are read, because a detector that
  /// understands only one style under-reports, and a backlog that looks smaller than it is defeats
  /// the point.
  ///
  /// **Twelve characters is the floor**, and it was reached by trying. At twenty-four, `D18` was
  /// missed: the whole of the spec text it replaces is *"OAuth sign-in."*, fourteen characters. A
  /// floor exists at all because a fragment like `F2` occurs everywhere and would match by accident;
  /// the number is the shortest one that still separates a quotation from a passing mention.
  static func fragments(of block: String) -> [String] {
    var found: [String] = []

    found += backtickedSpans(in: block)

    if let quoted = try? NSRegularExpression(pattern: "[\u{201C}\"]([^\u{201D}\"]{12,})[\u{201D}\"]") {
      let range = NSRange(block.startIndex..<block.endIndex, in: block)
      quoted.enumerateMatches(in: block, range: range) { match, _, _ in
        guard let match, let span = Range(match.range(at: 1), in: block) else { return }
        found.append(squashed(String(block[span])))
      }
    }

    // Trailing ellipses mark an abbreviated quotation; the part before one is still verbatim.
    return found
      .map { $0.replacingOccurrences(of: " …", with: "").replacingOccurrences(of: "…", with: "") }
      .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " ·")) }
      .filter { $0.count >= 12 }
  }

  /// `theIndexListsEveryDelta` — the table at the top of the file cannot rot.
  ///
  /// The index exists because the file is in the order decisions were *taken*, not in numeric order,
  /// and renumbering is impossible: these ids are cited by name across production code. An index that
  /// silently falls behind the file is worse than none, because it is the thing people trust to
  /// answer "what is the next free number" — and a wrong answer there is how D14's hole opened.
  @Test("theIndexListsEveryDelta")
  func theIndexListsEveryDelta() throws {
    let lines = try Self.deltaFileLines()
    let defined = try Self.definedDeltas()

    guard let start = lines.firstIndex(where: { $0.hasPrefix("## Index") }) else {
      Issue.record("00-deltas.md has no '## Index' section.")
      return
    }
    let end = lines[(start + 1)...].firstIndex { $0.hasPrefix("## D") } ?? lines.count
    let indexed = Self.deltaIDs(in: lines[start..<end].joined(separator: "\n"))

    let missing = defined.subtracting(indexed).sorted()
    #expect(
      missing.isEmpty,
      Comment(rawValue: "Deltas missing from the index: \(missing.joined(separator: ", "))"))

    let phantom = indexed.subtracting(defined).sorted()
    #expect(
      phantom.isEmpty,
      Comment(rawValue: "The index lists deltas that do not exist: \(phantom.joined(separator: ", "))"))
  }

  // MARK: The index states a number

  /// `theIndexStatesTheNumberOfDeltas` — the sentence under the index cannot state a count the file
  /// does not hold.
  ///
  /// It said *"36 deltas"* above 37 headings, and `O35` recorded the identical hole earlier at
  /// *"24 deltas"* above 32 rows. `theIndexListsEveryDelta` asserts membership both ways and never
  /// the number, so a stale count was invisible to it. `C31` corrected the number by hand; nothing
  /// stopped it drifting again until `D41`.
  ///
  /// The check is indifferent to everything except *a number, whitespace, the word "deltas"* — move
  /// the sentence, rewrap it, reword the rest, and it does not notice. **The two words must stay
  /// adjacent:** `43 ratified deltas` matches nothing and takes the absent-sentence branch, which
  /// fails loudly rather than passing, so the failure is safe — but the message has to say so, or a
  /// reader who inserted an adjective is sent hunting for a spelled-out number instead.
  ///
  /// **Absence fails, deliberately.** A check that silently passes when its subject disappears is
  /// the green-tick-on-a-tautology failure this repository has five recorded instances of.
  @Test("theIndexStatesTheNumberOfDeltas")
  func theIndexStatesTheNumberOfDeltas() throws {
    let lines = try Self.deltaFileLines()
    let defined = try Self.definedDeltas().count

    guard let start = lines.firstIndex(where: { $0.hasPrefix("## Index") }) else {
      Issue.record("00-deltas.md has no '## Index' section.")
      return
    }
    let end = lines[(start + 1)...].firstIndex { $0.hasPrefix("## D") } ?? lines.count
    let section = lines[start..<end].joined(separator: "\n")

    var stated: [Int] = []
    if let pattern = try? NSRegularExpression(pattern: "([0-9]+)\\s+deltas", options: .caseInsensitive) {
      let range = NSRange(section.startIndex..<section.endIndex, in: section)
      pattern.enumerateMatches(in: section, range: range) { match, _, _ in
        guard let match, let span = Range(match.range(at: 1), in: section) else { return }
        stated.append(Int(section[span]) ?? -1)
      }
    }

    guard stated.isEmpty == false else {
      Issue.record("""
        The index section of 00-deltas.md no longer states how many deltas there are, in a form \
        this check can read: the digits and the word 'deltas' must be adjacent, so '43 deltas' is \
        seen and '43 ratified deltas' or 'forty-three deltas' are not. Restore the adjacent form. \
        Failing on absence is deliberate: a check that passes when its subject disappears is worse \
        than no check — D41 clause 3 ratified this assertion for exactly that reason.
        """)
      return
    }

    let wrong = stated.filter { $0 != defined }
    #expect(
      wrong.isEmpty,
      Comment(rawValue: """
        The index sentence states \(wrong.map(String.init).joined(separator: ", ")) deltas, \
        but 00-deltas.md defines \(defined). Correct the sentence, not this test.
        """))
  }
}
