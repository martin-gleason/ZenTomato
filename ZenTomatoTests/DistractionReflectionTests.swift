import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// Tests for what happens *after* the taps: when a sheet is offered, when it is
/// deliberately not, and what a sentence written on it does to the rows that
/// already exist.
///
/// TWO RULES ARE BEING PROTECTED HERE AND THEY PULL IN OPPOSITE DIRECTIONS.
/// The prompt has to appear when somebody is there to answer it, because
/// reflection in the moment is the data the spec is asking for. And it must
/// *not* appear at any other time — not on the next launch, not behind a
/// stop sheet, not for a block that ran clean — because a queue of prompts
/// waiting to be worked through is a capture surface by another name, and this
/// app does not have one.
///
/// Under both of them sits D4: **the break starts behind the sheet.** The block
/// ends, the break's end instant is fixed from that boundary, and only then is
/// anything offered to look at. Reflection never eats break time.
@Suite("DistractionReflection")
@MainActor
struct DistractionReflectionTests {
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

  private var context: ModelContext {
    container.mainContext
  }

  private func distractions(in context: ModelContext) throws -> [Distraction] {
    try context.fetch(FetchDescriptor<Distraction>(sortBy: [SortDescriptor(\.timestamp)]))
  }

  private func distractions() throws -> [Distraction] {
    try distractions(in: context)
  }

  /// Turns on the setting that chains one block into the next. Off by default,
  /// and the two exit paths out of a block ending behave differently enough
  /// that both are tested.
  private func enableAutoStart() throws {
    let stored = try AppSettings.current(in: context)
    stored.autoStartNextBlock = true
    try context.save()
  }

  // MARK: D4 — the break starts behind the sheet

  /// When a focus block with taps ends and the next block begins by itself, the
  /// break is **already running** by the time anything is offered to look at,
  /// and its end instant was measured from the block boundary.
  ///
  /// THE LAST ASSERTION IS THE WHOLE TEST. The break ends five minutes after
  /// the *focus block's* end instant — not five minutes after the sheet was
  /// dismissed, and not five minutes after anything a person did. That is what
  /// makes it impossible for reflection to eat into a break, or for a sheet
  /// left open while somebody walks away to silently stretch their day.
  ///
  /// This test covers the auto-start way out of a block ending;
  /// `promptWithAutoStartOffLeavesTheTimerIdle` covers the other. There are two
  /// because the engine has two, and an assignment made on only one of them
  /// would leave half the app silently unprompted.
  @Test("breakStartsBehindSheet")
  func breakStartsBehindSheet() async throws {
    try enableAutoStart()
    await engine.start()

    let workSessionID = try TimerState.current(in: context).sessionID
    let frozenShortBreakMinutes = try TimerState.current(in: context).shortBreakMinutes
    #expect(engine.recordDistraction(.internalInterruption))
    let workEndsAt = try #require(engine.endsAt)

    clock.advance(by: 25 * 60)
    await engine.boundaryReached()

    let reflection = try #require(engine.pendingReflection)
    #expect(reflection.id == workSessionID)
    #expect(reflection.prompts.count == 1)
    #expect(reflection.prompts.first?.kind == .internalInterruption)

    #expect(engine.kind == .shortBreak)
    #expect(engine.isRunning)
    #expect(engine.endsAt == workEndsAt.addingTimeInterval(TimeInterval(frozenShortBreakMinutes * 60)))
  }

  /// Taking the reflection an hour later changes nothing about the timer.
  ///
  /// The sheet is a thing to look at, not a step in the timer's sequence. If
  /// the break's end instant moved when it was dismissed, a slow reader would
  /// get a longer break than a fast one, which is the failure D4 exists to
  /// rule out.
  @Test("reflectionSheetDoesNotDelayAnything")
  func reflectionSheetDoesNotDelayAnything() async throws {
    try enableAutoStart()
    await engine.start()
    #expect(engine.recordDistraction(.externalInterruption))

    clock.advance(by: 25 * 60)
    await engine.boundaryReached()
    let breakEndsAt = try #require(engine.endsAt)

    clock.advance(by: 60 * 60)
    #expect(engine.consumePendingReflection() != nil)

    #expect(engine.endsAt == breakEndsAt)
    #expect(engine.kind == .shortBreak)
  }

  /// A focus block with taps and auto-start switched off leaves a prompt behind
  /// and leaves the timer idle. Taking the prompt does not start anything.
  ///
  /// The second of the engine's two ways out of a block ending. See
  /// `breakStartsBehindSheet` for why both are tested separately.
  @Test("promptWithAutoStartOffLeavesTheTimerIdle")
  func promptWithAutoStartOffLeavesTheTimerIdle() async throws {
    await engine.start()
    #expect(engine.recordDistraction(.internalInterruption))

    clock.advance(by: 25 * 60)
    await engine.boundaryReached()

    #expect(engine.pendingReflection != nil)
    #expect(engine.isRunning == false)
    #expect(engine.kind == .shortBreak)

    #expect(engine.consumePendingReflection() != nil)
    #expect(engine.isRunning == false)
    #expect(engine.kind == .shortBreak)
  }

  /// A stop confirmed in the millisecond the engine is suspended starting the
  /// next block still does not produce a reflection sheet.
  ///
  /// WHY THIS IS NOT A CONTRIVED CASE
  /// `end()` freezes the ended block's facts and then, when auto-start is on,
  /// genuinely waits while the next block's alarm is scheduled. A stop is
  /// confirmed from its own task, so it can run to completion inside that wait:
  /// it clears the offer and takes the timer idle, and then `end()` resumes and
  /// assigns the offer anyway. The visible result is a sheet appearing over an
  /// idle screen at the exact moment somebody confirmed they wanted to quit,
  /// which is the one thing D14 forbids.
  ///
  /// The engine now freezes a counter alongside the block's facts and refuses
  /// to publish if it has moved. **The second half of this test is the control**
  /// — the identical sequence without the stop must still produce a prompt, so
  /// this cannot pass by the prompt mechanism being broken.
  @Test("stoppingInsideTheTransitionStillDoesNotPresentTheSheet")
  func stoppingInsideTheTransitionStillDoesNotPresentTheSheet() async throws {
    let clock = TestClock()
    let alarms = ReentrantAlarmScheduler()
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext
    let stored = try AppSettings.current(in: context)
    stored.autoStartNextBlock = true
    try context.save()
    let engine = TimerEngine(context: context, clock: clock, alarms: alarms)

    await engine.start()
    #expect(engine.recordDistraction(.internalInterruption))

    // Fired from inside `begin()`'s one suspension point, while the break is
    // being armed and before `end()` has published anything.
    alarms.duringScheduleAsync = { await engine.stop(reason: "Called away.") }

    clock.advance(by: 25 * 60)
    await engine.boundaryReached()

    #expect(engine.pendingReflection == nil)
    #expect(engine.isRunning == false)

    // THE CONTROL. Same engine, same shape, nothing stopping it.
    await engine.start()
    #expect(engine.kind == .work)
    #expect(engine.recordDistraction(.externalInterruption))
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()
    #expect(engine.pendingReflection != nil)
  }

  // MARK: When nothing is offered

  /// A focus block that ran clean ends with nothing to dismiss.
  ///
  /// The second half is the control: the same block with one tap in it *does*
  /// produce a prompt. Without it this test would keep passing if the whole
  /// prompt mechanism were deleted.
  @Test("noTapsNoSheet")
  func noTapsNoSheet() async throws {
    await engine.start()
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()
    #expect(engine.pendingReflection == nil)

    // The same block, with one tap in it.
    await engine.start()
    #expect(engine.kind == .shortBreak)
    clock.advance(by: 5 * 60)
    await engine.boundaryReached()
    await engine.start()
    #expect(engine.kind == .work)
    #expect(engine.recordDistraction(.internalInterruption))
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()
    #expect(engine.pendingReflection != nil)
  }

  /// A block that ended while the app was closed records nothing new and
  /// prompts for nothing.
  ///
  /// The taps were written down when they happened, so they are all still
  /// there. What is refused is the *question*: nobody was present when the
  /// block ended, and a sentence written the next morning is not the
  /// in-the-moment self-knowledge the spec asks for. It is also why there is no
  /// backlog of prompts waiting on the next launch.

  /// Stopping never puts a second sheet in front of somebody who has just
  /// decided to quit.
  ///
  /// The sheet that asked for the stop reason already asked for a sentence
  /// about each tap, in the same sheet, at the same moment — that is what D14
  /// merged. Two modals back to back train a person to dismiss both without
  /// reading, and the one that gets dismissed is the one that mattered.
  ///
  /// The rows themselves are untouched by stopping. What is withdrawn is the
  /// offer to annotate them, not the record.
  @Test("stoppingDoesNotAlsoPresentTheReflectionSheet")
  func stoppingDoesNotAlsoPresentTheReflectionSheet() async throws {
    await engine.start()
    #expect(engine.recordDistraction(.internalInterruption))
    clock.advance(by: 60)
    #expect(engine.recordDistraction(.internalInterruption))

    await engine.stop(reason: "The fire alarm went off.")

    #expect(engine.pendingReflection == nil)
    #expect(engine.currentBlockDistractions.isEmpty)
    #expect(try distractions().count == 2)
  }

  /// The prompt can be taken once. A second look finds nothing.
  ///
  /// A value that can be read twice can be presented twice, and a sheet
  /// reappearing the instant the first is dismissed — asking the same questions
  /// about the same block — is exactly the nagging this feature refuses to
  /// build.
  @Test("consumingIsOneShot")
  func consumingIsOneShot() async throws {
    await engine.start()
    #expect(engine.recordDistraction(.externalInterruption))
    clock.advance(by: 25 * 60)
    await engine.boundaryReached()

    #expect(engine.consumePendingReflection() != nil)
    #expect(engine.pendingReflection == nil)
    #expect(engine.consumePendingReflection() == nil)
  }

  // MARK: Writing the sentences down

  /// A skipped sentence is stored as **nothing**, never as empty text, and the
  /// two stay tellable apart in the database.
  ///
  /// This is the distinction the whole feature rests on. Nothing means the
  /// person skipped it, which is a normal outcome here — the counts alone are
  /// data. Empty text would mean they answered with silence. On screen the two
  /// look identical; in a review two weeks later they mean opposite things.
  ///
  /// Whitespace counts as skipped: a stray space or a stray newline is an
  /// artefact of a text field rather than something anybody meant.
  @Test("skippingLeavesNilNotNotEmpty")
  func skippingLeavesNilNotNotEmpty() async throws {
    await engine.start()
    #expect(engine.recordDistraction(.internalInterruption))
    clock.advance(by: 30)
    #expect(engine.recordDistraction(.externalInterruption))
    clock.advance(by: 30)
    #expect(engine.recordDistraction(.internalInterruption))

    let rows = try distractions()
    #expect(rows.count == 3)
    #expect(engine.attachNotes([
      rows[0].id: "   ",
      rows[1].id: "Slack, about the deploy.",
      rows[2].id: ""
    ], notEarlierThan: rows[0].timestamp))

    // Read back through a separate database handle, so this is a statement
    // about what was committed rather than about what is in memory.
    // Named rather than written as a bare literal, so that what is being ruled
    // out is legible: not "some empty thing", but a sentence deliberately left
    // blank, which is the one thing a skipped field must never be confused with.
    let deliberatelyEmptySentence: String? = ""
    let written = try distractions(in: ModelContext(container))
    #expect(written[0].note == nil)
    #expect(written[0].note != deliberatelyEmptySentence)
    #expect(written[1].note == "Slack, about the deploy.")
    #expect(written[2].note == nil)
    #expect(written[2].note != deliberatelyEmptySentence)
  }

  /// A sentence written about the second tap lands on the second tap.
  ///
  /// Rows are matched by their own identity, never by their position in a list,
  /// which is why this holds no matter what order the database hands them back
  /// in. An identifier that matches nothing is ignored rather than treated as
  /// an error: a sheet outliving its rows is possible, and it is not worth an
  /// alarm.
  @Test("notesAttachToCorrectTap")
  func notesAttachToCorrectTap() async throws {
    await engine.start()
    #expect(engine.recordDistraction(.internalInterruption))
    clock.advance(by: 30)
    #expect(engine.recordDistraction(.externalInterruption))
    clock.advance(by: 30)
    #expect(engine.recordDistraction(.internalInterruption))

    let rows = try distractions()
    #expect(engine.attachNotes([
      rows[1].id: "A colleague asked about the release notes.",
      UUID(): "A sentence about a tap that does not exist."
    ], notEarlierThan: rows[0].timestamp))

    let written = try distractions(in: ModelContext(container))
    #expect(written.count == 3)
    #expect(written[0].note == nil)
    #expect(written[1].note == "A colleague asked about the release notes.")
    #expect(written[2].note == nil)
    #expect(engine.lastFailure == nil)
  }

  /// A sentence written while the block was still running is still there after
  /// the block ends.
  ///
  /// This is the "Keep going" path: somebody opens the stop sheet, writes about
  /// a tap, changes their mind and carries on. The stop reason is discarded
  /// because no stop happened. Their sentence about a real distraction is not —
  /// it was about something that genuinely occurred, and it survives the
  /// boundary like every other part of the row.
  @Test("notesSurviveTheBlockEnding")
  func notesSurviveTheBlockEnding() async throws {
    await engine.start()
    #expect(engine.recordDistraction(.internalInterruption))

    let rows = try distractions()
    #expect(engine.attachNotes(
      [rows[0].id: "Kept thinking about the invoice."], notEarlierThan: rows[0].timestamp))

    clock.advance(by: 25 * 60)
    await engine.boundaryReached()

    let written = try distractions(in: ModelContext(container))
    #expect(written.count == 1)
    #expect(written[0].note == "Kept thinking about the invoice.")
  }
}
