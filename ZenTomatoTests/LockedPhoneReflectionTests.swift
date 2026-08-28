import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// `D29` — a locked phone is somebody being there.
///
/// **Its own file because `DistractionReflectionTests` crossed the 400-line
/// limit** when these two arrived — against a ceiling `.swiftlint.yml` does not
/// override.
///
/// **No line count is quoted here, and that is deliberate.** The first version of
/// this sentence said 433; the count is 434, and being off by one is exactly the
/// kind of checkable claim this branch has now got wrong five times (see
/// `SilenceHarness` for three of them). A number nobody re-derives is a number
/// that rots. `make ci` refused the file; that is the fact, and it is
/// reproducible.
///
/// The pair belongs together anyway: one asserts the sheet is offered to somebody
/// who was there, the other that it is not offered to somebody who was not, and
/// neither half means anything without the other.
@MainActor
struct LockedPhoneReflectionTests {
  private let container: ModelContainer
  private let clock: TestClock
  private let alarms: SpyAlarmScheduler
  private let engine: TimerEngine

  init() throws {
    let clock = TestClock()
    let alarms = SpyAlarmScheduler()
    let container = try TestStore.inMemoryContainer()
    self.clock = clock
    self.alarms = alarms
    self.container = container
    engine = TimerEngine(context: container.mainContext, clock: clock, alarms: alarms)
  }

  private func distractions(in context: ModelContext) throws -> [Distraction] {
    try context.fetch(FetchDescriptor<Distraction>(sortBy: [SortDescriptor(\.timestamp)]))
  }

  /// **`D29`: a locked phone is somebody being there.**
  ///
  /// This test used to assert the opposite — that a block ending while the app
  /// was away got no prompt at all, on the reasoning that there was "nobody there
  /// to fill in the sheet". The owner found the hole by running a sprint the
  /// ordinary way: phone locked, in a pocket, three external interruptions
  /// tapped, and no way to write any of them down when they picked it up.
  ///
  /// The wake here is prompt — the block ran out a minute ago — so the sheet is
  /// offered.
  @Test("aBlockEndedWhileLockedStillOffersThePrompt")
  func aBlockEndedWhileLockedStillOffersThePrompt() async throws {
    await engine.start()
    #expect(engine.recordDistraction(.internalInterruption))
    clock.advance(by: 60)
    #expect(engine.recordDistraction(.externalInterruption))

    // The block ends, and the phone is picked up a minute later.
    clock.advance(by: 24 * 60)
    clock.advance(by: 60)
    let freshHandle = ModelContext(container)
    let relaunched = TimerEngine(context: freshHandle, clock: clock, alarms: alarms)
    await relaunched.synchronize()

    let offered = try #require(
      relaunched.pendingReflection,
      "The sheet was refused for somebody who was there the whole time.")
    #expect(offered.prompts.count == 2)

    let rows = try distractions(in: freshHandle)
    #expect(rows.count == 2)
    #expect(rows.map(\.kind) == [.internalInterruption, .externalInterruption])
    #expect(rows.allSatisfy { $0.note == nil })
    #expect(try freshHandle.fetch(FetchDescriptor<PomodoroSession>()).count == 1)
  }

  /// **And the other half of `D29`, which is the half that keeps it honest.**
  ///
  /// A phone left overnight gets no sheet. Nobody remembers what a tap at 2am was
  /// about, and being asked would be worse than being left alone — the protection
  /// the old rule was providing, kept.
  @Test("aBlockEndedLongAgoStillGetsNoPrompt")
  func aBlockEndedLongAgoStillGetsNoPrompt() async throws {
    await engine.start()
    #expect(engine.recordDistraction(.internalInterruption))
    clock.advance(by: 60)
    #expect(engine.recordDistraction(.externalInterruption))

    // Fourteen hours: the phone was put down and the day ended.
    clock.advance(by: 14 * 60 * 60)
    let freshHandle = ModelContext(container)
    let relaunched = TimerEngine(context: freshHandle, clock: clock, alarms: alarms)
    await relaunched.synchronize()

    #expect(relaunched.pendingReflection == nil)
    #expect(relaunched.isRunning == false)
    #expect(relaunched.currentBlockDistractions.isEmpty)

    // The taps keep their rows either way. They are written when they are tapped.
    let rows = try distractions(in: freshHandle)
    #expect(rows.count == 2)
    #expect(rows.allSatisfy { $0.note == nil })
    #expect(try freshHandle.fetch(FetchDescriptor<PomodoroSession>()).count == 1)
  }
}
