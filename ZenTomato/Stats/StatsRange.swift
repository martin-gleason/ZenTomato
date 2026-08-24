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
  /// There is no way for the screen to produce one — it offers a closed list of
  /// five spans and no free-form date pickers — so this costs one comparison and
  /// removes a whole class of failure.
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

  /// Everything ever recorded, up to and including the given day.
  ///
  /// There is no way to ask the database "what is the earliest row" without
  /// counting something, and this feature has exactly one thing that counts. So
  /// *everything* is expressed as a range that starts before the app could
  /// possibly have any data, and the period that comes back reports the span it
  /// actually found through `StatsPeriod.recordedSpan` — which is derived from
  /// the day rows rather than from a second query.
  ///
  /// The floor is the start of 1970, the zero point of the clock this phone
  /// keeps. A row older than that would need a clock set wrong by half a
  /// century.
  static func everything(endingOn last: StatsDay, in calendar: Calendar) -> StatsRange {
    StatsRange(first: StatsDay.containing(Date(timeIntervalSince1970: 0), in: calendar), last: last)
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
