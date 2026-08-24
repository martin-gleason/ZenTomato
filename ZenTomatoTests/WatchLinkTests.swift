import Foundation
import Testing

@testable import ZenTomato

/// What may and may not live on the wrist, and what crosses between the two.
///
/// **THE OTHER HALF OF A FENCE THAT MOVED, AND THE ARGUMENT FOR MOVING IT.**
///
/// `StatsFenceTests.nothingOutOfScopeAndNoForcedShortcuts` forbade `WCSession`,
/// `watchOS` and `WatchConnectivity` outright, across every file F6 touched. That
/// was correct: a watch was Phase 2, and the ban was doing real work.
///
/// D2 moved the **remote** watch into v0.1 as F7 and the amendment reached
/// `SPEC.md` on 2026-08-24, so the ban became wrong. **A fence that is wrong is
/// dangerous in a way an absent one is not** — the next person to hit it deletes
/// the whole list rather than the three entries that stopped applying, and
/// `CloudKit`, `macOS`, `AppIntent` and `WidgetKit` go with them.
///
/// So it was narrowed rather than deleted, and the replacement is here, next to
/// the thing it now governs. `standalone watchOS` is still out of scope by the
/// amended spec. What the watch may not be — a second timer, a second database,
/// a second opinion about the music — is held by the two tests below, which read
/// the watch target's own sources rather than a feature's file list. Everything
/// unrelated to D2 stayed exactly where it was.
@Suite("WatchLink")
struct WatchLinkTests {
  // MARK: What the watch may not own

  /// `noStoreOnWatch` — the wrist never touches the database.
  ///
  /// D2 puts the source of truth on the phone. A watch that could open the store
  /// could write to it, and then two devices hold opinions about the one number
  /// this app exists to produce. There is no merge strategy for that and there
  /// should never need to be one.
  @Test("noStoreOnWatch")
  func noStoreOnWatch() throws {
    for file in try Self.watchSources() {
      let code = try String(contentsOf: file, encoding: .utf8)
      for forbidden in ["import SwiftData", "ModelContainer", "ModelContext", "FetchDescriptor"] {
        #expect(
          code.contains(forbidden) == false,
          "\(file.lastPathComponent) reaches for \(forbidden). The watch has no database.")
      }
    }
  }

  /// `theWatchOwnsNoTimer` — it renders a countdown; it does not run one.
  ///
  /// The distinction is not pedantry. The watch draws its number from the
  /// `endsAt` the phone sent, which is display arithmetic. It has no authority to
  /// end a block, fire an alarm, advance a sprint or write a session — so when
  /// its countdown reaches zero it says it has lost touch rather than deciding
  /// the block finished.
  @Test("theWatchOwnsNoTimer")
  func theWatchOwnsNoTimer() throws {
    for file in try Self.watchSources() {
      let code = try String(contentsOf: file, encoding: .utf8)
      for forbidden in ["TimerEngine", "AlarmManager", "import AlarmKit", "import MusicKit", "Timer.publish"] {
        #expect(
          code.contains(forbidden) == false,
          "\(file.lastPathComponent) reaches for \(forbidden). The phone runs the only timer.")
      }
    }
  }

  // MARK: What crosses

  /// `theTapCarriesItsOwnMomentAndIdentity` — the two fields that make a queued
  /// tap survivable.
  ///
  /// `tappedAt` is the moment of the press, never of delivery: a tap that waits
  /// eleven minutes in a queue must still say when it happened, or the wrist —
  /// whose entire purpose is capturing that instant — silently rewrites it.
  /// `id` is what makes redelivery harmless: WatchConnectivity guarantees
  /// eventual delivery, not exactly-once, so without it a resend becomes a second
  /// row and the counts inflate in the direction that flatters.
  @Test("theTapCarriesItsOwnMomentAndIdentity")
  func theTapCarriesItsOwnMomentAndIdentity() throws {
    let tapped = Date(timeIntervalSince1970: 1_756_000_000)
    let session = UUID()
    let tap = WatchTap(id: UUID(), kind: .internalInterruption, tappedAt: tapped, sessionID: session)

    let round = try JSONDecoder().decode(WatchTap.self, from: JSONEncoder().encode(tap))

    #expect(round == tap)
    #expect(round.tappedAt == tapped, "The moment must survive the journey unchanged.")
    #expect(round.id == tap.id, "Without a stable id a redelivery becomes a second distraction.")
    #expect(round.sessionID == session)
  }

  /// `theStateCarriesAnInstantNotADuration` — and why that is the whole design.
  ///
  /// A remaining-time figure is wrong the moment it is sent and wrong again every
  /// second the connection is quiet, so the phone would have to talk once a
  /// second to keep the wrist right. An instant is still true twenty minutes
  /// later. That is what lets the watch draw its own countdown and the phone say
  /// nothing at all between blocks.
  @Test("theStateCarriesAnInstantNotADuration")
  func theStateCarriesAnInstantNotADuration() throws {
    let ends = Date(timeIntervalSince1970: 1_756_001_500)
    let state = WatchBlockState(block: .init(
      kind: .work, endsAt: ends, taskTitle: "Ch.3 draft", sessionID: UUID()))

    let round = try JSONDecoder().decode(
      WatchBlockState.self, from: JSONEncoder().encode(state))

    #expect(round.block?.endsAt == ends)
    #expect(round == state)
  }

  /// `onlyAWorkBlockAcceptsTaps` — a break hides the buttons rather than refusing.
  ///
  /// `SPEC.md`: the two buttons are *"tappable during a pomodoro"*. A break is not
  /// one. F5 settled this on the phone by reserving the space rather than drawing
  /// a control that would say no, and the wrist matches it.
  @Test("onlyAWorkBlockAcceptsTaps")
  func onlyAWorkBlockAcceptsTaps() {
    let ends = Date(timeIntervalSince1970: 1_756_001_500)
    func state(_ kind: BlockKind) -> WatchBlockState {
      WatchBlockState(block: .init(kind: kind, endsAt: ends, taskTitle: nil, sessionID: UUID()))
    }

    #expect(state(.work).acceptsTaps)
    #expect(state(.shortBreak).acceptsTaps == false)
    #expect(state(.longBreak).acceptsTaps == false)
    #expect(WatchBlockState().acceptsTaps == false, "Nothing running accepts nothing.")
  }

  // MARK: Private

  private static func watchSources() throws -> [URL] {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appending(path: "ZenTomatoWatch")
    guard let walk = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
    else { return [] }
    return walk.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
  }
}
