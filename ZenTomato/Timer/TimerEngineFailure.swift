import Foundation

/// The ways a timer command can fail to do what it said.
///
/// WHY FAILURES ARE A VALUE ON THE ENGINE RATHER THAN AN ERROR THROWN AT A BUTTON
/// The three things below can all fail after the user has already been told
/// the timer started — the block is on disk and the screen is counting down
/// before the alarm is scheduled. There is nothing useful to throw back at the
/// tap. What matters is that the *state* is visible: an alarm that silently
/// failed to schedule is the worst bug this feature can ship, because the app
/// looks entirely normal right up until the block ends in silence and the
/// user, who is in a Focus session by definition, does not find out for an
/// hour. So the engine keeps the last failure and the timer screen shows it.
enum TimerEngineFailure: Equatable, Sendable {
  /// The block is running but no alarm could be set for its end. The countdown
  /// on screen is correct; nothing will sound when it reaches zero.
  case alarmSchedulingFailed

  /// An alarm that should have been called off could not be. The risk is an
  /// alarm sounding for a block the user has already skipped or stopped.
  case alarmCancellationFailed

  /// The app was asked to silence a ringing alarm and iOS refused.
  ///
  /// **The sprint still advances** — see `TimerEngine.silenceAlarm()`. Somebody
  /// who asked for quiet and got an error must not also be left with a stuck
  /// timer, so this reports the noise and nothing else.
  case alarmSilenceFailed

  /// The database refused a write. The timer is running in memory but the
  /// state on disk is behind, so closing the app could lose the block.
  case persistenceFailed

  /// One plain sentence for the timer screen. Written for the person holding
  /// the phone, not for whoever has to debug it.
  var message: String {
    switch self {
    case .alarmSchedulingFailed:
      "This block won't sound an alarm when it ends."
    case .alarmCancellationFailed:
      "An old alarm couldn't be called off and may still sound."
    case .alarmSilenceFailed:
      "The alarm couldn't be switched off. Use the alert on the Lock Screen."
    case .persistenceFailed:
      "This block couldn't be saved and may be lost if you close the app."
    }
  }
}
