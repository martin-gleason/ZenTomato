import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// A tap made on the wrist, becoming a row on the phone.
///
/// `docs/plans/F7.md` names four of these by hand — `duplicateTapIgnored`,
/// `timestampIsTapTimeNotDeliveryTime`, `lateTapAttachesToItsSession` and
/// `lateTapInheritsTaskSnapshot`. They are the four ways this path can be wrong
/// while looking entirely ordinary, which is what makes them worth naming in a
/// plan rather than leaving to whoever writes the code.
@Suite("WatchTapInbox")
@MainActor
struct WatchTapInboxTests {
  private let container: ModelContainer

  init() throws {
    container = try TestStore.inMemoryContainer()
  }

  private var context: ModelContext { container.mainContext }
  private var inbox: WatchTapInbox { WatchTapInbox(context: context) }

  private func taps() throws -> [Distraction] {
    try context.fetch(FetchDescriptor<Distraction>(sortBy: [SortDescriptor(\.timestamp)]))
  }

  // MARK: The four F7.md names

  /// `duplicateTapIgnored` — the same tap twice is one row.
  ///
  /// **WatchConnectivity delivers at least once, not exactly once.** The system
  /// may hand the same payload over again after a relaunch or a flaky link, and
  /// nothing marks the second copy as a repeat. Without the id check this is two
  /// distractions where there was one — and the error is invisible, plausible,
  /// and always upward, in the numbers the fortnightly review is read from.
  @Test("duplicateTapIgnored")
  func duplicateTapIgnored() throws {
    let tap = WatchTap(
      id: UUID(),
      kind: .internalInterruption,
      tappedAt: Date(timeIntervalSince1970: 1_756_000_000),
      sessionID: UUID())

    #expect(inbox.receive(tap) == .recorded)
    #expect(inbox.receive(tap) == .duplicate)
    #expect(inbox.receive(tap) == .duplicate)

    #expect(try taps().count == 1, "One tap must never become two rows.")
  }

  /// `timestampIsTapTimeNotDeliveryTime` — eleven minutes late, still 14:32.
  ///
  /// The whole point of the wrist is capturing the instant attention wandered.
  /// A row stamped with its arrival time would look perfectly ordinary and be
  /// quietly wrong, and nothing downstream could ever detect it.
  @Test("timestampIsTapTimeNotDeliveryTime")
  func timestampIsTapTimeNotDeliveryTime() throws {
    let tapped = Date(timeIntervalSince1970: 1_756_000_000)
    let tap = WatchTap(
      id: UUID(), kind: .externalInterruption, tappedAt: tapped, sessionID: UUID())

    #expect(inbox.receive(tap) == .recorded)

    let row = try #require(try taps().first)
    #expect(row.timestamp == tapped)
    // Stated separately: a row stamped "now" would still be a Date, and would
    // still pass a test that only checked the type.
    #expect(abs(row.timestamp.timeIntervalSinceNow) > 60 * 60 * 24,
            "The row took this device's clock instead of the watch's.")
  }

  /// `lateTapAttachesToItsSession` — a block that has already ended still owns it.
  ///
  /// `TimerEngine.recordDistraction(_:)` refuses once a block is over, and is
  /// right to: a *phone* tap happens in the instant it is made. A wrist tap was
  /// made inside the block and merely arrived afterwards. **Late delivery does
  /// not change when something happened**, so this path takes the block from the
  /// payload and never re-derives it from the clock.
  @Test("lateTapAttachesToItsSession")
  func lateTapAttachesToItsSession() throws {
    let session = UUID()
    let started = Date(timeIntervalSince1970: 1_756_000_000)

    // The block ran, and finished, long before the tap was delivered.
    context.insert(PomodoroSession(
      id: session,
      kind: .work,
      startedAt: started,
      endedAt: started.addingTimeInterval(25 * 60),
      wasAbandoned: false,
      taskID: "t1",
      taskTitle: "Ch.3 draft",
      projectID: "p1",
      projectTitle: "Thesis"))
    try context.save()

    let tap = WatchTap(
      id: UUID(),
      kind: .internalInterruption,
      tappedAt: started.addingTimeInterval(9 * 60),
      sessionID: session)

    #expect(inbox.receive(tap) == .recorded)
    #expect(try #require(try taps().first).sessionID == session)
  }

  /// `lateTapInheritsTaskSnapshot` — and it inherits it by *reference*, which is
  /// the only reason this works at all.
  ///
  /// The row stores a session id and nothing else about the task. Everything a
  /// reader sees — the task, the project, the day — is read off that block when
  /// the export is built. So a tap arriving after the block ended inherits the
  /// snapshots automatically, and there is no second copy to keep in step.
  @Test("lateTapInheritsTaskSnapshot")
  func lateTapInheritsTaskSnapshot() throws {
    let session = UUID()
    let started = StatsStoreFixture.at(2026, 8, 19, 9, 0)

    context.insert(PomodoroSession(
      id: session,
      kind: .work,
      startedAt: started,
      endedAt: StatsStoreFixture.at(2026, 8, 19, 9, 25),
      wasAbandoned: false,
      taskID: "t1",
      taskTitle: "Ch.3 draft",
      projectID: "p1",
      projectTitle: "Thesis"))
    try context.save()

    inbox.receive(WatchTap(
      id: UUID(),
      kind: .externalInterruption,
      tappedAt: StatsStoreFixture.at(2026, 8, 19, 9, 12),
      sessionID: session))

    // Read back the way the export reads it, rather than off the row.
    let query = StatsQuery(context: context, calendar: StatsStoreFixture.calendar)
    let period = query.period(.day(StatsStoreFixture.day(2026, 8, 19)))

    #expect(period.externalCount == 1)
    let entry = try #require(period.days.first?.distractions.first)
    #expect(entry.taskTitle == "Ch.3 draft")
    #expect(entry.projectTitle == "Thesis")
  }

  // MARK: What a wrist tap must not be able to do

  /// A tap for a block this phone has never heard of is written down anyway.
  ///
  /// **Never drop a tap.** A wrist can be a version ahead, or the block row can
  /// be gone; either way the tap is a finished fact about somebody's attention,
  /// and `Distraction.swift` already promises that a row matching no block is
  /// shown as having no block rather than treated as an error. F6 renders it.
  /// Refusing it here would be the one failure this feature exists to prevent.
  @Test("aTapForAnUnknownBlockIsStillRecorded")
  func aTapForAnUnknownBlockIsStillRecorded() throws {
    let orphan = UUID()
    #expect(inbox.receive(WatchTap(
      id: UUID(),
      kind: .internalInterruption,
      tappedAt: Date(timeIntervalSince1970: 1_756_000_000),
      sessionID: orphan)) == .recorded)

    #expect(try taps().count == 1)
    #expect(try #require(try taps().first).sessionID == orphan)
  }

  /// Two different taps in the same block are two rows.
  ///
  /// The mirror image of `duplicateTapIgnored`: deduping on the session instead
  /// of the tap would collapse a block's real taps into one and pass that test.
  @Test("twoRealTapsInOneBlockAreTwoRows")
  func twoRealTapsInOneBlockAreTwoRows() throws {
    let session = UUID()
    let base = Date(timeIntervalSince1970: 1_756_000_000)

    inbox.receive(WatchTap(id: UUID(), kind: .internalInterruption, tappedAt: base, sessionID: session))
    inbox.receive(WatchTap(
      id: UUID(), kind: .externalInterruption, tappedAt: base.addingTimeInterval(120), sessionID: session))

    #expect(try taps().count == 2)
    #expect(try taps().map(\.kind) == [.internalInterruption, .externalInterruption])
  }

  /// A wrist tap carries no sentence, and that is a normal outcome rather than a
  /// gap.
  ///
  /// F5 made the note optional on purpose — the counts alone are the data the
  /// spec asks for. A watch has no keyboard worth the name, and D2 forbids
  /// editing a note there, so every wrist tap starts with `nil` and may be given
  /// a sentence later in the phone's end-of-block sheet.
  @Test("aWristTapArrivesWithNoSentence")
  func aWristTapArrivesWithNoSentence() throws {
    inbox.receive(WatchTap(
      id: UUID(),
      kind: .internalInterruption,
      tappedAt: Date(timeIntervalSince1970: 1_756_000_000),
      sessionID: UUID()))

    #expect(try #require(try taps().first).note == nil)
  }
}
