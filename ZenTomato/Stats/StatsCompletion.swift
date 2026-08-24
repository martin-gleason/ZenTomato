import Foundation

/// One task this app ticked off, on the day it ticked it off.
///
/// A completion is not a pomodoro and is never counted as one (D11). It is
/// recorded independently, it can happen on a day with no finished blocks at
/// all, and it appears in the document under its own heading.
struct StatsCompletion: Sendable, Equatable {
  /// The day Todoist confirmed the close.
  let day: StatsDay

  /// The title as it read at that moment.
  ///
  /// **The snapshot, never a fresh lookup.** A fortnight-old review shows what
  /// was true then, and a task since deleted in Todoist still appears here —
  /// which is correct, because it was still finished.
  let title: String

  /// Whether Todoist said the task was recurring when it was closed (D21).
  ///
  /// Closing a recurring task in Todoist does not finish it, it advances it to
  /// its next occurrence. Without this, one daily habit lands on eight days of
  /// a fortnight in the same list as *finished Chapter 3*, with nothing to
  /// explain the difference. It is read from Todoist's own answer at the moment
  /// of the close, never guessed from how often a title repeats.
  let wasRecurring: Bool
}
