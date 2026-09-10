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
  /// `nothingIsTrackedOrCollected` — the two empty arrays, asserted as empty.
  ///
  /// **An empty array is a statement; a missing key is a silence.** Both read the
  /// same to a careless eye and mean different things to App Store Connect, so
  /// each key is checked for presence *and* for emptiness.
  ///
  /// **`NSPrivacyAccessedAPITypes` used to be checked here as a third empty array and is now
  /// checked below as an exact declaration.** `D32` put one required-reason API into the app, and
  /// an assertion that the array is empty would have had to be deleted to let it land. Deleting a
  /// fence is how a claim stops being checked; replacing "empty" with "exactly this, and nothing
  /// else" keeps the same instrument pointed at the same file.
  @Test("nothingIsTrackedOrCollected")
  func nothingIsTrackedOrCollected() throws {
    let manifest = try Self.manifest()

    #expect(manifest["NSPrivacyTracking"] as? Bool == false, "The app declares that it tracks.")

    for key in ["NSPrivacyTrackingDomains", "NSPrivacyCollectedDataTypes"] {
      let value = try #require(
        manifest[key] as? [Any],
        "\(key) is missing, which says nothing rather than nothing-collected.")
      #expect(value.isEmpty, "\(key) has \(value.count) entries; the app now declares something it did not.")
    }
  }

  /// `theOneAccessedAPIIsTheShapeStore` — one declaration, named, with its reason code.
  ///
  /// The app reaches for exactly one required-reason API: `UserDefaults`, holding the shape of the
  /// sprint you are in. CA92.1 is Apple's code for an app reading its own defaults for its own use,
  /// which is the whole of what the shape store does.
  ///
  /// Asserted as a **whole array of one** rather than by looking for the entry, because "contains
  /// the declaration we expect" stays green while a second declaration arrives beside it.
  @Test("theOneAccessedAPIIsTheShapeStore")
  func theOneAccessedAPIIsTheShapeStore() throws {
    let manifest = try Self.manifest()
    let declared = try #require(
      manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]],
      "NSPrivacyAccessedAPITypes is missing, which says nothing rather than none.")

    #expect(declared.count == 1, "The app declares \(declared.count) required-reason APIs; it uses one.")
    let entry = try #require(declared.first)
    #expect(entry["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults")
    #expect(entry["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
  }

  /// `theManifestAndTheCodeAgree` — the claim is checked against the tree.
  ///
  /// A manifest that declares one required-reason API is only worth something if exactly that one
  /// is used. The four the manifest is silent about must not appear at all; `UserDefaults` must
  /// appear in the shape store and nowhere else, which `PolishFenceTests.noNewPersistentSurface`
  /// states as a set of filenames and this states as a location.
  ///
  /// Comments are stripped first, because a fence that cannot tell a mention from a use is one
  /// somebody switches off — `AppSettings.swift` still carries a paragraph naming `UserDefaults` to
  /// explain why the settings row is not one.
  @Test("theManifestAndTheCodeAgree")
  func theManifestAndTheCodeAgree() throws {
    for api in ["systemUptime", "\\.creationDate", "\\.modificationDate",
                "volumeAvailableCapacity", "activeInputModes"] {
      #expect(
        try Self.usesInShippedCode(api) == 0,
        """
        \(api) is a required-reason API and the manifest declares only UserDefaults. Either \
        add it to NSPrivacyAccessedAPITypes with its reason code, or stop using it.
        """)
    }
    #expect(
      try Self.usesInShippedCode("UserDefaults", outside: "ShapeStore.swift") == 0,
      "UserDefaults is declared for the shape store. A second user of it is a second store.")
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
  ///
  /// - Parameter exempt: one filename the pattern is permitted to appear in. Named rather than
  ///   counted: an allowance of "one occurrence somewhere" is satisfied by moving the occurrence.
  private static func usesInShippedCode(_ pattern: String, outside exempt: String? = nil) throws -> Int {
    var total = 0
    for directory in ["ZenTomato", "ZenTomatoWatch", "ZenTomatoActivity"] {
      guard let walk = FileManager.default.enumerator(
        at: root.appending(path: directory), includingPropertiesForKeys: nil) else { continue }
      for case let url as URL in walk where url.pathExtension == "swift" {
        guard url.lastPathComponent != exempt else { continue }
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
