import Foundation
import SwiftData

// swiftlint:disable file_length
//
// THE ONLY LINT RULE THIS FILE TURNS OFF, AND WHY.
// `file_length` counts documentation. This project requires every type and
// every non-obvious member to be argued in prose for a reviewer who reads code
// but does not write Swift, and this file is the feature's one dense piece of
// behaviour: the wall-clock model, the no-pause decision, the restore rules and
// the clock-skew guard all have to be explained where they are implemented.
// Roughly half of what follows is that explanation. The alternative — splitting
// the class across two files — would only move the lines, and would force every
// piece of the engine's private state to become visible to the rest of the app,
// which is real protection traded away for a line count. Every other rule,
// including all of the ones that catch actual defects, stays on.

/// The timer itself: what is running, what happens when it ends, and what is
/// written down about it.
///
/// THE ONE IDEA EVERYTHING HERE FOLLOWS FROM: THE TIMER DOES NOT COUNT.
/// It records the wall-clock instant the block ends and derives everything from
/// that. The screen's ticking label and the task that wakes the app at the
/// boundary are both *notifications that time has passed* — neither is ever the
/// record of how much. That is the difference between a timer that survives
/// being backgrounded and one that quietly loses four minutes because iOS
/// suspended the process.
///
/// SETTINGS ARE READ ONCE, AT A BOUNDARY, INTO A FROZEN COPY.
/// A running block holds a `TimerSettingsSnapshot` taken the instant it began
/// and cannot see the settings row at all. That is what makes "changes take
/// effect at the next block" true by construction rather than by anybody
/// remembering it.
///
/// IT ALSO OWNS THE DISTRACTION LOG, AND THAT IS AN ARCHITECTURAL DECISION.
/// Writing down a tap needs one answer the engine alone can give safely: *which
/// block is running at this exact instant?* A separate store type could only
/// ask the database, and would get either a half-finished answer — the engine's
/// own in-flight changes, mid-transition — or a stale one, depending on which
/// handle it was given. Both are silent, and both file a distraction against
/// the wrong pomodoro, which is the single defect this feature exists to
/// prevent. So the engine records them. See `recordDistraction(_:)`.
///
/// THERE IS NO PAUSE, AND ITS ABSENCE IS DELIBERATE.
/// `start()` and `stop()` are the whole of the timer's surface — D13 removed
/// skip, and the recording methods below never touch the clock. AlarmKit's own
/// guidance suggests offering a pause control in a countdown Live Activity, so
/// the omission will read as an oversight: it is not. The contract's list of
/// what may be customised does not include pause, a paused pomodoro is not a
/// pomodoro under the method, and a pause button on a Lock Screen is the
/// easiest way to turn a focus block into a twenty-minute negotiation with
/// yourself.
///
/// WHY IT IS MAIN-ACTOR ONLY: it owns a `ModelContext`, SwiftData's handle for
/// reading and writing, and that handle is not safe to share between threads.
/// Every database access in this app is on the main thread, and confining the
/// whole engine is how that is enforced rather than remembered. `@Observable`
/// is what lets the screens redraw when any of the values below change.
@MainActor
@Observable
final class TimerEngine {
  /// How far the wall clock and the monotonic clock may disagree before the
  /// wall clock is treated as having moved. More than ordinary scheduling
  /// drift, less than any real clock change, which is at minimum a minute.
  static let clockSkewTolerance: TimeInterval = 5

  // MARK: What the screens read

  /// The block that is running, or — when idle — the one `start()` would begin.
  private(set) var kind: BlockKind

  /// Whether a block is running right now.
  private(set) var isRunning: Bool

  /// How many focus blocks are complete in the current sprint.
  private(set) var completedInSprint: Int

  /// How many focus blocks make up the sprint. From the running block's frozen
  /// settings while a block runs, from the live settings while idle.
  private(set) var pomodorosPerSprint: Int

  /// When the running block ends. `nil` when idle.
  private(set) var endsAt: Date?

  /// Whether the app may set alarms.
  private(set) var authorization: AlarmAuthorization

  /// Non-nil when the last command could not do what it said. Shown on the
  /// timer screen: a failure nobody sees is a failure discovered when a block
  /// ends in silence.
  private(set) var lastFailure: TimerEngineFailure?

  /// The size of the sprint that has just been completed, or `nil` if the last
  /// thing to happen was not the end of a sprint.
  ///
  /// It exists for one line on the timer screen — "Sprint complete — 4
  /// pomodoros done." — which cannot be drawn from `completedInSprint`, because
  /// by then the count has returned to zero. Held in memory only and never
  /// saved: it acknowledges a moment. The record is the finished-block rows.
  private(set) var lastCompletedSprintSize: Int?

  /// The taps recorded during the block that is running now, oldest first.
  ///
  /// **A DERIVED VIEW OF THE DATABASE, NOT A BUFFER.** Every element in here is
  /// already a committed row; nothing is waiting to be written. Deleting this
  /// property would change what the screen shows and nothing whatsoever about
  /// what is stored. That claim is not an assertion: the array is rebuilt from
  /// the database in `init` and in `synchronize()`, and a test relaunches the
  /// engine to prove the counts come back.
  ///
  /// It resets to empty at every block boundary, so the count drawn beside each
  /// capture button is about *this* block and never about the day. Reading
  /// distractions back is F6's job and no part of it is here.
  private(set) var currentBlockDistractions: [DistractionPrompt] = []

  /// Takes a tap that arrived from the wrist and, if it belongs to the block
  /// running now, adds it to the sentences this block will be asked about.
  ///
  /// **THE ROW IS ALREADY WRITTEN BEFORE THIS IS CALLED.** `WatchTapInbox` has
  /// committed it, and nothing here can lose it: this only decides whether the
  /// end-of-block sheet asks for a sentence about it. A tap the engine never
  /// hears about keeps its row and its `nil` note, which F5 already treats as a
  /// completely normal outcome — *"the counts alone are the data the spec asks
  /// for"*.
  ///
  /// **WHY THIS EXISTS AT ALL.** The prompt list is held in memory rather than
  /// read back from the database, so a tap written straight to the store — which
  /// is exactly what a wrist tap is — would never appear in the sheet. `F7.md`
  /// says a wrist tap *"gets a sentence field in the phone's end-of-pomodoro
  /// sheet like any other, provided it arrives before the sheet is presented"*,
  /// and without this it never would, however promptly it arrived.
  ///
  /// **The session check is the whole of the safety.** A tap is adopted only if
  /// it names the block running right now. One from a block that has already
  /// ended is not held over and not reassigned — that would put a distraction
  /// from twenty minutes ago into the sheet for a block it did not happen in,
  /// which is the defect `recordDistraction(_:)` guards the same way. Late is
  /// fine; wrong is not.
  ///
  /// - Returns: `true` when the sheet will ask about it.
  @discardableResult
  func adoptWristTap(id: UUID, kind: DistractionKind, at instant: Date, sessionID: UUID) -> Bool {
    guard isRunning, let state, state.isRunning, state.kind == .work else { return false }
    guard state.sessionID == sessionID else { return false }
    guard currentBlockDistractions.contains(where: { $0.id == id }) == false else { return false }

    currentBlockDistractions.append(DistractionPrompt(id: id, kind: kind, timestamp: instant))
    return true
  }

  /// Set once, at the end of a work block the app was awake to see end, when
  /// that block had at least one tap. The screen takes it and clears it.
  ///
  /// It is a *presentation signal* and never a record. Nothing about what is
  /// stored depends on it: a block whose sheet is never presented, is swiped
  /// away, or is killed with, keeps exactly the rows its taps made, with no
  /// sentences on them. It has one writer — `end(...)` — and one reader,
  /// `consumePendingReflection()`.
  private(set) var pendingReflection: BlockReflection?

  // MARK: Collaborators

  /// The database handle. Main-thread only, which is why this whole class is.
  private let context: ModelContext

  /// Where time comes from. Real in the app, controlled by the test in tests.
  private let clock: any TimerClock

  /// Where alarms come from. Never AlarmKit directly — see `AlarmScheduling`.
  private let alarms: any AlarmScheduling

  /// Where the next focus block's task comes from, or `nil` when the app has no
  /// session plan. **This is the whole of what the timer knows about Todoist:**
  /// one question, asked once per focus block, answered with four strings.
  private let attachments: (any SessionAttaching)?

  // MARK: Private state

  /// The saved timer row. `nil` only when the database could not be read, in
  /// which case the app is already showing its store-failure screen.
  private var state: TimerState?

  /// The settings as of the last boundary: what the idle screen shows, and what
  /// the next block will be started with.
  private var idleSettings: TimerSettingsSnapshot

  /// The running block's deadline on the monotonic clock, held **in memory
  /// only**. See `correctForClockSkew` for what it is for and why it must never
  /// be saved or rebuilt from `endsAt`.
  private var continuousDeadline: ContinuousClock.Instant?

  /// The one task that waits for the current block to end. Cancelled and
  /// replaced at every transition; never more than one at a time.
  private var boundaryTask: Task<Void, Never>?

  /// A counter bumped every time a boundary task is armed, so that a task which
  /// has already woken can tell whether it is still the current one.
  ///
  /// WHY A PLAIN COUNTER RATHER THAN COMPARING THE TASKS THEMSELVES. Swift has
  /// no way to ask "am I the task this handle points at", and the question has
  /// to be answered for correctness rather than tidiness: a woken task must let
  /// go of `boundaryTask` before it does any work, or the work it does will
  /// cancel it — see `armBoundary` — and it must *not* let go if it has already
  /// been superseded, or it would drop the handle to a newer task that is still
  /// waiting. The counter answers both questions in one comparison.
  private var boundaryGeneration = 0

  /// Counts the times the engine has been abandoned from outside a transition —
  /// a confirmed stop, or a Live Activity dismiss.
  ///
  /// WHY A COUNTER RATHER THAN A FLAG, AND WHY IT EXISTS AT ALL
  /// `end()` freezes the ended block's facts and then, on the auto-start path,
  /// genuinely suspends inside `begin()` while the next block's alarm is
  /// scheduled. `stop(reason:)` is reached from its own task and can run to
  /// completion inside that window: it clears `pendingReflection` and goes idle,
  /// and then `end()` resumes and assigns the ended block's reflection anyway —
  /// putting a sheet in front of somebody who has just confirmed they want to
  /// quit, which is the one thing D14 forbids. Freezing this number before the
  /// suspension and refusing to publish if it has moved makes that impossible
  /// rather than merely unlikely, which is the standard the rest of this
  /// feature is held to.
  private var abandonGeneration = 0

  /// The alarm the next `schedule()` must not cancel.
  ///
  /// Set when a block ends, read once when the block after it is scheduled.
  /// Without it, chaining cancels the finished block's alarm at the instant it is
  /// due — which is why breaks never sounded while focus blocks, dismissed by a
  /// person, always did: by the time somebody has dismissed an alarm it has
  /// certainly fired, and nothing waits for a break.
  private var alarmToSpare: UUID?

  // MARK: Initialisation

  /// Builds the engine and adopts whatever the database already says, so the
  /// screen is right immediately. `synchronize()` works out whether it is still
  /// true; the app calls that at launch and on every return to the foreground.
  init(
    context: ModelContext,
    clock: any TimerClock,
    alarms: any AlarmScheduling,
    attachments: (any SessionAttaching)? = nil) {
    self.context = context
    self.clock = clock
    self.alarms = alarms
    self.attachments = attachments

    let fallback = TimerSettingsSnapshot.fallback
    idleSettings = fallback
    kind = .work
    isRunning = false
    completedInSprint = 0
    pomodorosPerSprint = fallback.pomodorosPerSprint
    authorization = alarms.authorization

    do {
      let row = try TimerState.current(in: context)
      state = row
      idleSettings = try TimerSettingsSnapshot(clamping: AppSettings.current(in: context))
      adopt(row)
      // The taps for a block that is still running were written to the database
      // by whatever process recorded them, which may well have been a previous
      // launch of this app. Rebuilding them here is what makes the count beside
      // the capture buttons survive a relaunch — and it is also the proof that
      // the array is derived from the store rather than being the store.
      rehydrateDistractions()
    } catch {
      lastFailure = .persistenceFailed
    }
  }

  // MARK: Reading the countdown

  /// How long is left at a given instant.
  ///
  /// It takes the instant rather than reading a clock, so the screen can drive
  /// it from the date its own refresh hands it and a test can ask about any
  /// moment without moving anything. While idle it returns the whole length of
  /// the block Start would begin: nothing has run, so all of it is left.
  func remaining(at instant: Date) -> Duration {
    guard isRunning, let endsAt else { return idleSettings.duration(for: kind) }
    let seconds = endsAt.timeIntervalSince(instant)
    return seconds > 0 ? .seconds(seconds) : .zero
  }

  // MARK: Commands

  /// Asks for alarm permission if it has not been asked for, then begins the
  /// next block. If permission is refused this does nothing but record the
  /// refusal, and the screen shows a blocking explainer — there is deliberately
  /// no quieter fallback, because a timer that cannot reliably tell you a block
  /// ended has no working state to degrade into.
  func start() async {
    guard !isRunning else { return }
    lastFailure = nil
    lastCompletedSprintSize = nil

    authorization = alarms.authorization
    if authorization == .notDetermined {
      authorization = await alarms.requestAuthorization()
    }
    guard authorization == .authorized else { return }

    await begin(kind: kind, completedInSprint: completedInSprint, settings: readSettings())
  }

  /// Abandons the sprint: records the running block with the reason the person
  /// gave, calls off the alarm, returns the sprint count to zero and goes idle
  /// with a focus block queued.
  ///
  /// **This is the only way out of a running block, and it is deliberately the
  /// only one.** A pomodoro is indivisible: it is finished or it is void, never
  /// paused and never quietly skipped. An exit still has to exist, because a
  /// mistyped two-hour focus length would otherwise be inescapable — but it is
  /// priced. The caller must supply a reason, and the screen will not let anyone
  /// past without writing one.
  ///
  /// The reason is required by the *type*, not merely by the screen. A second
  /// caller added later cannot quietly stop a block without one.
  func stop(reason: String) async {
    guard isRunning, let state else { return }
    abandonGeneration &+= 1
    lastFailure = nil
    cancelAlarm()
    recordSession(state: state, endedAt: clock.now, wasAbandoned: true, abandonReason: reason)
    lastCompletedSprintSize = nil
    // STOPPING NEVER PRODUCES A REFLECTION SHEET, AND THAT IS A DECISION.
    // The sheet that asked for the stop reason has already asked for a sentence
    // about each tap, in the same sheet, at the same moment — that is what D14
    // merged. A second modal appearing the instant somebody confirms they want
    // to quit is the exact defect D14 exists to prevent: two sheets back to
    // back train a person to dismiss both without reading, and the one that
    // gets dismissed is the one that mattered. The rows themselves are
    // untouched; only the offer to annotate them is withdrawn.
    pendingReflection = nil
    goIdle(kind: .work, completedInSprint: 0)
    persist()
  }

  // MARK: Reconciliation

  /// Brings the engine back into agreement with the wall clock. Call it at
  /// launch, on every return to the foreground, and after the settings screen
  /// closes. Idempotent, and safe to call while idle.
  ///
  /// TWO THINGS HAPPEN, IN THIS ORDER, AND THE ORDER MATTERS. First a clock
  /// change is corrected, before anything looks at the block's end instant —
  /// the other way round would complete the block before the correction could
  /// save it. Then a block that ended unobserved is recorded, as **exactly
  /// one** row, and the timer goes idle whatever auto-start says. That is the
  /// answer to a phone left on a desk overnight: there is no replay loop,
  /// because there is nothing to replay. Auto-starting a block that began at
  /// three in the morning would be a lie about how long somebody worked.
  func synchronize() async {
    authorization = alarms.authorization

    if state == nil {
      // Unreadable when the engine was built. Trying again is free, and a store
      // that has recovered should not need a relaunch.
      do {
        state = try TimerState.current(in: context)
      } catch {
        lastFailure = .persistenceFailed
      }
    }
    guard let state else { return }

    // Idle: nothing to reconcile, but the settings may have changed since the
    // screen last read them.
    guard state.isRunning else { return goIdle(kind: state.kind, completedInSprint: state.completedInSprint) }

    await correctForClockSkew(state)

    guard clock.now >= state.endsAt else {
      adopt(state)
      armBoundary()
      // Still the same block, possibly after hours away. Its taps are read back
      // from the database rather than assumed to still be in memory, because
      // this is also the path a fresh launch takes.
      rehydrateDistractions()
      return
    }

    // Ended while the app was suspended or closed. Recorded as completed rather
    // than abandoned: it finished and the alarm fired; the user was not looking.
    cancelAlarm()
    // No reflection sheet on this path, for the same reason there is no
    // auto-start on it: arriving here means nobody was present when the block
    // ended. The taps are already recorded and stay recorded; what is refused
    // is the *prompt*. A sentence written an hour after the fact is not the
    // self-knowledge data the spec asks for, and a queue of prompts waiting to
    // be worked through the next time the app opens is a capture surface by
    // another name.
    // WHETHER THE CYCLE CARRIES ON DEPENDS ON HOW LONG AGO IT ENDED.
    //
    // This path is taken whenever a block finished while the app was not awake —
    // which, on a phone, is *every* block, because locking the screen suspends
    // the app. Refusing to auto-start here meant the setting worked only while
    // somebody was staring at the screen, and a locked sprint stalled at its
    // first boundary. That is the opposite of what a Pomodoro timer is for, and
    // it is why F4's own device check — a playlist through a full sprint with the
    // screen locked — could not have passed.
    //
    // The protection this refusal was providing is real and is kept. A phone left
    // overnight must not wake mid-focus-block, and its owner must not find a
    // night of pomodoros in the record. What separates the two cases is the size
    // of the gap: two seconds is the alarm doing its job; fourteen hours is
    // nobody being there.
    //
    // The threshold is the finished block's own length. Anything inside that is
    // a wake this app asked for.
    let gap = clock.now.timeIntervalSince(state.endsAt)
    let wakeWasPrompt = gap <= state.endsAt.timeIntervalSince(state.startedAt)
    await end(
      state: state,
      completed: true,
      at: state.endsAt,
      mayAutoStart: wakeWasPrompt,
      // Still no reflection prompt, whatever the gap: the taps are recorded and
      // stay recorded, and what is refused is a sheet nobody was there to fill in.
      mayPromptForReflection: false)
    // A sprint that ended while the app was closed is not announced on the next
    // launch. The acknowledgement is for the person who was there.
    lastCompletedSprintSize = nil
  }

  // MARK: Silencing a ringing alarm

  /// Which block's alarm is making a noise right now, or `nil`. `D26`.
  ///
  /// Stored here rather than in `TimerEngine+Silence.swift` because Swift has no
  /// stored properties in extensions. The two methods that use it are over
  /// there; this line is the only part that had to stay.
  private(set) var ringingAlarmID: UUID?

  /// The Live Activity's dismiss button was tapped. The same button means two
  /// things and the engine, not the button, decides which: dismissing a block
  /// before its end abandons it; dismissing one whose end has passed is just
  /// silencing the alarm on a block that finished.
  ///
  /// It never chains into another block. A dismiss arrives from a locked phone
  /// where the app may not be resident, and starting a focus block nobody is
  /// present for is exactly what auto-start is not for.
  func handleDismiss() async {
    guard isRunning, let state else { return }
    let completed = clock.now >= state.endsAt

    // **A DISMISS FOR A BLOCK THAT HAS NOT ENDED IS A STALE ALARM, NOT AN ABANDON.**
    //
    // The owner found this in a compressed sprint: focus ended, the sheet
    // appeared, the break started — and then *"alarm fired, reset short break."*
    // The alarm that fired was the **focus block's**, arriving after the break
    // had begun. It landed here, found a break that had not reached its end, and
    // abandoned it.
    //
    // **It is a hole in the sparing rule, not in the alarm fix.** Scheduling
    // spares an alarm that is `.alerting` so the next block cannot silence it —
    // and nothing then cleans that alarm up, so it outlives the block it belonged
    // to and its dismiss lands on the next one.
    //
    // The way out is this file's own invariant, from `DismissBlockIntent`:
    // *"there is no longer a dismiss button on the running countdown… the only
    // way to arrive here is a sounding alarm."* The mid-block button was removed.
    // So there is no legitimate way to dismiss a block that has not ended, and
    // arriving here with `completed == false` means the alarm belonged to an
    // earlier block.
    //
    // **Nothing is cancelled on the way out.** This ran *because* somebody
    // dismissed that alarm, so iOS has already ended it — and `cancelAlarm()`
    // clears everything outstanding, which would take the current block's alarm
    // with it and leave the break to end in silence.
    guard completed else { return }

    // **THE GENERATION IS BUMPED HERE, NOT ABOVE THE GUARD, AND THAT ORDER COST
    // THE DISTRACTION LOG A PROMPT.**
    //
    // It used to be the first line of this method. A dismiss for a block that
    // has *not* ended returns without doing anything else — but it had already
    // bumped the counter, and `publishReflection` refuses to publish when the
    // generation has moved. So this sequence dropped a sheet:
    //
    //   focus ends -> `boundaryReached()` -> `end()` -> `begin()` suspends
    //   awaiting `alarms.schedule(...)` -> the alarm rings -> Silence is tapped
    //   -> `handleDismiss()` sees the *new* block, which has not completed,
    //   bumps, returns -> `publishReflection` for the block that just finished
    //   finds the generation moved and publishes nothing.
    //
    // That window is a real AlarmKit round trip, and it is exactly the case
    // `D26` exists for: the app in the foreground when the bell goes. The lost
    // sheet is the one thing this app is for.
    //
    // Bumping belongs to abandoning, and nothing above this line abandons.
    abandonGeneration &+= 1
    lastFailure = nil

    // **THE SHEET IS OFFERED HERE NOW, AND THE OLD REASONING WAS BACKWARDS.**
    //
    // It used to refuse, on the grounds that "a dismiss arrives from a locked
    // phone, where there is no screen in front of anybody to present a sheet
    // on." But dismissing an alarm is somebody reaching for the phone — it is
    // the most reliable evidence this engine ever gets that a person is present
    // and holding it. The old rule refused a prompt at the one moment it was
    // certain of an audience.
    //
    // Combined with the boundary path no longer cancelling the alarm, this is
    // the owner's ruling in two lines: the alarm always sounds, and the sheet
    // follows it.
    //
    // **AND IT CHAINS, WHICH IT DID NOT AT FIRST — THAT WAS A REGRESSION.**
    //
    // This passed `mayAutoStart: false`, on the reasoning that "a dismiss can
    // arrive from a locked phone, and starting a focus block nobody is present
    // for is what auto-start is not for."
    //
    // That reasoning was written when a dismiss was **rare**. Before the alarm
    // was allowed to fire, this path ran almost never — the boundary handled
    // block ends, and it chained. Letting the alarm through made dismissing the
    // normal way a block ends, so a rule written for an edge case started
    // governing every block. The owner found it within an hour: *"it appears
    // stopping the alarm cancels the break."* Eight blocks, and not one of them
    // rolled into its break.
    //
    // **`completed` is the honest condition.** A dismiss before the end instant
    // is somebody abandoning a block and must chain into nothing; a dismiss
    // after it is somebody acknowledging a block that finished, and `D4` is
    // explicit that the break follows — *"the break timer starts running the
    // instant the block ends, behind the sheet."*
    //
    // And the original worry does not survive contact with what a dismiss is: it
    // is a **deliberate tap on a button**. That is the same evidence of presence
    // this method now relies on to offer a sheet at all. Refusing to start the
    // next block while accepting the tap as proof somebody is there would be two
    // opposite readings of one gesture.
    //
    // `BlockReflection` refuses to exist without at least one tap, so a block
    // with nothing to reflect on still shows nothing.
    await end(state: state, completed: true, at: clock.now, mayAutoStart: true, mayPromptForReflection: true)
  }

  /// The block's deadline arrived and the app was awake to see it. This is the
  /// only path on which auto-start can chain one block into the next, because
  /// it is the only one that can establish that the app was here when the block
  /// ended. The engine stays correct if it never runs: `synchronize()` is the
  /// guarantee.
  func boundaryReached() async {
    guard isRunning, let state, state.isRunning else { return }
    // Each block reports its own alarm outcome and nothing else. Without this,
    // a failure recorded for the block that is ending would stay on the screen
    // through every block auto-start chains after it — and a warning that is
    // sometimes stale is a warning a person learns to ignore, which disarms the
    // one message that matters.
    lastFailure = nil

    guard clock.now >= state.endsAt else {
      // Woken early: the monotonic clock says the block is over and the wall
      // clock disagrees, so the wall clock moved. Reconciling knows what to do.
      return await synchronize()
    }

    // HOW LATE IS TOO LATE, AND WHY THE QUESTION HAS TO BE ASKED HERE.
    // A sleeping task does not fire while iOS has the app suspended: it fires
    // the instant the app is resumed, however many hours later that is. So
    // arriving here is not by itself evidence that anybody was present when the
    // block ended, and auto-starting a break because the phone was picked up at
    // breakfast would be exactly the replay this feature refuses to do. More
    // than a few seconds late means we were not watching, so this is handed to
    // reconciliation, which records one block and goes idle whatever auto-start
    // says. It also removes a race: on resume this task and the app's own
    // foreground reconciliation are both queued, and before this guard the two
    // produced different screens depending on which ran first.
    guard clock.now.timeIntervalSince(state.endsAt) <= Self.clockSkewTolerance else {
      return await synchronize()
    }

    // **THE ALARM IS NOT CANCELLED HERE, AND THAT LINE'S REMOVAL IS THIS FIX.**
    //
    // It used to be. `cancelAlarm()` sat on this path with no comment saying
    // why, and the consequence was that the app went quiet in exactly the case
    // somebody was present: this task only runs when the app is awake, so
    // reaching this line meant cancelling the alarm a moment before AlarmKit
    // made a sound. `docs/chores/C14.md` has the owner's report — one block in
    // three ever sounded.
    //
    // **The audio background mode made it worse rather than rarer.** A sprint
    // playing music keeps the app alive, so this task fires on time even with
    // the phone locked and face down — cancelling the alarm while no screen
    // exists to show a sheet on. Neither the noise nor the prompt.
    //
    // The reasoning underneath it was that the app being awake meant somebody
    // was watching. **It does not.** A phone face down on a desk — which is what
    // people do to remove distractions, and therefore precisely when the alarm
    // is the only thing that can reach them — has this app frontmost and awake.
    //
    // `SPEC.md` F2 promises the alert sounds through silent mode and an active
    // Focus. It makes no exception for the app being open, and there is now no
    // code that invents one.
    //
    // Ended at the instant it was due to end, not the instant this ran: the
    // task can wake a moment late and the record must not drift with it.
    //
    // THIS IS THE ONLY PLACE A REFLECTION SHEET IS EVER OFFERED.
    // Not because sheets are special, but because this is the only path in the
    // engine that can establish the app was awake and in front of somebody when
    // the block ended — the two guards above are exactly that test, and they
    // are F2's, already written and already tested for the auto-start question.
    // Every other way a block can end goes through `synchronize()` or
    // `handleDismiss()`, both of which mean nobody was watching.
    await end(state: state, completed: true, at: state.endsAt, mayAutoStart: true, mayPromptForReflection: true)
  }

  // MARK: Running a block

  /// Starts a block: writes it down, then arranges to be told when it ends.
  ///
  /// THE ORDER IS THE POINT. The block is saved before anything is awaited, so
  /// a cancelled task can lose an alarm — which reconciliation repairs on the
  /// next foreground — and can never lose a block.
  private func begin(kind newKind: BlockKind, completedInSprint count: Int, settings: TimerSettingsSnapshot) async {
    guard let state else {
      lastFailure = .persistenceFailed
      return
    }
    let startedAt = clock.now

    state.kind = newKind
    state.startedAt = startedAt
    state.endsAt = startedAt.addingTimeInterval(TimeInterval(settings.minutes(for: newKind) * 60))
    state.completedInSprint = count
    state.sessionID = UUID()
    // A pomodoro takes the plan's next item; a break takes nothing, because a
    // break is not a pomodoro. Asked once, here, and frozen for the block.
    state.attach(newKind == .work ? attachments?.takeNextAttachment() : nil)
    // A new block starts with nothing recorded against it. This is the only
    // place the running count is emptied for a block that is *starting*; the
    // idle paths empty it in `goIdle`. Note where it sits: after the new
    // identity is minted, so that a tap arriving during the rest of this method
    // is counted against the block it will genuinely belong to.
    currentBlockDistractions = []
    state.isRunning = true
    // The settings are frozen here and nowhere else.
    state.apply(settings)
    persist()

    adopt(state)
    continuousDeadline = clock.continuousNow.advanced(by: settings.duration(for: newKind))
    armBoundary()
    await scheduleAlarm(for: state)
  }

  /// Ends the running block: records it, works out what follows, and either
  /// starts that or goes idle.
  ///
  /// WHY `mayPromptForReflection` IS ITS OWN PARAMETER WHEN IT IS TRUE ON
  /// EXACTLY THE SAME PATH AS `mayAutoStart`
  /// Today the two conditions coincide, so reusing `mayAutoStart` would be
  /// correct and would save a line. It would also be a trap. `mayAutoStart`
  /// means "the app is permitted to chain one block into the next"; the first
  /// future caller that passes it `true` for some reason of its own would
  /// silently begin putting sheets in front of people. A parameter that says
  /// what it means costs one line and cannot be misread.
  ///
  /// - Parameters:
  ///   - state: the running timer row, about to become the block that ended.
  ///   - completed: whether it ran to its end rather than being abandoned.
  ///   - instant: the moment to record it as having ended.
  ///   - mayAutoStart: whether the next block may begin by itself.
  ///   - mayPromptForReflection: whether the person is here to be asked about
  ///     their taps. True only from `boundaryReached()`.
  private func end(
    state: TimerState,
    completed: Bool,
    at instant: Date,
    mayAutoStart: Bool,
    mayPromptForReflection: Bool) async {
    let finished = state.snapshot
    // FROZEN BEFORE ANYTHING ELSE RUNS, BECAUSE EVERYTHING BELOW OVERWRITES IT.
    // `state` is the single timer row: the transition rewrites its kind and
    // mints a new `sessionID` in place. These three locals are the ended
    // block's facts, and reading any of them afterwards would describe the
    // block that came next.
    let endedSessionID = state.sessionID
    // Carried to whatever is scheduled next, so the alarm for the block ending
    // right now survives being replaced.
    alarmToSpare = endedSessionID
    let prompts = currentBlockDistractions
    // Frozen with the rest, so that a stop confirmed while `begin()` below is
    // suspended cannot be overtaken by this method resuming. See
    // `abandonGeneration`.
    let generation = abandonGeneration

    recordSession(state: state, endedAt: instant, wasAbandoned: !completed)

    let transition = TimerCycle.next(
      after: state.kind, completedInSprint: state.completedInSprint, completed: completed, settings: finished)
    lastCompletedSprintSize = transition.endsSprint ? finished.pomodorosPerSprint : nil

    // Auto-start carries you through a sprint, not into the next one: when a
    // long break ends the timer stops and waits, even with the setting on.
    guard mayAutoStart, finished.autoStartNextBlock, !transition.endsSprint else {
      goIdle(kind: transition.kind, completedInSprint: transition.completedInSprint)
      persist()
      publishReflection(
        allowed: mayPromptForReflection, sessionID: endedSessionID, prompts: prompts, generation: generation)
      return
    }
    // A boundary is where new settings are allowed in, so the next block reads
    // them fresh rather than inheriting the ended block's copy.
    await begin(kind: transition.kind, completedInSprint: transition.completedInSprint, settings: readSettings())
    // THE LAST STATEMENT ON BOTH WAYS OUT OF THIS METHOD, AND THAT IS D4.
    // By the time the sheet can possibly be presented, the break has already
    // been written down and its end instant is already fixed — measured from
    // the boundary, not from whenever somebody finishes typing. Reflection can
    // therefore never eat into a break, and a sheet left open while its owner
    // walks away does not silently stretch their day. Moving either of these
    // two calls above the transition would quietly undo that.
    publishReflection(
      allowed: mayPromptForReflection, sessionID: endedSessionID, prompts: prompts, generation: generation)
  }

  /// Puts the timer at rest with `kind` queued up as the next block.
  private func goIdle(kind idleKind: BlockKind, completedInSprint count: Int) {
    boundaryTask?.cancel()
    boundaryTask = nil
    continuousDeadline = nil
    // Every way of coming to rest passes through here — a block ending with
    // auto-start off, a stop, and reconciliation finding the timer was already
    // idle — so the running count is emptied here once rather than at each of
    // them. It is a count for the block in progress, and there is no block in
    // progress. Nothing is deleted: the rows stay exactly where they were
    // written.
    currentBlockDistractions = []
    guard let state else { return }
    state.kind = idleKind
    state.completedInSprint = count
    state.isRunning = false
    readSettings()
    adopt(state)
  }

  /// Copies the saved row into the values the screens read.
  private func adopt(_ state: TimerState) {
    kind = state.kind
    completedInSprint = state.completedInSprint
    isRunning = state.isRunning
    endsAt = state.isRunning ? state.endsAt : nil
    pomodorosPerSprint = state.isRunning ? state.pomodorosPerSprint : idleSettings.pomodorosPerSprint
  }

  // MARK: The database

  /// Re-reads the settings row. Called only at a boundary and while idle, never
  /// while a block runs — the rule this whole design rests on.
  @discardableResult
  private func readSettings() -> TimerSettingsSnapshot {
    do {
      idleSettings = try TimerSettingsSnapshot(clamping: AppSettings.current(in: context))
    } catch {
      lastFailure = .persistenceFailed
    }
    return idleSettings
  }

  /// Writes the finished-block row. Saving is left to the caller so the row and
  /// the new timer state are written in one go.
  private func recordSession(
    state: TimerState,
    endedAt: Date,
    wasAbandoned: Bool,
    abandonReason: String? = nil) {
    let session = PomodoroSession(
      id: state.sessionID, kind: state.kind, startedAt: state.startedAt,
      endedAt: endedAt, wasAbandoned: wasAbandoned, abandonReason: abandonReason,
      taskID: state.taskID, taskTitle: state.taskTitle,
      projectID: state.projectID, projectTitle: state.projectTitle)
    context.insert(session)
  }

  /// Saves, and remembers it if the save was refused.
  private func persist() {
    do {
      try context.save()
    } catch {
      lastFailure = .persistenceFailed
    }
  }

  // MARK: The alarm

  // MARK: The clock

  /// Arranges for `boundaryReached()` to run when the block is due to end. A
  /// convenience, never a guarantee: iOS may suspend the app and this task with
  /// it. The alarm alerts the user; `synchronize()` keeps the state right.
  private func armBoundary() {
    boundaryTask?.cancel()
    boundaryTask = nil
    guard isRunning, let state, state.isRunning else { return }

    // THIS LOCAL VALUE IS NOT `continuousDeadline` AND MUST NOT BE STORED IN IT.
    // After a relaunch there is no monotonic deadline — a monotonic instant is
    // meaningless across a process launch — so one is worked out from `endsAt`
    // purely to decide when to wake up. Assigning it to `continuousDeadline`
    // would make the skew check compare a value derived from `endsAt` against
    // `endsAt`, which always agrees: the guard would be silently deleted while
    // still appearing in the file.
    let deadline = continuousDeadline
      ?? clock.continuousNow.advanced(by: .seconds(max(0, state.endsAt.timeIntervalSince(clock.now))))

    boundaryGeneration &+= 1
    let generation = boundaryGeneration

    boundaryTask = Task { [weak self] in
      guard let self else { return }
      do {
        try await clock.sleep(until: deadline)
      } catch {
        // The only ways out are cancellation — a new block replaced this one —
        // and a clock that declines to wait. Neither is anything to act on.
        return
      }
      // LETTING GO OF THE HANDLE BEFORE DOING THE WORK IS NOT TIDINESS.
      // This task is about to call `boundaryReached()`, which — when auto-start
      // is on — ends the block and begins the next one, and beginning a block
      // calls `armBoundary()`, whose first act is to cancel whatever
      // `boundaryTask` points at. At this instant that is *this* task. Without
      // these two lines every auto-started block would set its alarm from
      // inside a task that had just cancelled itself, and a cancellation-aware
      // system call refuses to run in one: the block would run to its end and
      // make no sound. That is the single failure this whole feature exists to
      // prevent, on the path a person meets most often.
      //
      // The generation check is the other half. If a newer boundary has already
      // been armed then this task is stale, `boundaryTask` belongs to the newer
      // one, and this task must neither clear it nor act.
      guard boundaryGeneration == generation else { return }
      boundaryTask = nil
      await boundaryReached()
    }
  }
}

// MARK: - The clock moving underneath a block

/// Everything the engine does about a phone whose clock jumped: a timezone
/// change, a network correction, or somebody setting it by hand.
///
/// It lives in an extension rather than in the class body for the same reason
/// the recording code below does — it is one self-contained concern with a long
/// argument attached, and grouping it keeps the class itself readable. Being an
/// extension in the same file changes nothing about what it can reach.
@MainActor
extension TimerEngine {
  /// Notices that the phone's clock moved underneath a running block, and puts
  /// the block back where it belongs.
  ///
  /// WHY THIS IS MORE COMPLICATED THAN IT LOOKS LIKE IT NEEDS TO BE. `endsAt`
  /// is an absolute time, so a timezone change, a network clock correction, or
  /// someone setting the clock by hand can make a block appear to have finished
  /// an hour ago. The engine therefore also keeps the deadline on the monotonic
  /// clock, which nothing can move; when the two disagree by more than
  /// `clockSkewTolerance`, the monotonic one wins and `endsAt` is rewritten.
  /// That deadline exists only while this process has been running since the
  /// block started — after a relaunch it is absent and the wall clock is the
  /// only truth available, a real limitation accepted knowingly, because a
  /// monotonic instant cannot be saved.
  private func correctForClockSkew(_ state: TimerState) async {
    guard let deadline = continuousDeadline else { return }
    let wallRemaining = state.endsAt.timeIntervalSince(clock.now)
    let monotonicRemaining = Self.seconds(clock.continuousNow.duration(to: deadline))
    guard abs(wallRemaining - monotonicRemaining) > Self.clockSkewTolerance else { return }

    let corrected = clock.now.addingTimeInterval(max(0, monotonicRemaining))
    // THE START INSTANT MOVES BY THE SAME AMOUNT AS THE END INSTANT.
    // Both are absolute times in a frame the phone has just redrawn, so
    // correcting one and not the other leaves the block claiming to have
    // started after it will finish. Two things break if it does: a finished
    // block would be written down with `startedAt` later than `endedAt`, and —
    // the reason this was found — `rehydrateDistractions` bounds its query at
    // `startedAt`, so after a *backward* correction every tap made afterwards
    // would carry a timestamp below the bound and silently vanish from the
    // count under the button and from the end-of-block sheet. The rows would
    // still be on disk; the receipt would be lying, which is worse than absent.
    state.startedAt = state.startedAt.addingTimeInterval(corrected.timeIntervalSince(state.endsAt))
    state.endsAt = corrected
    persist()
    adopt(state)
    armBoundary()
    // The alarm was asked for as a length of time rather than an instant, so it
    // may or may not have moved with the system clock. Re-issuing is the only
    // way to be certain; scheduling calls off what is outstanding first.
    await scheduleAlarm(for: state)
  }

  /// A `Duration` as a plain number of seconds.
  private static func seconds(_ duration: Duration) -> TimeInterval {
    let parts = duration.components
    return TimeInterval(parts.seconds) + TimeInterval(parts.attoseconds) / 1e18
  }
}

// MARK: - Recording a distraction

/// The distraction log: writing a tap down, attaching a sentence to one, and
/// handing the finished block to the screen that asks about it.
///
/// WHY THIS IS AN EXTENSION IN THE SAME FILE RATHER THAN A SEPARATE ONE
/// It has to be *in* this file: the two values it maintains —
/// `currentBlockDistractions` and `pendingReflection` — are stored properties,
/// and Swift only allows those in the main body of a type. It is an
/// *extension* so that the timer proper and the log it keeps read as two
/// separate subjects, which is what they are. Moving any of this to another
/// file would force the engine's private state to become visible to the rest
/// of the app, which is real protection traded away for tidiness.
///
/// `@MainActor` is inherited from the class and repeated here for the reader:
/// every method below touches the database, and the database handle is not
/// safe to use from more than one thread.
@MainActor
extension TimerEngine {
  /// Writes down that something pulled the person's attention away, right now.
  ///
  /// **THE TAP IS THE RECORD.** By the time this returns, either a row is
  /// committed to the database file or nothing has happened at all. There is no
  /// in-memory stage, no queue, no batch, and no "save it when the sheet
  /// closes". Killing the app in the next millisecond cannot lose the tap,
  /// because the tap is already on disk.
  ///
  /// **IT IS SYNCHRONOUS, AND THAT IS THE GUARANTEE RATHER THAN THE STYLE.**
  /// There is no `await` anywhere in this method. On the main thread that makes
  /// it one indivisible step: it cannot be interrupted halfway through by a
  /// block starting, ending, or being stopped, so a tap can never be written
  /// against a block that changed underneath it. Somebody will one day be
  /// tempted to make it `async` for symmetry with `start()` and `stop()`. That
  /// would leave the code looking identical and delete this guarantee.
  ///
  /// **THE RULE THAT FOLLOWS, AND IT IS NOW PART OF THIS ENGINE'S CONTRACT:**
  /// *any new `await` added anywhere in `TimerEngine` must be checked against
  /// the guard below.* The guard is only meaningful because every existing
  /// suspension point leaves the timer row describing exactly one block — the
  /// one a tap at that instant genuinely belongs to.
  ///
  /// WHAT THE RETURN VALUE IS FOR
  /// `true` means a row exists. The screen fires its haptic on `true` and on
  /// nothing else, so **the buzz in the person's hand is proof that a row is
  /// committed, not a promise that one is about to be.** On `false` nothing at
  /// all happens: no buzz, no count, no badge — and the screen draws its own
  /// amber line about the tap. This method deliberately does not set
  /// `lastFailure`: that value's wording is about the *block*, and a refused tap
  /// has not endangered the block.
  ///
  /// `@discardableResult` exists so tests may ignore the answer. Screens may
  /// not.
  ///
  /// - Parameter kind: internal or external — the spec's I and E.
  /// - Returns: `true` if and only if a row is committed to the database.
  @discardableResult
  func recordDistraction(_ kind: DistractionKind) -> Bool {
    // A TAP BELONGS TO THE BLOCK THAT OWNS THE INSTANT IT HAPPENED, OR TO NO
    // BLOCK AT ALL. It is never held for the next block and never reassigned to
    // the last one: a distraction filed against the wrong pomodoro is worse
    // than one that was never filed, because it is wrong rather than missing.
    //
    // Work blocks only. A distraction during a break is not a distraction —
    // that is the whole point of a break. The screen also hides the buttons
    // during a break, so a person cannot reach this; the check is here as well
    // because the screen is what somebody sees and this is what makes it true
    // for every future caller.
    guard isRunning, let state, state.isRunning, state.kind == .work else { return false }
    let now = clock.now
    // THIS SECOND GUARD IS NOT REDUNDANT WITH THE FIRST, AND DELETING IT IS A
    // DEFECT RATHER THAN A SIMPLIFICATION. A block is still marked as running
    // in the instant between its end time passing and the app noticing — the
    // waking task may not have fired yet, or the phone may have been asleep
    // across the boundary. Without this line, a tap in that gap would be
    // written against a work block that the wall clock says is already over,
    // and would then be swept into that block's reflection: a distraction that
    // happened during a break, presented as if it happened during work.
    guard now < state.endsAt else { return false }

    // The row is complete here. Nothing about it is filled in later except an
    // optional sentence, and nothing about it depends on a second write.
    let row = Distraction(kind: kind, timestamp: now, sessionID: state.sessionID)

    context.insert(row)
    do {
      try context.save()
    } catch {
      // The row never became real, so it must not be left waiting in the
      // context: a later successful save — the next block boundary, say — would
      // commit it silently, minutes after the person got no buzz and saw no
      // count, and it would be in no sheet and no reflection. Better that a
      // refused tap stays refused and the screen says so.
      context.delete(row)
      // AND `lastFailure` IS DELIBERATELY NOT SET HERE.
      // `.persistenceFailed` says "this block couldn't be saved and may be lost
      // if you close the app", which is a sentence about the *pomodoro*. A
      // refused tap has not endangered the block. Worse, nothing clears
      // `lastFailure` until the next boundary, so a tap that was refused and
      // then retried successfully would have replaced the correct amber line
      // ("That tap wasn't saved. Tap again.") with a block-loss warning — and
      // the screen announces every change of that line, so a VoiceOver reader
      // would hear the warning at the exact instant of the tap that worked.
      // The screen owns this wording; `false` is the whole message from here.
      return false
    }

    // ONLY NOW DOES ANYTHING ON SCREEN LEARN THAT THIS HAPPENED. If this line
    // came before the save, the count beside the button would be counting a row
    // that does not exist.
    currentBlockDistractions.append(DistractionPrompt(row))
    return true
  }

  /// Attaches the sentences somebody wrote to the taps they were written about.
  ///
  /// **This method cannot lose a distraction, and it cannot create one.** Every
  /// row it touches was already committed at tap time; all it ever does is set
  /// one optional piece of text on a row that exists. An identifier it does not
  /// recognise is skipped rather than treated as an error — a sheet outliving
  /// its rows is a possibility, and it is not worth an alarm.
  ///
  /// Synchronous for the same reason `recordDistraction(_:)` is: it must not be
  /// able to interleave with a block transition.
  ///
  /// It answers whether the write succeeded rather than recording a failure of
  /// its own. The engine's `lastFailure` wordings are all about the *timer*; a
  /// sentence that did not save is the screen's news to break, not the engine's.
  ///
  /// WHAT AN EMPTY FIELD DOES
  /// Whatever `DistractionNote.normalised(_:)` says, which for a blank or
  /// whitespace-only field is *nothing*. The row's note is then left as
  /// nothing, and never stored as empty text. Skipping a sentence is a normal
  /// outcome in this app and the store has to be able to tell it apart from
  /// somebody who answered with silence.
  ///
  /// - Parameters:
  ///   - notes: what was typed, by row identity. Fields left untouched may be
  ///     included or omitted; both mean the same thing.
  ///   - earliest: the instant of the oldest tap being annotated. It bounds the
  ///     query and nothing else — see below.
  /// - Returns: `true` if the sentences were written. `false` means the store
  ///   refused them, and the caller words that for the person.
  @discardableResult
  func attachNotes(_ notes: [UUID: String], notEarlierThan earliest: Date) -> Bool {
    guard !notes.isEmpty else { return true }
    do {
      // BOUNDED BY DATE, MATCHED BY IDENTITY. Two different jobs, done by the
      // two mechanisms each is actually good at.
      //
      // The database is asked only for rows at or after the oldest tap being
      // annotated, which is a comparison SwiftData's predicates handle
      // reliably. The identifiers are then matched in ordinary Swift, where the
      // behaviour is not in doubt — an identifier predicate is the case most
      // likely to compile and then quietly match nothing, which here would look
      // exactly like a person's sentence being thrown away.
      //
      // The bound is not an optimisation detail. Without it this reads the
      // whole distraction table, on the main thread, every time either sheet
      // closes — and that table is the app's entire log, which only ever grows.
      // `rehydrateDistractions` below bounds its own fetch the same way for the
      // same reason.
      let descriptor = FetchDescriptor<Distraction>(
        predicate: #Predicate<Distraction> { $0.timestamp >= earliest })
      let rows = try context.fetch(descriptor)
      for row in rows {
        guard let typed = notes[row.id] else { continue }
        row.note = DistractionNote.normalised(typed)
      }
      try context.save()
      return true
    } catch {
      // NOT `.persistenceFailed`. That message is about the block being lost,
      // and what failed here is a handful of sentences on rows that are already
      // safely on disk. Telling somebody their pomodoro may be gone because a
      // note did not save is a warning that is false, and a warning that is
      // sometimes false is one they learn to ignore.
      return false
    }
  }

  /// Hands over the reflection waiting to be presented, and clears it.
  ///
  /// WHY IT IS CALLED *CONSUME* AND WHY IT CLEARS IN THE SAME BREATH
  /// A value that can be read twice can be presented twice. A second sheet
  /// appearing the moment the first is dismissed, asking the same questions
  /// about the same block, is precisely the "queue of nagging prompts" this
  /// feature refuses to build. Taking and clearing in one call makes a second
  /// presentation impossible rather than unlikely.
  ///
  /// - Returns: the block waiting to be reflected on, or `nil` if none is.
  func consumePendingReflection() -> BlockReflection? {
    defer { pendingReflection = nil }
    return pendingReflection
  }

  /// Rebuilds the running block's tap list from the database.
  ///
  /// This is what makes `currentBlockDistractions` a *view* of the store rather
  /// than the store itself: after a relaunch, or a day spent in somebody's
  /// pocket, the array is empty and the rows are not, and this puts them back.
  ///
  /// WHY THE DATABASE IS ASKED FOR A DATE RANGE AND THE REST IS DONE IN SWIFT
  /// Every tap in the running block happened after that block began, so the
  /// start instant bounds the query to a handful of rows without asking
  /// SwiftData to compare identifiers — the one kind of comparison its
  /// predicates are least reliable at. The block is then picked out by identity
  /// in ordinary Swift, where the behaviour is not in doubt. Being wrong here
  /// would cost a count on a button; being wrong in a way that is hard to see
  /// would cost trust in the count, which is worse.
  ///
  /// A failure to read leaves the list empty and records the failure. **It
  /// never stops a timer.** The list is what the screen draws; the rows are the
  /// record, and they are already safe.
  private func rehydrateDistractions() {
    guard let state, state.isRunning else {
      currentBlockDistractions = []
      return
    }
    let blockStartedAt = state.startedAt
    let blockSessionID = state.sessionID
    let descriptor = FetchDescriptor<Distraction>(
      predicate: #Predicate<Distraction> { $0.timestamp >= blockStartedAt },
      sortBy: [SortDescriptor(\.timestamp)])
    do {
      currentBlockDistractions = try context.fetch(descriptor)
        .filter { $0.sessionID == blockSessionID }
        .map { DistractionPrompt($0) }
    } catch {
      currentBlockDistractions = []
      lastFailure = .persistenceFailed
    }
  }

  /// Offers the ended block's taps to the screen, if there is anybody there to
  /// be asked and anything to ask about.
  ///
  /// All three conditions are here rather than at the two call sites so that
  /// they cannot drift apart. The tap count is not written as a condition at
  /// all: `BlockReflection` refuses to exist without at least one tap, so "no
  /// taps, no sheet" is enforced by the type.
  ///
  /// The third condition is the generation check. Between `end()` freezing its
  /// facts and reaching this line, the auto-start path really suspends, and a
  /// stop confirmed in that window has already cleared `pendingReflection` and
  /// gone idle. Publishing anyway would put a reflection sheet over an idle
  /// screen immediately after somebody confirmed a stop. See
  /// `abandonGeneration`.
  private func publishReflection(
    allowed: Bool,
    sessionID: UUID,
    prompts: [DistractionPrompt],
    generation: Int) {
    guard allowed, generation == abandonGeneration else { return }
    pendingReflection = BlockReflection(sessionID: sessionID, prompts: prompts)
  }
}

// MARK: - The alarm

/// Setting and calling off the one alarm this app holds.
///
/// In an extension because the class reached the linter's body limit, and this is
/// the seam that costs least: both methods are about the alarm and neither is
/// about the cycle. The limit is worth keeping — an engine is exactly the kind of
/// type that accretes, and the honest answer to "four lines too long" is to find
/// a seam rather than raise the number.
@MainActor
extension TimerEngine {
  /// Asks for an alarm at the block's end instant. Everything the Lock Screen
  /// will draw travels with it, because the Lock Screen is drawn by a separate
  /// program that cannot open this database.
  private func scheduleAlarm(for state: TimerState) async {
    let request = BlockAlarmRequest(
      id: state.sessionID, kind: state.kind, endsAt: state.endsAt,
      soundEnabled: state.soundEnabled, alertSound: AlertSound.stored(state.alertSoundRawValue),
      completedInSprint: state.completedInSprint,
      pomodorosPerSprint: state.pomodorosPerSprint)
    do {
      // The block that just ended, whose alarm is ringing or about to. Consumed
      // here so it cannot leak into a later, unrelated schedule.
      let spare = alarmToSpare
      alarmToSpare = nil
      try await alarms.schedule(request, sparing: spare)
    } catch {
      // The block is running and saved. All that failed is the noise at the end
      // of it, and the screen says so.
      lastFailure = .alarmSchedulingFailed
    }
  }

  /// Calls off whatever alarm this app has outstanding.
  private func cancelAlarm() {
    do {
      // `false`: every caller of this is somebody asking for silence — a stop, a
      // dismiss, or a block being abandoned — and a ringing alarm is the loudest
      // thing there is to be asked about.
      try alarms.cancelOutstanding(sparingAlerting: false)
    } catch {
      lastFailure = .alarmCancellationFailed
    }
  }
}

// MARK: - Silencing a ringing alarm

/// `D26` — the two methods behind the Silence button.
///
/// **An extension, in this same file, because `TimerEngine`'s body reached its
/// 250-line lint ceiling** — and that ceiling is doing its job: this is the
/// largest type in the app and every feature has a reason to add to it. An
/// extension is a separate declaration for the length rule, and being in the
/// same file keeps `private` access, so nothing had to be widened to the module
/// to make room. The stored `ringingAlarmID` stays in the class above, because
/// Swift has no stored properties in extensions.
extension TimerEngine {
  /// Keeps `ringingAlarmID` current for as long as the caller keeps this
  /// running. Attach it to the timer screen's lifetime.
  func watchForAlarms() async {
    // **THE FLAG IS CLEARED WHEN THE STREAM ENDS, NOT LEFT AT ITS LAST VALUE.**
    //
    // Start and Stop are disabled while it is set, so a stream that finishes
    // while the last value was non-`nil` — the screen going away mid-alarm, a
    // sequence that terminates — would leave the flag stuck on and the controls
    // stuck off. `defer` covers every exit including cancellation, which is the
    // ordinary one: this is attached to a screen's lifetime.
    defer { ringingAlarmID = nil }
    for await id in alarms.alertingUpdates() {
      ringingAlarmID = id
    }
  }

  /// **`D26`: silence the alarm and move the sprint on, exactly as the system
  /// alert's own Dismiss does.**
  ///
  /// THE ORDER IS STOP-THEN-DISMISS, AND IT IS NOT INTERCHANGEABLE.
  /// `handleDismiss()` was written for `DismissBlockIntent`, which runs *after*
  /// iOS has already ended the alert — its own comment says so. Reaching it from
  /// inside the app means nothing has silenced anything yet, so the noise is
  /// stopped first. Calling `handleDismiss()` alone here would advance the sprint
  /// and leave the alarm ringing, which is the reported defect with an extra step.
  ///
  /// **AND IT IS `handleDismiss()`, NEVER `stop(reason:)`.** Stop ends the
  /// *sprint* and `SPEC.md` prices that exit deliberately — it asks why and will
  /// not proceed without an answer. Silencing an alarm is a different act with a
  /// different consequence: the block is recorded **completed**, the reflection
  /// prompt appears if it earned one, and the next block auto-starts or waits
  /// according to the setting. One method carrying both meanings is how the `F2b`
  /// arc produced four fixes in a row.
  ///
  /// A failure to stop is recorded rather than thrown. The sprint must still
  /// advance: a person who asked for silence and got an error would otherwise be
  /// left with a ringing alarm *and* a stuck timer.
  func silenceAlarm() async {
    guard let id = ringingAlarmID else { return }
    var silenceFailed = false
    do {
      try alarms.stopAlerting(id: id)
    } catch {
      silenceFailed = true
    }
    // **RE-READ, NEVER CLEARED BLIND — AND THE BLIND CLEAR WAS ITSELF A FIX THAT
    // RECREATED `O26`.**
    //
    // The first version cleared only on success, which left a dead screen when
    // iOS refused. The second cleared on both branches, with a comment claiming
    // `alertingUpdates()` would re-raise the flag if the alarm really was still
    // going. **It would not.** That stream de-duplicates against its last value,
    // and a refused stop changes no AlarmKit state — so the ringing id equals the
    // last id, nothing is ever yielded again, and the button is gone for the rest
    // of the session. `AlarmKitScheduler`'s own notes record an undismissed alarm
    // sitting `.alerting` for over thirty seconds, and the next block is scheduled
    // *sparing* that id, so it survives. That is the reported defect back, reached
    // through the branch added to fix it.
    //
    // So the truth is asked for instead of assumed. The dead screen is solved
    // where it belongs — `TimerScreen` no longer disables anything, because the
    // Silence button's space is reserved and nothing moves under a finger.
    ringingAlarmID = silenceFailed ? alarms.alertingAlarmID : nil
    await handleDismiss()
    // **REPORTED AFTER, NOT BEFORE, AND A TEST FOUND THAT.**
    //
    // `handleDismiss()` clears `lastFailure` as its first act, correctly: a new
    // block starts without the last one's complaint on screen. Setting the
    // failure before calling it therefore wrote a message that was wiped a line
    // later — the person would have been left with a ringing alarm and a screen
    // saying nothing was wrong.
    if silenceFailed { lastFailure = .alarmSilenceFailed }
  }
}
