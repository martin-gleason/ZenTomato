import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// **A finished pom makes the garden bigger; a stopped block does not** — `F16-T4`, end to end.
///
/// From the engine's own write to the garden's rows, through the same path the screen uses: the timer
/// records the block, `StatsQuery` counts it, `Garden` turns the count into rows. Nothing here builds
/// a row by hand, so a rule anywhere on that path that disagreed with the log would show.
///
/// **The stop rule is not restated here.** An abandoned block is not a pom because `CountedBlock.init?`
/// says so; this suite only checks that the garden agrees, which is the point — the garden must not
/// grow a second opinion about what counts.
@Suite("GardenGrows")
@MainActor
struct GardenGrowsTests {
  // MARK: Lifecycle

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  // MARK: Internal

  /// Run a focus block to its end: the garden is exactly one pom larger, and its count is the one the
  /// Pomodoros sheet would show for the same span.
  @Test("aFinishedPomMakesTheGardenOneBigger")
  func aFinishedPomMakesTheGardenOneBigger() async throws {
    let clock = TestClock()
    let engine = TimerEngine(context: context, clock: clock, alarms: SpyAlarmScheduler())
    let before = query.lifetimePomodoroCount()

    await engine.start()
    let due = try #require(engine.endsAt)
    clock.advance(by: due.timeIntervalSince(clock.now))
    await engine.boundaryReached()

    let after = query.lifetimePomodoroCount()
    #expect(after == before + 1)
    #expect(Garden(finishedPoms: after) == Garden(finishedPoms: before + 1))
    #expect(Garden(finishedPoms: after) != Garden(finishedPoms: before))

    // The same function as the counting screen, not a second tally beside it.
    let bounds = try #require(query.recordedDayBounds())
    #expect(after == query.period(StatsRange(first: bounds.first, last: bounds.last)).pomodoroCount)
  }

  /// Stop a block thirty seconds in, with a reason: the garden is unchanged, and the stop is still in
  /// the log — the garden ignores it, the record does not.
  @Test("aStoppedBlockLeavesTheGardenAlone")
  func aStoppedBlockLeavesTheGardenAlone() async throws {
    let clock = TestClock()
    let engine = TimerEngine(context: context, clock: clock, alarms: SpyAlarmScheduler())
    let before = query.lifetimePomodoroCount()

    await engine.start()
    clock.advance(by: 30)
    await engine.stop(reason: "Phone call")

    #expect(query.lifetimePomodoroCount() == before)
    #expect(Garden(finishedPoms: query.lifetimePomodoroCount()) == Garden(finishedPoms: before))

    let rows = try context.fetch(FetchDescriptor<PomodoroSession>())
    #expect(rows.count == 1, "The stopped block is not in the log.")
    #expect(rows.first?.wasAbandoned == true)
  }

  // MARK: Private

  private let container: ModelContainer

  private var context: ModelContext {
    container.mainContext
  }

  private var query: StatsQuery {
    StatsQuery(context: context)
  }
}
