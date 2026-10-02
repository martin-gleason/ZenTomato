/// What the garden draws, worked out from one number: **finished poms, ever** (`F16-T2`, `D48`).
///
/// **What this is, for a reader who does not write Swift.** It is a small calculator. It is handed a
/// single whole number — how many pomodoros have ever been finished — and it answers *how many of
/// what to draw*. It is not handed dates, days, a calendar or the database, and it keeps nothing. So
/// it cannot know whether those poms happened yesterday or last spring, or whether there was a gap
/// between them, and nothing it returns can say so. That blindness is the feature: `D48` licenses a
/// garden that only ever accumulates, and a calculator that cannot see time cannot count a run of days.
/// `GardenFenceTests` holds the line in code, not in this comment.
///
/// **Rows, and why.** A year of work is about a thousand poms, and a thousand tomatoes is a wall
/// rather than a picture. So the garden is drawn in rows, and each row stands for more poms per item
/// than the one before it: the first row's items are one pom each, the second row's four, then
/// sixteen, sixty-four, two hundred and fifty-six. A row holds at most 24 items; once it is full the
/// next poms start the next row, and the full row stays exactly as it was.
///
/// **Every number this returns only ever rises.** Not one row's count goes down when another pom is
/// finished — a full row is never emptied to make room — so there is no step at which the picture
/// gets smaller. `theGardenNeverShrinks` checks that over every count from 0 to 5,000.
///
/// **No names, no announcement, nothing that says what is next** (`Q2`, ruled 2026-09-24). The rows are
/// not tiers anyone has earned and nothing draws the empty space a row has left; a person notices
/// growth, the garden does not tell them about it.
struct Garden: Equatable, Sendable {
  // MARK: Lifecycle

  /// The garden for a number of finished poms. A negative number is treated as none.
  init(finishedPoms: Int) {
    var remaining = max(finishedPoms, 0)
    var rows: [Int] = []
    for (index, poms) in Self.pomsPerItem.enumerated() {
      let fits = remaining / poms
      // The last row has no limit, so poms beyond what the earlier rows hold are never lost.
      let drawn = index == Self.pomsPerItem.count - 1 ? fits : min(fits, Self.itemsPerRow)
      rows.append(drawn)
      remaining -= drawn * poms
    }
    self.rows = rows
  }

  // MARK: Internal

  /// How many poms one item stands for, row by row, first row first.
  static let pomsPerItem = [1, 4, 16, 64, 256]

  /// The most items a row holds, except the last, which holds as many as it needs.
  static let itemsPerRow = 24

  /// How many items each row draws, first row first. Always one entry per row, empty rows included.
  let rows: [Int]

  /// Every item the garden draws, across all rows.
  var itemCount: Int {
    rows.reduce(0, +)
  }
}
