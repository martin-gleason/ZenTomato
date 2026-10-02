import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit

@testable import ZenTomato

/// **A bad day changes nothing** — `F16-T5`, the task the plan calls *the ruling*.
///
/// Checked on the **assembled screen**, not on the calculator: each store goes through
/// `TimerView.gardenSheet` — the sheet the app really opens, which
/// `GardenFenceTests.theSheetIsTheOneTheTestsDraw` pins — rendered in a window, and the pixels are
/// compared. A rule about dates written anywhere on that path changes the picture.
///
/// The fixtures are dated **relative to now** on purpose: a shrink that waits for the last pom to be a
/// week old can only be seen by comparing a garden whose last pom was yesterday with one whose last pom
/// was a month ago.
@Suite("GardenBadDay", .serialized)
@MainActor
struct GardenBadDayTests {
  /// The same twenty-four poms, one store ending yesterday and one ending a month ago: the same garden,
  /// pixel for pixel — and twenty-three poms draw a different one, so a rule that took one away would show.
  ///
  /// **Twenty-four, not forty-one, and the reason is a miss.** This test first used forty-one, and a rule
  /// taking one pom from a month-old garden (`F16-M13b`) passed it: forty and forty-one draw the same
  /// picture (`Q9`), so the shrink was real and invisible. Its earlier "catch" of `F16-M3` was a timing
  /// flake, since fixed. At twenty-four, one pom is the whole difference between two pictures.
  @Test("theSamePomsOnDifferentDatesDrawTheSameGarden")
  func theSamePomsOnDifferentDatesDrawTheSameGarden() async throws {
    let recent = try Self.store(poms: 24, endingDaysAgo: 1, gapBeforeLast: 0)
    let old = try Self.store(poms: 24, endingDaysAgo: 30, gapBeforeLast: 0)
    let oneFewer = try Self.store(poms: 23, endingDaysAgo: 1, gapBeforeLast: 0)

    #expect(TimerView.gardenCount(in: recent.mainContext) == 24)
    #expect(TimerView.gardenCount(in: old.mainContext) == 24)
    let recentScreen = try await Self.render(recent)
    let oldScreen = try await Self.render(old)
    let oneFewerScreen = try await Self.render(oneFewer)
    #expect(recentScreen != oneFewerScreen, "One pom makes no visible difference here; this test sees nothing.")
    #expect(recentScreen == oldScreen, "The garden looks different because of when the poms happened.")
  }

  /// Twenty-three poms, twenty-three days of nothing, then one more: exactly the garden of twenty-four
  /// poms with no gap — nothing on the screen knows there was one.
  ///
  /// **Twenty-three and twenty-four, chosen because the extra pom is visible there.** The first draft
  /// used forty and forty-one and failed its own last check: past the first full row an item stands for
  /// four poms, so forty-one draws exactly what forty does. That is the design (`F16-T2`), and it is put
  /// to the owner as a question rather than hidden by a friendlier number elsewhere.
  @Test("aGapLeavesNoTrace")
  func aGapLeavesNoTrace() async throws {
    let gap = try Self.store(poms: 24, endingDaysAgo: 1, gapBeforeLast: 23)
    let noGap = try Self.store(poms: 24, endingDaysAgo: 1, gapBeforeLast: 0)

    #expect(TimerView.gardenCount(in: gap.mainContext) == 24)
    let gapScreen = try await Self.render(gap)
    let noGapScreen = try await Self.render(noGap)
    #expect(gapScreen == noGapScreen, "A gap changed the garden.")

    // And the garden is the one twenty-four poms grow, not the one twenty-three would.
    let before = try Self.store(poms: 23, endingDaysAgo: 1, gapBeforeLast: 0)
    let beforeScreen = try await Self.render(before)
    #expect(gapScreen != beforeScreen, "The pom after the gap did not grow anything.")
  }

  // MARK: Private

  /// `poms` finished blocks, four a day going back from `endingDaysAgo`, with `gapBeforeLast` empty
  /// days between the last block and the rest.
  private static func store(poms: Int, endingDaysAgo: Int, gapBeforeLast: Int) throws -> ModelContainer {
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext
    let calendar = Calendar.current
    let lastDay = try #require(calendar.date(byAdding: .day, value: -endingDaysAgo, to: calendar.startOfDay(for: .now)))
    for index in 0..<poms {
      let back = index == 0 ? 0 : gapBeforeLast + 1 + (index - 1) / 4
      let day = try #require(calendar.date(byAdding: .day, value: -back, to: lastDay))
      let start = day.addingTimeInterval(Double(9 * 3600 + (index % 4) * 1_800))
      context.insert(StatsStoreFixture.work(300_000 + index, from: start))
    }
    try context.save()
    return container
  }

  /// The garden sheet's content, drawn through the real count function, as pixels.
  private static func render(_ container: ModelContainer) async throws -> Screenshot {
    let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
    window.overrideUserInterfaceStyle = .light
    // **The theme pinned on this window, not left to the scene.** These windows share a scene with the
    // app the suite runs inside, whose Auto theme rewrites the scene's theme on the hour — one run of
    // this test straddled 15:00 and its two renders drew different themes. `ThemeReachesSheetsTests`
    // also sets the scene's theme while other suites run. A window's own override wins over both.
    window.traitOverrides[ThemeTrait.self] = .sage
    let context = container.mainContext
    window.rootViewController = UIHostingController(rootView: TimerView.gardenSheet(in: context))
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    return try await settled(window)
  }

  /// The screen once the tomatoes are on it and it has stopped changing: two shots in a row identical.
  ///
  /// **A fixed wait was the first version and it flaked**: under the full parallel suite, 1.2 seconds
  /// sometimes caught a frame before `.task` had counted, and two stores drew "different" gardens.
  /// Polled instead, with a ceiling so a broken screen ends the test rather than hanging it. **"Drawn"
  /// means the fruit's own colour is on screen** — the title is there before the count, and two
  /// identical title-only frames would make every comparison here pass on nothing.
  private static func settled(_ window: UIWindow) async throws -> Screenshot {
    var previous: Screenshot?
    for _ in 0..<40 {
      try await Task.sleep(for: .milliseconds(250))
      let shot = try #require(Screenshot(window: window))
      if let previous, previous == shot, shot.contains(ColorRole.tomatoFlesh.light.description) { return shot }
      previous = shot
    }
    Issue.record("The garden never settled.")
    return try #require(previous)
  }
}
