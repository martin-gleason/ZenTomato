import Foundation

/// Whether this app may play music at all, and the one plain line to show when
/// it may not.
///
/// **EVERY CASE BELOW LEAVES A WORKING TIMER.** That is the ratified decision
/// (D19.2) and it is the single most important property of this feature. None
/// of these values reaches the timer engine, none of them can stop a block
/// starting, and none of them changes how long a block runs or whether it is
/// recorded. The whole consequence of any of them is that the app is quiet and
/// one muted grey line on the timer screen says why.
///
/// **THIS IS DELIBERATELY THE OPPOSITE OF THE ALARM PERMISSION.** When alarms
/// are refused the app puts an explainer over the whole screen and will not
/// start, because a Pomodoro timer that cannot tell you a block ended has no
/// working state to degrade into. Music is an accessory: a timer that is merely
/// quiet works perfectly. Same app, opposite handling, and the reason is
/// written in both places so that neither reads as an oversight.
///
/// **THE COPY LIVES ON THE VALUE, NOT ON THE SCREEN.** Each unavailable case
/// carries its own sentence, so the row and the sheet cannot word the same
/// situation two different ways, and a test can assert the exact sentence
/// rather than assert that some sentence exists. Every line obeys the same
/// four rules: it says what happened, it says what to do or that there is
/// nothing to do, it names no framework and no error code, and it does not read
/// as though the app is broken. None of them is a link, a button or a call to
/// action — a "Subscribe" button would be a new surface, and this feature's
/// whole posture is that music is an accessory nobody is sold.
enum MusicAvailability: Equatable, Sendable, CaseIterable {
  /// Permission has been given, there is a subscription, and music can play.
  case ready

  /// Permission has never been asked for.
  ///
  /// **This is not a failure and it draws no explanation.** It is the state
  /// every install begins in, because permission is asked for at the moment
  /// somebody first switches music on and never at launch. A first-run screen
  /// that opens with a permission prompt for a feature nobody has touched is
  /// the surest way to be refused.
  case notAsked

  /// Permission was asked for and refused.
  case denied

  /// Music is turned off on the device itself — Screen Time, or a phone
  /// somebody else manages. Not the same thing as a refusal, and told apart
  /// from one because the advice differs: there is nowhere useful to send
  /// somebody who is not allowed to grant the permission in the first place.
  case restricted

  /// There is no Apple Music subscription on this phone.
  ///
  /// Playing a library item through this app's own player needs one. The
  /// underlying fact the framework reports is *"can this device play catalogue
  /// content"*, which is the honest flag, and the wording of the line follows
  /// from that rather than from the word "subscription".
  case noSubscription

  /// The subscription could not be established at all — the check itself
  /// failed, or the library could not be read.
  ///
  /// Told apart from `noSubscription` because it is not a statement that there
  /// is no subscription; it is a statement that this app does not know. It
  /// clears itself the next time the check succeeds.
  case couldNotBeChecked

  // MARK: Derived

  /// Whether sound is permitted. Exactly one case says yes.
  ///
  /// Written as a name rather than as `== .ready` at each call site, so that
  /// "may we play" is asked in one vocabulary everywhere.
  var permitsPlayback: Bool {
    self == .ready
  }

  /// The one plain line the dimmed row shows, or `nil` when there is nothing to
  /// explain.
  ///
  /// `nil` for `ready` — nothing is wrong — and `nil` for `notAsked`, because
  /// somebody who has never switched music on is not owed an explanation of a
  /// permission they have not been asked for. The row shows its invitation to
  /// choose something instead.
  var explanation: String? {
    switch self {
    case .ready, .notAsked:
      nil
    case .denied:
      "ZenTomato doesn't have permission to use your music."
    case .restricted:
      "Music is turned off on this iPhone."
    case .noSubscription:
      "Playing your library needs Apple Music."
    case .couldNotBeChecked:
      "ZenTomato couldn't tell whether it can play your music."
    }
  }
}
