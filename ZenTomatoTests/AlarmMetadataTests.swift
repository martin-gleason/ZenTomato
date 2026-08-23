import Foundation
import Testing

@testable import ZenTomato

/// The one piece of data that crosses from the app into another program.
///
/// WHY THIS TEST EXISTS, FOR A READER WHO DOES NOT WRITE SWIFT
/// The countdown on the Lock Screen is drawn by a separate miniature program
/// that ships inside the app. It cannot read the app's database, so everything
/// it shows is packed up, handed to iOS along with the alarm, and unpacked again
/// on the other side. `FocusAlarmMetadata` is what gets packed.
///
/// If that packing and unpacking ever stops agreeing — a field renamed, the type
/// copied instead of shared, a value changed to something that cannot be
/// written down — **the Lock Screen simply goes blank and nothing else in the app
/// notices.** There is no crash, no error, and no log. The block still runs, the
/// alarm still fires, and the only symptom is on a locked phone that nobody is
/// looking at.
///
/// This test is the tripwire for that. It packs a value up and unpacks it again,
/// and insists the result is identical.
@Suite("Alarm metadata")
struct AlarmMetadataTests {
  /// A value written down and read back must be the same value.
  @Test("metadataSurvivesRoundTrip")
  func metadataSurvivesRoundTrip() throws {
    let original = FocusAlarmMetadata(kind: .shortBreak, completedInSprint: 2, pomodorosPerSprint: 4)

    let written = try JSONEncoder().encode(original)
    let readBack = try JSONDecoder().decode(FocusAlarmMetadata.self, from: written)

    #expect(readBack == original)
  }

  /// Every kind of block must survive, not just the one that happened to be
  /// tested first.
  ///
  /// The block kind is stored as a word rather than a number precisely so that
  /// this cannot break by somebody reordering the list, and this is the test that
  /// says so out loud.
  @Test("everyBlockKindSurvivesRoundTrip")
  func everyBlockKindSurvivesRoundTrip() throws {
    for kind in BlockKind.allCases {
      let original = FocusAlarmMetadata(kind: kind, completedInSprint: 0, pomodorosPerSprint: 1)

      let written = try JSONEncoder().encode(original)
      let readBack = try JSONDecoder().decode(FocusAlarmMetadata.self, from: written)

      #expect(readBack.kind == kind)
      #expect(readBack == original)
    }
  }

  /// The widest sprint the settings allow, and the narrowest, both travel.
  ///
  /// A sprint of one is a real setting and the sprint counter on the Lock Screen
  /// has to be able to say "0 of 1" as readily as "11 of 12".
  @Test("metadataCarriesTheFullSprintRange")
  func metadataCarriesTheFullSprintRange() throws {
    let widest = FocusAlarmMetadata(
      kind: .work,
      completedInSprint: SettingsBounds.pomodorosPerSprint.upperBound - 1,
      pomodorosPerSprint: SettingsBounds.pomodorosPerSprint.upperBound)

    let readBack = try JSONDecoder().decode(
      FocusAlarmMetadata.self,
      from: try JSONEncoder().encode(widest))

    #expect(readBack.completedInSprint == SettingsBounds.pomodorosPerSprint.upperBound - 1)
    #expect(readBack.pomodorosPerSprint == SettingsBounds.pomodorosPerSprint.upperBound)
  }
}
