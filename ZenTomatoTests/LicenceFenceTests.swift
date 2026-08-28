import Foundation
import Testing

@testable import ZenTomato

/// One licence, one pledge, and neither may quietly become something else.
///
/// **WHAT IS BEING PROTECTED.** ZenPom is GPL-3.0-or-later everywhere, paired
/// with an App Store distribution exception — the copyright holder's pledge not
/// to enforce the GPL's no-added-restrictions clause against Apple's terms. It is
/// the arrangement the GPL apps actually on the App Store use: Signal, Nextcloud,
/// Telegram, Element, Bitwarden.
///
/// **The failure this guards is redescription.** The exception is not a second
/// licence, and the moment prose describes the project as "GPL or something
/// else", the copyleft is being offered away. `scripts/check-licence-wording.sh`
/// greps the prose for that shape; this file holds what a grep cannot — that the
/// files exist, that each says what kind of thing it is, and that the GPL notice
/// actually travels inside the app, which GPL §4 requires of every conveyed copy.
@Suite("LicenceFence")
struct LicenceFenceTests {
  /// `theLicenceAndThePledgeExist` — files, not promises.
  @Test("theLicenceAndThePledgeExist")
  func theLicenceAndThePledgeExist() throws {
    let gpl = try Self.read("LICENSE")
    #expect(gpl.contains("GNU GENERAL PUBLIC LICENSE"))
    #expect(gpl.contains("Version 3"))

    let exception = try Self.read("LICENSE-EXCEPTION.md")
    // Whitespace-normalised before matching: the pledge spans a hard-wrapped
    // line, and a fence that broke when a paragraph was re-wrapped would be
    // deleted rather than obeyed.
    let flattened = exception.components(separatedBy: .whitespacesAndNewlines)
      .filter { $0.isEmpty == false }.joined(separator: " ")
    #expect(
      flattened.contains("commits not to pursue any licence violation that results"),
      "The exception no longer contains the pledge, which is its entire content.")
    #expect(
      exception.contains("solely"),
      "The pledge must stay scoped to the one conflict; without 'solely' it reads as blanket non-enforcement.")
  }

  /// `theExceptionSaysWhatItIsNot` — the redescription guard, from inside the file.
  ///
  /// Whoever edits the exception must keep the sentence saying it is not a second
  /// licence and not a choice, because that sentence is what a hurried reader
  /// needs and what a helpful summariser would cut first.
  @Test("theExceptionSaysWhatItIsNot")
  func theExceptionSaysWhatItIsNot() throws {
    let exception = try Self.read("LICENSE-EXCEPTION.md")
    #expect(exception.contains("not a second licence"))
    #expect(exception.contains("does not add a second one"))
  }

  /// `contributionTermsJoinThePledge` — because a pledge over the whole work
  /// needs every copyright holder in it.
  ///
  /// A merged contribution whose author never joined the pledge can do what a VLC
  /// developer did in 2011: object, and be entitled to. The terms exist so that
  /// conversation happens before the work, not after.
  @Test("contributionTermsJoinThePledge")
  func contributionTermsJoinThePledge() throws {
    let contributing = try Self.read("CONTRIBUTING.md")
    #expect(contributing.contains("LICENSE-EXCEPTION.md"))
    #expect(contributing.contains("You keep your copyright"))

    let notice = try Self.read("NOTICE")
    #expect(notice.contains("Martin Gleason"))
    #expect(notice.contains("GPL-3.0-or-later"))
  }

  /// `theGplNoticeShipsInsideTheApp` — §4's obligation, held in code.
  ///
  /// A licence file in the repository satisfies the repository. Every conveyed
  /// copy of the program owes its recipient the notice, and the app is a
  /// conveyed copy.
  @Test("theGplNoticeShipsInsideTheApp")
  func theGplNoticeShipsInsideTheApp() {
    #expect(AppLicence.notice.contains("GNU General Public License"))
    #expect(AppLicence.notice.contains("Martin Gleason"))
    #expect(AppLicence.notice.contains("version 3"))
    #expect(
      AppLicence.notice.contains("WITHOUT ANY WARRANTY"),
      "The warranty disclaimer is part of the notice the GPL's appendix specifies.")
    #expect(AppLicence.appStoreException.contains("pledged"))
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
