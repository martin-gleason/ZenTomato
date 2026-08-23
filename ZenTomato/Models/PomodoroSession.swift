import Foundation
import SwiftData

/// One finished block, written to the database the moment it ends.
///
/// WHY THE ENGINE WRITES THESE AND NOT SOME LATER FEATURE
/// The engine is the only thing that ever knows a block has ended — whether it
/// ran out, was skipped, or was dismissed from the Lock Screen. A history
/// feature that tried to reconstruct that afterwards would be guessing. So the
/// rows are written now, by the only code in a position to be right about
/// them, and a later feature reads them.
///
/// EVERY ROW IS WRITTEN, INCLUDING THE ABANDONED ONES
/// A skipped block still produces a row, marked abandoned. Two reasons. The
/// honest one: a record that quietly omits the blocks you bailed out of is a
/// record that flatters you, and the whole point of keeping one is that the
/// number means what it says. The practical one: "pomodoros today" has to mean
/// blocks *finished*, so the distinction has to be stored rather than inferred
/// from which rows exist.
///
/// FIVE FIELDS AND NOT ONE MORE
/// This model gains columns in later features — the task a block was attached
/// to, the distractions logged during it. It does not gain them now. A field
/// that is always empty looks finished and is not, which is worse than a field
/// that is absent.
@Model
final class PomodoroSession {
  /// The block's identity, carried over from the running timer state so that a
  /// finished row can be matched to the alarm that was set for it.
  var id: UUID

  /// Which kind of block this was. Only finished `work` blocks are pomodoros.
  var kind: BlockKind

  /// When the block began, on the wall clock.
  var startedAt: Date

  /// When it ended. For a block that ran out this is the moment it was due to
  /// end, not the moment the app noticed — the app may well have been closed.
  var endedAt: Date

  /// True when the block did not run to its end: skipped, stopped, or
  /// dismissed early from the Lock Screen. Abandoned blocks are excluded from
  /// every count.
  var wasAbandoned: Bool

  /// Creates a finished-block row. Every value is required: there is no
  /// sensible default for any of them, and a default would only ever hide a
  /// caller that forgot to say.
  init(id: UUID, kind: BlockKind, startedAt: Date, endedAt: Date, wasAbandoned: Bool) {
    self.id = id
    self.kind = kind
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.wasAbandoned = wasAbandoned
  }
}
