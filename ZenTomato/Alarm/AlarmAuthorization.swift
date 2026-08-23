import Foundation

/// Whether the app is allowed to set alarms.
///
/// WHY THIS EXISTS WHEN THE SYSTEM ALREADY HAS THE SAME THREE CASES
/// It is a deliberate copy of AlarmKit's own answer, made so that the timer
/// engine, the screens and every test can talk about permission without any of
/// them importing AlarmKit. Exactly one file in the app — `AlarmKitScheduler` —
/// is allowed to name an AlarmKit type. That is what makes the promise in
/// `AlarmScheduling` true: if the alarm framework has to be replaced, one file
/// changes and nothing else in the app has ever heard of it.
///
/// The three cases are not interchangeable and the app treats them differently:
/// `notDetermined` means nobody has been asked yet, and the ask happens the
/// first time someone taps Start rather than at launch. `denied` means the app
/// has asked and been refused, which is the only case that puts a blocking
/// explainer on screen.
enum AlarmAuthorization: Sendable, Equatable {
  /// Permission has never been requested. The app asks at the first Start.
  case notDetermined

  /// Permission was refused. No block can be reliably alerted, so the app says
  /// so rather than running a timer that ends in silence.
  case denied

  /// Permission was granted. Alarms can be scheduled.
  case authorized
}
