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

  // MARK: The contract's amendment backlog

  /// `everyRatifiedSpecAmendmentIsApplied` — H2. The gap between what was ratified and what the
  /// contract actually says, made countable.
  ///
  /// **THE AGENT MAY NOT FIX THIS, AND THAT IS WHY THE TEST EXISTS.** `CLAUDE.md` and
  /// `conventions.md` both say the agent never edits `SPEC.md`; spec authority is the owner's.
  /// So this test cannot close the gap. It can only refuse to let the gap stay invisible.
  ///
  /// **What went wrong without it.** Twenty-two deltas were ratified between 2026-08-21 and
  /// 2026-08-24 and not one was ever applied to `SPEC.md`. The contract still said minimum iOS 18.0
  /// after D1 raised it to 26, still said OAuth sign-in after D18 replaced it with a pasted token,
  /// still listed watchOS as out of scope after D2 moved the remote half in. `CLAUDE.md`'s working
  /// loop opens with *"Re-read `SPEC.md`"* — so an agent following its instructions exactly gets
  /// answers that are two months stale, and then re-derives from 1,000 lines of deltas or, worse,
  /// believes the contract. That is what happened at the F7 gate.
  ///
  /// **How a delta is judged to need spec text.** It carries a `**Currently:**` block — the
  /// convention this file uses for quoting the spec line a delta replaces. A delta that records a
  /// verification result or a build decision has no such block and is not counted.
  ///
  /// **How to make it pass:** apply the amendment to `SPEC.md` and add its id to the
  /// `## Amendments applied` list there. Not by editing this test.
  @Test("everyRatifiedSpecAmendmentIsApplied")
  func everyRatifiedSpecAmendmentIsApplied() throws {
    let lines = try Self.deltaFileLines()
    var owed: [(id: String, summary: String)] = []

    for (index, line) in lines.enumerated() where line.hasPrefix("## D") {
      guard let id = Self.headingID(line) else { continue }
      let end = lines[(index + 1)...].firstIndex { $0.hasPrefix("## D") } ?? lines.count
      let body = lines[index..<end].joined(separator: "\n")
      guard body.contains("Ratified") else { continue }
      guard body.contains("REJECTED") == false else { continue }
      // A delta owes an amendment when the text it says the spec CURRENTLY says is still there.
      guard try Self.quotesLiveSpecText(in: body) else { continue }
      let summary = line.dropFirst(3).prefix(72)
      owed.append((id, String(summary)))
    }

    let applied = try Self.appliedAmendments()
    let outstanding = owed.filter { applied.contains($0.id) == false }
    let baseline = try Self.amendmentBaseline()

    // THE RATCHET, AND WHY IT IS NOT SIMPLY `outstanding.isEmpty`.
    //
    // Nine amendments are outstanding today. Asserting zero would fail every run until the owner
    // works through all nine — and under branch protection a permanently red test blocks every
    // merge, including the features still to come. A gate that cannot be met is a gate somebody
    // deletes, and then the check is gone rather than satisfied.
    //
    // So the assertion is on the DIRECTION instead: the backlog may shrink or hold, never grow.
    // Ratifying a new amendment without applying it fails immediately, which is the behaviour that
    // let this reach nine in the first place. The baseline lives in a committed file, so lowering it
    // is a visible edit in a diff rather than a number somebody nudged.
    #expect(
      outstanding.count <= baseline,
      Comment(rawValue: """
        The unapplied-amendment backlog grew: \(outstanding.count) outstanding against a baseline of \(baseline).
        A delta was ratified without its text reaching docs/specs/SPEC.md. Apply it, add its id to the
        '## Amendments applied' list there, and lower the number in docs/specs/AMENDMENT-BASELINE.txt.
        """))

    // Named on every run whether or not the ratchet trips, because the point is that the gap is
    // countable and visible rather than merely bounded.
    if outstanding.isEmpty == false {
      print("""

        ── SPEC.md amendment backlog: \(outstanding.count) outstanding (baseline \(baseline)) ──
        The contract states things that are no longer true, so "re-read SPEC.md" returns stale
        answers. Only the owner may close these; the agent never edits the contract.

        \(outstanding.map { "  \($0.id) — \($0.summary)" }.joined(separator: "\n"))

        """)
    }
  }

  /// The highest number of unapplied amendments this repository currently tolerates.
  ///
  /// A missing or unreadable file means zero, so deleting it makes the test stricter rather than
  /// silently switching it off.
  private static func amendmentBaseline() throws -> Int {
    let url = repositoryRoot.appending(path: "docs/specs/AMENDMENT-BASELINE.txt")
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { return 0 }
    let digits = text.split(separator: "\n")
      .first { $0.trimmingCharacters(in: .whitespaces).first?.isNumber == true }
    return Int(digits?.trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
  }

  /// Whether a delta's `**Currently:**` block quotes text that is *still present* in `SPEC.md`.
  ///
  /// **THIS IS THE WHOLE DETECTOR, AND IT SELF-CLOSES.** A delta amends the contract when it says
  /// "the spec currently says X" and the spec does, in fact, still say X. The moment the owner
  /// applies the amendment, X is gone from `SPEC.md`, this returns false, and the delta stops being
  /// counted — with no list to maintain and no baseline to remember to lower.
  ///
  /// The first version of this test asked only whether a `**Currently:**` block existed, and
  /// over-counted: `D14` quotes a conflict between `D13` and `F5`, and `D21` quotes a SwiftData
  /// model. Neither quotes the contract, and neither owes it anything. A check that names the wrong
  /// files is one people stop reading.
  ///
  /// Fragments are taken from backticked spans, because that is how this file quotes spec lines.
  /// Only fragments long enough to be distinctive are used — a short one like `F2` appears
  /// everywhere and would match by accident.
  private static func quotesLiveSpecText(in body: String) -> Bool {
    guard let currently = body.range(of: "**Currently:**") else { return false }
    let tail = body[currently.upperBound...]
    let block = tail.range(of: "**Proposed").map { String(tail[..<$0.lowerBound]) } ?? String(tail)

    let spec = squashed((try? String(
      contentsOf: repositoryRoot.appending(path: "docs/specs/SPEC.md"), encoding: .utf8)) ?? "")

    return fragments(of: block).contains { spec.contains($0) }
  }

  /// Whitespace collapsed to single spaces.
  ///
  /// Load-bearing: `00-deltas.md` wraps its quotations across lines, so a quoted spec line contains a
  /// newline exactly where `SPEC.md` has a space. Comparing raw text finds nothing and the check
  /// silently reports a clean backlog — the worst failure available to a test whose whole job is to
  /// count what is outstanding.
  private static func squashed(_ text: String) -> String {
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
  private static func fragments(of block: String) -> [String] {
    var found: [String] = []

    found += block
      .split(separator: "`", omittingEmptySubsequences: false)
      .enumerated()
      .filter { $0.offset % 2 == 1 }
      .map { squashed(String($0.element)) }

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

  /// The ids listed under `## Amendments applied` in `SPEC.md`, or an empty set when the section
  /// does not exist yet.
  private static func appliedAmendments() throws -> Set<String> {
    let spec = try String(
      contentsOf: repositoryRoot.appending(path: "docs/specs/SPEC.md"), encoding: .utf8)
    guard let start = spec.range(of: "## Amendments applied") else { return [] }
    let rest = spec[start.upperBound...]
    let section = rest.range(of: "\n## ").map { String(rest[..<$0.lowerBound]) } ?? String(rest)
    return deltaIDs(in: section)
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
}
