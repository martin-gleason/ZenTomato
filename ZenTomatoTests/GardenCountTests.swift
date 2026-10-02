import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// **Finished poms, ever** — `F16-T1`, the one number the garden grows from.
///
/// THE RULE THIS IS WRITTEN UNDER, AND THE REASON THERE IS NO SECOND COUNTER
/// `lifetimePomodoroCount()` is `StatsPeriod.pomodoroCount` over a wider span: the same function
/// today's number and the Rhodia export already come from, asked a bigger question. A stored total or
/// an incrementing column would be a second account of something the log already answers, and
/// `StatsFenceTests` exists to refuse exactly that.
///
/// **IT MEASURES BEFORE IT DECIDES.** `ExportCostTests` is the precedent: it timed the all-time path
/// at 57.5 ms over a seeded year and then explicitly declined to optimise it — *"the number is
/// recorded so the next person can decide with it rather than about it."* This suite prints the
/// lifetime query's cost beside that, and `F16`'s `Q5` is where the owner rules on it. **If the number
/// is bad that is a finding, not a licence to add a cache.**
///
/// `@MainActor`: everything here touches SwiftData.
@Suite("GardenCount")
@MainActor
struct GardenCountTests {
  /// **A new install has grown no tomatoes**, and that is a real answer rather than a missing one.
  @Test("anEmptyStoreCountsZero")
  func anEmptyStoreCountsZero() throws {
    let container = try TestStore.inMemoryContainer()
    let query = StatsQuery(context: container.mainContext, calendar: StatsStoreFixture.calendar)

    #expect(query.recordedDayBounds() == nil)
    #expect(query.lifetimePomodoroCount() == 0)
  }

  /// **A refused read is not an empty garden.** Forty poms on disk, the database files overwritten so
  /// SQLite refuses: the count is `nil`, never `0`, and the screen draws its failure, not *"Nothing has
  /// grown here yet"*. Found by `F16`'s adversarial review — the first version said zero, which on
  /// screen is a reset `D48` forbids, and the Pomodoros sheet over the same store said it could not read.
  ///
  /// The files are overwritten the way `WatchTapInboxTests`' `CorruptibleStore` does it, all three:
  /// leaving the write-ahead log intact lets SQLite answer from it, and then nothing is refused.
  @Test("aRefusedReadIsNotAnEmptyGarden")
  func aRefusedReadIsNotAnEmptyGarden() throws {
    let store = try TestStore.temporaryFileStore()
    let container = try AppModelContainer.make(.file(store.storeURL))
    let context = container.mainContext
    for index in 0..<40 {
      context.insert(StatsStoreFixture.work(400_000 + index, from: StatsStoreFixture.at(2026, 3, 2, 9, 0)
        .addingTimeInterval(Double(index) * 1_800)))
    }
    try context.save()
    #expect(TimerView.gardenCount(in: context) == 40, "The precondition: the store is readable first.")

    for suffix in ["", "-wal", "-shm"] {
      let url = URL(fileURLWithPath: store.storeURL.path(percentEncoded: false) + suffix)
      if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
        try Data(repeating: 0x41, count: 4096).write(to: url)
      }
    }

    let count = TimerView.gardenCount(in: context)
    #expect(count == nil, "A refused read came back as \(String(describing: count)).")
    #expect(GardenView.Load(count) == .unreadable)
  }

  /// **The span comes from the data, not from a date somebody typed.**
  ///
  /// A hardcoded start is a claim about a person's history that stops being true the moment they
  /// restore a backup from before it — and the garden would then quietly omit the months that came
  /// back. This seeds a year and asserts the bounds are the year's own edges.
  @Test("theSpanIsTheOneTheDataOccupies")
  func theSpanIsTheOneTheDataOccupies() throws {
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext
    _ = StatsStoreFixture.writeYear(
      into: context, endingOn: StatsStoreFixture.at(2026, 8, 21, 12, 0))
    try context.save()
    let query = StatsQuery(context: context, calendar: StatsStoreFixture.calendar)

    let bounds = try #require(query.recordedDayBounds())
    #expect(bounds.last == StatsStoreFixture.day(2026, 8, 21))
    // The first day is a year earlier, and it is read off the store rather than assumed: whatever
    // the fixture wrote, the bounds must reach it.
    #expect(bounds.first < bounds.last)
    #expect(bounds.first.year == 2025)
  }

  /// **The lifetime count equals the count over the span the data occupies**, exactly.
  ///
  /// Asserted against `period(_:)` over the same range rather than against a number typed here: a
  /// literal would pass whether or not the two paths agreed, and the whole claim of `F16-T1` is that
  /// they are the same function.
  @Test("theLifetimeCountIsTheSameFunctionOverAWiderSpan")
  func theLifetimeCountIsTheSameFunctionOverAWiderSpan() throws {
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext
    let written = StatsStoreFixture.writeYear(
      into: context, endingOn: StatsStoreFixture.at(2026, 8, 21, 12, 0))
    try context.save()
    let query = StatsQuery(context: context, calendar: StatsStoreFixture.calendar)

    let bounds = try #require(query.recordedDayBounds())
    let overTheSpan = query.period(StatsRange(first: bounds.first, last: bounds.last)).pomodoroCount

    #expect(query.lifetimePomodoroCount() == overTheSpan)
    // And it is a real count of the seeded history rather than zero passing both sides.
    #expect(overTheSpan > 0)
    #expect(overTheSpan <= written)
  }

  /// **The measurement `Q5` is ruled on.**
  ///
  /// Printed beside `ExportCostTests`' existing figures, over the same seeded year, so the two are
  /// comparable. The threshold is deliberately loose: this test exists to produce a NUMBER, and a
  /// tight bound here would turn a measurement into a flaky gate on whatever machine runs it.
  @Test("theLifetimeCountIsMeasured")
  func theLifetimeCountIsMeasured() throws {
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext
    let written = StatsStoreFixture.writeYear(
      into: context, endingOn: StatsStoreFixture.at(2026, 8, 21, 12, 0))
    try context.save()
    let query = StatsQuery(context: context, calendar: StatsStoreFixture.calendar)
    let clock = ContinuousClock()

    let bounding = clock.measure { _ = query.recordedDayBounds() }
    let lifetime = clock.measure { _ = query.lifetimePomodoroCount() }
    let count = query.lifetimePomodoroCount()

    print("GARDEN lifetime count, \(written) blocks over a year")
    print("  bounding the span : \(bounding)")
    print("  whole count       : \(lifetime)")
    print("  poms counted      : \(count)")
    print("  -> F16 Q5 is ruled on this number. ExportCostTests measured the")
    print("     all-time export path at 57.5 ms over the same shape of store.")

    #expect(lifetime < .milliseconds(500))
  }
}
