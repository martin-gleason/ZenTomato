import Foundation

/// The span of days a count covers: a first day and a last day, both included.
///
/// **Both ends are inclusive**, because that is how a person says it. "The last
/// fourteen days" ending on Friday 21 August means Saturday 8 August *through*
/// Friday 21 August, and both of those days are counted. The half-open
/// arithmetic a database query needs is done in one place — `bounds(in:)` —
/// rather than being something every caller has to remember.
///
/// It carries no `Date`. A range is two calendar days, and the moment either
/// end became an instant it would start depending on a time zone that the
/// document it titles does not carry.
struct StatsRange: Sendable, Hashable {
  // MARK: What a range is

  /// The first day counted.
  let first: StatsDay

  /// The last day counted. Inclusive.
  let last: StatsDay

  /// How many days the default range covers. Fourteen, matching the fortnightly
  /// paper review this whole feature is written for.
  static let trailingDayCount = 14

  // MARK: Building one

  /// Builds a range from two days.
  ///
  /// The two are put in order rather than trusted. A range whose end came
  /// before its start would silently count nothing, and a document that is
  /// empty for a reason nobody can see is the worst outcome available here.
  /// **The screen can produce one, which is why this is not merely defensive.**
  /// `StatsRangeControl` ships two free-form date pickers — its own header says
  /// *"Two pickers and a reset. No presets."* — so a reader can move the end
  /// before the start with two taps. Each picker bounds itself against the other,
  /// so it should not happen; this is what makes "should not" into "cannot".
  ///
  /// *(This comment previously claimed the opposite — a closed list of five spans
  /// and no free-form pickers — describing a control that was never built. In a
  /// codebase reviewed by reading, a comment asserting the inverse of the code is
  /// a defect, and this one had already misled once.)*
  init(first: StatsDay, last: StatsDay) {
    self.first = min(first, last)
    self.last = max(first, last)
  }

  /// One single day.
  static func day(_ day: StatsDay) -> StatsRange {
    StatsRange(first: day, last: day)
  }

  /// Today and the thirteen days before it: fourteen calendar days, inclusive
  /// at both ends.
  ///
  /// Falls back to the single day it was given if the calendar cannot do the
  /// arithmetic. That is a degraded answer rather than a crash, and it is
  /// visible — the screen would say *"Nothing in these 14 days"* over a range
  /// showing one date, which reads as wrong rather than as a quiet lie.
  static func trailing14Days(endingOn last: StatsDay, in calendar: Calendar) -> StatsRange {
    guard let first = last.addingDays(-(trailingDayCount - 1), in: calendar) else {
      return .day(last)
    }
    return StatsRange(first: first, last: last)
  }

  // MARK: Reading one

  /// True when the range covers exactly one day. The document titles a single
  /// day differently from a span.
  var isSingleDay: Bool { first == last }

  /// Whether a day falls inside the range. Inclusive at both ends.
  func contains(_ day: StatsDay) -> Bool {
    day >= first && day <= last
  }

  // MARK: Turning one into database bounds

  /// The two instants a database query compares against.
  struct Bounds: Sendable, Equatable {
    /// The first instant of the first day. Rows at exactly this instant are in.
    let lower: Date

    /// The first instant of the day *after* the last day. Rows at exactly this
    /// instant are out.
    let upper: Date
  }

  /// The half-open window `[lower, upper)` that covers this range.
  ///
  /// **Half-open, and that is the whole reason this method exists.** The
  /// tempting version compares against the *end* of the last day, and then
  /// either drops or double-counts a block that begins exactly at midnight,
  /// depending on which comparison was written. Written this way there is no
  /// instant that belongs to two ranges and none that belongs to neither.
  ///
  /// Returns nothing when the calendar cannot turn these numbers into dates.
  /// The one caller treats that as "nothing to count".
  func bounds(in calendar: Calendar) -> Bounds? {
    guard let lower = first.start(in: calendar),
          let dayAfterLast = last.addingDays(1, in: calendar),
          let upper = dayAfterLast.start(in: calendar) else { return nil }
    return Bounds(lower: lower, upper: upper)
  }
}
