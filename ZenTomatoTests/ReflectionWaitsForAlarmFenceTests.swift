import Foundation
import Testing

@testable import ZenTomato

/// The rule that the reflection sheet does not cover the Silence button.
///
/// **THE HEADLINE FIX OF THE FOURTH ADVERSARIAL PASS, GUARDED BY NOTHING UNTIL
/// NOW.** A focus block with taps in it, ending with the app in the foreground,
/// used to present the sheet *over* `TimerScreen` while the alarm was still
/// ringing — a modal with no silence control of its own, covering the one control
/// that could stop the noise. That is `D26`'s entire complaint, surviving inside
/// the feature built to answer it.
///
/// **A fence over source, and the omission it closes was a choice rather than a
/// limitation.** There is no UI test target, so `SilenceControlFenceTests` already
/// reads `TimerScreen.swift` as text for exactly this kind of claim. `TimerView`
/// had no such fence, and the fifth pass pointed out that the same commit edited
/// `SilenceControlFenceTests` without adding one.
///
/// What it cannot check is that the sheet actually appears afterwards on a phone.
/// That is `O29`.
@Suite("ReflectionWaitsForAlarmFence")
struct ReflectionWaitsForAlarmFenceTests {
  /// The guard is in the list, and the retry exists to make waiting safe.
  ///
  /// Both halves are load-bearing. Without the guard the sheet covers the button;
  /// without the retry the offer waits for ever, which trades a covered button for
  /// a lost prompt — and the prompt is the thing this app exists to collect.
  @Test("theSheetWaitsForTheAlarmAndThenArrives")
  func theSheetWaitsForTheAlarmAndThenArrives() throws {
    let source = try Self.timerViewSource()

    let guardList = try #require(
      Self.slice(of: source, from: "private func presentReflectionIfPossible() {", to: "else { return }"),
      "presentReflectionIfPossible's guard list is gone.")
    #expect(
      guardList.contains("engine.ringingAlarmID == nil"),
      "The sheet no longer waits for the alarm, so it can cover the Silence button.")

    // And the other side: something must try again when the alarm stops, or the
    // offer waits for ever.
    // Sliced to the *modifier's* closing brace rather than the first `}`, which
    // belongs to the guard inside the closure. A window that ends too early is a
    // fence that fails on correct code, and a fence that fails on correct code is
    // one somebody deletes.
    let retry = try #require(
      Self.slice(of: source, from: ".onChange(of: engine.ringingAlarmID)", to: "\n      }"),
      "Nothing retries the sheet when the alarm stops.")
    #expect(
      retry.contains("presentReflectionIfPossible()"),
      "The alarm stopping no longer retries the sheet, so a withheld offer waits for ever.")
  }

  /// The sheet itself carries no silence control, which is *why* it must wait.
  ///
  /// Stated so that a future editor who adds one can delete the guard above
  /// deliberately rather than discovering the reason is gone.
  @Test("theReflectionSheetHasNoSilenceControl")
  func theReflectionSheetHasNoSilenceControl() throws {
    let sheet = try Self.source(of: "ZenTomato/Views/BlockReflectionSheet.swift")

    #expect(sheet.contains("onSilenceAlarm") == false)
    #expect(sheet.contains("silenceAlarm") == false)
  }

  // MARK: Private

  private static func timerViewSource() throws -> String {
    try source(of: "ZenTomato/Views/TimerView.swift")
  }

  /// A file from the source tree, with comments stripped — the lesson
  /// `StatsFenceTests` and `PolishFenceTests` already learned: a fence that
  /// cannot tell a mention from a use fires on the comment explaining the rule.
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
}
