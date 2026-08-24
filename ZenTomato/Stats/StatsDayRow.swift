import Foundation

/// One day: what was finished on it, and what interrupted it.
///
/// A day appears at all only when something was recorded on it — a finished
/// pomodoro, a tap, a stop, or a task ticked off. Fourteen rows of zeroes in a
/// fortnight are padding, and a gap in the dates says the same thing more
/// honestly.
struct StatsDayRow: Sendable, Equatable {
  // MARK: Which day

  /// The day itself.
  let day: StatsDay

  // MARK: What was counted

  /// Focus blocks finished on this day. Stopped blocks count for nothing and
  /// breaks are not pomodoros, so this can be zero on a day with plenty of
  /// evidence on it.
  let pomodoroCount: Int

  /// The seconds those blocks actually ran for, summed.
  let focusedSeconds: Int

  /// Every tap that belongs to this day, **oldest first by the real instant of
  /// the tap**.
  ///
  /// **Do not re-sort this by clock time.** A tap at 00:05 inside a block that
  /// began at 23:50 belongs to the day the block began, and re-sorting on the
  /// printed time would move it to the top of the day it was tapped at the end
  /// of. The order this array arrives in is the order things happened in, and
  /// it is the order to draw.
  let distractions: [StatsDistractionEntry]

  /// Internal taps on this day.
  var internalCount: Int {
    distractions.count(where: { $0.kind == .internalInterruption })
  }

  /// External taps on this day.
  var externalCount: Int {
    distractions.count(where: { $0.kind == .externalInterruption })
  }

  /// Every tap on this day, of either kind.
  var distractionCount: Int { distractions.count }

  /// The kinds of every tap on this day, in order — exactly what
  /// `DistractionTally.summary(of:)` takes.
  ///
  /// Here so that the screen and the exported page both speak the vocabulary of
  /// the owner's own file rather than inventing a second one for the same fact.
  var distractionKinds: [DistractionKind] { distractions.map(\.kind) }
}
