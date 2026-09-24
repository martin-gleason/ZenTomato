import Foundation
import Testing

/// The amendment ratchet, for every ratified baseline this project has.
///
/// **WHY THIS FILE EXISTS, AND WHY IT IS AN EXTENSION.** `D41` ruled that the ratchet had three
/// holes. Closing them needs about a hundred lines, and `DeltaIntegrityTests.swift` was 393 lines
/// against SwiftLint's default 400-line cap, which counts comments. Widening `.swiftlint.yml` to
/// fit is the silence-the-instrument move this project refuses, so the code moved instead.
///
/// It is an `extension` and not a new suite type because three documents cite these members by
/// qualified name and one may not be edited: `docs/specs/SPEC.md:80` says *"`DeltaIntegrityTests`
/// reads this list"*, and `docs/plans/F17.md` cites
/// `DeltaIntegrityTests.everyRatifiedSpecAmendmentIsApplied` and `DeltaIntegrityTests.fragments(of:)`.
/// A new type would make the `SPEC.md` sentence false, and the agent cannot fix `SPEC.md`. The
/// helpers left behind changed only from `private static` to `static`, because `private` does not
/// cross a file boundary even into an extension of the same type.
extension DeltaIntegrityTests {
  // MARK: What the ratchet watches

  /// A ratified baseline document the ratchet watches.
  ///
  /// `SPEC.md` keeps its applied-list inside itself because the **owner** edits `SPEC.md`.
  /// `zenpom-v1.5.md` cannot: the agent is forbidden to touch a ratified baseline — `C31` needed
  /// `D40` before one character of it could change — so its ledger is a separate artifact *about*
  /// the baseline, in the relationship `AMENDMENT-BASELINE.txt` already has to `SPEC.md`.
  struct WatchedBaseline {
    /// Repo-relative path of the baseline whose live text is searched.
    let document: String
    /// The document carrying the `## Amendments applied` list.
    let appliedList: String
    /// The file carrying the tolerated outstanding count.
    let baselineFile: String
  }

  static let watchedBaselines = [
    WatchedBaseline(
      document: "docs/specs/SPEC.md",
      appliedList: "docs/specs/SPEC.md",
      baselineFile: "docs/specs/AMENDMENT-BASELINE.txt"),
    // `D44`, ratified by the owner 2026-09-24: v1.5's ledger moved INSIDE the
    // baseline, so this row is now identical in shape to `SPEC.md`'s above. The
    // asymmetry this struct was built to carry — a ledger beside the spec, because
    // the agent may not edit a ratified baseline — is gone. `O45` was the row that
    // asked, and the answer was the owner's to give.
    WatchedBaseline(
      document: "docs/specs/zenpom-v1.5.md",
      appliedList: "docs/specs/zenpom-v1.5.md",
      baselineFile: "docs/specs/V15-AMENDMENT-BASELINE.txt")
  ]

  // MARK: Hole 1 — the marker has two spellings

  /// Both spellings of the marker.
  ///
  /// Four ratified deltas — `D31`, `D32`, `D33`, `D34` — write `**Currently**,` with the comma
  /// outside the bold, and were invisible to a detector matching only `**Currently:**`. `D35` uses
  /// the colon form and **was** seen, so the finding is four, not "everything since 2026-09-09";
  /// `D41` records that precision because an overstated finding gets refuted and takes the real one
  /// down with it. A ratified decision is never edited, so the instrument learns both spellings.
  ///
  /// **Two literals, not a regular expression.** The block is sliced from the marker's upper bound,
  /// so the marker's *consumed length* is part of the contract; with literals it is exactly the
  /// matched literal's, which for a colon-form delta is character-for-character what the pre-`C32`
  /// code did. A pattern with an optional comma would make that length depend on whether the comma
  /// matched. Neither literal is a prefix of the other, so they cannot shadow each other.
  static let currentlyMarkers = ["**Currently:**", "**Currently**"]

  /// The text a delta says its baseline CURRENTLY says: everything after the marker, up to
  /// `**Proposed` if the delta has one, otherwise to the end of the delta body.
  ///
  /// **Earliest position wins, not list order.** `D41` itself contains both spellings, in backticks,
  /// while quoting the bug it fixes. The colon form comes first there, so earliest-position
  /// reproduces the pre-`C32` choice for the one delta where the two rules could disagree.
  static func currentlyMarkerRange(in body: String) -> Range<String.Index>? {
    currentlyMarkers
      .compactMap { body.range(of: $0) }
      .min { $0.lowerBound < $1.lowerBound }
  }

  static func currentlyBlock(in body: String) -> String? {
    guard let hit = currentlyMarkerRange(in: body) else { return nil }
    let tail = body[hit.upperBound...]
    return tail.range(of: "**Proposed").map { String(tail[..<$0.lowerBound]) } ?? String(tail)
  }

  /// Every single-backtick span in a piece of text, whitespace squashed.
  ///
  /// One extractor, three callers — the declaration rule, the preamble scan and `fragments(of:)` —
  /// so a span that counts as a declaration cannot be parsed one way there and another way here.
  static func backtickedSpans(in text: String) -> [String] {
    text
      .split(separator: "`", omittingEmptySubsequences: false)
      .enumerated()
      .filter { $0.offset % 2 == 1 }
      .map { squashed(String($0.element)) }
  }

  // MARK: The detector

  /// The watched baseline a delta body owes text to, or `nil` when it owes none.
  ///
  /// **THIS IS THE WHOLE DETECTOR, AND IT SELF-CLOSES.** A delta amends a baseline when it says
  /// "the spec currently says X" and the spec does, in fact, still say X. The moment the amendment
  /// is applied, X is gone, this returns `nil`, and the delta stops being counted.
  ///
  /// **A declaration only ever REDIRECTS; it never excuses.** When the declaration resolves to no
  /// watched baseline — `D40` declares `CLAUDE.md` — the block is judged against `SPEC.md`, exactly
  /// as every delta was before `C32`. An earlier draft of this method returned `nil` there, which
  /// silently narrowed the `SPEC.md` ratchet: a delta naming an unwatched document while quoting
  /// live `SPEC.md` text verbatim was dropped and the whole suite stayed green.
  /// `anUnwatchedDeclarationIsStillJudgedAgainstSpec` is the assertion that pins it.
  static func owedBaseline(for body: String) -> WatchedBaseline? {
    guard let block = currentlyBlock(in: body) else { return nil }
    let baseline = declaredBaseline(for: body) ?? watchedBaselines[0]
    let live = squashed((try? String(
      contentsOf: repositoryRoot.appending(path: baseline.document), encoding: .utf8)) ?? "")
    return fragments(of: block).contains { live.contains($0) } ? baseline : nil
  }

  // MARK: Reading the deltas file

  /// One ratified, unrejected delta: its id, a short summary from the heading, and its body.
  struct RatifiedDelta {
    let id: String
    let summary: String
    let body: String
  }

  /// Every ratified, unrejected delta, in file order.
  static func ratifiedDeltas() throws -> [RatifiedDelta] {
    let lines = try deltaFileLines()
    var found: [RatifiedDelta] = []
    for (index, line) in lines.enumerated() where line.hasPrefix("## D") {
      guard let id = headingID(line) else { continue }
      let end = lines[(index + 1)...].firstIndex { $0.hasPrefix("## D") } ?? lines.count
      let body = lines[index..<end].joined(separator: "\n")
      guard body.contains("Ratified"), body.contains("REJECTED") == false else { continue }
      found.append(RatifiedDelta(id: id, summary: String(line.dropFirst(3).prefix(72)), body: body))
    }
    return found
  }

  /// The highest number of unapplied amendments the named file currently tolerates.
  ///
  /// A missing or unreadable file means zero, so deleting it makes the test stricter rather than
  /// silently switching it off.
  static func amendmentBaseline(_ path: String) throws -> Int {
    guard let text = try? String(contentsOf: repositoryRoot.appending(path: path), encoding: .utf8)
    else { return 0 }
    let digits = text.split(separator: "\n")
      .first { $0.trimmingCharacters(in: .whitespaces).first?.isNumber == true }
    return Int(digits?.trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
  }

  /// The ids listed under `## Amendments applied` in the named file, or an empty set when the
  /// section does not exist yet.
  ///
  /// **The heading is matched at the start of a line, and `C32-M6` is why.** The pre-`C32` code
  /// matched the bare string anywhere, so a document that *mentions* `## Amendments applied` in
  /// prose — as this project's v1.5 ledger does, explaining why `SPEC.md` may carry its list inline
  /// and v1.5 may not — had its section read from the mention instead of the heading. The parser
  /// then returned the ids in the surrounding paragraph and missed every id in the real list. It
  /// went unnoticed because the wrong answer happened to contain the id the ratchet was asking
  /// about: a fixture that satisfies both the right and the wrong implementation distinguishes
  /// nothing.
  static func appliedAmendments(in path: String) throws -> Set<String> {
    guard let text = try? String(contentsOf: repositoryRoot.appending(path: path), encoding: .utf8)
    else { return [] }
    let padded = "\n" + text
    guard let start = padded.range(of: "\n## Amendments applied") else { return [] }
    let rest = padded[start.upperBound...]
    let section = rest.range(of: "\n## ").map { String(rest[..<$0.lowerBound]) } ?? String(rest)
    return deltaIDs(in: section)
  }

  // MARK: The ratchet itself

  /// The shared ratchet, applied to one baseline.
  ///
  /// **THE AGENT MAY NOT FIX A RED RATCHET, AND THAT IS WHY IT EXISTS.** `CLAUDE.md` and
  /// `conventions.md` both say the agent never edits the contract; spec authority is the owner's.
  /// This check cannot close the gap. It can only refuse to let the gap stay invisible.
  ///
  /// **Why it is not simply `outstanding.isEmpty`.** Under branch protection a permanently red test
  /// blocks every merge, and a gate that cannot be met is a gate somebody deletes — after which the
  /// check is gone rather than satisfied. So the assertion is on the DIRECTION: the backlog may
  /// shrink or hold, never grow. The baseline lives in a committed file, so lowering it is a visible
  /// edit in a diff rather than a number somebody nudged.
  static func assertRatchet(for baseline: WatchedBaseline) throws {
    let owed = try ratifiedDeltas().filter { owedBaseline(for: $0.body)?.document == baseline.document }
    let applied = try appliedAmendments(in: baseline.appliedList)
    let outstanding = owed.filter { applied.contains($0.id) == false }
    let tolerated = try amendmentBaseline(baseline.baselineFile)

    #expect(
      outstanding.count <= tolerated,
      Comment(rawValue: """
        The unapplied-amendment backlog for \(baseline.document) grew: \(outstanding.count) \
        outstanding against a baseline of \(tolerated).
        A delta was ratified without its text reaching that baseline. Apply it, add its id to the
        '## Amendments applied' list in \(baseline.appliedList), and lower the number in
        \(baseline.baselineFile). Never by editing this test.
        """))

    // Named on every run whether or not the ratchet trips, because the point is that the gap is
    // countable and visible rather than merely bounded.
    if outstanding.isEmpty == false {
      print("""

        ── \(baseline.document) amendment backlog: \(outstanding.count) outstanding \
        (baseline \(tolerated)) ──
        The contract states things that are no longer true, so "re-read the spec" returns stale
        answers. Only the owner may close these; the agent never edits the contract.

        \(outstanding.map { "  \($0.id) — \($0.summary)" }.joined(separator: "\n"))

        """)
    }
  }

  /// `everyRatifiedSpecAmendmentIsApplied` — H2. The gap between what was ratified and what
  /// `SPEC.md` actually says, made countable.
  ///
  /// **What went wrong without it.** Twenty-two deltas were ratified between 2026-08-21 and
  /// 2026-08-24 and not one was ever applied to `SPEC.md`. The contract still said minimum iOS 18.0
  /// after `D1` raised it to 26, still said OAuth sign-in after `D18` replaced it with a pasted
  /// token, still listed watchOS as out of scope after `D2` moved the remote half in. `CLAUDE.md`'s
  /// working loop opens with *"Re-read `SPEC.md`"* — so an agent following its instructions exactly
  /// gets answers that are two months stale, and then believes the contract. That is what happened
  /// at the F7 gate.
  ///
  /// **How to make it pass:** apply the amendment to `SPEC.md` and add its id to the
  /// `## Amendments applied` list there. Not by editing this test.
  @Test("everyRatifiedSpecAmendmentIsApplied")
  func everyRatifiedSpecAmendmentIsApplied() throws {
    try Self.assertRatchet(for: Self.watchedBaselines[0])
  }

  /// `theWatchedBaselinesAreInTheOrderEveryCallerAssumes` — the index is load-bearing and nothing
  /// else says so.
  ///
  /// **The defect this pins.** `watchedBaselines` is read BY POSITION in three places: the two named
  /// ratchet tests above and below, and `owedBaseline(for:)`'s fallback, which sends every
  /// unresolvable declaration to `[0]`. Insert a third baseline at the front of that array and
  /// `everyRatifiedSpecAmendmentIsApplied` silently measures a different document while keeping its
  /// name, and every fallback lands on the wrong contract. Nothing would fail.
  ///
  /// **A check that names the wrong file is the failure class this repository already records** —
  /// a per-theme rule checked once against one theme, a parser returning one value for every row.
  /// Two `#expect`s cost nothing and make the positional contract explicit rather than assumed.
  @Test("theWatchedBaselinesAreInTheOrderEveryCallerAssumes")
  func theWatchedBaselinesAreInTheOrderEveryCallerAssumes() {
    #expect(
      Self.watchedBaselines[0].document == "docs/specs/SPEC.md",
      "Index 0 is the SPEC.md ratchet and is also owedBaseline(for:)'s fallback.")
    #expect(
      Self.watchedBaselines[1].document == "docs/specs/zenpom-v1.5.md",
      "Index 1 is the v1.5 ratchet, read by name in everyRatifiedV15AmendmentIsApplied.")
  }

  /// `everyRatifiedV15AmendmentIsApplied` — the same ratchet, for `docs/specs/zenpom-v1.5.md`.
  ///
  /// **What went wrong without it.** `everyRatifiedSpecAmendmentIsApplied` read only `SPEC.md`, and
  /// `zenpom-v1.5.md` is an equally ratified baseline. `D33` amended it on 2026-09-09 and sat
  /// unapplied for thirteen days with nothing able to go red. `C31` applied it by hand, under `D40`,
  /// because a person happened to look.
  ///
  /// **A separate `@Test`, not a loop inside one**, so each baseline has a nameable failing test for
  /// its mutation and a red v1.5 ratchet cannot be mistaken for a red SPEC one.
  ///
  /// **How to make it pass:** apply the amendment — which only the owner may do, under a `D<n>`, as
  /// `D40` authorised for `D33` — and add its id to `docs/specs/V15-AMENDMENTS-APPLIED.md`.
  @Test("everyRatifiedV15AmendmentIsApplied")
  func everyRatifiedV15AmendmentIsApplied() throws {
    try Self.assertRatchet(for: Self.watchedBaselines[1])
  }

  // MARK: The three proofs that the detector really changed

  /// `bothCurrentlySpellingsAreRecognised` — the finding in `D41`, pinned to the real file.
  ///
  /// `D31`–`D34` write `**Currently**,` and were invisible; `D35` writes `**Currently:**` and was
  /// not. Hard-coding those five ids is legitimate here and nowhere else: `D41` names them as the
  /// finding, and ratified delta text is immutable, so the fixture cannot rot. **The count is four
  /// plus one, not "everything since 2026-09-09"** — an overstatement in an earlier review is the
  /// reason `D41` records the precision.
  ///
  /// **How to make it pass:** teach the detector the spelling it is missing. Never by editing
  /// `00-deltas.md`, which is the act `D41` refused.
  ///
  /// **Found is not usable, and the second loop is why.** Asserting only that a block exists would
  /// stay green if the comma-form slice came back as garbage — the same green-tick-on-a-tautology
  /// this repository has five recorded instances of. `theColonFormBlockIsByteIdentical` covers only
  /// the colon form, so the comma form gets the identical treatment here: its slice is compared,
  /// as a **string**, against the pre-`C32` three-line algorithm recomputed from the comma marker.
  /// `**Currently:**` does not contain `**Currently**` as a substring, so the colon-form deltas skip
  /// this loop rather than needing a special case.
  @Test("bothCurrentlySpellingsAreRecognised")
  func bothCurrentlySpellingsAreRecognised() throws {
    let seen = try Self.ratifiedDeltas()
      .filter { DeltaIntegrityTests.currentlyBlock(in: $0.body) != nil }
      .map(\.id)
    let expected = ["D31", "D32", "D33", "D34", "D35"]
    let missing = expected.filter { seen.contains($0) == false }
    #expect(
      missing.isEmpty,
      Comment(rawValue: """
        The detector cannot see the 'Currently' block of: \(missing.joined(separator: ", ")).
        D31–D34 use the comma form and D35 the colon form; D41 requires both to be read.
        """))

    var compared = 0
    for delta in try Self.ratifiedDeltas() where expected.contains(delta.id) {
      guard let marker = delta.body.range(of: "**Currently**") else { continue }
      let tail = delta.body[marker.upperBound...]
      let old = tail.range(of: "**Proposed").map { String(tail[..<$0.lowerBound]) } ?? String(tail)
      #expect(
        DeltaIntegrityTests.currentlyBlock(in: delta.body) == old,
        Comment(rawValue: "\(delta.id): the comma-form block is not the slice the marker implies."))
      compared += 1
    }
    #expect(compared == 4, "Expected D31–D34 to be compared as comma-form; compared \(compared).")
  }

  /// `theColonFormBlockIsByteIdentical` — the non-regression proof for `D41`'s first clause.
  ///
  /// Teaching the detector a second marker must not move the first one by a single character, since
  /// the block is sliced from the marker's upper bound. This recomputes the pre-`C32` three-line
  /// algorithm inline and asserts **string** equality with `currentlyBlock(in:)`.
  ///
  /// **String equality, not fragment equality, and that is the whole point.** The marker contains no
  /// backtick and no quote character, so `fragments(of:)` is insensitive to a small slice shift — a
  /// fragment-level assertion here would be a tautology with a green tick, which is the failure this
  /// repository has five recorded instances of. `C32-M5` shifts the slice by the marker's own length
  /// and only this assertion notices.
  @Test("theColonFormBlockIsByteIdentical")
  func theColonFormBlockIsByteIdentical() throws {
    var compared = 0
    for delta in try Self.ratifiedDeltas() {
      guard let marker = delta.body.range(of: "**Currently:**") else { continue }
      let tail = delta.body[marker.upperBound...]
      let old = tail.range(of: "**Proposed").map { String(tail[..<$0.lowerBound]) } ?? String(tail)
      #expect(
        DeltaIntegrityTests.currentlyBlock(in: delta.body) == old,
        Comment(rawValue: "\(delta.id): the colon-form block moved from what the pre-C32 code read."))
      compared += 1
    }
    #expect(compared > 0, "No colon-form delta was compared, so this assertion proved nothing.")
  }

  /// `aCommaFormDeltaQuotingTheV15SpecIsSeen` — marker, declaration, document read and fragment
  /// match, end to end, without editing anything.
  ///
  /// The fixture is a comma-form block quoting a sentence that is genuinely in `zenpom-v1.5.md`. If
  /// any link in the chain breaks — the second spelling, the declaration rule, the second watched
  /// baseline, the fragment extractor — this reports the wrong document or none.
  ///
  /// **The setup is asserted first.** `C28`'s `statusCheckCatchesAHandEdit` failed the first time it
  /// ran because its own mutation silently matched nothing: *an assertion whose setup failed proves
  /// nothing.* So the quoted prefix is checked against the live spec before it is used.
  ///
  /// The fixture has no heading and no `D<n>` token, deliberately: `citingFiles()` walks
  /// `ZenTomatoTests` as well as `docs/`, so a literal fixture id here would be reported by
  /// `everyCitedDeltaIsDefined` as a citation of a delta that does not exist.
  @Test("aCommaFormDeltaQuotingTheV15SpecIsSeen")
  func aCommaFormDeltaQuotingTheV15SpecIsSeen() throws {
    let path = "docs/specs/zenpom-v1.5.md"
    let spec = try String(
      contentsOf: DeltaIntegrityTests.repositoryRoot.appending(path: path), encoding: .utf8)
    guard let vision = spec
      .components(separatedBy: "\n")
      .first(where: { $0.hasPrefix("> A focus timer that works with the fixed toolset") })
    else {
      Issue.record("The v1.5 vision sentence has moved; this fixture needs a new quotation.")
      return
    }
    let quotation = String(vision.dropFirst(2).prefix(60))

    // Setup first: a fixture quoting text the spec does not contain would prove nothing at all.
    #expect(
      DeltaIntegrityTests.squashed(spec).contains(DeltaIntegrityTests.squashed(quotation)),
      "The fixture's quotation is not in the live v1.5 spec, so the rest of this test is vacuous.")

    let body = "**Currently**, `\(path)` says \"\(quotation)\""
    #expect(
      DeltaIntegrityTests.owedBaseline(for: body)?.document == path,
      Comment(rawValue: """
        A comma-form delta quoting live zenpom-v1.5.md text was not reported as owing it. \
        Resolved to: \(DeltaIntegrityTests.owedBaseline(for: body)?.document ?? "no baseline").
        """))
  }
}
