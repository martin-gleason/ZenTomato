import Foundation

/// What the alarm should sound like, decided before any framework type is
/// involved.
///
/// **THIS TYPE EXISTS SO THE PRECEDENCE CAN BE TESTED.** `F2c.md` names one rule
/// as *"the rule most likely to be got backwards"* — sound **off** beats a chosen
/// sound — and the first version of this feature held that rule in a `private
/// static` function returning `ActivityKit.AlertConfiguration.AlertSound`. That is
/// unreachable from a test in principle, and the framework value is not usefully
/// comparable even if it were reachable. The rule was therefore guarded by nothing
/// but a comment saying it mattered.
///
/// So the decision is ours and the framework type is a rendering of it.
/// `AlarmKitScheduler` translates these three cases into the two `AlertSound`
/// offers, and this enum is what the tests hold still.
enum AlarmSoundDecision: Equatable, Sendable {
  /// The person turned sound off. The alarm still fires and the alert still
  /// appears; the phone makes no noise.
  case silent

  /// Whatever iOS plays when asked for nothing in particular.
  case systemDefault

  /// A file this app ships, by name.
  case bundled(String)

  /// **Sound off wins.** Written as an early return rather than a nested
  /// condition so the order is legible at a glance and survives a tidy-up: the
  /// switch is a person saying *no noise*, and a sound they picked last week must
  /// not speak over that.
  ///
  /// A choice this build cannot play is the system default, not a named file that
  /// resolves to nothing — see `AlertSound.isPlayable`, where a missing file is
  /// silence rather than a fallback.
  static func decide(soundEnabled: Bool, choice: AlertSound) -> AlarmSoundDecision {
    guard soundEnabled else { return .silent }
    guard choice.isPlayable, let fileName = choice.fileName else { return .systemDefault }
    return .bundled(fileName)
  }
}
