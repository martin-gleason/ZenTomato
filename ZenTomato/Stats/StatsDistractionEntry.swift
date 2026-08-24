import Foundation

/// One recorded distraction, placed on a day and against a name.
///
/// A finished value: no database row, no identifier, nothing that could be
/// looked up again. Whoever draws it — the screen or the exported document —
/// has everything it needs and nothing it could count a second time.
///
/// **The day and the time come from two different places, and that is the
/// counting rule rather than an oversight.** The day is the day the *block* it
/// was tapped in began; the time is the moment of the tap itself. A tap at
/// 00:05, inside a block that began at 23:50, therefore reads as `Wed 19 Aug,
/// 00:05` — because `F6.md` says a distraction belongs to the work block it was
/// tapped in, and a block belongs entirely to the day it started.
struct StatsDistractionEntry: Sendable, Equatable {
  // MARK: When

  /// The day this belongs to: the day its block began.
  let day: StatsDay

  /// The clock time of the tap itself.
  let time: StatsClockTime

  // MARK: What

  /// Internal or external — the spec's I and E, in the vocabulary
  /// `DistractionTally` already uses.
  let kind: DistractionKind

  /// The sentence the person wrote, or nothing if they skipped it.
  ///
  /// **Nothing is a real answer, not missing data.** The tap is the record; the
  /// sentence is colour. The document says so out loud rather than leaving a
  /// blank line, because a blank line reads as a bug and this line has to agree
  /// with a number in a table two sections above it.
  let note: String?

  // MARK: Against what

  /// The task's title as it read when the block began, or nothing.
  let taskTitle: String?

  /// The project's name as it read when the block began, or nothing.
  let projectTitle: String?
}
