import Foundation

/// One block somebody stopped, and the sentence they wrote about why.
///
/// **Stops are excluded from every count and appear in one place only** (D15).
/// `42 pomodoros` keeps meaning blocks you finished; the bail-outs stay fully
/// visible under their own heading with their reasons, rather than being
/// averaged into a rate at the top of the page. A distraction is a moment; a
/// stop is a decision, and a written sentence was charged for each one (D13)
/// precisely so it would be worth reading a fortnight later.
struct StatsStop: Sendable, Equatable {
  // MARK: When

  /// The day the block **began** — the same day rule everything else here uses.
  ///
  /// A block begun at 23:50 and stopped at 00:15 is listed under the day it
  /// began, at the time it was stopped. One rule applied everywhere beats a
  /// second rule that reads slightly better in one rare case.
  let day: StatsDay

  /// The clock time the block was stopped at.
  let time: StatsClockTime

  // MARK: What was stopped

  /// Which kind of block it was.
  ///
  /// Kept because a break can be stopped too, and a section called *where I
  /// bailed* that leaves those out is not answering its own question. A
  /// non-work block has no attachment and is named by its kind instead.
  let blockKind: BlockKind

  /// The task's title as it read when the block began, or nothing.
  let taskTitle: String?

  /// The project's name as it read when the block began, or nothing.
  let projectTitle: String?

  /// What the person wrote when they stopped, or nothing.
  ///
  /// Nothing is possible for rows written before the stop sheet demanded a
  /// sentence, and for a block dismissed from the Lock Screen. The document
  /// says so in place of the quotation rather than printing an empty pair of
  /// quote marks.
  let reason: String?
}
