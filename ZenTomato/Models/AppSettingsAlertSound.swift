import Foundation

/// The chosen alert sound, as a value rather than a raw string.
///
/// **In its own file so that `PolishFenceTests` keeps counting what it means to
/// count.** That fence pins the number of `var` declarations in
/// `AppSettings.swift`, and its subject is the **schema** — how many values this
/// app persists — because a settings screen grows one reasonable-looking field at
/// a time and the count is what makes each one a visible decision.
///
/// A computed accessor is not a stored value and must not inflate that number, or
/// the fence starts measuring something other than the thing it was put there to
/// hold.
extension AppSettings {
  /// The chosen sound, or the default when nothing is stored or the stored value
  /// is not one this build knows about.
  var alertSound: AlertSound {
    get { AlertSound.stored(alertSoundRawValue) }
    set { alertSoundRawValue = newValue.rawValue }
  }
}
