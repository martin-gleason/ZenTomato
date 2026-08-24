import Foundation

/// A time of day, as two plain whole numbers.
///
/// The same idea as `StatsDay` and for the same reason: the question *"what
/// does this instant read as on a clock?"* is asked once, here, while a
/// calendar is still in the room, and the answer is two integers from then on.
///
/// **This is what makes `14:32` mean `14:32` on every phone.** A date formatter
/// asked for `HH:mm` quietly returns `2:32 PM` on a phone set to a twelve-hour
/// clock, unless its locale is pinned — a real and frequently-shipped bug. The
/// export has no formatter to get that wrong: it prints two numbers with a
/// colon between them.
///
/// Seconds are not kept. Nothing in the document shows them, and a value nobody
/// renders is a value that can only ever disagree with one that is rendered.
struct StatsClockTime: Sendable, Hashable, Comparable {
  // MARK: What a time is

  /// The hour on a 24-hour clock, 0 through 23.
  let hour: Int

  /// The minute, 0 through 59.
  let minute: Int

  // MARK: Building one

  // Building one from its two parts uses the initialiser Swift writes for a
  // struct on its own — `StatsClockTime(hour: 14, minute: 32)` — which is what
  // test fixtures use. Only the reading below needs code of its own.

  /// What a clock in this calendar's time zone reads at that instant.
  static func at(_ instant: Date, in calendar: Calendar) -> StatsClockTime {
    StatsClockTime(
      hour: calendar.component(.hour, from: instant),
      minute: calendar.component(.minute, from: instant))
  }

  // MARK: Order

  /// Earlier in the day sorts first.
  ///
  /// Useful for a single day. It is **not** how taps are ordered: a tap at
  /// 00:05 can belong to the day before, so the arrays this feature builds are
  /// ordered by the real instant and must not be re-sorted by clock time. See
  /// `StatsDayRow.distractions`.
  static func < (lhs: StatsClockTime, rhs: StatsClockTime) -> Bool {
    (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
  }
}
