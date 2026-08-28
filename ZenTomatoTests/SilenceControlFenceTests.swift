import Foundation
import Testing

@testable import ZenTomato

/// `D26` — the shape of the timer screen while an alarm rings.
///
/// **A fence over source, because there is no UI test target.** "The Silence
/// button takes the primary control's place, and nothing is disabled" is a claim
/// about how `TimerScreen.swift` is written rather than about a rendered pixel,
/// and `PolishFenceTests` and `StatsFenceTests` already read the tree this way.
///
/// **A correction about this file.** Its first header said it was created because
/// `SilenceAlarmTests` had crossed the 400-line limit and two source fences were
/// moved into it. **Every part of that was false**: nothing was removed from that
/// suite, it had never held a source fence, and this file has always held one
/// test rather than two. What actually happened is that the test was written new
/// and put here so the other file would stay under the limit. The commit message
/// carried the same false claim. Recorded rather than quietly rewritten, because
/// it is the same defect as the stale evidence blocks the same commit fixed:
/// committed prose asserting something about the tree that the tree contradicts.
///
/// What it cannot check is whether the swap *looks* right, which is `O29`.
@Suite("SilenceControlFence")
struct SilenceControlFenceTests {
  /// **Nothing on the timer screen is disabled while the alarm rings, and the
  /// Silence button takes the primary control's slot rather than adding one.**
  ///
  /// Both halves are load-bearing and both come from a defect. Disabling Start
  /// and Stop produced a screen with three controls and nothing pressable when
  /// iOS refused to stop the alarm. Adding a slot — first conditionally, then as
  /// reserved space — either moved a control under a finger or put sixty fixed
  /// points of blank page into every other state, outside the ScrollView that
  /// exists because this screen already does not fit at the largest text sizes.
  @Test("theSilenceButtonTakesTheSlotAndDisablesNothing")
  func theSilenceButtonTakesTheSlotAndDisablesNothing() throws {
    let source = try Self.timerScreenSource()

    // The swap: one `if` choosing between Silence and the primary control.
    #expect(source.contains("if model.alarmIsRinging {"))
    #expect(source.contains("primaryControl"))

    // No control is switched off because of a ringing alarm. Written as a search
    // for the substring `alarmIsRinging` inside any `.disabled(`, so a reformat
    // cannot slip a re-added one past — the previous version matched two exact
    // historical strings and would have missed `.disabled(model.alarmIsRinging )`.
    for line in source.split(separator: "\n") where line.contains(".disabled(") {
      #expect(
        line.contains("alarmIsRinging") == false,
        "A control is disabled while the alarm rings: \(line.trimmingCharacters(in: .whitespaces))")
    }

    // And no reserved-space rework has crept back.
    #expect(source.contains("opacity(model.alarmIsRinging") == false)
  }

  private static func timerScreenSource() throws -> String {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appending(path: "ZenTomato/Views/TimerScreen.swift")
    let text = try String(contentsOf: url, encoding: .utf8)
    return text
      .split(separator: "\n", omittingEmptySubsequences: false)
      .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") == false }
      .joined(separator: "\n")
  }

  // MARK: The drift test
}
