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

  /// The two programs are still told to compile the *same* description of this
  /// data, rather than a copy each.
  ///
  /// WHAT THIS CATCHES AND WHAT IT HONESTLY CANNOT
  /// The round-trip tests above pack a value and unpack it with the same code,
  /// so they would keep passing unchanged if somebody copied
  /// `FocusAlarmMetadata` into the widget and let the two versions drift apart —
  /// which is precisely the failure that produces a blank Lock Screen with no
  /// crash, no error and no log. This test cannot compare the two copies either:
  /// the test target links the app and not the widget, so there is only ever one
  /// copy in the room.
  ///
  /// What it *can* do is read the project description off disk and insist the
  /// shared directory is still listed in the widget's sources. That fails on the
  /// exact action the comment in `FocusAlarmMetadata` warns about — somebody
  /// "tidying" the sharing away — which is a mechanism rather than a promise.
  /// It is the same technique `LaunchBackgroundTests` uses to hold a colour in
  /// an asset catalog equal to a colour in the token table.
  @Test("sharedSourcesAreCompiledIntoTheWidget")
  func sharedSourcesAreCompiledIntoTheWidget() throws {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()   // ZenTomatoTests
      .deletingLastPathComponent()   // repository root
      .appending(path: "project.yml")
    let projectFile = try String(contentsOf: url, encoding: .utf8)

    // Everything from the widget target's name to the start of the next
    // top-level key. Narrowing to that slice is what stops the app target's own
    // listing of the same directories from satisfying the check.
    let widgetSection = try #require(
      projectFile.range(of: "\n  ZenTomatoActivity:\n").map { start in
        let rest = projectFile[start.upperBound...]
        let end = rest.range(of: "\n  ZenTomatoTests:\n")?.lowerBound ?? rest.endIndex
        return String(rest[..<end])
      })

    #expect(widgetSection.contains("- path: ZenTomato/Shared"))
    #expect(widgetSection.contains("- path: ZenTomato/DesignSystem"))
    #expect(widgetSection.contains("ZenTomato/Timer/BlockKind.swift"))
    // The database model must NOT be handed to a program that has no database.
    #expect(widgetSection.contains("AppSettings.swift") == false)
  }
}
