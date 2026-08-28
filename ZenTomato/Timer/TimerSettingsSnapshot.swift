import Foundation

/// The six settings values, frozen at the instant a block began.
///
/// THIS TYPE IS THE WHOLE OF "SETTINGS APPLY AT THE NEXT BLOCK BOUNDARY".
/// The rule is that changing the focus length while a focus block is running
/// must not shorten the block you are already in. The obvious way to honour
/// that is for everybody to remember not to re-read the settings — which is a
/// rule held in people's heads, and therefore a rule that will eventually be
/// broken. Instead, the engine copies the six values once, at the boundary,
/// into this immutable struct, and the running block can only see the copy.
/// The living settings row is simply not reachable from a running block, so
/// the rule cannot be broken by accident.
///
/// `struct` and `let` mean every value here is fixed for the life of the copy.
/// `Sendable` means the copy is safe to hand to another thread, which matters
/// because it travels to the alarm scheduler.
struct TimerSettingsSnapshot: Equatable, Sendable {
  // MARK: The six values

  /// Length of a focus block, in minutes.
  let workMinutes: Int
  /// Length of the short break, in minutes.
  let shortBreakMinutes: Int
  /// Length of the long break that ends a sprint, in minutes.
  let longBreakMinutes: Int
  /// How many focus blocks make up one sprint.
  let pomodorosPerSprint: Int
  /// Whether the alarm makes a noise when the block ends.
  let soundEnabled: Bool

  /// Which sound the alarm makes, frozen with everything else.
  ///
  /// **Snapshotted rather than read when the alarm fires**, for the reason the
  /// whole type exists: a block runs under the settings it started with, so
  /// changing a setting mid-block cannot rewrite what that block was.
  let alertSound: AlertSound
  /// Whether the next block begins by itself when this one ends.
  let autoStartNextBlock: Bool

  // MARK: Initialisation

  /// Creates a snapshot, forcing every number inside `SettingsBounds`.
  ///
  /// Clamping happens here rather than at the call sites so that there is no
  /// way to construct an out-of-range snapshot at all — not from the settings
  /// screen, not from a stored row, not from a test.
  init(
    workMinutes: Int,
    shortBreakMinutes: Int,
    longBreakMinutes: Int,
    pomodorosPerSprint: Int,
    soundEnabled: Bool,
    alertSound: AlertSound,
    autoStartNextBlock: Bool
  ) {
    self.workMinutes = SettingsBounds.minutes.clamping(workMinutes)
    self.shortBreakMinutes = SettingsBounds.minutes.clamping(shortBreakMinutes)
    self.longBreakMinutes = SettingsBounds.minutes.clamping(longBreakMinutes)
    self.pomodorosPerSprint = SettingsBounds.pomodorosPerSprint.clamping(pomodorosPerSprint)
    self.soundEnabled = soundEnabled
    self.alertSound = alertSound
    self.autoStartNextBlock = autoStartNextBlock
  }

  /// Copies the saved settings row, clamping anything out of range.
  ///
  /// WHY IT IS MAIN-ACTOR ONLY
  /// `AppSettings` is a saved database row, and everything this app reads out
  /// of the database is read on the main thread — SwiftData's handle for
  /// reading and writing is not safe to share between threads. Marking the
  /// initialiser rather than trusting the caller means the compiler enforces
  /// it.
  @MainActor
  init(clamping settings: AppSettings) {
    self.init(
      workMinutes: settings.workMinutes,
      shortBreakMinutes: settings.shortBreakMinutes,
      longBreakMinutes: settings.longBreakMinutes,
      pomodorosPerSprint: settings.pomodorosPerSprint,
      soundEnabled: settings.soundEnabled,
      alertSound: settings.alertSound,
      autoStartNextBlock: settings.autoStartNextBlock)
  }

  /// The values to fall back on when the settings row cannot be read at all.
  ///
  /// This is not a second set of defaults. It is built from a brand-new,
  /// unsaved `AppSettings`, whose initialiser holds the only copy of the
  /// spec's defaults in the codebase — so the two cannot drift apart. It is
  /// reached only in a state where the database has failed, which is a state
  /// the app already shows a dedicated failure screen for.
  @MainActor
  static var fallback: TimerSettingsSnapshot {
    TimerSettingsSnapshot(clamping: AppSettings())
  }

  // MARK: Reading a length out of the snapshot

  /// How many minutes a block of this kind lasts, under these settings.
  func minutes(for kind: BlockKind) -> Int {
    switch kind {
    case .work: workMinutes
    case .shortBreak: shortBreakMinutes
    case .longBreak: longBreakMinutes
    }
  }

  /// How long a block of this kind lasts, as a measured span of time.
  ///
  /// `Duration` is Swift's type for "an amount of time" as distinct from "a
  /// moment in time". The distinction matters here: the deadline the engine
  /// sleeps against is a moment plus a duration, and mixing the two up is how
  /// a timer ends up firing in 1970.
  func duration(for kind: BlockKind) -> Duration {
    .seconds(minutes(for: kind) * 60)
  }
}
