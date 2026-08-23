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
/// THERE IS NO PAUSE, AND ITS ABSENCE IS DELIBERATE.
/// `start()`, `skip()` and `stop()` are the whole surface. AlarmKit's own
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

  // MARK: Collaborators

  /// The database handle. Main-thread only, which is why this whole class is.
  private let context: ModelContext

  /// Where time comes from. Real in the app, controlled by the test in tests.
  private let clock: any TimerClock

  /// Where alarms come from. Never AlarmKit directly — see `AlarmScheduling`.
  private let alarms: any AlarmScheduling

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

  // MARK: Initialisation

  /// Builds the engine and adopts whatever the database already says, so the
  /// screen is right immediately. `synchronize()` works out whether it is still
  /// true; the app calls that at launch and on every return to the foreground.
  init(context: ModelContext, clock: any TimerClock, alarms: any AlarmScheduling) {
    self.context = context
    self.clock = clock
    self.alarms = alarms

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

  /// Ends the current block early and moves to the next one. A skipped block is
  /// recorded as abandoned, and a skipped *focus* block does not count towards
  /// the sprint: the long break is earned by finished pomodoros, not attempts.
  func skip() async {
    guard isRunning, let state else { return }
    lastFailure = nil
    // Called off first. An alarm sounding four minutes after the block it
    // belonged to was skipped is this feature's most likely user-visible bug.
    cancelAlarm()
    await end(state: state, completed: false, at: clock.now, mayAutoStart: true)
  }

  /// Abandons the sprint: records the running block, calls off the alarm,
  /// returns the sprint count to zero and goes idle with a focus block queued.
  /// That reset is the whole difference between this and `skip()`.
  func stop() async {
    guard isRunning, let state else { return }
    lastFailure = nil
    cancelAlarm()
    recordSession(state: state, endedAt: clock.now, wasAbandoned: true)
    lastCompletedSprintSize = nil
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
      return
    }

    // Ended while the app was suspended or closed. Recorded as completed rather
    // than abandoned: it finished and the alarm fired; the user was not looking.
    cancelAlarm()
    await end(state: state, completed: true, at: state.endsAt, mayAutoStart: false)
    // A sprint that ended while the app was closed is not announced on the next
    // launch. The acknowledgement is for the person who was there.
    lastCompletedSprintSize = nil
  }

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
    lastFailure = nil
    cancelAlarm()
    let completed = clock.now >= state.endsAt
    await end(state: state, completed: completed, at: clock.now, mayAutoStart: false)
  }

  /// The block's deadline arrived and the app was awake to see it. This is the
  /// only path on which auto-start can chain one block into the next, because
  /// it is the only one that knows the app was here when the block ended. The
  /// engine stays correct if it never runs: `synchronize()` is the guarantee.
  func boundaryReached() async {
    guard isRunning, let state, state.isRunning else { return }
    guard clock.now >= state.endsAt else {
      // Woken early: the monotonic clock says the block is over and the wall
      // clock disagrees, so the wall clock moved. Reconciling knows what to do.
      return await synchronize()
    }
    cancelAlarm()
    // Ended at the instant it was due to end, not the instant this ran: the
    // task can wake a moment late and the record must not drift with it.
    await end(state: state, completed: true, at: state.endsAt, mayAutoStart: true)
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
  private func end(state: TimerState, completed: Bool, at instant: Date, mayAutoStart: Bool) async {
    let finished = state.snapshot
    recordSession(state: state, endedAt: instant, wasAbandoned: !completed)

    let transition = TimerCycle.next(
      after: state.kind, completedInSprint: state.completedInSprint, completed: completed, settings: finished)
    lastCompletedSprintSize = transition.endsSprint ? finished.pomodorosPerSprint : nil

    // Auto-start carries you through a sprint, not into the next one: when a
    // long break ends the timer stops and waits, even with the setting on.
    guard mayAutoStart, finished.autoStartNextBlock, !transition.endsSprint else {
      goIdle(kind: transition.kind, completedInSprint: transition.completedInSprint)
      return persist()
    }
    // A boundary is where new settings are allowed in, so the next block reads
    // them fresh rather than inheriting the ended block's copy.
    await begin(kind: transition.kind, completedInSprint: transition.completedInSprint, settings: readSettings())
  }

  /// Puts the timer at rest with `kind` queued up as the next block.
  private func goIdle(kind idleKind: BlockKind, completedInSprint count: Int) {
    boundaryTask?.cancel()
    boundaryTask = nil
    continuousDeadline = nil
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
  private func recordSession(state: TimerState, endedAt: Date, wasAbandoned: Bool) {
    let session = PomodoroSession(
      id: state.sessionID, kind: state.kind, startedAt: state.startedAt,
      endedAt: endedAt, wasAbandoned: wasAbandoned)
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

  /// Asks for an alarm at the block's end instant. Everything the Lock Screen
  /// will draw travels with it, because the Lock Screen is drawn by a separate
  /// program that cannot open this database.
  private func scheduleAlarm(for state: TimerState) async {
    let request = BlockAlarmRequest(
      id: state.sessionID, kind: state.kind, endsAt: state.endsAt,
      soundEnabled: state.soundEnabled, completedInSprint: state.completedInSprint,
      pomodorosPerSprint: state.pomodorosPerSprint)
    do {
      try await alarms.schedule(request)
    } catch {
      // The block is running and saved. All that failed is the noise at the end
      // of it, and the screen says so.
      lastFailure = .alarmSchedulingFailed
    }
  }

  /// Calls off whatever alarm this app has outstanding.
  private func cancelAlarm() {
    do {
      try alarms.cancelOutstanding()
    } catch {
      lastFailure = .alarmCancellationFailed
    }
  }

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

    boundaryTask = Task { [weak self] in
      guard let self else { return }
      do {
        try await clock.sleep(until: deadline)
      } catch {
        // The only ways out are cancellation — a new block replaced this one —
        // and a clock that declines to wait. Neither is anything to act on.
        return
      }
      await boundaryReached()
    }
  }

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

    state.endsAt = clock.now.addingTimeInterval(max(0, monotonicRemaining))
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
