import Foundation
import Testing

@testable import ZenTomato

/// The privacy manifest says nothing is collected, and keeps saying it.
///
/// **WHY A TEST FOR A FILE APPLE DOES NOT REQUIRE.** The manifest exists to make
/// `SPEC.md`'s *"local only. No network calls except Todoist and MusicKit. No
/// analytics"* checkable rather than merely written down. A claim nobody verifies
/// is exactly the kind of thing this project keeps finding to be true in a
/// document and false in the code — the MusicKit entitlement that could not
/// exist, the fence that forbade a search field the contract permitted, the
/// comment that said a property read was free when it was a cross-process call.
///
/// So the file is held to its word here. If the app ever starts collecting
/// something or reaching for a required-reason API, the manifest has to change —
/// and this fails until it does, in a diff somebody reads.
///
/// **The manifest is read from the source tree** by `#filePath`, the way
/// `PolishFenceTests` and the golden reader already do. That is deliberate: it is
/// a reviewable artifact rather than a resource whose absence from a bundle would
/// be silent.
@Suite("PrivacyManifest")
struct PrivacyManifestTests {
  /// `nothingIsTrackedOrCollected` — the three empty arrays, asserted as empty.
  ///
  /// **An empty array is a statement; a missing key is a silence.** Both read the
  /// same to a careless eye and mean different things to App Store Connect, so
  /// each key is checked for presence *and* for emptiness.
  @Test("nothingIsTrackedOrCollected")
  func nothingIsTrackedOrCollected() throws {
    let manifest = try Self.manifest()

    #expect(manifest["NSPrivacyTracking"] as? Bool == false, "The app declares that it tracks.")

    for key in ["NSPrivacyTrackingDomains", "NSPrivacyCollectedDataTypes", "NSPrivacyAccessedAPITypes"] {
      let value = try #require(
        manifest[key] as? [Any],
        "\(key) is missing, which says nothing rather than nothing-collected.")
      #expect(value.isEmpty, "\(key) has \(value.count) entries; the app now declares something it did not.")
    }
  }

  /// `theManifestAndTheCodeAgree` — the claim is checked against the tree.
  ///
  /// The manifest declaring no required-reason APIs is only worth something if no
  /// required-reason API is used. This checks the five categories Apple names,
  /// with comments stripped first — the only `UserDefaults` in this repository is
  /// a word inside a comment explaining why SwiftData was chosen instead, and a
  /// fence that cannot tell a mention from a use is one somebody switches off.
  @Test("theManifestAndTheCodeAgree")
  func theManifestAndTheCodeAgree() throws {
    for api in ["UserDefaults", "systemUptime", "\\.creationDate", "\\.modificationDate",
                "volumeAvailableCapacity", "activeInputModes"] {
      #expect(
        try Self.usesInShippedCode(api) == 0,
        """
        \(api) is a required-reason API and the manifest declares none. Either \
        add it to NSPrivacyAccessedAPITypes with its reason code, or stop using it.
        """)
    }
  }

  // MARK: Private

  private static let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()

  private static func manifest() throws -> [String: Any] {
    let url = root.appending(path: "ZenTomato").appending(path: "PrivacyInfo.xcprivacy")
    let data = try #require(
      try? Data(contentsOf: url),
      "PrivacyInfo.xcprivacy is missing. It is committed on purpose — see its own comments.")
    let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
    return try #require(plist as? [String: Any], "The manifest is not a dictionary.")
  }

  /// Occurrences across the shipped Swift, with comment lines removed.
  private static func usesInShippedCode(_ pattern: String) throws -> Int {
    var total = 0
    for directory in ["ZenTomato", "ZenTomatoWatch", "ZenTomatoActivity"] {
      guard let walk = FileManager.default.enumerator(
        at: root.appending(path: directory), includingPropertiesForKeys: nil) else { continue }
      for case let url as URL in walk where url.pathExtension == "swift" {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
        let code = text
          .components(separatedBy: "\n")
          .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") == false }
          .joined(separator: "\n")
        guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
        total += expression.numberOfMatches(
          in: code, range: NSRange(code.startIndex..<code.endIndex, in: code))
      }
    }
    return total
  }
}
