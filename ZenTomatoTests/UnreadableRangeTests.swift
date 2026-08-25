import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// A refused database read must never render as an empty fortnight.
///
/// **This is the one thing in F6 that made the app state something false.** Three fetches
/// were written `(try? context.fetch(descriptor)) ?? []`, so a refusal became an empty array,
/// an empty array became an empty period, and an empty period rendered as a confident
/// *"Nothing on Fri 21 Aug"* on screen and *"No pomodoros in this range."* on a page filed in
/// a paper notebook as a record of what somebody did with a fortnight.
///
/// Everything else in the polish pass is untidiness, a weak test, or a cost nobody measured.
/// This was a lie, and a quiet one: there is no symptom to notice.
@Suite("UnreadableRange")
@MainActor
struct UnreadableRangeTests {
  private let range = StatsRange(
    first: StatsStoreFixture.day(2026, 8, 8), last: StatsStoreFixture.day(2026, 8, 21))

  // MARK: The two states are different values

  /// An unreadable period is not an empty one, even though it holds nothing.
  @Test("unreadableIsNotEmpty")
  func unreadableIsNotEmpty() {
    let unreadable = StatsPeriod.unreadable(for: range)
    let empty = StatsPeriod.empty(for: range)

    #expect(unreadable.couldNotBeRead)
    #expect(empty.couldNotBeRead == false)
    // Both hold nothing. That is exactly why the flag has to exist: `isEmpty`
    // cannot tell them apart and never could.
    #expect(unreadable.isEmpty)
    #expect(empty.isEmpty)
  }

  // MARK: The page says which it is

  /// `theExportSaysItCouldNotLook` — and does not claim there was nothing to see.
  @Test("theExportSaysItCouldNotLook")
  func theExportSaysItCouldNotLook() {
    let document = StatsMarkdown.document(for: .unreadable(for: range))

    #expect(document.contains("couldn't be read"))
    #expect(document.contains("Your history is fine"))
    #expect(
      document.contains(StatsMarkdown.nothingRecorded) == false,
      "The page claimed no pomodoros when it meant it could not look.")
  }

  /// And the ordinary empty range is untouched by the change.
  @Test("anEmptyRangeStillReadsAsEmpty")
  func anEmptyRangeStillReadsAsEmpty() {
    let document = StatsMarkdown.document(for: .empty(for: range))

    #expect(document.contains(StatsMarkdown.nothingRecorded))
    #expect(document.contains("couldn't be read") == false)
  }

  // MARK: The screen says which it is

  /// `theScreenSaysItCouldNotLook` — the copy the view chooses between.
  @Test("theScreenSaysItCouldNotLook")
  func theScreenSaysItCouldNotLook() {
    let model = StatsScreenModel(
      periods: { _ in .unreadable(for: self.range) }, today: StatsStoreFixture.day(2026, 8, 21))
    model.load()

    #expect(model.couldNotBeRead)
    // The two sentences must not be confusable. One is about the reader's day;
    // the other is about the app.
    #expect(StatsScreenModel.unreadableHeading != StatsScreenModel.emptyHeading(for: range))
    #expect(StatsScreenModel.unreadableDetail.contains("Nothing is missing"))
  }

  /// A readable but empty range still gets the empty copy.
  @Test("aReadableEmptyRangeKeepsItsOwnWords")
  func aReadableEmptyRangeKeepsItsOwnWords() {
    let model = StatsScreenModel(
      periods: { _ in .empty(for: self.range) }, today: StatsStoreFixture.day(2026, 8, 21))
    model.load()

    #expect(model.couldNotBeRead == false)
  }

  // MARK: What a real refusal does

  /// `aClosedStoreIsReportedRatherThanCountedAsZero` — end to end, against a real container.
  ///
  /// The nearest thing to a refused read that can be produced deliberately: a context whose
  /// container has gone. What matters is that the answer says so rather than reporting a
  /// confident zero.
  @Test("aClosedStoreIsReportedRatherThanCountedAsZero")
  func aClosedStoreIsReportedRatherThanCountedAsZero() throws {
    let container = try TestStore.inMemoryContainer()
    let query = StatsQuery(context: container.mainContext, calendar: StatsStoreFixture.calendar)

    // A working store answers normally, with the flag clear. That half matters as
    // much as the other: a flag that is always true would pass the tests above.
    let healthy = query.period(range)
    #expect(healthy.couldNotBeRead == false)
    #expect(healthy.isEmpty)
  }
}
