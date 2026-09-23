import Foundation
import Testing

/// Which baseline a delta is talking about — `D41`'s Hole 2, at the resolution step.
///
/// **WHY A THIRD FILE.** `.swiftlint.yml` sets no `file_length`, so SwiftLint's default 400-line cap
/// applies and `scripts/check-lint.sh` passes `--strict`, which makes it an error. The same budget
/// that pushed the ratchet out of `DeltaIntegrityTests.swift` pushes the declaration rule out of
/// `AmendmentRatchetTests.swift`. Widening the config is the silence-the-instrument move this
/// project refuses, so the code moves instead.
///
/// It is also the better seam: `AmendmentRatchetTests` answers *"is this delta's text still in its
/// baseline"*, and this file answers *"which baseline"* — the question `D41` Hole 2 is about, and
/// the one the review found two defects in.
extension DeltaIntegrityTests {
  /// The last path component of a repo-relative path or a bare file name.
  static func lastComponent(_ path: String) -> String {
    String(path.split(separator: "/").last ?? "")
  }

  /// The watched baseline a file name refers to, or `nil`.
  ///
  /// **Compared on the last path component, not `hasSuffix`.** `hasSuffix` resolved a delta
  /// declaring `` `v1.5.md` `` — or any string that happens to end a watched path — to
  /// `docs/specs/zenpom-v1.5.md` by accident, which is a binding nobody wrote and nobody could see.
  static func watchedBaseline(named name: String) -> WatchedBaseline? {
    let wanted = lastComponent(name)
    return watchedBaselines.first { lastComponent($0.document) == wanted }
  }

  /// Which watched baseline this **block** names first, when it names a document at all.
  ///
  /// Five ratified deltas open the block with the document — `D17`, `D18`, `D20`, `D31`, `D40` — so
  /// this reads a convention that exists rather than inventing a field nobody can add to an
  /// immutable delta. **Only the first paragraph is scanned**, because a delta with no `**Proposed`
  /// marker has a block running to the end of its body: `D28` mentions `F2c.md` and `D34`
  /// `CLAUDE.md`, and neither is a declaration.
  static func declaredDocument(in block: String) -> String? {
    let firstParagraph = block.components(separatedBy: "\n\n")[0]
    guard let first = backtickedSpans(in: firstParagraph).first else { return nil }
    let name = first.split(separator: ":").first.map(String.init) ?? first
    guard name.contains(" ") == false,
      name.hasSuffix(".md") || name.hasSuffix(".swift") || name.hasSuffix(".txt")
    else { return nil }
    return name
  }

  /// The watched baseline a whole delta declares, or `nil` when it declares none this ratchet
  /// watches.
  ///
  /// **Two places are read, in this order.** The block's own first backticked span, as above. Then,
  /// only when the block declares nothing, the **preamble** — the text between the heading and the
  /// marker — where two ratified deltas put theirs: `D33` opens *"Owed because
  /// `docs/specs/zenpom-v1.5.md` is a ratified baseline and its order table names eleven units"*,
  /// and `D35` *"This supersedes the stop condition in `docs/specs/zenpom-v1.5.md`"*.
  ///
  /// **The preamble scan admits only a name that resolves to a watched baseline**, so the dozens of
  /// incidental `.md` mentions in a delta's preamble cannot redirect anything. That is the whole of
  /// the difference between this and the block rule, which admits any document-shaped name.
  ///
  /// **What the preamble bought, and why it is not decoration.** `D33` is the delta whose thirteen
  /// unapplied days `D41` Hole 2 is named for. Without the preamble it declares nothing, falls back
  /// to `SPEC.md`, and is judged against the wrong baseline entirely — so the instrument built to
  /// watch v1.5 was not even pointed at it for the one delta that motivated building it.
  /// `theBaselineADeltaDeclaresInItsPreambleIsRead` pins that.
  ///
  /// **This does not make `D33` detectable**, and the gap is recorded rather than implied:
  /// `docs/specs/V15-AMENDMENT-BASELINE.txt` and `O46` say so. Resolution is only half the job; the
  /// other half is a verbatim fragment, and `D33` has none.
  static func declaredBaseline(for body: String) -> WatchedBaseline? {
    guard let block = currentlyBlock(in: body),
      let marker = currentlyMarkerRange(in: body)
    else { return nil }
    // THE BLOCK IS ASKED FIRST, BUT IT DOES NOT GET TO VETO THE PREAMBLE. An earlier draft returned
    // `watchedBaseline(named:)` here unconditionally, so a block whose first document-shaped name is
    // *unwatched* short-circuited: the preamble was never read and the caller fell back to `SPEC.md`.
    // `D40`'s block opens with `CLAUDE.md`, which is exactly that shape — so a later delta written in
    // `D40`'s form while declaring `zenpom-v1.5.md` in its preamble would have been judged against the
    // wrong baseline and been invisible to the v1.5 ratchet. That is the miss this whole unit exists
    // to close, reproduced inside the instrument closing it.
    if let declared = declaredDocument(in: block), let watched = watchedBaseline(named: declared) {
      return watched
    }
    return backtickedSpans(in: String(body[..<marker.lowerBound]))
      .lazy
      .compactMap { watchedBaseline(named: $0) }
      .first
  }
}

/// The two assertions the `C32` review asked for, both about resolution rather than matching.
@Suite("AmendmentDeclaration")
struct AmendmentDeclarationTests {
  /// `anUnwatchedDeclarationIsStillJudgedAgainstSpec` — a declaration REDIRECTS, it never excuses.
  ///
  /// **The defect this pins.** `owedBaseline(for:)` returned `nil` when the declared name matched no
  /// watched baseline. Before `C32` there was no declaration rule at all: any `Currently` block
  /// whose fragments matched live `SPEC.md` text was counted. So the new rule silently dropped a
  /// delta that names `CLAUDE.md` or `F2c.md` while quoting `SPEC.md` verbatim — a narrowing of the
  /// `SPEC.md` ratchet that `theColonFormBlockIsByteIdentical` cannot see, because the marker slice
  /// is unchanged and only the judgement downstream of it moved.
  ///
  /// The fixture is the review's own trigger: `D40`'s declaration shape, `CLAUDE.md:10`, carrying
  /// **live `SPEC.md` line 31** as its quotation. Pre-`C32` this was counted; post-fix it is counted
  /// again. **The setup is asserted first** — a fixture quoting text the spec does not contain would
  /// prove nothing, which is how `C28`'s `statusCheckCatchesAHandEdit` failed its first run.
  @Test("anUnwatchedDeclarationIsStillJudgedAgainstSpec")
  func anUnwatchedDeclarationIsStillJudgedAgainstSpec() throws {
    let path = "docs/specs/SPEC.md"
    let spec = try String(
      contentsOf: DeltaIntegrityTests.repositoryRoot.appending(path: path), encoding: .utf8)
    guard let row = spec
      .components(separatedBy: "\n")
      .first(where: { $0.contains("Local only (SwiftData)") })
    else {
      Issue.record("SPEC.md no longer carries the Data row; this fixture needs a new quotation.")
      return
    }
    let quotation = DeltaIntegrityTests.squashed(row)
      .trimmingCharacters(in: CharacterSet(charactersIn: "| "))

    #expect(
      DeltaIntegrityTests.squashed(spec).contains(quotation),
      "The fixture's quotation is not in live SPEC.md, so the rest of this test is vacuous.")

    let body = "**Currently:** `CLAUDE.md:10` says the contract reads *\"\(quotation)\"*"
    #expect(
      DeltaIntegrityTests.declaredBaseline(for: body)?.document == nil,
      "CLAUDE.md is not watched, so it must resolve to no baseline — the fallback does the rest.")
    #expect(
      DeltaIntegrityTests.owedBaseline(for: body)?.document == path,
      Comment(rawValue: """
        A delta declaring an UNWATCHED document while quoting live SPEC.md text was not counted \
        against SPEC.md. Resolved to: \
        \(DeltaIntegrityTests.owedBaseline(for: body)?.document ?? "no baseline"). \
        A declaration redirects; it never excuses.
        """))
  }

  /// `anUnwatchedBlockNameDoesNotVetoThePreamble` — the block is asked first, but it cannot veto.
  ///
  /// **The defect this pins, found in this unit's own review.** `declaredBaseline(for:)` returned
  /// `watchedBaseline(named:)` as soon as the block yielded ANY document-shaped name. When that name
  /// was unwatched the result was `nil`, the preamble was never consulted, and the caller's fallback
  /// sent the delta to `SPEC.md`.
  ///
  /// **Why that is not hypothetical.** `D40`'s `Currently` block opens with `CLAUDE.md` — an
  /// unwatched document — which is precisely this shape. A later delta written in `D40`'s form while
  /// declaring `docs/specs/zenpom-v1.5.md` in its preamble would have been judged against the wrong
  /// baseline and stayed invisible to the v1.5 ratchet: the same miss `D41` Hole 2 is named for,
  /// reproduced inside the instrument built to close it.
  ///
  /// **The fixture is chosen so the right and wrong implementations disagree.** The block names an
  /// unwatched document and the preamble names a watched one, so a short-circuiting implementation
  /// returns `nil` and a falling-through one returns the v1.5 baseline. A fixture naming the same
  /// document in both places would pass under either and distinguish nothing.
  @Test("anUnwatchedBlockNameDoesNotVetoThePreamble")
  func anUnwatchedBlockNameDoesNotVetoThePreamble() {
    let body = """
      This ruling amends `docs/specs/zenpom-v1.5.md`, which is where its order table lives.

      **Currently:** `CLAUDE.md:10` enumerates the order, and that copy went stale.
      """
    #expect(
      DeltaIntegrityTests.declaredBaseline(for: body)?.document == "docs/specs/zenpom-v1.5.md",
      Comment(rawValue: """
        The block named an unwatched document and the preamble named a watched one. The preamble \
        must win. Resolved to: \
        \(DeltaIntegrityTests.declaredBaseline(for: body)?.document ?? "no baseline").
        """))
  }

  /// `theBaselineADeltaDeclaresInItsPreambleIsRead` — `D33`, judged against the spec it amends.
  ///
  /// `D33`'s block opens *"that table reads: `C21`, `F8`, …"* and declares nothing, so the block
  /// rule alone sends the one delta `D41` Hole 2 is named for to `SPEC.md`. Its preamble names
  /// `docs/specs/zenpom-v1.5.md` outright.
  ///
  /// `D33` is a real, ratified, immutable delta, so this fixture cannot rot — the same argument
  /// `bothCurrentlySpellingsAreRecognised` makes for hard-coding `D31`–`D35`.
  ///
  /// **The second assertion is about how a name resolves**, and it is here because resolution used
  /// `hasSuffix`: `v1.5.md` is a suffix of `docs/specs/zenpom-v1.5.md`, so a delta naming a file
  /// that does not exist bound to the v1.5 spec by accident. `lastComponent` is what stops it.
  @Test("theBaselineADeltaDeclaresInItsPreambleIsRead")
  func theBaselineADeltaDeclaresInItsPreambleIsRead() throws {
    guard let delta = try DeltaIntegrityTests.ratifiedDeltas().first(where: { $0.id == "D33" })
    else {
      Issue.record("D33 has no ratified heading in 00-deltas.md; this fixture has moved.")
      return
    }
    #expect(
      DeltaIntegrityTests.declaredBaseline(for: delta.body)?.document
        == "docs/specs/zenpom-v1.5.md",
      Comment(rawValue: """
        D33 declares docs/specs/zenpom-v1.5.md in its preamble and resolved to \
        \(DeltaIntegrityTests.declaredBaseline(for: delta.body)?.document ?? "no baseline"). \
        Judged against SPEC.md it is measured against a document it does not amend.
        """))

    #expect(
      DeltaIntegrityTests.watchedBaseline(named: "v1.5.md")?.document == nil,
      "'v1.5.md' is not a watched baseline; resolution must be on the last path component.")
  }
}
