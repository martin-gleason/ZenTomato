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

  // MARK: When the database will not answer

  /// A store whose file can be overwritten and put back.
  ///
  /// **THIS IS WHY THERE IS NO INJECTED CLOSURE IN `WatchTapInbox`.** The first
  /// draft of this unit reached the refused-read branch through a replaceable
  /// `refusableFetch` on the production type. It worked, and it tested the wrong
  /// line: the seam's `if let` was the only thing exercised, while
  /// `try context.fetch(descriptor)` — the one line the app actually runs — was
  /// never driven as a throwing call. Re-applying the original defect one level
  /// deeper left the whole suite green.
  ///
  /// A real `ModelContext` *can* be made to throw, and this is the way. Three
  /// routes were tried and the first two do not work: a container whose schema
  /// omits `Distraction` returns an empty array rather than throwing, and there
  /// is no supported call that puts a live context into a failing state.
  /// Overwriting the SQLite file's bytes under an open on-disk store does throw,
  /// cleanly and without killing the process — `NSCocoaErrorDomain` 259, *"isn't
  /// in the correct format"*, `NSSQLiteErrorDomain` 26.
  ///
  /// The original bytes are kept so the store can be made readable again and the
  /// row count can be read off the disk afterwards. **That count is recorded, not
  /// relied on** — see the note on `aRefusedDedupReadCannotDuplicateAnExistingRow`
  /// for why it cannot discriminate in this fixture.
  @MainActor
  private struct CorruptibleStore {
    let store: TestStore.TemporaryFileStore
    private var saved: [URL: Data] = [:]

    init() throws {
      store = try TestStore.temporaryFileStore()
    }

    /// The database file and the two side files SwiftData keeps beside it. All
    /// three are overwritten: leaving the write-ahead log intact lets SQLite
    /// answer from it and the read succeeds.
    ///
    /// **THIS FIXTURE IS COUPLED TO SQLITE JOURNALLING, AND THAT IS THE ONE WAY
    /// IT CAN AGE BADLY.** `F7b-M6` in `docs/plans/F7b.md` is the run that
    /// proves the coupling: overwrite the main file alone and the read is
    /// answered from the intact `-wal`, so no refused read happens at all and
    /// the test reports `outcome → .duplicate`. If a future runtime checkpoints
    /// or removes `-wal` before `corrupt()` runs, this goes red about the
    /// *fixture* rather than about `receive(_:)`. That is the safe direction to
    /// fail in — a fixture that stops refusing is loud, not silent — but the
    /// symptom to recognise is an `outcome` that is `.duplicate` or `.recorded`
    /// rather than `.failed`, which is what a genuine regression prints.
    private var files: [URL] {
      ["", "-wal", "-shm"].map {
        URL(fileURLWithPath: store.storeURL.path(percentEncoded: false) + $0)
      }
    }

    mutating func corrupt() throws {
      for url in files where FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
        saved[url] = try Data(contentsOf: url)
        try Data(repeating: 0x41, count: 4096).write(to: url)
      }
    }

    func restore() throws {
      for (url, data) in saved { try data.write(to: url) }
    }

    /// Every tap in the store, read through a **freshly opened** container.
    ///
    /// Fresh because the context that met the corrupt file is not trusted to
    /// answer afterwards, and because the question being asked is what is on
    /// disk rather than what some context still remembers.
    func rowsOnDisk() throws -> [Distraction] {
      let reopened = try AppModelContainer.make(.file(store.storeURL))
      return try reopened.mainContext.fetch(FetchDescriptor<Distraction>())
    }
  }

  private func aTap(_ kind: DistractionKind = .internalInterruption) -> WatchTap {
    WatchTap(
      id: UUID(),
      kind: kind,
      tappedAt: Date(timeIntervalSince1970: 1_756_000_000),
      sessionID: UUID())
  }

  /// **The defect, as a test.** A resend arriving while the dedup read is refused
  /// became a second row for one press — and this app has no surface that can
  /// ever delete it.
  ///
  /// **THE OUTCOME IS THE DISCRIMINATING ASSERTION, AND THE ROW COUNT IS NOT.**
  /// Said plainly because the reverse was assumed once already. A store too
  /// corrupt to read is also too corrupt to *write*, so every mutation that
  /// falls through to the insert has its `save()` refused as well — and the row
  /// count after the bytes are put back is `1` whether the code is right or
  /// wrong. The count is asserted anyway, off the disk through a fresh
  /// container, because it is the honest record of what is there; it is not
  /// evidence, and `F7b-M1` in the plan is the run that shows it staying green
  /// under the defect.
  ///
  /// What *does* discriminate is `Outcome`, and the reason is structural:
  /// **`.failed` is reachable only after `context.insert(row)`.** So
  /// `.unreadable` rather than `.failed` is a proof that the insert was never
  /// attempted, which is exactly the guarantee this unit exists to hold. Every
  /// mutation that reinstates the fall-through prints `outcome → .failed`.
  @Test("aRefusedDedupReadCannotDuplicateAnExistingRow")
  func aRefusedDedupReadCannotDuplicateAnExistingRow() throws {
    var corruptible = try CorruptibleStore()
    defer { corruptible.store.remove() }
    let tap = aTap()

    let outcome: WatchTapInbox.Outcome
    do {
      let container = try AppModelContainer.make(.file(corruptible.store.storeURL))
      let onDisk = WatchTapInbox(context: container.mainContext)
      #expect(onDisk.receive(tap) == .recorded)

      try corruptible.corrupt()
      // The same tap again, exactly as WatchConnectivity may redeliver it, while
      // the dedup read cannot be answered.
      outcome = onDisk.receive(tap)
    }

    #expect(outcome == .unreadable)
    #expect(outcome != .failed, "`.failed` means the insert was attempted. Nothing should have been.")
    try corruptible.restore()
    // Recorded, not relied on — see the note above.
    #expect(try corruptible.rowsOnDisk().count == 1)
  }

  /// A refused read drops the tap, and says which of the four outcomes it was.
  ///
  /// `.unreadable` and `.failed` are the pair worth separating, and the
  /// separation is not cosmetic: `.failed` can only be returned *after* a row has
  /// been inserted, so a run that reports it has been through the branch this
  /// unit exists to keep out. The same note about the row count applies here.
  @Test("aRefusedDedupReadDropsTheTapAndSaysSo")
  func aRefusedDedupReadDropsTheTapAndSaysSo() throws {
    var corruptible = try CorruptibleStore()
    defer { corruptible.store.remove() }

    let outcome: WatchTapInbox.Outcome
    do {
      let container = try AppModelContainer.make(.file(corruptible.store.storeURL))
      let onDisk = WatchTapInbox(context: container.mainContext)
      try corruptible.corrupt()
      outcome = onDisk.receive(aTap(.externalInterruption))
    }

    #expect(outcome == .unreadable)
    #expect(outcome != .failed, "Nothing was refused a write; the phone could not look.")
    try corruptible.restore()
    // Recorded, not relied on — see `aRefusedDedupReadCannotDuplicateAnExistingRow`.
    #expect(try corruptible.rowsOnDisk().isEmpty)
  }
}
