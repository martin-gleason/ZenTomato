import Foundation

/// The chosen alert sound, as a value rather than a raw string.
///
/// **In its own file, and the reason changed under it.** This was separated so a
/// computed accessor could not inflate `PolishFenceTests`' count of `var`
/// declarations in `AppSettings.swift`. That fence no longer greps: it asks
/// `Schema` how many columns are persisted, which is what its subject always
/// was — a settings screen grows one reasonable-looking field at a time, and the
/// count is what makes each one a visible decision.
///
/// So the separation is now housekeeping rather than load-bearing, and it stays
/// for the honest reason: **this file was itself the proof that a property can be
/// moved out of a regex's reach**, which is why the fence was rewritten.
extension AppSettings {
  /// The chosen sound, or the default when nothing is stored or the stored value
  /// is not one this build knows about.
  var alertSound: AlertSound {
    get { AlertSound.stored(alertSoundRawValue) }
    set { alertSoundRawValue = newValue.rawValue }
  }
}
