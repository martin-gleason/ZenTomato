import Foundation
import Testing

@testable import ZenTomato

/// `F12-T3` — Auto, and what a stored choice reads back as.
///
/// Auto is a pure function of the date, so its boundaries are asserted here rather than waited for.
/// Each case sits on or beside an edge, because an off-by-one at an edge is the only way a rule
/// this small goes wrong (`F12-M4` moves the 9pm edge by one hour and must be caught at 21:00).
@Suite("ThemeChoice")
struct ThemeChoiceTests {
  struct Case: Sendable, CustomStringConvertible {
    let month: Int
    let hour: Int
    let expected: Theme
    var description: String { "month \(month) at \(hour):00 → \(expected.name)" }
  }

  static let autoCases: [Case] = [
    // The clock: before 6 and from 21 is Ink, whatever the month.
    Case(month: 3, hour: 5, expected: .ink),
    Case(month: 3, hour: 6, expected: .sage),
    Case(month: 3, hour: 20, expected: .sage),
    Case(month: 3, hour: 21, expected: .ink),
    Case(month: 3, hour: 0, expected: .ink),
    // The season: August and September daylight is Ripen; July and October are not.
    Case(month: 7, hour: 12, expected: .sage),
    Case(month: 8, hour: 12, expected: .ripen),
    Case(month: 9, hour: 12, expected: .ripen),
    Case(month: 10, hour: 12, expected: .sage),
    // The clock wins over the season: a September night is Ink.
    Case(month: 9, hour: 21, expected: .ink),
    Case(month: 8, hour: 5, expected: .ink)
  ]

  @Test("autoFollowsTheClockAndTheSeason", arguments: autoCases)
  func autoFollowsTheClockAndTheSeason(testCase: Case) throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/Chicago"))
    let date = try #require(
      calendar.date(from: DateComponents(year: 2026, month: testCase.month, day: 15, hour: testCase.hour)))
    #expect(ThemeChoice.auto(at: date, calendar: calendar) == testCase.expected, "\(testCase)")
    #expect(ThemeChoice.auto.resolved(at: date, calendar: calendar) == testCase.expected)
  }

  /// A fixed choice ignores the clock entirely: Plum at midnight is Plum.
  @Test("aFixedChoiceIgnoresTheClock", arguments: Theme.allCases)
  func aFixedChoiceIgnoresTheClock(theme: Theme) throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/Chicago"))
    let midnight = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 0)))
    #expect(ThemeChoice(theme).resolved(at: midnight, calendar: calendar) == theme)
  }

  /// Nothing stored, or a name this build has never heard of, is Auto — never a failure.
  @Test("anUnknownStoredValueIsAuto")
  func anUnknownStoredValueIsAuto() {
    #expect(ThemeChoice.stored(nil) == .auto)
    #expect(ThemeChoice.stored("sepia") == .auto)
    #expect(ThemeChoice.stored("") == .auto)
    for choice in ThemeChoice.allCases {
      #expect(ThemeChoice.stored(choice.rawValue) == choice)
    }
  }

  /// Every theme has exactly one choice that draws it, and Auto is the one choice that is not fixed.
  @Test("everyThemeIsChoosable")
  func everyThemeIsChoosable() {
    #expect(ThemeChoice.allCases.compactMap(\.fixed) == Theme.allCases)
    #expect(ThemeChoice.allCases.filter { $0.fixed == nil } == [.auto])
    #expect(ThemeChoice.allCases.first == .auto, "Auto sits at the top of the picker.")
  }
}
