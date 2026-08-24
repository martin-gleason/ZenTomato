import Foundation

/// One distraction tapped on the wrist, travelling to the phone.
///
/// **THIS IS THE ONLY THING THE WATCH EVER SENDS**, and losing one is the failure
/// F7 exists to prevent — `SPEC.md` calls the distraction log the app's unique
/// value, and a tap that never arrives is a hole in it that nothing can detect
/// afterwards.
///
/// **`tappedAt` is taken on the watch at the moment of the press.** Never the
/// moment of delivery. A tap made with the phone in another room may sit in a
/// queue for eleven minutes; it must still say 14:32, because the whole point of
/// the wrist is to capture the instant attention wandered. A delivery timestamp
/// would silently rewrite the one number this feature exists to get right.
///
/// **`id` is what makes redelivery harmless.** WatchConnectivity guarantees
/// eventual delivery, not exactly-once: the system may hand the same payload over
/// more than once, and without an identifier the phone cannot tell a resend from
/// a second tap. Two rows where there was one tap inflates the counts the
/// fortnightly review reads — quietly, plausibly, and in the direction that
/// flatters. The phone ignores an id it has already stored.
struct WatchTap: Codable, Equatable, Sendable, Identifiable {
  /// Minted on the watch, once, when the button is pressed.
  var id: UUID

  /// Internal or external.
  var kind: DistractionKind

  /// When the button was pressed, by the watch's clock.
  var tappedAt: Date

  /// The block the watch was showing when it was pressed.
  ///
  /// The phone attributes the tap to this session. It does **not** second-guess
  /// it from the timestamp: the tap happened during that pomodoro, and arriving
  /// late does not change which block somebody was working in.
  var sessionID: UUID
}
