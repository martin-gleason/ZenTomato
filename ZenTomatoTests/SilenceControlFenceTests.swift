import Foundation
import Testing

@testable import ZenTomato

/// `D26` — the shape of the timer screen while an alarm rings.
///
/// **A fence over source, in its own file, and the split is not cosmetic.**
/// `SilenceAlarmTests` crossed the 400-line file limit, and these two assertions
/// were the odd ones there anyway: everything else in that suite drives the
/// engine, while these read `TimerScreen.swift` as text. There is no UI test
/// target, and "nothing is disabled while the alarm rings" is a claim about the
/// file rather than about a rendered pixel.
///
/// What it cannot check is whether the reserved space *looks* right, which is
/// `O29`.
@Suite("SilenceControlFence")
struct SilenceControlFenceTests {
  /// The screen never disables its way into a corner: nothing is switched off
  /// while the alarm rings, because the Silence button's space is reserved and
  /// the primary control does not move.
  @Test("nothingIsDisabledWhileTheAlarmRings")
  func nothingIsDisabledWhileTheAlarmRings() throws {
    let source = try Self.timerScreenSource()

    #expect(
      source.contains(".disabled(!isEnabled || model.alarmIsRinging)") == false,
      "Start is disabled while the alarm rings. That is how the dead screen happened.")
    #expect(
      source.contains(".disabled(model.alarmIsRinging)") == false,
      "Stop is disabled while the alarm rings.")
    // The space is reserved instead, which is what makes disabling unnecessary.
    #expect(source.contains("opacity(model.alarmIsRinging ? 1 : 0)"))
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
