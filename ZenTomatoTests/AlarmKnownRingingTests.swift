import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// `D26` — the app knows an alarm is ringing *before* it offers the reflection
/// sheet, so the sheet cannot cover the Silence button.
///
/// **Its own file because `SilenceAlarmTests` crossed the 400-line limit** when
/// the cold-relaunch test arrived; `make ci` refused it, which is the fact.
///
/// **These are the behavioural half of a rule whose other half is a source-text
/// grep.** `ReflectionWaitsForAlarmFenceTests` asserts the guard exists in
/// `TimerView`. It cannot see whether the flag is set in time — which is exactly
/// how the defect survived seven review passes, and how the *fix* for it then
/// survived an eighth on the cold-relaunch path. Timing needs tests that run.
@MainActor
struct AlarmKnownRingingTests {
  private let harness: SilenceHarness

  init() throws {
    harness = try SilenceHarness()
  }

  private var engine: TimerEngine { harness.engine }
  private var alarms: SpyAlarmScheduler { harness.alarms }
  private var clock: TestClock { harness.clock }
  private var context: ModelContext { harness.context }

  /// **THE FLAG IS SET AT THE BOUNDARY, NOT WHEN THE FRAMEWORK GETS ROUND TO
  /// SAYING SO — AND SEVEN REVIEW PASSES MISSED THAT IT WAS NOT.**
  ///
  /// `presentReflectionIfPossible()` withholds the sheet while an alarm rings, so
  /// it cannot cover the Silence button. That guard is only as good as the flag,
  /// and the flag used to be written solely by `watchForAlarms()` — which learns
  /// from an IPC round trip. With auto-start **off**, which is the default,
  /// `end()` reaches `publishReflection` with no suspension in between, so the
  /// offer arrived while the flag was still `nil` and the sheet presented over the
  /// button. It looked fixed only because the auto-start path suspends long
  /// enough inside `begin()` for the notification to land.
  ///
  /// The fence that was supposed to hold this is a source-text grep. It asserts
  /// the guard *exists*; it cannot see whether the flag is set in time. This is
  /// the behavioural half.
  @Test("theAlarmIsKnownToBeRingingBeforeTheOfferIsMade")
  func theAlarmIsKnownToBeRingingBeforeTheOfferIsMade() async throws {
    let settings = try #require(try context.fetch(FetchDescriptor<AppSettings>()).first)
    // The default, and the configuration the defect lived on.
    settings.autoStartNextBlock = false

    await engine.start()
    _ = engine.recordDistraction(.internalInterruption)
    clock.advance(by: 25 * 60)

    // No watcher: the point is that the engine does not need one to know.
    await engine.boundaryReached()

    #expect(
      engine.pendingReflection != nil,
      "The block had a tap, so there is an offer to withhold.")
    #expect(
      engine.ringingAlarmID != nil,
      """
      The offer was published while the app still believed no alarm was ringing, \
      so the sheet would cover the Silence button.
      """)
  }

  /// And it does not claim one that was never set.
  ///
  /// If scheduling failed there is no alarm, nothing will ever arrive to say it
  /// stopped, and withholding the sheet on a false flag would lose the prompt
  /// permanently — trading the covered button for the thing it was protecting.
  @Test("noAlarmIsClaimedWhenNoneWasScheduled")
  func noAlarmIsClaimedWhenNoneWasScheduled() async throws {
    alarms.scheduleError = SpyAlarmScheduler.Failure()
    await engine.start()
    _ = engine.recordDistraction(.internalInterruption)
    clock.advance(by: 25 * 60)

    await engine.boundaryReached()

    #expect(engine.ringingAlarmID == nil, "An alarm was claimed that was never scheduled.")
    #expect(engine.pendingReflection != nil)
  }

  /// **AND IT SURVIVES THE APP BEING KILLED MID-BLOCK.**
  ///
  /// An AlarmKit alarm outlives the process that set it —
  /// `AlarmKitScheduler.cancelOutstanding` says so in as many words. The first
  /// version of this fix kept a `Bool` in memory instead, so a fresh launch
  /// mid-block had a live alarm and a `false` flag: `boundaryReached()` declined
  /// to seed, and the sheet went back to covering the Silence button. The fix
  /// worked on every path except the one nobody enumerated, which is this
  /// branch's most repeated mistake.
  @Test("aColdRelaunchMidBlockStillKnowsTheAlarmIsRinging")
  func aColdRelaunchMidBlockStillKnowsTheAlarmIsRinging() async throws {
    await engine.start()

    // A second engine over the same store and the same alarm system: a relaunch.
    // A **fresh** `ModelContext`, so the second engine reads the block back from
    // the store rather than being handed the live object the first one mutated.
    // Sharing `mainContext` made this test pass for a weaker reason than its name
    // claims.
    let relaunched = TimerEngine(
      context: ModelContext(harness.container), clock: clock, alarms: alarms)
    await relaunched.synchronize()
    _ = relaunched.recordDistraction(.internalInterruption)
    clock.advance(by: 25 * 60)

    await relaunched.boundaryReached()

    #expect(relaunched.pendingReflection != nil)
    #expect(
      relaunched.ringingAlarmID != nil,
      "After a relaunch the app forgot its own alarm, so the sheet would cover the Silence button.")
  }
  /// **The `D29` locked-phone path: the block ended while the phone was in a
  /// pocket, and the alarm is still going when it comes out.**
  ///
  /// `synchronize()`'s already-ended branch offers the reflection sheet when the
  /// wake was prompt — and offered it over the Silence button, because the seed
  /// added for the two other paths was not on this one. The fourth repetition of
  /// the same mistake on this branch, and the one that matters most: this is the
  /// ordinary way the app is used.
  @Test("aLockedPhonePathKnowsTheAlarmIsStillRinging")
  func aLockedPhonePathKnowsTheAlarmIsStillRinging() async throws {
    await engine.start()
    _ = engine.recordDistraction(.externalInterruption)
    let id = try #require(alarms.outstanding?.id)

    // The block ends while nobody is looking, and the alarm is sounding.
    clock.advance(by: 25 * 60 + 30)
    alarms.ring(id)

    let relaunched = TimerEngine(
      context: ModelContext(harness.container), clock: clock, alarms: alarms)
    await relaunched.synchronize()

    #expect(relaunched.pendingReflection != nil, "D29 offers the prompt on a prompt wake.")
    #expect(
      relaunched.ringingAlarmID != nil,
      "The sheet would be offered over a ringing alarm with no Silence button.")
  }

  /// And when nothing is ringing by the time the phone is unlocked, the sheet is
  /// not held back.
  @Test("aQuietLockedPhonePathDoesNotWithholdTheSheet")
  func aQuietLockedPhonePathDoesNotWithholdTheSheet() async throws {
    await engine.start()
    _ = engine.recordDistraction(.externalInterruption)
    clock.advance(by: 25 * 60 + 30)
    // Nobody is alerting: the alarm was dismissed from the Lock Screen.

    let relaunched = TimerEngine(
      context: ModelContext(harness.container), clock: clock, alarms: alarms)
    await relaunched.synchronize()

    #expect(relaunched.pendingReflection != nil)
    #expect(
      relaunched.ringingAlarmID == nil,
      "A sheet was withheld for an alarm that had already stopped, with nothing to release it.")
  }

  /// **The direct-read half of the boundary union, which nothing exercised.**
  ///
  /// The tenth pass neutered `alreadyAlerting` and the whole suite stayed green —
  /// then the first version of *this* test stayed green too, because the flag half
  /// covers everything in a process that scheduled its own alarm. So the flag is
  /// deliberately cold here: a relaunch that cannot see the alarm through
  /// `hasAlarm`, with iOS nevertheless reporting it as alerting. Only the read can
  /// answer.
  @Test("theBoundarySeedsFromADirectReadWhenTheFlagIsCold")
  func theBoundarySeedsFromADirectReadWhenTheFlagIsCold() async throws {
    await engine.start()
    let id = try #require(alarms.outstanding?.id)

    // A relaunch whose rebuild finds nothing — the flag will be false.
    alarms.outstandingAlarmIDs.removeAll()
    let relaunched = TimerEngine(
      context: ModelContext(harness.container), clock: clock, alarms: alarms)
    await relaunched.synchronize()
    _ = relaunched.recordDistraction(.internalInterruption)

    // iOS says it is alerting anyway.
    clock.advance(by: 25 * 60)
    alarms.ring(id)

    await relaunched.boundaryReached()

    #expect(
      relaunched.ringingAlarmID != nil,
      "The direct read never fired, so the union's second half is doing nothing.")
  }
}
