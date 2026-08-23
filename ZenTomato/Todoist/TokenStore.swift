import Foundation

/// Where the Todoist token is kept, as something that can be replaced in a test.
///
/// Three operations and no more: read the one token, put one there, remove it.
/// There is exactly one token, for one account, so nothing here takes a name or
/// a key — a store with a key is a store somebody will put a second thing in.
///
/// WHY A TEST NEEDS A STAND-IN FOR THIS
/// The real implementation writes to the iPhone's Keychain, which is shared
/// system-wide storage that outlives the app. A test suite that wrote to it
/// would leave rubbish behind on the machine it ran on, and would be at the
/// mercy of whatever an earlier run left. So every test but one uses an
/// in-memory stand-in, and the one exception writes a value that is obviously
/// not a credential and removes it again on the way out.
///
/// `Sendable` marks it safe to use from any thread. The Keychain is itself
/// thread-safe, and nothing on this side of the app touches the database.
protocol TokenStore: Sendable {
  /// The stored token, or `nil` when nobody has connected an account.
  ///
  /// - Throws: if the store cannot be read at all — a real failure, and
  ///   deliberately different from "there is nothing there".
  func read() throws -> String?

  /// Stores a token, replacing whatever was there.
  ///
  /// - Parameter token: the token as the person pasted it. Implementations trim
  ///   surrounding whitespace, because a token copied from a web page very often
  ///   arrives with a newline on the end and would otherwise be rejected by
  ///   Todoist for a reason nobody could see.
  /// - Throws: if the token is empty once trimmed, or if the store refuses.
  func write(_ token: String) throws

  /// Removes the token. Doing this when there is nothing there is not an error.
  ///
  /// - Throws: if the store refuses.
  func clear() throws
}
