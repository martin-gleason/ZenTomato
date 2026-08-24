import Foundation
import Testing

@testable import ZenTomato

/// Tests for the span of days a count covers.
///
/// Small, but three of the four things this file checks are the classic ways a
/// date range goes wrong: an end that is exclusive when it should be inclusive,
/// a "fourteen days" that is really fifteen, and arithmetic done in seconds
/// that lands on the wrong date twice a year.
@Suite("StatsRange")
@MainActor
struct StatsRangeTests {
  /// A fixed calendar in a zone that actually changes its clocks, so the
  /// daylight-saving test below is testing something.
  private static let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
    return calendar
  }()

  private static func day(_ year: Int, _ month: Int, _ day: Int) -> StatsDay? {
    StatsDay(year: year, month: month, day: day, in: calendar)
  }

  // MARK: The default

  /// The trailing fourteen days are today and the **thirteen** days before it.
  ///
  /// This is the one number in the feature that comes from outside the app: the
  /// paper review happens every fortnight, so the export defaults to a
  /// fortnight. Fourteen days inclusive means the first day is thirteen days
  /// before the last, and getting that wrong by one is a whole extra day of
  /// somebody's history in a document titled as two weeks.
  @Test("defaultRangeIsTrailing14Days")
  func defaultRangeIsTrailing14Days() throws {
    let last = try #require(Self.day(2026, 8, 21))
    let range = StatsRange.trailing14Days(endingOn: last, in: Self.calendar)

    #expect(range.last == last)
    #expect(range.first == Self.day(2026, 8, 8))
    #expect(StatsRange.trailingDayCount == 14)

    // Counted out the long way, because "thirteen days before" is exactly the
    // sort of thing that reads right and is off by one.
    var counted = 0
    var cursor = range.first
    while cursor < range.last {
      cursor = try #require(cursor.addingDays(1, in: Self.calendar))
      counted += 1
    }
    #expect(counted == 13)
  }

  /// Fourteen days spanning the night the clocks change is still fourteen days.
  ///
  /// The tempting implementation subtracts thirteen lots of 86,400 seconds. In
  /// Europe/London one night in late October is twenty-five hours long, so that
  /// version quietly lands an hour into the wrong day and the export covers a
  /// different fortnight from the one in its title — twice a year, on nobody's
  /// machine but the owner's.
  @Test("aFortnightAcrossTheClockChangeIsStillAFortnight")
  func aFortnightAcrossTheClockChangeIsStillAFortnight() throws {
    let last = try #require(Self.day(2026, 10, 30))
    let range = StatsRange.trailing14Days(endingOn: last, in: Self.calendar)

    // The clocks go back on Sunday 25 October 2026, inside this span.
    #expect(range.first == Self.day(2026, 10, 17))
  }

  // MARK: One day

  /// A single day is a range whose ends are the same day.
  @Test("aSingleDayIsARangeOfOne")
  func aSingleDayIsARangeOfOne() throws {
    let day = try #require(Self.day(2026, 8, 23))
    let range = StatsRange.day(day)

    #expect(range.isSingleDay)
    #expect(range.first == day)
    #expect(range.last == day)
    #expect(range.contains(day))
  }

  /// Two days handed over the wrong way round are put in order rather than
  /// producing a range that contains nothing.
  @Test("aRangeOrdersItsOwnEnds")
  func aRangeOrdersItsOwnEnds() throws {
    let earlier = try #require(Self.day(2026, 8, 8))
    let later = try #require(Self.day(2026, 8, 21))
    let backwards = StatsRange(first: later, last: earlier)

    #expect(backwards.first == earlier)
    #expect(backwards.last == later)
  }

  // MARK: The bounds a query compares against

  /// The window is half-open: it starts at the first instant of the first day
  /// and ends at the first instant of the day **after** the last.
  ///
  /// An inclusive upper bound is the classic off-by-one here. Written that way
  /// a block beginning at exactly midnight either belongs to two spans or to
  /// neither, depending on which comparison somebody wrote, and both mistakes
  /// look correct until a fortnight's worth of rows are on the phone.
  @Test("theFetchWindowIsHalfOpen")
  func theFetchWindowIsHalfOpen() throws {
    let first = try #require(Self.day(2026, 8, 8))
    let last = try #require(Self.day(2026, 8, 21))
    let bounds = try #require(StatsRange(first: first, last: last).bounds(in: Self.calendar))

    #expect(bounds.lower == StatsStoreFixture.at(2026, 8, 8, 0, 0))
    #expect(bounds.upper == StatsStoreFixture.at(2026, 8, 22, 0, 0))
    #expect(bounds.lower < bounds.upper)
  }

  /// A single day's window is exactly twenty-four hours long, and its upper
  /// bound is the next midnight rather than the same one.
  @Test("aSingleDaysWindowEndsAtTheNextMidnight")
  func aSingleDaysWindowEndsAtTheNextMidnight() throws {
    let day = try #require(Self.day(2026, 8, 23))
    let bounds = try #require(StatsRange.day(day).bounds(in: Self.calendar))

    #expect(bounds.lower == StatsStoreFixture.at(2026, 8, 23, 0, 0))
    #expect(bounds.upper == StatsStoreFixture.at(2026, 8, 24, 0, 0))
  }

  // MARK: Everything

  /// *Everything* reaches back far enough that no row this app could have
  /// written falls outside it.
  @Test("everythingReachesBackBeforeAnythingCouldHaveBeenRecorded")
  func everythingReachesBackBeforeAnythingCouldHaveBeenRecorded() throws {
    let today = try #require(Self.day(2026, 8, 23))
    let range = StatsRange.everything(endingOn: today, in: Self.calendar)

    #expect(range.last == today)
    #expect(range.first.year == 1970)
    #expect(range.contains(try #require(Self.day(2020, 1, 1))))
    #expect(range.contains(try #require(Self.day(2026, 8, 23))))
    // Tomorrow is not in it. A range is inclusive at both ends and no further.
    #expect(range.contains(try #require(Self.day(2026, 8, 24))) == false)
  }

  // MARK: The day itself

  /// A day knows which day of the week it is, and does not lose it on the way
  /// to an instant and back.
  ///
  /// The weekday is the one thing the export cannot work out for itself, so it
  /// is worth one direct check that the number means what the tables in the
  /// export assume: 1 is Sunday.
  @Test("aDayCarriesItsWeekday")
  func aDayCarriesItsWeekday() throws {
    // Wednesday 19 August 2026.
    let wednesday = try #require(Self.day(2026, 8, 19))
    #expect(wednesday.weekday == 4)

    let sunday = try #require(Self.day(2026, 8, 23))
    #expect(sunday.weekday == 1)

    let saturday = try #require(Self.day(2026, 8, 8))
    #expect(saturday.weekday == 7)
  }

  /// Two days with the same date are the same day, and the derived weekday
  /// takes no part in that.
  ///
  /// It matters because these are used as dictionary keys while the counting is
  /// being done. A type that is neither equal to, less than, nor greater than
  /// another breaks sorting and dictionaries in ways that only show up once
  /// there is a fortnight of rows to sort.
  @Test("aDaysIdentityIsItsDateAndNotItsWeekday")
  func aDaysIdentityIsItsDateAndNotItsWeekday() throws {
    let real = try #require(Self.day(2026, 8, 19))
    let wrongWeekday = StatsDay(year: 2026, month: 8, day: 19, weekday: 1)

    #expect(real == wrongWeekday)
    #expect((real < wrongWeekday) == false)
    #expect((wrongWeekday < real) == false)
    #expect(Set([real, wrongWeekday]).count == 1)
  }
}
