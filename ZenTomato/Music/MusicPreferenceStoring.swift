import Foundation

/// The two facts this feature remembers between launches, and the only way it
/// is allowed to remember them.
///
/// **WHY THESE TWO FACTS ARE NOT IN `AppSettings`, AND WHY THAT IS A RULE.**
/// `SPEC.md`'s list of what this timer may be customised with is six items long
/// and ends with the words *"Nothing else."* Putting the music switch beside
/// those six would be a seventh setting whatever it was called, and the six-item
/// rule is defended by the settings screen looking like six things. So this
/// feature keeps its own small row: one switch and one chosen item, owned here,
/// with `ZenTomato/Models/AppSettings.swift` untouched — zero changed lines,
/// and a test that still counts six columns there.
///
/// **WHY IT IS A PROTOCOL RATHER THAN THE DATABASE CLASS ITSELF.** The
/// coordinator's job is deciding when there should be sound. Handing it a
/// database handle would mean every test of that decision needed a database,
/// and the tests that matter most here are the failure ones — a refused
/// permission, a lapsed subscription, a phone call in the middle of a break.
/// Behind this protocol those run against a stand-in holding two values in
/// memory, which is the whole of what they need.
///
/// **NOTHING HERE THROWS, AND THAT IS A CONTRACT ON THE IMPLEMENTATION RATHER
/// THAN AN OVERSIGHT.** Writing to a database can be refused, and the
/// implementation must absorb that refusal and record it for itself. It may not
/// hand it back. The reason is D19.2: a preference that could not be written
/// must not be able to affect a running timer, and there is nothing the caller
/// would do about it if it could — the switch is already where the person put
/// it, the session behaves correctly, and the only cost is that the next launch
/// starts from whatever was last written successfully. That is a working silent
/// timer, which is what every failure in this feature is required to become.
///
/// `@MainActor` because an implementation holds the app's database handle, and
/// those are not safe to share between threads. `AnyObject` because it holds
/// state that must not be copied.
@MainActor
protocol MusicPreferenceStoring: AnyObject {
  /// Whether music should play during focus blocks.
  ///
  /// This is the person's standing intention, not a statement about whether
  /// anything can actually play. A phone with no subscription can still have
  /// this switched on; the coordinator refuses to make sound because
  /// availability says so, and when the subscription comes back the music
  /// returns without anybody having to switch it on again.
  var isEnabled: Bool { get }

  /// The one chosen playlist or song, or `nil` when nothing has been chosen.
  ///
  /// **Exactly one, ever.** There is no list and no history. Choosing something
  /// replaces whatever was chosen before, which is why the picker needs no way
  /// to un-choose: the switch is the off control, and a second route to
  /// "nothing will play" would be a second off switch that looks like a
  /// mistake.
  var selection: MusicSelection? { get }

  /// Remembers that music is on or off.
  ///
  /// **This records a preference and does nothing else.** It does not start or
  /// stop anything and it does not ask whether the timer is idle. The
  /// coordinator owns both of those, and enforcing the same rule in two places
  /// is how two places come to disagree.
  func setEnabled(_ isEnabled: Bool)

  /// Remembers the chosen playlist or song, or that nothing is chosen.
  ///
  /// The title travels with the identifier and is stored as it reads now,
  /// because a playlist can be renamed or deleted in the Music app and the app
  /// still has to be able to name the thing that has gone.
  func setSelection(_ selection: MusicSelection?)
}
