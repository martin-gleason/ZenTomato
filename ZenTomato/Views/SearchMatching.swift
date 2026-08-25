import Foundation

/// How this app decides that typed text matches a name — **in one place, because
/// there are now two pickers doing it.**
///
/// The Todoist picker has searched this way since F3, in a `private extension`
/// inside `PickerScreenModel.swift`. F4e gives the music picker a search field
/// too, and the obvious move was to write the same three lines again.
///
/// **That is exactly the mistake F4c was opened to stop.** Two copies of the same
/// rule pass every test on the day they are written and drift on the third edit:
/// somebody adds a `.widthInsensitive` here and not there, and now a playlist
/// with an accent in it is findable and a task with the same accent is not — a
/// difference nobody can see in a diff and everybody feels on the device.
///
/// So the semantics live here and both pickers call them.
extension String {
  /// Trimmed of the whitespace and newlines a paste tends to arrive with.
  var trimmedQuery: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// A search that ignores capitals and accents.
  ///
  /// **Matches anywhere in the name, not just at the start.** People remember a
  /// word from the middle of *"Late Night Piano · Studio"* far more reliably than
  /// they remember how it begins.
  ///
  /// The parameter exists so the call site says what it is asking for. Written
  /// out rather than reached for inline, because the option set is the sort of
  /// thing that gets quietly dropped in a tidy-up and nobody notices until
  /// somebody's playlist with an accent in it stops being findable.
  func contains(_ other: String, caseAndAccentInsensitively: Bool) -> Bool {
    guard caseAndAccentInsensitively else { return contains(other) }
    return range(of: other, options: [.caseInsensitive, .diacriticInsensitive]) != nil
  }
}
