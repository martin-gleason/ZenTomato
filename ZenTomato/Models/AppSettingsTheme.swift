import Foundation

/// The chosen theme, as a value rather than a raw string — the same shape as
/// `AppSettingsAlertSound.swift`, for the same reason.
extension AppSettings {
  /// The theme choice, or Auto when nothing is stored or the stored value is not
  /// one this build knows about.
  var themeChoice: ThemeChoice {
    get { ThemeChoice.stored(themeRawValue) }
    set { themeRawValue = newValue.rawValue }
  }
}
