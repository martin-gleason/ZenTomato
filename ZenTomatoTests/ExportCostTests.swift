import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// What the export path actually costs, measured before anything is optimised.
///
/// **This project's rule is that assertions are not evidence, and it applies to speed.**
/// Before this file the only numbers anyone had were `period(fortnight)` at ~3 ms and
/// `period(.day)` at ~1 ms. Everything else was assumed — including the belief that
/// `refreshExport()` running synchronously on the main actor, on every range change, whether
/// or not anybody taps Export, was a problem worth fixing.
///
/// It may not be. **Measuring first is also what keeps the pass inside v0.1**: speculative
/// machinery never has a number behind it, so a rule that nothing changes without one keeps
/// the scope honest as a side effect of keeping the optimisation honest.
///
/// **What cannot be measured here, stated rather than skipped:** the Todoist refresh needs a
/// real account, the music library needs authorisation and a device, and watch delivery needs
/// hardware. Those three are device measurements and are recorded as such — a number this
/// file could produce for them would be a number about a stand-in.
///
/// ## What the numbers said, and what was NOT done because of them
///
/// Measured over 1,044 blocks — a year of use:
///
/// |                | fortnight | all-time (261 days) |
/// |----------------|-----------|---------------------|
/// | query          | 3.1 ms    | **57.5 ms**         |
/// | document build | 1.0 ms    | 5.0 ms              |
/// | file write     | 0.7 ms    | 0.7 ms              |
///
/// **A3 is closed by measurement, not by argument.** The suspicion was that `refreshExport()`
/// building the whole document and writing it, synchronously on the main actor on every range
/// change, was worth moving off. It is 5.7 ms combined for a *year* — a third of one frame.
/// Moving it would have been speculative work justified by how the code reads.
///
/// **The cost is the query, and it is deliberately left alone.** 57 ms for an all-time range
/// is 3.6× the frame budget. It is also roughly 0.22 ms per day of range, so the budget is
/// crossed at about ten weeks — and the default range is a fortnight, at 3 ms.
///
/// `F6-contract.md` pre-decided the escalation and then warned against taking it:
/// *"a MEASURED 16 ms budget with a pre-decided escalation to a `@ModelActor` — **not to be
/// taken pre-emptively, since a suspension point is where the last two features found their
/// real bugs**."* That warning is worth more than the hitch. Introducing a suspension point
/// into the counting core — the one thing three adversarial reviews certified as correct —
/// to remove a single 57 ms pause on a deliberate, rare action, twenty days from a hard stop,
/// is a bad trade. The number is recorded so the next person can decide with it rather than
/// about it.
@Suite("ExportCost")
@MainActor
struct ExportCostTests {
  /// `theExportPathIsMeasured` — the document build and the file write, separately.
  ///
  /// Separately on purpose. They are different costs with different fixes: building is CPU
  /// and would move off the actor, writing is disk and would move off the *path* — done when
  /// somebody taps Export rather than on every range change. Measuring them together would
  /// hide which one, if either, is worth touching.
  @Test("theExportPathIsMeasured")
  func theExportPathIsMeasured() throws {
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext
    let written = StatsStoreFixture.writeYear(
      into: context, endingOn: StatsStoreFixture.at(2026, 8, 21, 12, 0))
    try context.save()
    let query = StatsQuery(context: context, calendar: StatsStoreFixture.calendar)

    let period = query.period(StatsStoreFixture.fortnightRange)
    let clock = ContinuousClock()

    let build = clock.measure { _ = StatsMarkdown.document(for: period) }
    let document = StatsMarkdown.document(for: period)
    let write = clock.measure {
      _ = try? StatsExportFile.write(document: document, filename: "ZenTomato-cost.md")
    }

    print("""

      ── export cost, over \(written) blocks ──
        document build : \(build)
        file write     : \(write)
        document size  : \(document.count) characters

      """)

    // THE BUDGET IS A FRAME — 16 MS — AND THE BOUND IS NOT.
    //
    // `aFortnightIsCountedQuicklyOverAYearOfRows` already argues this and it is right: a test
    // asserting 16 ms fails on a loaded build machine for reasons that have nothing to do
    // with this code, and **a flaky gate is a gate people learn to re-run**. So the budget is
    // what the printed number is read against by a person, and the bound is set where a real
    // regression lives — an accidental read or format per row would be seconds, not
    // milliseconds.
    //
    // 250 ms rather than that test's one second, which is sixty times the budget and could
    // not fail. This is A9.
    #expect(build < .milliseconds(250), "Building the page has become an order of magnitude slower.")
    #expect(write < .milliseconds(250), "Writing the page has become an order of magnitude slower.")
  }

  /// `aYearLongPageIsStillCheap` — the case that actually worried anyone.
  ///
  /// A fortnight's page is about 1,500 characters and costs a millisecond, which was never in
  /// doubt. **`F6.md` names the real risk as "an all-time export after months of use"**, and
  /// that is what this measures: every row in the store rendered into one document.
  ///
  /// If this is cheap, `refreshExport()` running on the main actor is not worth moving, and
  /// A3 is closed by measurement rather than by argument.
  @Test("aYearLongPageIsStillCheap")
  func aYearLongPageIsStillCheap() throws {
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext
    let written = StatsStoreFixture.writeYear(
      into: context, endingOn: StatsStoreFixture.at(2026, 8, 21, 12, 0))
    try context.save()
    let query = StatsQuery(context: context, calendar: StatsStoreFixture.calendar)

    let wholeYear = StatsRange(
      first: StatsStoreFixture.day(2025, 8, 21), last: StatsStoreFixture.day(2026, 8, 21))
    let clock = ContinuousClock()

    let counted = clock.measure { _ = query.period(wholeYear) }
    let period = query.period(wholeYear)
    let build = clock.measure { _ = StatsMarkdown.document(for: period) }
    let document = StatsMarkdown.document(for: period)
    let write = clock.measure {
      _ = try? StatsExportFile.write(document: document, filename: "ZenTomato-year.md")
    }

    print("ALL-TIME export, \(written) blocks over a year")
    print("  count          : \(counted)")
    print("  document build : \(build)")
    print("  file write     : \(write)")
    print("  document size  : \(document.count) characters")
    print("  days on page   : \(period.days.count)")

    #expect(build < .milliseconds(250))
    #expect(write < .milliseconds(250))
  }

  /// `theWholeYearIsNotBuiltForAFortnight` — the cost scales with the answer, not the store.
  ///
  /// The real risk in the export path is not one slow build; it is a build whose cost grows
  /// with everything ever recorded. A fortnight's page must cost a fortnight, however many
  /// years sit behind it.
  @Test("theWholeYearIsNotBuiltForAFortnight")
  func theWholeYearIsNotBuiltForAFortnight() throws {
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext
    _ = StatsStoreFixture.writeYear(
      into: context, endingOn: StatsStoreFixture.at(2026, 8, 21, 12, 0))
    try context.save()
    let query = StatsQuery(context: context, calendar: StatsStoreFixture.calendar)

    let fortnight = query.period(StatsStoreFixture.fortnightRange)
    let clock = ContinuousClock()
    let cost = clock.measure { _ = StatsMarkdown.document(for: fortnight) }

    print("  fortnight page from a year of data: \(cost)")
    #expect(cost < .milliseconds(250))
  }
}
