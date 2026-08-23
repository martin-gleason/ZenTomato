import Foundation
import SwiftData

/// The running timer, as it exists on disk.
///
/// THIS ROW IS WHY THE TIMER SURVIVES BEING CLOSED.
/// The app does not count seconds. It writes down the wall-clock moment the
/// current block ends, and everything on screen is worked out from that. So
/// when iOS suspends the app — which it will, within seconds of the phone
/// being locked — nothing is lost, because nothing was being counted. On the
/// way back the app reads this row, compares `endsAt` to the actual time, and
/// knows exactly where it stands. A timer built on a ticking counter loses
/// whatever it was not awake for; this one cannot.
///
/// EXACTLY ONE ROW, THE SAME WAY `AppSettings` IS ONE ROW.
/// There is one timer. A second row would mean nothing, and the first piece of
/// code to fetch "the timer" would have to invent a rule for which one wins.
/// `current(in:)` below is the only way to obtain one, and nothing else may
/// insert one.
///
/// WHY THE SETTINGS ARE COPIED IN HERE, FLAT, INSTEAD OF BEING LOOKED UP
/// The six values at the bottom are a copy of the settings as they stood when
/// this block started, and they are what the block runs on. Changing the focus
/// length while a focus block is running therefore cannot shorten the block you
/// are already in — the running block is not looking at the settings row at
/// all. They are stored as six separate columns rather than as one grouped
/// value because a database does not need to understand the grouping, and six
/// plain numbers are six plain numbers to anybody reading the file.
@Model
final class TimerState {
  // MARK: The running block

  /// Which kind of block this is. While the timer is idle this is the block
  /// that Start would begin.
  var kind: BlockKind

  /// When the block began, on the wall clock.
  var startedAt: Date

  /// When the block ends. **This is the only thing that matters.** Everything
  /// the screen shows is derived from it, and it is meaningful only while
  /// `isRunning` is true.
  var endsAt: Date

  /// How many focus blocks are complete in the current sprint. Returns to zero
  /// when a long break ends or when the timer is stopped.
  var completedInSprint: Int

  /// The identity of the block, shared with the alarm set for it and with the
  /// history row written when it ends.
  var sessionID: UUID

  /// Whether a block is actually running. When false the row still describes
  /// the block Start would begin, but `startedAt` and `endsAt` are stale.
  var isRunning: Bool

  // MARK: The settings this block was started with

  /// Length of this block's focus period, in minutes, as it stood at the start.
  var workMinutes: Int
  /// Short break length, in minutes, as it stood at the start.
  var shortBreakMinutes: Int
  /// Long break length, in minutes, as it stood at the start.
  var longBreakMinutes: Int
  /// Sprint size as it stood at the start. The break this block has earned is
  /// decided against this number, not against whatever the settings say later.
  var pomodorosPerSprint: Int
  /// Whether this block's alarm makes a noise.
  var soundEnabled: Bool
  /// Whether the block after this one begins by itself.
  var autoStartNextBlock: Bool

  // MARK: Initialisation

  /// Creates the timer row in its idle state.
  ///
  /// The dates default to the distant past deliberately: they are meaningless
  /// while the timer is idle, and a date in 1 AD is obviously meaningless,
  /// whereas "now" would look like a block that had just ended.
  init(
    kind: BlockKind = .work,
    startedAt: Date = .distantPast,
    endsAt: Date = .distantPast,
    completedInSprint: Int = 0,
    sessionID: UUID = UUID(),
    isRunning: Bool = false,
    snapshot: TimerSettingsSnapshot
  ) {
    self.kind = kind
    self.startedAt = startedAt
    self.endsAt = endsAt
    self.completedInSprint = completedInSprint
    self.sessionID = sessionID
    self.isRunning = isRunning
    workMinutes = snapshot.workMinutes
    shortBreakMinutes = snapshot.shortBreakMinutes
    longBreakMinutes = snapshot.longBreakMinutes
    pomodorosPerSprint = snapshot.pomodorosPerSprint
    soundEnabled = snapshot.soundEnabled
    autoStartNextBlock = snapshot.autoStartNextBlock
  }

  // MARK: The frozen settings, as one value

  /// The six stored settings columns, read back as the immutable copy the
  /// engine works with.
  var snapshot: TimerSettingsSnapshot {
    TimerSettingsSnapshot(
      workMinutes: workMinutes,
      shortBreakMinutes: shortBreakMinutes,
      longBreakMinutes: longBreakMinutes,
      pomodorosPerSprint: pomodorosPerSprint,
      soundEnabled: soundEnabled,
      autoStartNextBlock: autoStartNextBlock)
  }

  /// Writes a fresh copy of the settings into the row. Called at a block
  /// boundary and nowhere else — that restriction is what makes "settings take
  /// effect at the next block" true rather than merely intended.
  func apply(_ snapshot: TimerSettingsSnapshot) {
    workMinutes = snapshot.workMinutes
    shortBreakMinutes = snapshot.shortBreakMinutes
    longBreakMinutes = snapshot.longBreakMinutes
    pomodorosPerSprint = snapshot.pomodorosPerSprint
    soundEnabled = snapshot.soundEnabled
    autoStartNextBlock = snapshot.autoStartNextBlock
  }

  // MARK: The single-row accessor

  /// Returns the app's one and only timer row, creating an idle one the first
  /// time the app is ever launched.
  ///
  /// The new row copies the current settings, so the defaults still live in
  /// exactly one place — `AppSettings`' initialiser — and cannot drift.
  ///
  /// WHY IT IS MAIN-ACTOR ONLY
  /// The same reason `AppSettings.current(in:)` is. It looks for a row and
  /// inserts one if it finds none; two threads running that at once could both
  /// look, both find nothing, and both insert, leaving exactly the two rows
  /// this design exists to prevent. Confining it to one thread makes the race
  /// impossible rather than unlikely. SwiftData's `ModelContext` is not safe to
  /// share between threads in any case, which is why every database access in
  /// this app is main-actor bound.
  ///
  /// - Parameter context: the SwiftData context to read and write through.
  /// - Returns: the timer row, idle and freshly created on first launch.
  /// - Throws: whatever SwiftData throws if the store cannot be read or
  ///   written. Never swallowed: a timer that silently fails to save is a
  ///   timer that loses a block.
  @MainActor
  static func current(in context: ModelContext) throws -> TimerState {
    var descriptor = FetchDescriptor<TimerState>()
    // There is at most one row by construction, so asking for more than one
    // would be asking the database a question whose answer is already known.
    descriptor.fetchLimit = 1

    if let existing = try context.fetch(descriptor).first {
      return existing
    }

    let created = TimerState(snapshot: TimerSettingsSnapshot(clamping: try AppSettings.current(in: context)))
    context.insert(created)
    // Saved immediately rather than left pending, so that a launch interrupted
    // between here and the first block does not produce a second row.
    try context.save()
    return created
  }
}
