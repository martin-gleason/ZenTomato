import Foundation

/// What the token screen holds while somebody is pasting a credential, and the
/// one command it can run.
///
/// WHY THE SCREEN IS SPLIT FROM ITS STATE
/// The same reason the timer screen is: every state of the token screen — the
/// empty field, the refused token, the connection that could not be made, the
/// screen a revoked credential lands you on — can then be looked at in a
/// preview without a Keychain, a network or an account.
///
/// TWO RULES THIS TYPE EXISTS TO KEEP
///
/// 1. **The token is never echoed anywhere except the field it was typed in.**
///    Not in a message, not in an error, not in a log line, not in a comment,
///    not in a spoken announcement. Every sentence below is written by hand for
///    that reason: passing a system error's own description through to the
///    screen is the commonest way a failing request's URL — and with it a
///    credential — reaches a place somebody can read it.
///
/// 2. **Nothing about the shape of a token is checked locally.** No length, no
///    prefix, no character set. Todoist is the only judge of a token, and a
///    local rule would reject a valid one the day the format changes — on the
///    one screen with no way around it. The only local check is that something
///    is there after the whitespace has been trimmed off.
@MainActor
@Observable
final class SignInScreenModel {
  // MARK: Lifecycle

  /// - Parameters:
  ///   - tokens: where a credential is kept. The Keychain in the app; a plain
  ///     in-memory box in a test. **Optional so that this screen can be looked
  ///     at in a preview with nothing behind it**, which is the same
  ///     arrangement `SettingsView` already uses for the timer engine. A model
  ///     with no connection can be read and cannot connect.
  ///   - cache: the local mirror of Todoist. Filling it is also how a token is
  ///     checked — see `connect()`.
  ///   - banner: why this screen is being shown, when it is being shown because
  ///     something happened rather than because nobody has connected yet.
  ///   - failure: a wording to start with, for the previews and tests that need
  ///     to look at a refusal without provoking one.
  init(
    tokens: (any TokenStore)? = nil,
    cache: TodoistCacheStore? = nil,
    banner: Banner? = nil,
    showing failure: TodoistError? = nil) {
    self.tokens = tokens
    self.cache = cache
    self.banner = banner
    errorMessage = failure.map { Self.message(for: $0) }
  }

  // MARK: Nested types

  /// Why the token screen appeared, when it did not simply appear because there
  /// is no token yet.
  enum Banner: Equatable, Sendable {
    /// A stored token stopped being accepted. It was revoked or regenerated in
    /// Todoist, and the old one stops working the moment that happens.
    case revoked

    /// The token went away while the picker was open.
    case disconnected

    /// Amber, and above the heading. **Passive voice, deliberately** — "you
    /// revoked your token" is an accusation and may not even be true: a shared
    /// account, a password reset, somebody else's administrator.
    var message: String {
      switch self {
      case .revoked:
        """
        Todoist no longer accepts your token. It was revoked or regenerated in \
        your Todoist account, and the old one stops working the moment that \
        happens.
        """
      case .disconnected:
        "You're not connected to Todoist any more. Paste a token below to pick up where you were."
      }
    }

    /// The quiet line directly under the amber row. It answers the question the
    /// amber row raises — *what happened to my work?* — before it is asked.
    var note: String? {
      switch self {
      case .revoked:
        """
        Get a fresh one and paste it below. Your plan and everything ZenTomato \
        has recorded are untouched.
        """
      case .disconnected:
        nil
      }
    }
  }

  // MARK: Internal

  /// What is in the field. Bound straight to it.
  var token = ""

  /// Whether the field is showing what was pasted rather than dots.
  ///
  /// The reveal is not a nicety. A token that arrived truncated, or with a
  /// character missing off one end, is the commonest first-run failure — and
  /// somebody has to be able to look at what they pasted before they blame
  /// themselves.
  var isRevealed = false

  /// Why this screen appeared, or `nil` when nobody has connected yet.
  ///
  /// **Cleared the moment a fresh attempt begins**, and that is not tidiness.
  /// This screen's rule — written on the screen itself — is that amber marks
  /// exactly one thing. The banner is amber and so is a refusal, so a revoked
  /// token followed by one fumbled paste would otherwise put two warning
  /// triangles on one screen, which is the state that makes the signal stop
  /// meaning anything. The refusal replaces the banner rather than stacking
  /// under it: it is the more recent, more specific thing.
  private(set) var banner: Banner?

  /// Whether a check is in flight. The button says "Connecting…" and is
  /// switched off while it is.
  private(set) var isConnecting = false

  /// What Todoist said, in the reader's language rather than the protocol's.
  /// Shown as the one amber row on this screen.
  private(set) var errorMessage: String?

  /// Whether the button is live.
  ///
  /// Whitespace is not a token. A space bar tapped once would otherwise unlock
  /// the button and send a credential of one space, which fails in a way that
  /// looks like Todoist's fault.
  var canConnect: Bool {
    isConnecting == false && token.trimmedCredential.isEmpty == false
  }

  /// Takes what the paste button handed over.
  ///
  /// Trimmed on arrival, and revealed, so the first thing that happens after a
  /// paste is that you can see what landed.
  func paste(_ strings: [String]) {
    guard let pasted = strings.first else { return }
    let trimmed = pasted.trimmedCredential
    token = trimmed
    isRevealed = true
  }

  /// Checks the token with Todoist and, if it is accepted, keeps it.
  ///
  /// THE ORDER, AND WHY IT IS THIS WAY ROUND
  /// The credential has to be stored before it can be used, because the request
  /// builder reads it from the store — there is deliberately no second path
  /// that takes a token as an argument, since a second path is a second place a
  /// credential could be logged. So it is written, tried, and removed again if
  /// it was refused. The screen's copy says "Nothing has been saved" and this is
  /// what makes that true.
  ///
  /// **WHAT WAS THERE BEFORE IS READ FIRST, AND PUT BACK.** This screen is
  /// reachable from Settings while a perfectly good token is already stored. A
  /// stale paste — or simply tapping Connect on a train — would otherwise
  /// overwrite the working credential, fail, and clear it: signed out, with no
  /// dialog, by an action whose own message says "Nothing has been saved". That
  /// sentence is true about the new token and was false about the old one, and
  /// the old one is the one the person was relying on. So the previous value is
  /// taken before the overwrite and restored on any refusal; only a store that
  /// held nothing is left holding nothing.
  ///
  /// **The check is an ordinary read.** Filling the local mirror is the first
  /// thing a connected app does anyway, so a token is proved by doing the work
  /// rather than by a request that exists only to ask "am I allowed?".
  ///
  /// - Returns: `true` when the token was accepted and stored.
  func connect() async -> Bool {
    let credential = token.trimmedCredential
    guard let tokens, let cache else { return false }
    guard credential.isEmpty == false, isConnecting == false else { return false }

    isConnecting = true
    errorMessage = nil
    // One amber thing at a time: the attempt about to be made owns the row.
    banner = nil
    defer { isConnecting = false }

    // Read before it is overwritten. A Keychain that will not answer is treated
    // as one holding nothing, which is the same conclusion every other reader of
    // it in this app draws.
    let previous = try? tokens.read()

    do {
      try tokens.write(credential)
      try await cache.refresh()
      // Cleared the instant it is no longer needed, so a credential does not
      // survive in a screen's state — including inside a preview snapshot.
      token = ""
      isRevealed = false
      return true
    } catch {
      restore(previous, in: tokens)
      errorMessage = Self.message(for: error)
      return false
    }
  }

  // MARK: Private

  private let tokens: (any TokenStore)?
  private let cache: TodoistCacheStore?

  /// The token screen's own wording, by cause.
  ///
  /// Each is at most two sentences, and the second is the action. No status
  /// code, no "unauthorized", no framework name, and above all not one
  /// character of the credential — the `401` line names the *symptom* and never
  /// echoes what was typed.
  private static func message(for error: any Error) -> String {
    guard let todoist = error as? TodoistError else { return anythingElse }
    switch todoist {
    case .tokenRejected:
      return """
        Todoist didn't accept that token. Check you copied the whole string — \
        the first or last character is the one that usually goes missing.
        """
    case .offline:
      return """
        Couldn't reach Todoist to check the token. Nothing has been saved. Try \
        again when you're back on a connection.
        """
    case .rateLimited:
      return "Todoist asked us to slow down. Try again in a moment — the token is still in the field."
    case .notSignedIn, .server, .malformedResponse, .paginationDidNotTerminate:
      return anythingElse
    }
  }

  private static let anythingElse =
    "Todoist couldn't answer just now. Nothing has been saved. Try again in a moment."

  /// Puts the store back the way it was before a refused attempt.
  ///
  /// If something was there, it goes back — the attempt that just failed said
  /// nothing about it, and in the offline case it definitely said nothing about
  /// it. If nothing was there, the refused credential is removed, which is what
  /// makes the screen's "Nothing has been saved" true.
  ///
  /// **This cannot put a revoked credential back.** The only way somebody
  /// reaches this screen because their stored token stopped working is a refusal
  /// that has already taken it out of the Keychain — the client does that the
  /// moment Todoist says no. So a stored value still being here means nothing
  /// has refused it, and restoring it is returning to the last state known to
  /// work rather than reinstating a dead one.
  ///
  /// A Keychain that refuses either operation is not reported: there is nothing
  /// the reader could do about it, and the message already on screen is the true
  /// and useful one. Saying so here is cheaper than a sentence nobody can act on.
  private func restore(_ previous: String?, in tokens: any TokenStore) {
    do {
      if let previous, previous.isEmpty == false {
        try tokens.write(previous)
      } else {
        try tokens.clear()
      }
    } catch {
      return
    }
  }
}

// MARK: - Trimming

extension String {
  /// A pasted credential with its whitespace and newlines taken off.
  ///
  /// People paste with a trailing newline, and a token with one on the end is
  /// rejected by Todoist in a way that looks exactly like a wrong token. This
  /// runs before the field is judged empty, before the credential is sent and
  /// before it is stored, so all three agree about what the token is.
  ///
  /// **Nothing on screen announces the trim.** It is a correction to a paste,
  /// not a change to what somebody meant.
  var trimmedCredential: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
