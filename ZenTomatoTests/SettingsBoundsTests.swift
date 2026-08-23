import Foundation
import Testing

@testable import ZenTomato

/// Tests for the legal range of every settings value, and for the clamp that
/// stands behind the settings screen.
///
/// `@MainActor` because copying the settings row is a database read, and every
/// database access in this app is main-thread only.
@Suite("SettingsBounds")
@MainActor
struct SettingsBoundsTests {
  /// The bounds are the ones the contract names. This test exists so that
  /// widening them is a deliberate act with a failing test attached, rather
  /// than a one-character edit nobody notices.
  @Test("boundsAreTheContractedRanges")
  func boundsAreTheContractedRanges() {
    #expect(SettingsBounds.minutes == 1...120)
    #expect(SettingsBounds.pomodorosPerSprint == 1...12)

    // One minute is legal on purpose: it is what makes a whole sprint
    // hand-testable in about eight minutes rather than two hours.
    #expect(SettingsBounds.minutes.contains(1))
    #expect(SettingsBounds.pomodorosPerSprint.contains(1))
  }

  /// A value that is somehow out of range in the database is pulled back inside
  /// when the block's settings are copied.
  ///
  /// WHY THIS IS WORTH TESTING WHEN THE SCREEN CANNOT PRODUCE ONE
  /// The screen offers only legal values, so in normal use nothing here ever
  /// changes anything. The row can also come from a store written by an older
  /// build, and a block whose length came out of a file is not a block whose
  /// length was chosen. This is the second line of defence, and the point of a
  /// second line of defence is that it works when the first is absent.
  @Test("clampingPullsStoredValuesBackInsideTheBounds")
  func clampingPullsStoredValuesBackInsideTheBounds() {
    let wild = AppSettings(
      workMinutes: 0,
      shortBreakMinutes: 999,
      longBreakMinutes: -5,
      pomodorosPerSprint: 40,
      soundEnabled: true,
      autoStartNextBlock: false)

    let snapshot = TimerSettingsSnapshot(clamping: wild)

    #expect(snapshot.workMinutes == 1)
    #expect(snapshot.shortBreakMinutes == 120)
    #expect(snapshot.longBreakMinutes == 1)
    #expect(snapshot.pomodorosPerSprint == 12)
  }

  /// A legal value is passed through untouched. Without this, a clamp that
  /// returned a constant would pass the test above.
  @Test("clampingLeavesLegalValuesAlone")
  func clampingLeavesLegalValuesAlone() {
    let snapshot = TimerSettingsSnapshot(clamping: AppSettings())

    #expect(snapshot.workMinutes == 25)
    #expect(snapshot.shortBreakMinutes == 5)
    #expect(snapshot.longBreakMinutes == 15)
    #expect(snapshot.pomodorosPerSprint == 4)
    #expect(snapshot.soundEnabled)
    #expect(snapshot.autoStartNextBlock == false)
  }

  /// The lengths a block actually runs for come out of the snapshot, per kind.
  @Test("durationsComeFromTheSnapshot")
  func durationsComeFromTheSnapshot() {
    let snapshot = TimerSettingsSnapshot(clamping: AppSettings())

    #expect(snapshot.duration(for: .work) == .seconds(25 * 60))
    #expect(snapshot.duration(for: .shortBreak) == .seconds(5 * 60))
    #expect(snapshot.duration(for: .longBreak) == .seconds(15 * 60))
  }
}
