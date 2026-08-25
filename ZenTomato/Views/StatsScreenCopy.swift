import Foundation

/// Every sentence the history screen says, in one place.
///
/// **Split from `StatsScreenModel` when that file outgrew the 400-line limit — a seam rather
/// than a raised limit.** It is a real one: what the screen *computes* and what it *says* are
/// different concerns, and the words are the half the owner reviews. An extension rather than
/// a new type, so every call site reads exactly as it did.
///
/// The rule these all follow, and the reason several of them are long: **a statement of fact,
/// never a verdict.** Somebody who installed the app this morning reads the same words as
/// somebody with four hundred pomodoros behind them, and both have to find them true and
/// unembarrassing.
extension StatsScreenModel {
  /// **A statement of fact, never a verdict.** Somebody who installed the app
  /// this morning sees this, and so does somebody with four hundred pomodoros
  /// who picked last February. It has to be true and unembarrassing for both, so
  /// it says what *will* be here and where to look for what is not — and never
  /// says "you have nothing". No exclamation marks, no encouragement, no
  /// illustration, and no button that starts a timer: the timer is one swipe
  /// away and this screen does not nag.
  static func emptyHeading(for range: StatsRange) -> String {
    range.isSingleDay ? "Nothing on \(StatsWords.date(range.first))" : "Nothing in these days"
  }

  static let emptyDetail = """
    Finished pomodoros are counted here — today's first, then by day, project and task.
    """

  /// The load-bearing line: it answers the question this state provokes — *"I
  /// did a block this morning, why is it not here?"* — before the reader
  /// concludes the app is broken.
  static let emptyOrigin = """
    The count starts when your first block ends. A block you stop early isn't counted, and it's \
    kept separately in the export. Widen the range above to look further back.
    """

  /// What the screen says when the database would not answer. **"Nothing on Fri
  /// 21 Aug" is a claim about the reader's day; this is a claim about the app**,
  /// and drawing the first when the second is true was the one place in F6 where
  /// this app stated something false. See `UnreadableRangeTests`.
  static let unreadableHeading = "Couldn't read your history"

  static let unreadableDetail = """
    Nothing is missing — this screen just couldn't reach the database. Your pomodoros, taps \
    and completions are all still recorded. Close the screen and open it again.
    """

  static let exportHint = "Opens the share sheet with a Markdown file."
  static let rangeHint = "Which days the lists below and the export cover."
  static let openDayHint = "Shows what interrupted this day."
  static let todaySpokenLabel = "Pomodoros today"

  /// What the write of the temporary file says when it fails. One plain
  /// sentence, and the control goes with it: sharing a stale file is worse than
  /// sharing none, and a share button that does nothing gets tapped four times
  /// before somebody gives up.
  static let exportUnavailable = "The export couldn't be prepared. Your history is fine."
}
