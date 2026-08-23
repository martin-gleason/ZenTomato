import Foundation
import Security

/// The Todoist token, kept in the iPhone's Keychain.
///
/// WHAT THE KEYCHAIN IS, FOR A READER WHO DOES NOT WRITE SWIFT
/// It is the part of iOS built for secrets: encrypted by the operating system,
/// tied to the device's own hardware, and not readable by any other app. It is
/// where a password belongs. The app's ordinary database, by contrast, is a
/// plain file — fine for a timer, wrong for a credential.
///
/// THE TWO DECISIONS THIS FILE IS JUDGED ON
///
///   1. **The item is locked to this iPhone and readable only while it is
///      unlocked.** That is the single line in `add(_:)` below that sets the
///      accessibility attribute, and it is the whole of the difference between
///      "this token lives on this phone" and "this token is copied to iCloud
///      and appears on every device signed into the same account". iOS's own
///      default is the second one, and — this is the dangerous part — storing
///      the item succeeds either way. Nothing fails, nothing warns. So a test
///      reads the attribute back off the stored item and asserts what it is.
///
///   2. **Nothing here writes a token out.** No console line, no logging call
///      of any kind, and no error case carrying the value. A secret scanner
///      catches a credential committed to the repository; it cannot catch one
///      written to a console.
///
/// `Sendable` marks it safe to use from any thread: it holds nothing mutable,
/// and the Keychain is itself thread-safe.
struct KeychainTokenStore: TokenStore {
  // MARK: What went wrong

  /// The ways the Keychain can refuse.
  ///
  /// **None of these carries the token**, and `unexpectedStatus` carries only
  /// Apple's numeric code — which is a number about the Keychain, never a piece
  /// of the value stored in it.
  enum Failure: Error, Equatable {
    /// The Keychain refused, with its own status code.
    case unexpectedStatus(OSStatus)

    /// Something was stored under this name, but it was not text this app
    /// wrote. Treated as a failure rather than as "no token", because silently
    /// reporting nothing would send the person round the sign-in loop forever.
    case unreadableValue

    /// The token was empty, or was nothing but whitespace. Refused before it is
    /// stored: an empty credential can only produce a rejection later, on a
    /// screen that cannot explain it.
    case emptyToken
  }

  // MARK: Where the item lives

  /// The name this app files the item under. It is the app's own bundle
  /// identifier with a suffix, so it cannot collide with anything else on the
  /// phone.
  static let service = "com.martingleason.ZenTomato.todoist"

  /// There is one account and therefore one item. This name is a constant, not
  /// a parameter: a store that took a name is a store somebody would put a
  /// second secret in.
  static let account = "apiToken"

  // MARK: Reading

  func read() throws -> String? {
    var query = Self.itemQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    switch status {
    case errSecSuccess:
      // A conditional cast, never a forced one: if what came back is not the
      // data this app wrote, that is a fact to report rather than a crash.
      guard let data = item as? Data, let token = String(data: data, encoding: .utf8) else {
        throw Failure.unreadableValue
      }
      return token
    case errSecItemNotFound:
      // Nobody has connected an account. Not a failure.
      return nil
    default:
      throw Failure.unexpectedStatus(status)
    }
  }

  // MARK: Writing

  func write(_ token: String) throws {
    let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw Failure.emptyToken }
    guard let data = trimmed.data(using: .utf8) else { throw Failure.unreadableValue }

    // DELETE, THEN ADD — and not "update if present".
    //
    // Adding an item that already exists fails with a duplicate error, so a
    // second sign-in would be refused for a reason that looks like nothing to
    // do with signing in. Removing first makes replacing a token the same
    // operation as storing the first one, which is one code path instead of
    // two, and the one that is always exercised.
    try clear()

    var attributes = Self.itemQuery
    attributes[kSecValueData as String] = data
    // THE LINE THIS FILE EXISTS FOR. Locked to this device, readable only while
    // the phone is unlocked, never copied to iCloud. Removing it does not break
    // anything visible — which is exactly why a test checks it.
    attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

    let status = SecItemAdd(attributes as CFDictionary, nil)
    guard status == errSecSuccess else { throw Failure.unexpectedStatus(status) }
  }

  // MARK: Removing

  func clear() throws {
    let status = SecItemDelete(Self.itemQuery as CFDictionary)
    // Deleting something that is not there is the outcome the caller wanted.
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw Failure.unexpectedStatus(status)
    }
  }

  // MARK: The one item

  /// The three attributes that name this app's single Keychain item. Every
  /// operation starts from this, so a read, a write and a delete cannot drift
  /// apart and address different items.
  private static var itemQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
  }
}
