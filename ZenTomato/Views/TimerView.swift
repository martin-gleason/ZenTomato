import SwiftData
import SwiftUI

// swiftlint:disable file_length
//
// THE ONLY LINT RULE THIS FILE TURNS OFF, AND WHY.
// `file_length` counts documentation, and this file is now more than half
// documentation — a little over three hundred lines of it. Most of that is one
// argument, made in several places because it is the argument the whole
// distraction feature rests on: that a tap becomes a durable row before
// anything else happens, and that every signal a person gets is driven by that
// row existing rather than by the touch. Where the ordering matters it is
// explained where it is written, because the code reads as if the obvious order
// would do, and the next person to tidy it will need to know why it is the way
// round it is. Splitting the file would move the lines and separate that
// argument from the four or five places it constrains. The same exemption, for
// the same reason, is already taken by `TimerEngine.swift`. Every other rule
// stays on.

/// The timer screen, wired to the engine.
///
/// WHAT THIS FILE DOES AND WHAT IT DELIBERATELY DOES NOT
/// It reads the engine, turns what it finds into finished strings and numbers,
/// and hands them to `TimerScreen`, which draws them. It owns the settings sheet
/// and the blocking cover that appears when alarms are switched off. It contains
/// no layout and no colours; those are all in `TimerScreen`.
///
/// THE NUMBER IS NOT COUNTED DOWN
/// Nothing in this app decrements a number once a second. The engine records the
/// wall-clock instant the block ends, and this screen asks it "how much is left
/// *at this moment*" each time it redraws. That is the difference between a timer
/// that survives being backgrounded and one that quietly loses four minutes
/// because iOS suspended the app.
///
/// The redraw comes from `TimelineView`, which is SwiftUI's own once-a-second
/// heartbeat. It is used rather than a repeating timer for one reason: it stops
/// on its own when the screen goes away, so there is no cancellation to get
/// wrong. It is only a nudge to redraw — never the record of how much time has
/// passed — and while no block is running it is not used at all.
///
/// THE ONE PLACE A DISTRACTION IS RECORDED FROM
/// Tapping Internal or External calls `engine.recordDistraction(_:)`, which is
/// **synchronous**: it writes the row and commits it to disk before it returns,
/// and it answers `true` only if that worked. Everything else — the buzz, the
/// count under the word, the two words VoiceOver speaks — is driven by that
/// answer, so no signal can ever fire for a row that does not exist.
///
/// **There is deliberately no `Task` on that path**, unlike Start and Stop two
/// screens' width away in this same file. Their asynchronous hop is safe because
/// the engine writes the block down before it waits for anything. A capture has
/// no such margin: the whole feature is the claim that a tap cannot be lost
/// between the finger and the disk, and starting a piece of work to do the
/// writing would put a gap back in exactly the place the claim is about.
struct TimerView: View {
  // MARK: Internal

  var body: some View {
    screen
      .sheet(isPresented: $showingSettings, onDismiss: settingsSheetClosed) {
        SettingsView()
      }
      // The toll on the one exit a running block has. Presented rather than
      // acted on: tapping Stop opens this, and the block keeps running until a
      // reason is written and confirmed. Nothing here can end a block silently.
      .sheet(isPresented: $isAskingWhyStopping) {
        StopReasonSheet(
          reason: $stopReason,
          // D14: the tap sentences ride along in the same sheet rather than
          // arriving as a second modal behind this one. Empty for most stops,
          // and then this is exactly the sheet that shipped in F2.
          //
          // Taken as a snapshot when the sheet opened rather than read live off
          // the engine. A block can reach its natural end while somebody is
          // still writing their reason, and the engine empties its list of the
          // running block's taps when the next block begins — so a live read
          // would make the fields disappear from under a finger mid-sentence.
          prompts: stopPrompts,
          notes: $noteDrafts,
          onConfirm: confirmStop,
          onCancel: keepGoing)
      }
      // The end-of-block sheet. Presented by *item* rather than by a boolean:
      // there is either a reflection to ask about or there is not, and a value
      // that cannot be two things at once cannot present two sheets at once.
      .sheet(item: $reflection, onDismiss: reflectionSheetClosed) { reflection in
        BlockReflectionSheet(
          reflection: reflection,
          notes: $noteDrafts,
          breakIsRunning: reflectionBreakIsRunning,
          onDone: { self.reflection = nil })
      }
      // THE PROMPT IS TAKEN, NOT WATCHED.
      //
      // The engine offers a reflection at most once, at the end of a work block
      // it was awake to see end. Consuming it hands it over and clears it in the
      // same call, so it cannot be read twice and therefore cannot be presented
      // twice — which is the defect D14 exists to prevent, arriving by a
      // different door. Nothing re-offers it later: a block whose sheet was
      // never seen keeps its rows and their notes stay empty.
      //
      // NOT WHILE ANOTHER SHEET IS UP, AND FOR THE STOP SHEET THAT IS D14.
      // A block can reach its natural end while somebody is still writing their
      // reason for stopping. The stop sheet in front of them already carries a
      // field for every one of those taps, so there is nothing left to ask —
      // and presenting a second modal on top of it, at the moment somebody has
      // decided to quit, is the precise thing D14 exists to prevent. The offer
      // is left unconsumed and is harmlessly replaced the next time a block
      // ends.
      //
      // The settings sheet is in the guard for a duller reason and it is not
      // optional: SwiftUI will not present a second sheet from the same view
      // while one is up, so without this clause the offer would be consumed,
      // cleared, and never drawn — no error, no amber row, just a prompt that
      // silently did not happen. Left unconsumed it stays on the engine, and is
      // harmlessly replaced the next time a block ends, exactly as the stop-sheet
      // case already behaves.
      .onChange(of: engine.pendingReflection) { _, offered in
        guard offered != nil, isAskingWhyStopping == false, showingSettings == false else { return }
        guard let taken = engine.consumePendingReflection() else { return }
        // Snapshotted at the moment of presentation rather than read live, so
        // the footer line cannot change its mind while somebody is reading it.
        reflectionBreakIsRunning = engine.isRunning
        closedReflectionPrompts = taken.prompts
        reflection = taken
      }
      // A REFUSED TAP BELONGS TO THE BLOCK IT HAPPENED IN.
      //
      // `endsAt` changes exactly once per block — when one begins, and again
      // when everything stops — so this clears the message at a boundary and at
      // no other time. Without it an amber line about a tap made twenty minutes
      // ago would still be sitting over a fresh block. That is precisely the
      // defect F2's review found on the alarm-failure row, where a chained block
      // inherited the previous block's warning; the engine clears its own
      // failures at a boundary for the same reason, and this is the one message
      // the engine does not own.
      .onChange(of: engine.endsAt) { _, _ in
        captureFailureNote = nil
      }
      // A blocking cover, presented *by this screen*, which is what gives the two
      // failure screens their order: if the database will not open this view is
      // never built, so the alarm explainer can never be drawn on top of the
      // database explainer. The precedence is structural rather than a condition
      // somebody has to remember.
      .fullScreenCover(isPresented: alarmsAreOff) {
        AlarmPermissionView()
      }
  }

  // MARK: Private

  /// How often the number is redrawn while a block runs.
  private static let refreshInterval: TimeInterval = 1

  /// What the screen shows when there is no settings row to read.
  ///
  /// It cannot happen in practice: the app creates the row at launch, before this
  /// screen is ever shown. It used to fall back to the number 25 — which is also
  /// the number a healthy first launch produces — so a database that opened but
  /// held nothing looked exactly like one that was working perfectly. Dashes
  /// cannot be mistaken for a working timer from across the room, which is the
  /// whole point.
  private static let missingReading = "--:--"

  /// What the screen says when a tap could not be written.
  ///
  /// It is short and it asks for the one thing that might work, because the
  /// person reading it is in the middle of a focus block and has already spent
  /// the second this feature is supposed to cost. It appears in the same amber
  /// row as an alarm failure, and is announced to VoiceOver by the same
  /// mechanism, so there is one way this app says something went wrong.
  private static let captureFailedNote = "That tap wasn't saved. Tap again."

  /// Shown when the store refuses the sentences somebody wrote.
  ///
  /// It says what actually failed. The taps themselves were written down when
  /// the buttons were pressed and are not at risk here — only the sentences
  /// are — so this must not borrow the engine's block-loss wording, which would
  /// tell somebody their pomodoro may be gone because a note did not save.
  private static let notesFailedNote = "Those sentences weren't saved. The taps themselves are safe."

  /// The running timer. Handed down by the app, which owns it.
  @Environment(TimerEngine.self) private var engine

  /// The settings row. This comes back as a list because that is the only shape
  /// SwiftData offers, but there is exactly one row by design.
  ///
  /// The screen does not read the six values out of it — the engine holds those,
  /// and reading them twice is how two numbers on one screen start to disagree.
  /// It is here to answer one question: is there a settings row at all?
  @Query private var settings: [AppSettings]

  @State private var showingSettings = false

  /// Whether the "why are you stopping?" sheet is up. Tapping Stop sets this;
  /// nothing else does.
  @State private var isAskingWhyStopping = false

  /// What has been typed into that sheet. Owned here rather than inside the
  /// sheet so a dismissal cannot strand a half-written sentence out of reach.
  @State private var stopReason = ""

  /// The sentences being written about individual taps, keyed by the id of the
  /// tap each belongs to.
  ///
  /// **Owned here, and deliberately shared by both sheets.** A sentence typed
  /// into the stop sheet is about a tap that really happened; it is not
  /// conditional on the stop. So changing your mind and going back to work
  /// keeps it, and if the block then runs to its natural end the same field
  /// comes back with the same sentence in it, because both sheets are reading
  /// the same drafts. Emptied once the notes have been handed to the engine.
  ///
  /// These are drafts, not records. The records were written when the buttons
  /// were tapped, minutes ago.
  @State private var noteDrafts: [UUID: String] = [:]

  /// The block whose end-of-block sheet is up, or `nil`.
  ///
  /// Purely in-memory and never persisted, which is the mechanism behind a
  /// ratified decision: killed with this sheet open, the app does not come back
  /// with it. The rows survive, their notes stay empty, and there is no queue of
  /// prompts waiting to nag. A sentence written an hour after the fact is not
  /// the data the spec asks for.
  @State private var reflection: BlockReflection?

  /// Whether a break was counting at the moment that sheet was presented.
  @State private var reflectionBreakIsRunning = false

  /// The taps of the block being stopped, frozen when the stop sheet opened.
  @State private var stopPrompts: [DistractionPrompt] = []

  /// The taps of the reflection sheet that is open, kept so that its dismissal
  /// knows how far back to look when it writes the sentences down. `reflection`
  /// itself is already `nil` by the time `onDismiss` runs.
  @State private var closedReflectionPrompts: [DistractionPrompt] = []

  /// Set when a tap was refused, cleared by the next tap that works.
  @State private var captureFailureNote: String?

  /// The screen, redrawn once a second only while something is actually counting.
  @ViewBuilder
  private var screen: some View {
    if engine.isRunning {
      TimelineView(.periodic(from: .now, by: Self.refreshInterval)) { context in
        timerScreen(at: context.date)
      }
    } else {
      timerScreen(at: .now)
    }
  }

  /// Whether the alarm explainer should be covering the screen.
  ///
  /// A one-way binding: the cover has no way to close itself, so nothing writes
  /// back. It lifts when the answer changes, which happens on the app's next
  /// return to the foreground — and since the only place the switch can be
  /// changed is the Settings app, coming back is unavoidable. That is what makes
  /// the promise in the cover's own words ("come back to this screen and it'll
  /// let you through by itself") a promise the code keeps.
  private var alarmsAreOff: Binding<Bool> {
    Binding(get: { self.engine.authorization == .denied }, set: { _ in })
  }

  private func timerScreen(at instant: Date) -> TimerScreen {
    TimerScreen(
      model: model(at: instant),
      onStart: { self.startBlock() },
      onStop: { self.stopBlock() },
      onOpenSettings: { self.showingSettings = true },
      // Called and finished on the spot. No `Task`, no `await`, nothing queued.
      onInternalDistraction: { self.record(.internalInterruption) },
      onExternalDistraction: { self.record(.externalInterruption) })
  }

  // MARK: Turning the engine into something to draw

  private func model(at instant: Date) -> TimerScreenModel {
    guard settings.first != nil else {
      return .noSettingsRow(numeral: Self.missingReading)
    }

    let kind = engine.kind
    // While a block runs this is what is left of it; while the screen is idle the
    // engine returns the whole length of the block Start would begin, because
    // nothing has run yet and all of it is left. One question, one answer, in
    // both states — which is why the idle screen cannot show a different number
    // from the one the next block will actually use.
    let secondsLeft = Self.wholeSeconds(engine.remaining(at: instant))
    let spokenBlock = Self.spokenName(for: kind)

    return TimerScreenModel(
      blockName: spokenBlock.capitalizedFirst,
      kicker: kind.displayName,
      numeral: Self.clockLabel(seconds: secondsLeft),
      spokenNumeral: engine.isRunning
        ? Self.spokenRemaining(seconds: secondsLeft)
        : Self.spokenMinutes(secondsLeft / 60),
      progress: progress,
      completionNote: completionNote,
      // ONE AMBER ROW, AND THE MOST RECENT THING WINS IT.
      //
      // Almost every failure wording is written by the engine, not by this
      // screen — there is one wording per failure and it lives with the thing
      // that can fail. A refused tap is the exception: the engine records only
      // that a save was refused, and the sentence a person needs in that moment
      // is about the tap they just made rather than about persistence. So it is
      // worded here and it takes precedence, because it is the thing that just
      // happened under their finger.
      failureNote: captureFailureNote ?? engine.lastFailure?.message,
      capture: capture,
      controls: engine.isRunning
        ? .running
        : .start(
          isEnabled: true,
          spokenLabel: "Start \(spokenBlock), \(Self.spokenMinutes(secondsLeft / 60))"))
  }

  /// How many pomodoros to draw as done, out of how many.
  ///
  /// While a sprint has just finished the engine's own count is already back to
  /// zero — correctly, because the next sprint starts from nothing — so the rule
  /// reads the size of the sprint that just ended instead. It is the only idle
  /// state in which every segment is filled.
  private var progress: TimerScreenModel.Progress? {
    if let size = engine.lastCompletedSprintSize {
      return TimerScreenModel.Progress(completed: size, total: size)
    }
    return TimerScreenModel.Progress(
      completed: engine.completedInSprint,
      total: engine.pomodorosPerSprint)
  }

  /// The capture buttons, or `nil` if there must not be any.
  ///
  /// The rule itself lives on `TimerScreenModel.Capture`, where it is a pure
  /// function of three finished values and is tested without a database, a
  /// timer or a screen. All this does is read those three values off the engine.
  ///
  /// `currentBlockDistractions` is a derived view of what is stored, not a
  /// tally this screen keeps: the engine rebuilds it from the database when the
  /// app launches and whenever it comes back to the foreground. So a count under
  /// a button is a count of committed rows, and relaunching the app mid-block
  /// shows the same numbers it showed before.
  private var capture: TimerScreenModel.Capture? {
    TimerScreenModel.Capture.forBlock(
      isRunning: engine.isRunning,
      kind: engine.kind,
      taps: engine.currentBlockDistractions.map(\.kind))
  }

  private var completionNote: String? {
    guard let size = engine.lastCompletedSprintSize else { return nil }
    // The singular matters: a sprint of one pomodoro is a real setting, and it is
    // the first thing a reader would notice written as "1 pomodoros done".
    let unit = size == 1 ? "pomodoro" : "pomodoros"
    return "Sprint complete — \(size) \(unit) done."
  }

  // MARK: Commands

  /// Each of these hands the engine a job from inside a button, which is a
  /// synchronous place, so a small piece of asynchronous work is started to carry
  /// it. That is safe here for one specific reason: the engine writes down what
  /// happened *before* it waits for anything, so a piece of work that is
  /// cancelled part way through can lose an alarm — which the app repairs on its
  /// next return to the foreground — and can never lose a block.
  private func startBlock() {
    captureFailureNote = nil
    Task { await engine.start() }
  }

  /// A distraction was tapped. Everything below happens before this function
  /// returns, and therefore before the finger has lifted.
  ///
  /// THE ORDER HERE IS THE WHOLE FEATURE, AND IT IS THE OPPOSITE OF THE OBVIOUS
  /// ONE. The natural sequence to write is tap, buzz, then save — it feels
  /// responsive. This does tap, **save**, then buzz. The engine's method is
  /// synchronous and answers `true` only once the row is committed to disk, so
  /// the buzz in your hand is a *receipt* for a record that already exists
  /// rather than a promise that one is coming. That distinction matters because
  /// most of these taps are made without looking at the screen — looking at the
  /// screen is the distraction — so the buzz is all the confirmation there is,
  /// and it must never be able to lie.
  ///
  /// If the write is refused, nothing at all happens except the amber row: no
  /// buzz, no count, nothing spoken. Silence is the correct signal for "that did
  /// not happen".
  private func record(_ kind: DistractionKind) {
    guard engine.recordDistraction(kind) else {
      captureFailureNote = Self.captureFailedNote
      return
    }

    captureFailureNote = nil
    CaptureHaptic.tapRecorded()
    announce(kind)
  }

  /// Says what was just written, in two words.
  ///
  /// WHY AN ANNOUNCEMENT AND NOT ONLY THE BUTTON'S VALUE
  /// Each button carries its count as an accessibility value, and VoiceOver
  /// re-reads a focused element's value when the reader's own action changes
  /// it — which is the confirmation. But whether the element is still focused is
  /// a runtime behaviour no comment can promise, so the receipt is also spoken
  /// outright. This uses the same announcement mechanism the screen already runs
  /// for its failure row, rather than inventing a second one.
  ///
  /// **Two words, and no more.** Not "Internal distraction recorded, that is
  /// your second internal distraction of this block": a long sentence spoken
  /// during a focus block is itself the interruption this app exists to measure.
  /// High priority, so the receipt arrives now rather than queued behind
  /// something else — for a receipt, late is the same as confusing.
  private func announce(_ kind: DistractionKind) {
    let tally = engine.currentBlockDistractions.filter { $0.kind == kind }.count
    var spoken = AttributedString("\(kind.captureLabel), \(tally)")
    spoken.accessibilitySpeechAnnouncementPriority = .high
    AccessibilityNotification.Announcement(spoken).post()
  }

  /// Stop was tapped. This does not stop anything yet — it opens the sheet that
  /// asks why. Nothing is recorded and the block keeps running until a reason is
  /// written and confirmed.
  private func stopBlock() {
    stopReason = ""
    stopPrompts = engine.currentBlockDistractions
    isAskingWhyStopping = true
  }

  /// The person wrote a reason and confirmed. Now the block ends.
  ///
  /// THE NOTES ARE SAVED BEFORE THE BLOCK IS STOPPED, AND THE ORDER IS NOT
  /// ARBITRARY. Attaching first means that if the app dies between the two
  /// steps, the sentences are on disk and the block is still running — a state
  /// the app recovers from on its own. The other order loses the sentences for
  /// good. Attaching is synchronous, so there is no window between them worth
  /// worrying about; the order is chosen for the case where there is.
  private func confirmStop() {
    let reason = stopReason.trimmingCharacters(in: .whitespacesAndNewlines)
    guard reason.isEmpty == false else { return }
    isAskingWhyStopping = false
    saveDrafts(for: stopPrompts)
    noteDrafts = [:]
    Task { await engine.stop(reason: reason) }
  }

  /// They decided to keep going. The block is untouched — and the sentences are
  /// kept.
  ///
  /// Those sentences are about taps that really happened. They were not
  /// conditional on the stop, so a change of mind must not throw away real
  /// reflection. The *reason for stopping* is the thing discarded here, because
  /// no stop occurred; it is cleared again the next time Stop is pressed.
  ///
  /// The drafts themselves are deliberately not emptied. If this block then runs
  /// to its natural end, the end-of-block sheet opens with those same fields
  /// already carrying those same sentences, because both sheets read the same
  /// drafts.
  private func keepGoing() {
    isAskingWhyStopping = false
    saveDrafts(for: stopPrompts)
  }

  /// The end-of-block sheet has closed, by the Done button or by being swiped
  /// away.
  ///
  /// **Those two are the same action, and neither discards anything.** This
  /// mirrors the rule already documented on the settings sheet, so the app
  /// teaches one thing about sheets rather than two. Whatever was typed is
  /// written onto rows that already exist; whatever was left blank stays blank,
  /// which is a first-class outcome rather than a failure.
  ///
  /// Nothing here can lose a record. The rows were written when the buttons were
  /// tapped. This only ever adds an optional sentence to one.
  private func reflectionSheetClosed() {
    saveDrafts(for: closedReflectionPrompts)
    closedReflectionPrompts = []
    noteDrafts = [:]
  }

  /// Writes the drafts onto the rows they belong to, and says so if the store
  /// refuses them.
  ///
  /// WHY THE TAPS ARE HANDED IN RATHER THAN LEFT TO THE ENGINE TO FIND
  /// The engine bounds its query at the oldest tap being annotated instead of
  /// reading the whole distraction log. That log is the one table in this app
  /// designed to grow for its whole life, and this runs on the main thread every
  /// time either sheet closes — which, by D4, is the moment a break has already
  /// started counting behind it.
  ///
  /// An empty list means there is nothing to write, so nothing is read either.
  private func saveDrafts(for prompts: [DistractionPrompt]) {
    guard let earliest = prompts.map(\.timestamp).min() else { return }
    if engine.attachNotes(noteDrafts, notEarlierThan: earliest) {
      if captureFailureNote == Self.notesFailedNote { captureFailureNote = nil }
    } else {
      captureFailureNote = Self.notesFailedNote
    }
  }

  /// The settings sheet has closed.
  ///
  /// The engine keeps its own copy of the six values, taken at the last block
  /// boundary, and a running block is never allowed to notice a change. But an
  /// *idle* screen must show the new focus length as soon as the sheet is
  /// dismissed, so the engine is asked to re-read. This is the only thing that
  /// happens when the sheet closes: there is no Save, because every change was
  /// already written the moment it was made.
  private func settingsSheetClosed() {
    Task { await engine.synchronize() }
  }

  // MARK: Formatting

  /// How VoiceOver names the block inside a sentence: "Start focus block, 25
  /// minutes".
  private static func spokenName(for kind: BlockKind) -> String {
    switch kind {
    case .work: "focus block"
    case .shortBreak: "short break"
    case .longBreak: "long break"
    }
  }

  /// Rounds a remaining time up to whole seconds.
  ///
  /// Up rather than down, so that a block which has just started reads `25:00`
  /// rather than `24:59`, and `00:00` appears exactly when the block is over
  /// rather than for the whole of its last second.
  private static func wholeSeconds(_ remaining: Duration) -> Int {
    let parts = remaining.components
    guard parts.seconds > 0 || parts.attoseconds > 0 else { return 0 }
    return Int(parts.seconds) + (parts.attoseconds > 0 ? 1 : 0)
  }

  /// Minutes are not carried into hours. A two-hour block reads `120:00`, which
  /// is longer than it is pretty and is unambiguous, where `2:00:00` next to
  /// `04:31` on another day would not be.
  private static func clockLabel(seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
  }

  private static func spokenMinutes(_ minutes: Int) -> String {
    "\(minutes) \(minutes == 1 ? "minute" : "minutes")"
  }

  /// What VoiceOver says is left of a running block.
  ///
  /// **WHOLE MINUTES, NOT MINUTES AND SECONDS, AND THE REASON IS NOT BREVITY.**
  /// This value is attached to an element that is redrawn once a second. When a
  /// VoiceOver reader has that element focused, a value that changes is a value
  /// the system may read out again — so a spoken figure containing seconds could
  /// mean a full sentence spoken every second for twenty-five minutes, which
  /// would make the screen unusable for exactly the readers the rest of this
  /// file is written for. Rounding to whole minutes takes the number of changes
  /// in a twenty-five minute block from about fifteen hundred to twenty-six.
  ///
  /// Rounded **down**, so the spoken minute and the printed one always agree:
  /// while the screen shows `24:58` this says twenty-four minutes, not
  /// twenty-five.
  ///
  /// The last minute is given as a phrase rather than a count of seconds for the
  /// same reason. Nothing is lost by it: the alarm is what tells a person the
  /// block ended, not this label.
  private static func spokenRemaining(seconds: Int) -> String {
    let wholeMinutes = seconds / 60
    guard wholeMinutes > 0 else { return "Less than a minute remaining" }
    return "\(spokenMinutes(wholeMinutes)) remaining"
  }
}

// MARK: - String helper

private extension String {
  /// "focus block" becomes "Focus block".
  ///
  /// The same phrase is needed in two shapes: inside a sentence VoiceOver reads
  /// ("Start focus block, 25 minutes") and on its own as the name of the element
  /// ("Focus block"). Deriving one from the other means they cannot drift apart,
  /// and it keeps the phrase written down exactly once.
  var capitalizedFirst: String {
    guard let first else { return self }
    return first.uppercased() + dropFirst()
  }
}

// MARK: - Previews

/// The wired screen, on a throwaway database that lives in memory only.
///
/// Every *state* of this screen is previewed next door in `TimerScreen.swift`,
/// where neither a database nor a timer is needed. This pair exists to check the
/// wiring itself — that the engine reaches the screen, in both appearances.
#Preview("Wired, light") {
  TimerViewPreviewHost(appearance: .light)
}

#Preview("Wired, dark") {
  TimerViewPreviewHost(appearance: .dark)
}

/// Preview scaffolding, never part of what ships.
///
/// A preview has no running app around it, so no database is open and the timer
/// would have nothing to read. This opens a throwaway store that lives in memory
/// only and disappears when the preview closes.
private struct TimerViewPreviewHost: View {
  // MARK: Internal

  /// Forces the preview into light or dark, so the pair is a real check that
  /// colours resolve for both.
  let appearance: ColorScheme

  var body: some View {
    switch bootstrap {
    case .success(let running):
      TimerView()
        .modelContainer(running.container)
        .environment(running.engine)
        .preferredColorScheme(appearance)

    case .failure(let error):
      StoreUnavailableView(technicalDetail: error.localizedDescription)
    }
  }

  // MARK: Private

  /// A container and an engine, built once per preview rather than on every
  /// redraw of the canvas.
  private struct PreviewRun {
    let container: ModelContainer
    let engine: TimerEngine
  }

  @State private var bootstrap: Result<PreviewRun, any Error> = Result {
    let container = try AppModelContainer.make(.inMemory)
    _ = try AppSettings.current(in: container.mainContext)
    return PreviewRun(
      container: container,
      engine: TimerEngine(
        context: container.mainContext,
        clock: SystemTimerClock(),
        alarms: AlarmKitScheduler()))
  }
}
