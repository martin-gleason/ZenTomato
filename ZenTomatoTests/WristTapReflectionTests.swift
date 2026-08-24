import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// Whether a tap made on the wrist gets asked about at the end of the block.
///
/// `F7.md`: a wrist tap *"gets a sentence field in the phone's end-of-pomodoro
/// sheet like any other, **provided it arrives before the sheet is presented**.
/// One that arrives later simply keeps `note == nil`"*.
///
/// **The provision is doing real work, and it nearly went unnoticed.** The
/// engine's prompt list is held in memory, not read back from the database — so
/// a tap written straight to the store, which is exactly what a wrist tap is,
/// would never have appeared in the sheet however promptly it arrived. The row
/// would have been perfectly correct and the question would simply never have
/// been asked.
@Suite("WristTapReflection")
@MainActor
struct WristTapReflectionTests {
  private let clock: TestClock
  private let container: ModelContainer
  private let engine: TimerEngine

  init() throws {
    let clock = TestClock()
    let container = try TestStore.inMemoryContainer()
    self.clock = clock
    self.container = container
    engine = TimerEngine(
      context: container.mainContext, clock: clock, alarms: SpyAlarmScheduler())
  }

  private var context: ModelContext { container.mainContext }

  /// The session the timer is running now, read the way the app reads it.
  private func runningSessionID() throws -> UUID {
    try TimerState.current(in: context).sessionID
  }

  /// A tap arriving during its own block is asked about.
  @Test("aWristTapInTheRunningBlockIsAskedAbout")
  func aWristTapInTheRunningBlockIsAskedAbout() async throws {
    await engine.start()
    let session = try runningSessionID()

    let adopted = engine.adoptWristTap(
      id: UUID(), kind: .internalInterruption, at: clock.now, sessionID: session)

    #expect(adopted)
    #expect(engine.currentBlockDistractions.count == 1)
    #expect(engine.currentBlockDistractions.first?.kind == .internalInterruption)
  }

  /// A tap naming a block that has already ended is **not** held over.
  ///
  /// This is the half that matters. Adopting it would put a distraction from a
  /// finished block into the sheet for the one running now — a tap presented
  /// against a pomodoro it did not happen in, which is worse than one that is
  /// never asked about. `TimerEngine.recordDistraction(_:)` guards the same way
  /// and for the same reason.
  @Test("aWristTapFromAFinishedBlockIsNotHeldOver")
  func aWristTapFromAFinishedBlockIsNotHeldOver() async throws {
    await engine.start()

    let stale = UUID()
    let adopted = engine.adoptWristTap(
      id: UUID(), kind: .externalInterruption, at: clock.now, sessionID: stale)

    #expect(adopted == false)
    #expect(engine.currentBlockDistractions.isEmpty)
  }

  /// Nothing is adopted when no block is running.
  @Test("noBlockRunningAdoptsNothing")
  func noBlockRunningAdoptsNothing() throws {
    #expect(engine.adoptWristTap(
      id: UUID(), kind: .internalInterruption, at: clock.now, sessionID: UUID()) == false)
    #expect(engine.currentBlockDistractions.isEmpty)
  }

  /// The same tap delivered twice is asked about once.
  ///
  /// `WatchTapInbox` already refuses the second row, so in the running app this
  /// cannot be reached — but the two guards are independent, and a prompt list
  /// with a duplicate would draw two sentence fields for one tap and write the
  /// second answer onto a row that has already been answered.
  @Test("aRedeliveredTapIsAskedAboutOnce")
  func aRedeliveredTapIsAskedAboutOnce() async throws {
    await engine.start()
    let session = try runningSessionID()
    let tap = UUID()

    #expect(engine.adoptWristTap(
      id: tap, kind: .internalInterruption, at: clock.now, sessionID: session))
    #expect(engine.adoptWristTap(
      id: tap, kind: .internalInterruption, at: clock.now, sessionID: session) == false)

    #expect(engine.currentBlockDistractions.count == 1)
  }
}
