import Foundation

/// One local calendar day, reduced to four plain whole numbers.
///
/// WHAT A READER WHO DOES NOT WRITE SWIFT NEEDS TO KNOW
/// Everything the timer records is an *instant* — a precise moment, which only
/// means a particular day once you say whose calendar and whose time zone you
/// are using. This type is that question asked once, at the moment the numbers
/// are counted, and then never again. After this point the answer is four
/// integers, and integers cannot change their mind on a phone set to a
/// different region.
///
/// **This is the single decision that makes the exported document stable.**
/// The export renders `Wed 19 Aug` by looking `4` up in a table of weekday
/// names. It owns no calendar, no locale and no date formatter, so there is
/// nothing left in it for a region setting, a first-day-of-week preference or a
/// twelve-hour clock to alter. A committed golden file can therefore be
/// compared byte for byte, which is the strongest evidence available for a
/// feature whose acceptance test is a person reading a page next to a paper
/// notebook.
///
/// **`containing(_:in:)` is the counting rule's day boundary.** `F6.md`: *"A
/// day is the local calendar day of the block's start. A pomodoro beginning
/// 23:50 and ending 00:15 belongs entirely to the day it started."* Every day in
/// this feature is produced by handing this method a block's `startedAt`. A
/// block's `endedAt` is never handed to it, anywhere in the tree.
struct StatsDay: Sendable, Hashable, Comparable {
  // MARK: What a day is

  /// The year, as a person writes it: 2026.
  let year: Int

  /// The month, 1 through 12.
  let month: Int

  /// The day of the month, 1 through 31.
  let day: Int

  /// Which day of the week it is, in `Calendar`'s own numbering: **1 is
  /// Sunday**, 7 is Saturday.
  ///
  /// Stored rather than worked out later, because working it out later would
  /// mean owning a calendar later, and the export deliberately owns none. It is
  /// the one value here that is *derived* from the other three, which is why it
  /// takes no part in whether two days are the same day — see `==` below.
  let weekday: Int

  // MARK: Building one

  /// Builds a day from its parts.
  ///
  /// Used by `containing(_:in:)` and by test fixtures. Nothing checks that
  /// `weekday` agrees with the date: a fixture that gets it wrong renders the
  /// wrong weekday name in the export, and the golden file is what catches
  /// that. Putting a check here would only move the same failure earlier and
  /// would require this type to own a calendar.
  init(year: Int, month: Int, day: Int, weekday: Int) {
    self.year = year
    self.month = month
    self.day = day
    self.weekday = weekday
  }

  /// Builds a day from its date alone, working the weekday out.
  ///
  /// This is the initialiser fixtures should use: it makes it impossible to
  /// write down a date and a weekday that disagree. It returns nothing when the
  /// three numbers are not a real date in this calendar — 31 February, say.
  init?(year: Int, month: Int, day: Int, in calendar: Calendar) {
    var parts = DateComponents()
    parts.year = year
    parts.month = month
    parts.day = day
    guard let instant = calendar.date(from: parts) else { return nil }
    self = Self.containing(instant, in: calendar)
  }

  /// The day an instant falls on, in a given calendar.
  ///
  /// **This is the counting rule's day boundary and there is no second copy of
  /// it.** Four separate readings rather than one bundle of components, because
  /// `Calendar.component(_:from:)` returns a plain number that cannot be
  /// missing — so there is no optional to unwrap here, no default to invent,
  /// and no way for this to quietly answer "year zero".
  static func containing(_ instant: Date, in calendar: Calendar) -> StatsDay {
    StatsDay(
      year: calendar.component(.year, from: instant),
      month: calendar.component(.month, from: instant),
      day: calendar.component(.day, from: instant),
      weekday: calendar.component(.weekday, from: instant))
  }

  // MARK: Turning one back into an instant

  /// The first instant of this day, or nothing if these numbers are not a real
  /// date in this calendar.
  ///
  /// Optional rather than forced: `Calendar` can legitimately fail here, and
  /// this project bans the exclamation mark that would turn that into a crash.
  /// The one caller — `StatsRange.bounds(in:)` — treats a failure as "there is
  /// nothing to count", which is a wrong-but-harmless empty page rather than a
  /// closed app.
  func start(in calendar: Calendar) -> Date? {
    var parts = DateComponents()
    parts.year = year
    parts.month = month
    parts.day = day
    // The weekday is deliberately left out. Handing a calendar both a date and
    // a weekday asks it to reconcile them, and a fixture with a wrong weekday
    // would then silently shift the date rather than showing a wrong name.
    guard let instant = calendar.date(from: parts) else { return nil }
    return calendar.startOfDay(for: instant)
  }

  /// The day this many days after this one — negative counts step backwards.
  ///
  /// Done through the calendar rather than by adding 86,400 seconds, because
  /// days are not all the same length: the day a clock goes forward is
  /// twenty-three hours long, and arithmetic on seconds silently lands on the
  /// wrong date twice a year.
  func addingDays(_ count: Int, in calendar: Calendar) -> StatsDay? {
    guard let start = start(in: calendar),
          let moved = calendar.date(byAdding: .day, value: count, to: start) else { return nil }
    return Self.containing(moved, in: calendar)
  }

  // MARK: Identity and order

  /// Two days are the same day when their date is the same.
  ///
  /// **`weekday` is deliberately excluded**, because it is derived from the
  /// other three rather than being a fact of its own. Including it would mean a
  /// value could be neither equal to, less than, nor greater than another —
  /// which is a rule Swift's own sorting and dictionaries rely on, and breaking
  /// it produces the kind of bug that only appears once a fortnight's worth of
  /// rows are on the phone.
  static func == (lhs: StatsDay, rhs: StatsDay) -> Bool {
    lhs.year == rhs.year && lhs.month == rhs.month && lhs.day == rhs.day
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(year)
    hasher.combine(month)
    hasher.combine(day)
  }

  /// Earlier days sort first.
  static func < (lhs: StatsDay, rhs: StatsDay) -> Bool {
    (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
  }
}
