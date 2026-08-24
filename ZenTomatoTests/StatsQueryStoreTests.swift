import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// The counting rule run over a real store: what the database reads bring back,
/// what they leave behind, and what the whole documented fortnight adds up to.
///
/// `StatsCountingTests` is about the rules. This file is about the seams either
/// side of them — the half-open window, the widened tap window, the row that
/// matches nothing — because those are the places where a rule that is written
/// correctly still produces the wrong answer.
@Suite("StatsQueryStore")
@MainActor
struct StatsQueryStoreTests {
  private let container: ModelContainer

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  private var context: ModelContext {
    container.mainContext
  }

  private var query: StatsQuery {
    StatsQuery(context: context, calendar: StatsStoreFixture.calendar)
  }

  private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> StatsDay {
    StatsStoreFixture.day(year, month, dayOfMonth)
  }

  // MARK: The window

  /// A block beginning at exactly midnight belongs to one span and one only.
  ///
  /// The window is half-open, so the block below is in the later span and not
  /// in the earlier one. An inclusive upper bound would put it in both, and a
  /// fortnight boundary would then count one block twice a fortnight, for ever,
  /// with nothing to notice.
  @Test("aBlockAtExactlyMidnightBelongsToOneSpanOnly")
  func aBlockAtExactlyMidnightBelongsToOneSpanOnly() throws {
    context.insert(StatsStoreFixture.block(
      1,
      from: StatsStoreFixture.at(2026, 8, 20, 0, 0),
      to: StatsStoreFixture.at(2026, 8, 20, 0, 25),
      task: "Ch.3 draft"))
    try context.save()

    let before = query.period(StatsRange(first: day(2026, 8, 18), last: day(2026, 8, 19)))
    let after = query.period(StatsRange(first: day(2026, 8, 20), last: day(2026, 8, 21)))

    #expect(before.pomodoroCount == 0)
    #expect(after.pomodoroCount == 1)
  }

  /// A block outside the span is not counted, and does not drag its day in.
  @Test("aBlockOutsideTheSpanIsNotCounted")
  func aBlockOutsideTheSpanIsNotCounted() throws {
    context.insert(StatsStoreFixture.block(
      1,
      from: StatsStoreFixture.at(2026, 8, 1, 9, 0),
      to: StatsStoreFixture.at(2026, 8, 1, 9, 25),
      task: "Ch.3 draft"))
    try context.save()

    let period = query.period(StatsRange(first: day(2026, 8, 8), last: day(2026, 8, 21)))

    #expect(period.isEmpty)
    #expect(period.days.isEmpty)
  }

  /// A tap that falls outside the span is still fetched when its block began
  /// inside it.
  ///
  /// The tap below is at 00:05 on 22 August, which is past the end of a span
  /// ending on the 21st. It belongs to a block that began at 23:50 on the 21st,
  /// so it must be read anyway — and it lands on the 21st, where the block it
  /// interrupted is counted. Bounding the tap read at the calendar rather than
  /// at the blocks is what drops it, and the symptom is a day whose tally is
  /// one short of the taps beneath it.
  @Test("aTapPastTheEndOfTheSpanIsStillReadWhenItsBlockBeganInside")
  func aTapPastTheEndOfTheSpanIsStillReadWhenItsBlockBeganInside() throws {
    context.insert(StatsStoreFixture.block(
      1,
      from: StatsStoreFixture.at(2026, 8, 21, 23, 50),
      to: StatsStoreFixture.at(2026, 8, 22, 0, 15),
      task: "Ch.3 draft"))
    context.insert(StatsStoreFixture.tap(
      in: 1, at: StatsStoreFixture.at(2026, 8, 22, 0, 5), kind: .internalInterruption, note: "drifted"))
    try context.save()

    let period = query.period(StatsRange(first: day(2026, 8, 8), last: day(2026, 8, 21)))

    #expect(period.internalCount == 1)
    #expect(period.days.map(\.day) == [day(2026, 8, 21)])
  }

  /// A tap made just after midnight on the first day of the span keeps the task
  /// of the block it was tapped in — and is counted on **that block's** day,
  /// which is outside the span.
  ///
  /// **This was a real defect, found by reading the query rather than by a
  /// failing test.** The block began at 23:50 on the 7th, so a read bounded at
  /// the span's own first day never saw it, the tap matched nothing, and it was
  /// shown on the 8th with no task against it — one nameless tap inflating the
  /// first day of every fortnight. The read now reaches one day further back
  /// for the sole purpose of recognising taps, and those extra blocks are never
  /// counted: the 7th is not part of this answer, so neither is its tap.
  @Test("aTapBelongingToTheNightBeforeTheSpanIsNotCountedInIt")
  func aTapBelongingToTheNightBeforeTheSpanIsNotCountedInIt() throws {
    context.insert(StatsStoreFixture.block(
      1,
      from: StatsStoreFixture.at(2026, 8, 7, 23, 50),
      to: StatsStoreFixture.at(2026, 8, 8, 0, 15),
      task: "Ch.3 draft"))
    context.insert(StatsStoreFixture.tap(
      in: 1, at: StatsStoreFixture.at(2026, 8, 8, 0, 5), kind: .internalInterruption, note: "drifted"))
    try context.save()

    let span = query.period(StatsRange(first: day(2026, 8, 8), last: day(2026, 8, 21)))

    #expect(span.isEmpty)
    #expect(span.internalCount == 0)

    // Ask about the day it really belongs to and it is all there, with its task.
    let theNightBefore = query.period(.day(day(2026, 8, 7)))
    #expect(theNightBefore.pomodoroCount == 1)
    #expect(theNightBefore.internalCount == 1)
    #expect(theNightBefore.days.first?.distractions.first?.taskTitle == "Ch.3 draft")
  }

  /// A tap whose block is not there is shown, not deleted.
  ///
  /// `Distraction.swift` promises this in its own documentation: an unmatched
  /// row must be shown as having no block rather than treated as an error. The
  /// engine has no path that produces one, so this is a branch that exists to
  /// make a future bug visible instead of silent — a log that quietly omits
  /// taps is the flattering record `PomodoroSession.swift` argues against.
  @Test("aTapWhoseBlockIsMissingStillAppears")
  func aTapWhoseBlockIsMissingStillAppears() throws {
    context.insert(StatsStoreFixture.tap(
      in: 99, at: StatsStoreFixture.at(2026, 8, 19, 14, 32), kind: .internalInterruption, note: "orphan"))
    try context.save()

    let period = query.period(.day(day(2026, 8, 19)))
    let entry = try #require(period.days.first?.distractions.first)

    #expect(period.internalCount == 1)
    #expect(entry.day == day(2026, 8, 19))
    #expect(entry.time == StatsClockTime(hour: 14, minute: 32))
    #expect(entry.taskTitle == nil)
    #expect(entry.projectTitle == nil)
  }

  // MARK: Empty and nearly empty

  /// Nothing recorded is nothing recorded, and the span it was asked about
  /// survives so the reader can still say which span was empty.
  @Test("anEmptySpanIsEmptyAndStillKnowsWhichSpanItWas")
  func anEmptySpanIsEmptyAndStillKnowsWhichSpanItWas() {
    let range = StatsRange(first: day(2026, 8, 8), last: day(2026, 8, 21))
    let period = query.period(range)

    #expect(period.isEmpty)
    #expect(period.range == range)
    #expect(period.recordedSpan == nil)
    #expect(period.pomodoroCount == 0)
    #expect(period.distractionKinds.isEmpty)
  }

  /// A span holding three stops and no finished blocks is **not** empty.
  ///
  /// The boundary is exact and worth locking: the document has a short form for
  /// a span where nothing happened, and a fortnight in which somebody started
  /// three blocks and stopped all three is not that. It is a fortnight with
  /// something to say.
  @Test("aSpanWithOnlyStopsIsNotEmpty")
  func aSpanWithOnlyStopsIsNotEmpty() throws {
    for number in 1...3 {
      context.insert(StatsStoreFixture.block(
        number,
        from: StatsStoreFixture.at(2026, 8, 18 + number, 9, 0),
        to: StatsStoreFixture.at(2026, 8, 18 + number, 9, 6),
        task: "Ch.3 draft",
        stoppedBecause: "too tired to take any of it in"))
    }
    try context.save()

    let period = query.period(StatsRange(first: day(2026, 8, 8), last: day(2026, 8, 21)))

    #expect(period.isEmpty == false)
    #expect(period.pomodoroCount == 0)
    #expect(period.stops.count == 3)
    #expect(period.days.count == 3)
    #expect(period.days.allSatisfy { $0.pomodoroCount == 0 })
  }

  // MARK: The whole documented fortnight

  /// Every number in `StatsStoreFixture`'s own tables, checked.
  ///
  /// This is the reference the hand-built period on the other side of the seam
  /// is built to match, so it is written out in full rather than summarised. If
  /// either fixture drifts, this fails first and says which number moved.
  @Test("theFortnightFixtureCountsAsDocumented")
  func theFortnightFixtureCountsAsDocumented() throws {
    try StatsStoreFixture.writeFortnight(into: context)
    let period = query.period(StatsStoreFixture.fortnightRange)

    #expect(period.pomodoroCount == 9)
    #expect(period.focusedSeconds == 9 * 25 * 60)
    #expect(period.internalCount == 3)
    #expect(period.externalCount == 3)

    // Friday the 21st is absent, and that is the midnight rule showing: the
    // last block ended at 00:15 on Friday and belongs entirely to Thursday.
    #expect(period.days.map(\.day) == [
      day(2026, 8, 8), day(2026, 8, 10), day(2026, 8, 12),
      day(2026, 8, 13), day(2026, 8, 18), day(2026, 8, 20)
    ])
    #expect(period.days.map(\.pomodoroCount) == [2, 3, 1, 2, 0, 1])
    #expect(period.days.map(\.internalCount) == [1, 1, 0, 0, 0, 1])
    #expect(period.days.map(\.externalCount) == [1, 0, 0, 1, 1, 0])

    // The named project first, the group for blocks with no project last.
    #expect(period.projects.map(\.title) == ["Thesis", nil])
    #expect(period.projects.map(\.pomodoroCount) == [7, 2])
    #expect(period.projects.first?.tasks.map(\.title) == ["Ch.3 draft", "Reading · notes", nil])
    #expect(period.projects.last?.tasks.map(\.title) == ["Marta's feedback"])

    // Busiest task first across the whole span, and the unnamed row last.
    #expect(period.taskRows.map(\.title) == [
      "Ch.3 draft", "Reading · notes", "Marta's feedback", nil
    ])

    #expect(period.stops.map(\.day) == [day(2026, 8, 12), day(2026, 8, 13), day(2026, 8, 18)])
    #expect(period.stops.map(\.time) == [
      StatsClockTime(hour: 16, minute: 20),
      StatsClockTime(hour: 11, minute: 2),
      StatsClockTime(hour: 14, minute: 40)
    ])
    #expect(period.stops.map(\.kind) == [.work, .shortBreak, .work])
    #expect(period.stops.map(\.title) == ["Ch.3 draft", nil, "Ch.3 draft"])
    #expect(period.stops.map(\.reason) == [
      "supervisor called and it ran long", nil, "couldn't settle at all"
    ])

    #expect(period.completions.map(\.title) == [
      "Pick 1–3 MITs",
      "Pick 1–3 MITs",
      "Pick 1–3 MITs",
      "Reading list for week 3",
      "Pick 1–3 MITs",
      "Pick 1–3 MITs",
      "Send Marta the outline"
    ])
    #expect(period.repeatingCompletions.count == 5)
    #expect(period.oneOffCompletions.map(\.title) == [
      "Reading list for week 3", "Send Marta the outline"
    ])

    #expect(period.distractionsByTask.map(\.taskTitle) == [
      "Ch.3 draft", "Marta's feedback", "Reading · notes"
    ])
    #expect(period.distractionsByTask.map(\.count) == [4, 1, 1])

    // The span the data occupies, which is not the span that was asked about.
    #expect(period.recordedSpan == StatsRange(first: day(2026, 8, 8), last: day(2026, 8, 20)))
  }

  /// **The merge gate.** The rows a timer would have written, run through the
  /// one counting rule, produce exactly the fortnight the exported document is
  /// rendered from.
  ///
  /// This is the most valuable test in the feature and it is worth saying why.
  /// The golden file proves that a given `StatsPeriod` renders to a given page.
  /// On its own that is a fact about a string function: a beautiful document
  /// could be rendered from numbers no timer ever produced. This test is the
  /// other half — it ties that page to blocks, taps and completions in a real
  /// store, counted by the code the app actually runs.
  ///
  /// When it fails, one of the two fixtures has drifted from the other. The
  /// test above says which number moved.
  @Test("theFixtureStoreProducesTheFixturePeriod")
  func theFixtureStoreProducesTheFixturePeriod() throws {
    try StatsStoreFixture.writeFortnight(into: context)

    let counted = query.period(StatsPeriodFixture.range)

    #expect(counted.days == StatsPeriodFixture.days)
    #expect(counted.projects == StatsPeriodFixture.projects)
    #expect(counted.completions == StatsPeriodFixture.completions)
    #expect(counted.stops == StatsPeriodFixture.stops)
    // And the whole thing, so that nothing added later can slip between the
    // four comparisons above.
    #expect(counted == StatsPeriodFixture.fortnight)
  }

  /// Today's number comes from the same function as everything else.
  ///
  /// There is no second method for it, and this is the test that would have to
  /// be rewritten before one could exist. `period(.day(today)).pomodoroCount`
  /// is the whole of what the stats screen opens with.
  @Test("todaysNumberIsTheSameFunctionAsTheFortnight")
  func todaysNumberIsTheSameFunctionAsTheFortnight() throws {
    try StatsStoreFixture.writeFortnight(into: context)

    let monday = query.period(.day(day(2026, 8, 10)))
    let fortnight = query.period(StatsStoreFixture.fortnightRange)
    let sameDayInsideTheFortnight = fortnight.days.first { $0.day == day(2026, 8, 10) }

    #expect(monday.pomodoroCount == 3)
    #expect(monday.pomodoroCount == sameDayInsideTheFortnight?.pomodoroCount)
    #expect(monday.focusedSeconds == sameDayInsideTheFortnight?.focusedSeconds)
  }

  /// A project group's heading cannot disagree with the lines under it, and the
  /// days cannot disagree with the projects.
  ///
  /// Both are true by construction — the totals are sums over the rows, and the
  /// days and the projects are filled from the same blocks — which is exactly
  /// why it is worth one test saying so. A structural guarantee nobody checks
  /// is a structural guarantee until somebody stores a total.
  @Test("totalsAgreeBetweenDaysAndProjects")
  func totalsAgreeBetweenDaysAndProjects() throws {
    try StatsStoreFixture.writeFortnight(into: context)

    let period = query.period(StatsStoreFixture.fortnightRange)
    let byProject = period.projects.reduce(0) { $0 + $1.pomodoroCount }
    let internalByProject = period.projects.reduce(0) { $0 + $1.internalCount }
    let externalByProject = period.projects.reduce(0) { $0 + $1.externalCount }

    #expect(period.pomodoroCount == byProject)
    #expect(period.internalCount == internalByProject)
    #expect(period.externalCount == externalByProject)
    #expect(period.focusedSeconds == period.projects.reduce(0) { $0 + $1.focusedSeconds })
    #expect(period.distractionCount == period.days.reduce(0) { $0 + $1.distractions.count })
  }

  /// Recurring completions are separated from one-offs, using what Todoist said
  /// rather than how often a title repeats (D21).
  @Test("repeatingCompletionsAreSeparatedFromOneOffs")
  func repeatingCompletionsAreSeparatedFromOneOffs() throws {
    try StatsStoreFixture.writeFortnight(into: context)

    let period = query.period(StatsStoreFixture.fortnightRange)

    #expect(period.completions.count == 7)
    #expect(period.repeatingCompletions.count == 5)
    #expect(Set(period.repeatingCompletions.map(\.title)) == ["Pick 1–3 MITs"])
    #expect(period.oneOffCompletions.map(\.title) == [
      "Reading list for week 3", "Send Marta the outline"
    ])
  }
  // MARK: Speed

  /// A year of rows in the store, and a fortnight still comes back in one pass.
  ///
  /// **The assertion is deliberately loose and the measurement is the point.**
  /// The build contract's budget is one frame — sixteen milliseconds — and it
  /// asks for the measured number in the pull request rather than a promise. A
  /// test that asserted sixteen milliseconds would fail on a loaded build
  /// machine for reasons that have nothing to do with this code, and a flaky
  /// gate is a gate people learn to re-run. So the bound here is the one that
  /// catches a real regression — an accidental read per row would be seconds,
  /// not milliseconds — and the number itself is printed for the pull request.
  @Test("aFortnightIsCountedQuicklyOverAYearOfRows")
  func aFortnightIsCountedQuicklyOverAYearOfRows() throws {
    let written = StatsStoreFixture.writeYear(
      into: context, endingOn: StatsStoreFixture.at(2026, 8, 21, 12, 0))
    try context.save()

    let clock = ContinuousClock()
    let fortnight = clock.measure { _ = query.period(StatsStoreFixture.fortnightRange) }
    let today = clock.measure { _ = query.period(.day(day(2026, 8, 21))) }

    print("period(fortnight) over \(written) blocks: \(fortnight)")
    print("period(.day(today)) over \(written) blocks: \(today)")

    #expect(fortnight < .seconds(1))
    #expect(today < .seconds(1))
    // And the answer is still only the fortnight, not the year.
    #expect(query.period(StatsStoreFixture.fortnightRange).days.count == 10)
  }
}
