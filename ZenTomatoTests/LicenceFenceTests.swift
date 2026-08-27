import Foundation
import Testing

@testable import ZenTomato

/// The two licences stay two licences.
///
/// **WHAT IS BEING PROTECTED.** ZenPom licenses the **source** under
/// GPL-3.0-or-later and **binaries distributed by the copyright holder** under
/// MIT. That is licence-per-channel, and it works only because one person holds
/// the copyright.
///
/// It is one sentence away from being worthless. *"Dual licensed under GPL-3.0 or
/// MIT"* is the **disjunctive** form: it offers both licences for the same
/// artifact, so anyone who wants the source takes MIT and the copyleft protects
/// nothing.
///
/// **The shell check is the real gate** — `scripts/check-licence-wording.sh` runs
/// in the pre-commit hook and in CI, and it reads the prose. This file holds the
/// parts a grep cannot: that the files exist, that each says what it is for, and
/// that the MIT notice reaches the built app, which MIT itself requires.
@Suite("LicenceFence")
struct LicenceFenceTests {
  /// `bothLicencesExistAndSayWhatTheyCover` — a file, not a promise.
  @Test("bothLicencesExistAndSayWhatTheyCover")
  func bothLicencesExistAndSayWhatTheyCover() throws {
    let gpl = try Self.read("LICENSE")
    #expect(gpl.contains("GNU GENERAL PUBLIC LICENSE"))
    #expect(gpl.contains("Version 3"))

    let app = try Self.read("LICENSE-APP.md")
    #expect(app.contains("MIT License"))
    #expect(
      app.contains("Permission is hereby granted, free of charge"),
      "LICENSE-APP.md names MIT without reproducing it, which grants nothing.")
    #expect(
      app.contains("does not cover the source"),
      "LICENSE-APP.md must say what it does NOT cover; that limit is the whole arrangement.")
  }

  /// `theBinaryLicenceRefusesToCoverTheSource` — the limit, stated in the file.
  ///
  /// A reader holding an MIT-licensed binary must not be able to conclude they
  /// hold MIT rights over the source. The file says so; this keeps it saying so.
  @Test("theBinaryLicenceRefusesToCoverTheSource")
  func theBinaryLicenceRefusesToCoverTheSource() throws {
    let app = try Self.read("LICENSE-APP.md")
    #expect(app.contains("GPL-3.0-or-later"), "The binary licence never names what governs the source.")
    #expect(app.lowercased().contains("not a choice between two"))
  }

  /// `contributionTermsExist` — because without them the arrangement expires.
  ///
  /// Dual licensing survives exactly as long as one person holds all the
  /// copyright. A merged contribution with no relicensing grant ends it, and
  /// nothing in the code can prevent that — only a document read beforehand.
  @Test("contributionTermsExist")
  func contributionTermsExist() throws {
    let contributing = try Self.read("CONTRIBUTING.md")
    #expect(contributing.lowercased().contains("relicense"))
    #expect(
      contributing.contains("You keep your copyright"),
      "The terms must say what a contributor keeps, not only what they grant.")

    let notice = try Self.read("NOTICE")
    #expect(notice.contains("Martin Gleason"))
    #expect(notice.contains("GPL-3.0-or-later"))
    #expect(notice.contains("MIT"))
  }

  /// `theMitNoticeShipsInsideTheApp` — MIT's one obligation.
  ///
  /// > The above copyright notice and this permission notice shall be included in
  /// > all copies or substantial portions of the Software.
  ///
  /// For an app that means the text is reachable **in the binary**, not merely in
  /// the repository. Until the About screen lands this is the copy that would
  /// carry it, so this test asserts the text exists somewhere the app can show —
  /// and fails loudly if the licence is ever shipped with nothing to display.
  @Test("theMitNoticeShipsInsideTheApp")
  func theMitNoticeShipsInsideTheApp() {
    #expect(
      AppLicence.mit.contains("Permission is hereby granted, free of charge"),
      "The app cannot show its own licence, which is the one thing MIT requires.")
    #expect(AppLicence.mit.contains("Martin Gleason"))
    #expect(
      AppLicence.sourceNotice.contains("GPL-3.0-or-later"),
      "The app does not say where its source is or what governs it.")
    #expect(AppLicence.sourceURL.absoluteString.contains("github.com"))
  }

  // MARK: Private

  private static func read(_ name: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    return try #require(
      try? String(contentsOf: root.appending(path: name), encoding: .utf8),
      "\(name) is missing.")
  }
}
