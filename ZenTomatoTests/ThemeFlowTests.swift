import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// `F12` — the theme's journey from the settings row to what the Lock Screen is handed.
///
/// **Written after the adversarial review broke the journey four ways and the suite stayed green.**
/// The colour tables, the Auto rule and the stored setting were each tested; nothing tested that a
/// picked theme ever left Settings. These two tests cover the part a test can reach: settings →
/// engine → alarm request → the metadata the widget decodes.
///
/// **What they cannot reach, stated rather than implied.** The last hop — the widget setting the
/// theme on the card — runs in a separate process no test links, and so does the app's root
/// `.environment(\.theme, …)` in `ThemedRoot`, which is a view modifier this project has no UI test
/// target to observe. Both rest on `F12-T6`, on hardware, and are named there.
@Suite("ThemeFlow")
@MainActor
struct ThemeFlowTests {
  /// A picked theme reaches the alarm request, and from it the widget's metadata (`F12-M8`, `M9`).
  @Test("aPickedThemeReachesTheLockScreensData")
  func aPickedThemeReachesTheLockScreensData() async throws {
    let container = try TestStore.inMemoryContainer()
    let alarms = SpyAlarmScheduler()
    let engine = TimerEngine(context: container.mainContext, clock: TestClock(), alarms: alarms)
    try AppSettings.current(in: container.mainContext).themeChoice = .plum
    try container.mainContext.save()

    await engine.start()

    let request = try #require(alarms.outstanding)
    #expect(request.theme == .plum)
    #expect(AlarmKitScheduler.metadata(for: request).theme == .plum)
  }

  /// Under Auto, the block's theme is Auto's answer at the **engine's** time, not the wall clock's:
  /// a block started at 22:00 is Ink.
  @Test("autoResolvesAtTheEnginesTime")
  func autoResolvesAtTheEnginesTime() async throws {
    let night = try #require(Calendar.current.date(
      from: DateComponents(year: 2026, month: 3, day: 15, hour: 22)))
    let container = try TestStore.inMemoryContainer()
    let alarms = SpyAlarmScheduler()
    let engine = TimerEngine(context: container.mainContext, clock: TestClock(now: night), alarms: alarms)

    await engine.start()

    #expect(try #require(alarms.outstanding).theme == .ink)
  }
}
