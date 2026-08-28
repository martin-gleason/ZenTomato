import Foundation
import Testing

@testable import ZenTomato

/// `D27` and `D28` — the settings screen while a block runs, and hearing a sound
/// before choosing it.
///
/// WHY THESE ARE FENCES OVER SOURCE RATHER THAN VIEW TESTS
/// This project has no UI test target, and the two rules here are both *structural*:
/// "every customization row is locked by one flag" and "a preview cannot outlive
/// its screen" are claims about how the file is written, not about a rendered
/// pixel. `PolishFenceTests` and `LicenceFenceTests` already read the tree this
/// way. What a fence cannot check is that it *looks* right, which is why `F2e`'s
/// *Done when* is two runs on a phone.
@Suite("SettingsLock")
struct SettingsLockTests {
  // MARK: D27 — locked while running

  /// **The customization rows are disabled by ONE modifier, on a group.**
  ///
  /// The failure this prevents is not today's code being wrong — it is next
  /// year's row being added outside the group and nobody noticing, because a
  /// settings screen grows one reasonable-looking row at a time. That is the same
  /// argument `PolishFenceTests` makes about the field count.
  @Test("theCustomizationRowsLockTogether")
  func theCustomizationRowsLockTogether() throws {
    let source = try Self.settingsSource()

    // The three sections that hold snapshotted settings, inside one Group that
    // carries the lock.
    let group = try #require(
      Self.slice(of: source, from: "Group {", to: ".disabled(isBlockRunning)"),
      "The customization Group with its single .disabled is gone.")
    for section in ["blockLengths", "sprint", "whenABlockEnds"] {
      #expect(group.contains(section), "\(section) is no longer locked with the others.")
    }

    // Exactly one lock, so a second one cannot appear and quietly mean something
    // different.
    #expect(Self.occurrences(of: ".disabled(isBlockRunning)", in: source) == 1)
  }

  /// **Music and Todoist are deliberately not locked.**
  ///
  /// `SPEC.md` gives music its own row explicitly permitting changes during a
  /// sprint, and neither is in `AppSettings` or snapshotted at block start. This
  /// asserts they sit outside the group rather than merely that they work.
  @Test("musicAndTodoistAreNotLocked")
  func musicAndTodoistAreNotLocked() throws {
    let source = try Self.settingsSource()
    let group = try #require(Self.slice(of: source, from: "Group {", to: ".disabled(isBlockRunning)"))

    #expect(group.contains("music") == false)
    #expect(group.contains("todoist") == false)
  }

  /// The note must not still promise that changes take effect later — nothing
  /// can be changed.
  @Test("theRunningNoteSaysLockedRatherThanLater")
  func theRunningNoteSaysLockedRatherThanLater() throws {
    let source = try Self.settingsSource()

    #expect(source.contains("These settings are locked until it ends."))
    #expect(
      source.contains("Changes take effect when it ends, not now.") == false,
      "The old note survived. It describes rows nobody can touch.")
  }

  // MARK: D28 — the preview

  /// **A preview is stopped on every way out of the screen, not only the tidy
  /// one.** A sound still playing after the screen has gone is `D26`'s defect
  /// arriving inside the feature built so nobody chooses a sound blind.
  @Test("aPreviewCannotOutliveItsScreen")
  func aPreviewCannotOutliveItsScreen() throws {
    let source = try Self.settingsSource()

    #expect(source.contains(".onDisappear { preview.stop() }"))
    // Backgrounding does not fire onDisappear, so the scene phase is checked too.
    #expect(source.contains("scenePhase"))
    #expect(source.contains("preview.stop()"))
  }

  /// The preview plays once. A loop would be a sound to hunt an off switch for.
  @Test("thePreviewDoesNotLoop")
  func thePreviewDoesNotLoop() throws {
    let source = try Self.previewSource()

    #expect(source.contains("numberOfLoops = 0"))
  }

  /// **The session must be audible with the ringer switch off, and must not stop
  /// the person's music.** `.playback` ignores the switch; `.mixWithOthers`
  /// declines to interrupt. This is the pair, and it is the part that fails
  /// quietly — hence also `F2e`'s device check.
  @Test("theSessionIsAudibleAndPolite")
  func theSessionIsAudibleAndPolite() throws {
    let source = try Self.previewSource()

    #expect(source.contains(".playback"))
    #expect(source.contains(".mixWithOthers"))
  }

  /// `systemDefault` is iOS's sound, not a file this app holds, so the player
  /// refuses rather than pretending — and the screen says so.
  @Test("theDefaultSoundIsNotPretendedToBePlayable")
  func theDefaultSoundIsNotPretendedToBePlayable() throws {
    #expect(AlertSound.systemDefault.fileName == nil)
    let settings = try Self.settingsSource()
    #expect(settings.contains("cannot be played here"))
  }

  // MARK: Private

  private static func settingsSource() throws -> String {
    try source(of: "ZenTomato/Views/SettingsView.swift")
  }

  private static func previewSource() throws -> String {
    try source(of: "ZenTomato/Alarm/AlertSoundPreview.swift")
  }

  /// A file from the source tree, **with comments stripped**.
  ///
  /// Stripping first is the lesson `StatsFenceTests` and `PolishFenceTests`
  /// already learned: a fence that cannot tell a mention from a use fires on the
  /// comment explaining the rule, and is switched off within a month.
  private static func source(of path: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appending(path: path)
    let text = try String(contentsOf: url, encoding: .utf8)
    return text
      .split(separator: "\n", omittingEmptySubsequences: false)
      .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") == false }
      .joined(separator: "\n")
  }

  private static func slice(of source: String, from start: String, to end: String) -> String? {
    guard let opening = source.range(of: start),
      let closing = source.range(of: end, range: opening.upperBound..<source.endIndex)
    else { return nil }
    return String(source[opening.upperBound..<closing.lowerBound])
  }

  private static func occurrences(of needle: String, in haystack: String) -> Int {
    haystack.components(separatedBy: needle).count - 1
  }
}
