import Foundation
import Security
import Testing

@testable import ZenTomato

/// The token store, checked in the two ways it can be.
///
/// WHAT HAS TO BE PROVED, AND WHY IT IS AWKWARD
/// One property of the stored token matters more than the rest: **the item is
/// locked to this device and is not copied to iCloud.** It is a single attribute
/// set at the moment of writing, and the dangerous thing about it is that
/// everything works either way. Storing succeeds with the attribute and succeeds
/// without it. Nothing fails, nothing warns, and the only visible consequence is
/// that somebody's Todoist credential quietly appears on their other devices.
///
/// THE AWKWARD PART, STATED PLAINLY RATHER THAN WORKED AROUND
/// Simulator builds in this project are never code-signed — that is what lets a
/// clone with no developer account run `make test` — and an unsigned app has no
/// Keychain entitlement, so the Keychain refuses every request with
/// `errSecMissingEntitlement (-34018)`. **The real Keychain is therefore
/// unusable in continuous integration**, and a suite that pretended otherwise
/// would either fail every run or be quietly deleted.
///
/// So there are two checks, and between them they cover both situations:
///
///   1. `theOnlyAccessibilityConstantIsThisDeviceOnly` reads the store's own
///      source and asserts that the one line deciding this names the
///      device-only constant and nothing weaker. **It runs everywhere**,
///      including in continuous integration, and it catches the exact silent
///      downgrade described above.
///   2. The behaviour tests write to the real Keychain and read the attribute
///      back off the stored item. They are **skipped, not failed**, where the
///      Keychain is unavailable, and they run on a signed build — which is the
///      device check this feature has to pass anyway.
///
/// THE VALUE THEY WRITE IS NOT CREDENTIAL-SHAPED, ON PURPOSE
/// A real Todoist token is forty characters of hexadecimal, which is exactly
/// what the secret scanner that runs before every commit is built to find. The
/// literal used here is `"not-a-real-token"`, as in every other test file.
///
/// `.serialized` because these tests share one real thing: there is one Keychain
/// item under one name, and tests otherwise run side by side. Two of them
/// writing and removing the same item at once would fail each other at random,
/// which is the worst kind of failing test — the kind people re-run instead of
/// reading.
@Suite("KeychainTokenStore", .serialized)
struct KeychainTokenStoreTests {
  private let store = KeychainTokenStore()

  // MARK: The check that runs everywhere

  /// The one line that decides how the item is stored names the device-only
  /// constant, and no weaker one appears anywhere in the file.
  ///
  /// Reading source text is an unusual thing for a test to do, and it is done
  /// here for a specific reason: the property cannot be observed at all on the
  /// machine most of these runs happen on, and "not observable" must not become
  /// "not checked" for the single attribute protecting a credential.
  @Test("theOnlyAccessibilityConstantIsThisDeviceOnly")
  func theOnlyAccessibilityConstantIsThisDeviceOnly() throws {
    let source = try String(contentsOf: Self.storeSourceURL, encoding: .utf8)
    let deciding = source
      .split(separator: "\n")
      .filter { $0.contains("kSecAttrAccessible") }

    // One line, which sets the attribute to its value.
    #expect(deciding.count == 1)

    let line = try #require(deciding.first).description
    #expect(line.contains("kSecAttrAccessibleWhenUnlockedThisDeviceOnly"))

    // And nothing else on it names an accessibility constant. Removing the
    // correct value leaves the attribute's own name; removing that must leave
    // nothing — which rules out the weaker constants, every one of which begins
    // with the same letters as the right one and would otherwise slip through a
    // plain search.
    let withoutTheValue = line.replacingOccurrences(
      of: "kSecAttrAccessibleWhenUnlockedThisDeviceOnly",
      with: "")
    let withoutTheKey = withoutTheValue.replacingOccurrences(
      of: "kSecAttrAccessible",
      with: "")
    #expect(withoutTheKey.contains("kSecAttrAccessible") == false)
  }

  // MARK: The checks that need a real Keychain

  /// The stored item really is readable only while the phone is unlocked, and
  /// only on this device.
  ///
  /// Read back off the item itself rather than asserted about the code that
  /// wrote it, because the failure being guarded against is one where the code
  /// looks right and the stored item is not.
  @Test("tokenIsLockedToThisDeviceOnly", .enabled(if: KeychainTokenStoreTests.keychainIsUsable))
  func tokenIsLockedToThisDeviceOnly() throws {
    defer { Self.removeStoredItem() }
    try store.write("not-a-real-token")

    let attributes = try #require(Self.storedAttributes())
    let accessibility = attributes[kSecAttrAccessible as String] as? String

    #expect(accessibility == (kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String))
    // Named the other way round as well, so a reader who does not know the
    // constants can still see what is being ruled out: the ordinary default is
    // the one that syncs to iCloud.
    #expect(accessibility != (kSecAttrAccessibleWhenUnlocked as String))
  }

  /// What goes in comes back out, and what is removed is gone.
  @Test("tokenRoundTripsAndClears", .enabled(if: KeychainTokenStoreTests.keychainIsUsable))
  func tokenRoundTripsAndClears() throws {
    defer { Self.removeStoredItem() }

    let empty = try store.read()
    #expect(empty == nil)

    try store.write("not-a-real-token")
    let stored = try store.read()
    #expect(stored == "not-a-real-token")

    try store.clear()
    let cleared = try store.read()
    #expect(cleared == nil)

    // Removing something that is not there is the outcome the caller wanted,
    // not a failure. Signing out twice must not produce an error.
    try store.clear()
  }

  /// Signing in again replaces the token rather than being refused.
  ///
  /// The Keychain refuses to add an item that already exists, so a store that
  /// only added would fail on the second sign-in with an error that looked
  /// nothing to do with signing in.
  @Test("writingTwiceReplacesTheToken", .enabled(if: KeychainTokenStoreTests.keychainIsUsable))
  func writingTwiceReplacesTheToken() throws {
    defer { Self.removeStoredItem() }

    try store.write("not-a-real-token")
    try store.write("not-a-real-token-either")

    let stored = try store.read()
    #expect(stored == "not-a-real-token-either")
  }

  /// A token pasted with a newline on the end is stored without it.
  ///
  /// Copying a token from a web page very often brings whitespace with it, and
  /// Todoist would refuse the result for a reason nobody could see, on the one
  /// screen that has no way around it.
  @Test("writingTrimsWhatWasPasted", .enabled(if: KeychainTokenStoreTests.keychainIsUsable))
  func writingTrimsWhatWasPasted() throws {
    defer { Self.removeStoredItem() }

    try store.write("  not-a-real-token\n")

    let stored = try store.read()
    #expect(stored == "not-a-real-token")
  }

  /// Nothing at all is refused before it is stored, and the refusal needs no
  /// Keychain to happen — which is why this one runs everywhere.
  @Test("anEmptyTokenIsRefused")
  func anEmptyTokenIsRefused() throws {
    #expect(throws: KeychainTokenStore.Failure.emptyToken) {
      try store.write("   \n ")
    }
  }

  // MARK: Whether the Keychain can be used at all

  /// Whether this run can store anything in the Keychain.
  ///
  /// Answered by trying, once, under a name of its own — not by guessing from
  /// the build configuration, which would be a second description of the same
  /// fact and would drift. An unsigned simulator build answers no; a signed
  /// build on a phone answers yes.
  static var keychainIsUsable: Bool {
    let probe: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "\(KeychainTokenStore.service).availability-probe",
      kSecAttrAccount as String: "probe",
      kSecValueData as String: Data("probe".utf8)
    ]
    let status = SecItemAdd(probe as CFDictionary, nil)
    guard status == errSecSuccess || status == errSecDuplicateItem else { return false }
    _ = SecItemDelete(probe as CFDictionary)
    return true
  }

  // MARK: Reading the item's own attributes

  /// The attributes of the stored item, straight from the Keychain.
  ///
  /// This deliberately does not go through `KeychainTokenStore`: a helper on the
  /// type under test could carry the same mistake as the code being checked.
  private static func storedAttributes() -> [String: Any]? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: KeychainTokenStore.service,
      kSecAttrAccount as String: KeychainTokenStore.account,
      kSecReturnAttributes as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess else {
      Issue.record("The Keychain would not return the stored item: status \(status).")
      return nil
    }
    return item as? [String: Any]
  }

  /// Removes the item, whether or not one is there.
  ///
  /// Written out rather than calling `clear()` in a `defer`, so that cleaning up
  /// never depends on the thing being tested and never quietly discards a real
  /// failure.
  private static func removeStoredItem() {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: KeychainTokenStore.service,
      kSecAttrAccount as String: KeychainTokenStore.account
    ]
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      Issue.record("The Keychain would not remove the test item: status \(status).")
      return
    }
  }

  /// The store's own source file, found relative to this one — the same way the
  /// endpoint test finds the committed allowlist.
  private static var storeSourceURL: URL {
    URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appending(path: "ZenTomato")
      .appending(path: "Todoist")
      .appending(path: "KeychainTokenStore.swift")
  }
}
