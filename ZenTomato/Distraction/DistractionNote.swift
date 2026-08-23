import Foundation

/// The one rule about what counts as a written sentence.
///
/// An `enum` with no cases, used purely as a namespace: there is never an
/// instance of this, it only holds the function below.
///
/// WHY THIS IS ONE FUNCTION IN ONE FILE RATHER THAN A LINE IN EACH SHEET
/// Three places decide whether somebody wrote something: the end-of-block
/// sheet, the merged stop sheet, and the engine that writes the answer down.
/// If each trimmed its own text, they would eventually disagree — one would
/// store a space, another would store nothing — and the difference would only
/// show up two weeks later, in the review this app exists to serve, as a
/// distraction that appears to have been annotated with silence.
///
/// THE DISTINCTION IT PROTECTS, WHICH IS THE POINT OF THE WHOLE FEATURE
/// A skipped sentence is stored as *nothing* (`nil`), never as an empty piece
/// of text (`""`). Those two look identical on screen and mean opposite things
/// in the store: nothing means "they were not asked to, or chose not to, and
/// that is a normal outcome"; empty text means "they answered, with silence".
/// Skipping is a first-class outcome in this app, so the store has to be able
/// to say which happened, and this function is where that is decided.
enum DistractionNote {
  /// Turns what somebody typed into what should be stored.
  ///
  /// | Given | Returns |
  /// |---|---|
  /// | `""` | nothing |
  /// | `"   "` | nothing |
  /// | a newline, or tabs and spaces | nothing |
  /// | `"Slack"` | `"Slack"` |
  /// | `"  Slack\n"` | `"Slack"` |
  ///
  /// Whitespace at the ends is removed, because a trailing newline is an
  /// artefact of a text field rather than something a person meant. Whitespace
  /// *inside* the sentence is left exactly as typed: it is theirs.
  ///
  /// `nonisolated` says this may be called from any thread. It can, safely,
  /// because it holds no state and touches nothing outside its own argument —
  /// which is also why it is the only piece of this feature with no test
  /// scaffolding around it at all.
  ///
  /// - Parameter raw: the contents of a text field, exactly as typed.
  /// - Returns: the sentence to store, or `nil` when nothing was written.
  nonisolated static func normalised(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
