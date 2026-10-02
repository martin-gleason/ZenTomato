import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit

@testable import ZenTomato

/// **A bad day changes nothing** — `F16-T5`, the task the plan calls *the ruling*.
///
/// Checked on the **assembled screen**, not on the calculator: each store goes through
/// `TimerView.gardenCount` — the function the garden sheet really calls — into `GardenView`, rendered in
/// a window, and the pixels are compared. A rule about dates written anywhere on that path changes the
/// picture, whatever it is named and wherever it lives; `GardenFenceTests` cannot see a rule outside the
/// garden's own files, and this can.
///
/// The fixtures are dated **relative to now** on purpose: a shrink that waits for the last pom to be a
/// week old can only be seen by comparing a garden whose last pom was yesterday with one whose last pom
/// was a month ago.
@Suite("GardenBadDay", .serialized)
@MainActor
struct GardenBadDayTests {
  /// The same forty-one poms, one store ending yesterday and one ending a month ago: the same garden,
  /// pixel for pixel.
  @Test("theSamePomsOnDifferentDatesDrawTheSameGarden")
  func theSamePomsOnDifferentDatesDrawTheSameGarden() async throws {
    let recent = try Self.store(poms: 41, endingDaysAgo: 1, gapBeforeLast: 0)
    let old = try Self.store(poms: 41, endingDaysAgo: 30, gapBeforeLast: 0)

    #expect(TimerView.gardenCount(in: recent.mainContext) == 41)
    #expect(TimerView.gardenCount(in: old.mainContext) == 41)
    let recentScreen = try await Self.render(recent)
    let oldScreen = try await Self.render(old)
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
    let context = container.mainContext
    window.rootViewController = UIHostingController(
      rootView: GardenView(countFinishedPoms: { TimerView.gardenCount(in: context) }))
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    try await Task.sleep(for: .milliseconds(1200))
    return try #require(Screenshot(window: window))
  }
}
