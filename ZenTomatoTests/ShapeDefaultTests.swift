import Foundation
import Testing

@testable import ZenTomato

/// The shape the screen opens on — **one hour, four cycles**, confirmed by the owner 2026-09-24.
///
/// WHY THIS IS A TEST AND NOT A COMMENT
/// The default was `@State private var budgetMinutes = 60` inside a view: a number nothing read and
/// nothing checked. Every other number on that screen is computed and asserted, and this one — the
/// one a person meets first — was the exception. It is also the number most likely to be changed by
/// somebody tidying a preview.
///
/// WHAT "TRADITIONAL 1 HOUR, 4 CYCLE SPRINT" MEANS, PRECISELY, BECAUSE THE TWO WORDS PULL APART
/// A **cycle** is a pomodoro plus the break that follows it (`docs/specs/definitions.md`). Four of
/// them in an hour is the rhythm. It is **not** four *traditional* 25-minute pomodoros: those need
/// 130 minutes, and at sixty the shaper squeezes each pom to its ten-minute floor. The default is
/// traditional in its shape — four poms, short breaks between, a long break at the end — and not in
/// its block length. Both halves are asserted below so that neither can drift into the other.
///
/// NOT MAIN-ACTOR. The shaper is a pure function and the copy is a constant.
struct ShapeDefaultTests {
  private static let settings = TimerSettingsSnapshot(
    workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15,
    pomodorosPerSprint: 4, soundEnabled: true, alertSound: .systemDefault, autoStartNextBlock: false)

  @Test("theScreenOpensOnOneHour")
  func theScreenOpensOnOneHour() {
    #expect(ShapeScreenModel.defaultBudgetMinutes == 60)
  }

  /// **Four cycles, and the shape is read off the shaper rather than restated here.**
  ///
  /// The assertion is on the block list the screen would draw, in order, so a change to the
  /// absorption rule or the floors shows up here as a different sprint rather than as a number that
  /// still happens to add to sixty.
  @Test("theDefaultBudgetMakesFourCycles")
  func theDefaultBudgetMakesFourCycles() throws {
    let shape = try #require(
      SprintShaper.shape(
        budgetMinutes: ShapeScreenModel.defaultBudgetMinutes,
        settings: Self.settings,
        preset: .balanced,
        endsWithLongBreak: true))

    let kinds = shape.blocks.map(\.kind)
    #expect(kinds == [.work, .shortBreak, .work, .shortBreak, .work, .shortBreak, .work, .longBreak])

    // Four poms and four breaks: four cycles, the last one ending long.
    #expect(kinds.filter { $0 == .work }.count == 4)
    #expect(kinds.filter { $0 == .shortBreak }.count == 3)
    #expect(kinds.filter { $0 == .longBreak }.count == 1)

    // And it fills the hour exactly — no remainder left unspent, none overrun.
    #expect(shape.blocks.reduce(0) { $0 + $1.minutes } == 60)
  }

  /// **The default is a full sprint, not a warned-about short one.**
  ///
  /// Sixty minutes is the suggested minimum rather than under it, so the screen a person meets first
  /// carries no warning line. A default that opened under the minimum would greet every new reader
  /// with a caveat.
  @Test("theDefaultIsNotUnderTheSuggestedMinimum")
  func theDefaultIsNotUnderTheSuggestedMinimum() throws {
    let shape = try #require(
      SprintShaper.shape(
        budgetMinutes: ShapeScreenModel.defaultBudgetMinutes,
        settings: Self.settings, preset: .balanced, endsWithLongBreak: true))
    #expect(shape.isUnderSuggestedMinimum == false)
    #expect(SprintShaper.suggestedMinimumMinutes(for: Self.settings)
            <= ShapeScreenModel.defaultBudgetMinutes)
  }

  /// **Traditional in rhythm, not in block length — stated so the distinction cannot quietly flip.**
  ///
  /// At the default the poms are at their floor, well short of the settings' 25. If somebody later
  /// changes the default to 130 to make the poms "traditional", this assertion is where that argument
  /// has to be had rather than a place it slips through.
  @Test("theDefaultSqueezesPomsBelowTheSettingLength")
  func theDefaultSqueezesPomsBelowTheSettingLength() throws {
    let shape = try #require(
      SprintShaper.shape(
        budgetMinutes: ShapeScreenModel.defaultBudgetMinutes,
        settings: Self.settings, preset: .balanced, endsWithLongBreak: true))

    let poms = shape.blocks.filter { $0.kind == .work }.map(\.minutes)
    #expect(poms == [10, 10, 10, 10])
    #expect(poms.allSatisfy { $0 < Self.settings.workMinutes })

    // Four traditional poms would need 130 minutes, which is why the default cannot be both.
    let traditional = 4 * Self.settings.workMinutes
      + 3 * Self.settings.shortBreakMinutes + Self.settings.longBreakMinutes
    #expect(traditional == 130)
    #expect(traditional > ShapeScreenModel.defaultBudgetMinutes)
  }
}
