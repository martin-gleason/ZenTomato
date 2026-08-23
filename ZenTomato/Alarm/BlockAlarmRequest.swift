import Foundation

/// One block's worth of "wake the user at this moment, and say this much".
///
/// Everything the alerting layer needs, and nothing about which alerting layer
/// it is. The engine builds one of these; the scheduler turns it into whatever
/// the system actually wants.
struct BlockAlarmRequest: Equatable, Sendable {
  /// The block's identity. It is the same value stored on the running
  /// `TimerState` and written to the `PomodoroSession` row when the block ends,
  /// so an alarm can always be traced back to the block it belongs to.
  let id: UUID

  /// Which kind of block is ending. Decides the words on the alert.
  let kind: BlockKind

  /// The wall-clock moment the block ends. The scheduler converts it into
  /// whatever shape the system wants at the moment it schedules — this app's
  /// source of truth is always the end instant, never a countdown.
  let endsAt: Date

  /// Whether the alert should make a noise.
  let soundEnabled: Bool

  /// How many focus blocks are already complete in this sprint.
  ///
  /// WHY A SPRINT COUNT IS TRAVELLING WITH AN ALARM
  /// This looks like it does not belong, and the reason it does is worth
  /// stating: the Lock Screen countdown is drawn by a *separate program* from
  /// the app, and that program cannot open the app's database. Anything it
  /// shows has to be handed to it at the moment the alarm is scheduled. It
  /// shows "2 OF 4", so these two numbers travel with the alarm.
  let completedInSprint: Int

  /// How many focus blocks make up this sprint. Travels for the same reason as
  /// `completedInSprint`.
  let pomodorosPerSprint: Int
}
