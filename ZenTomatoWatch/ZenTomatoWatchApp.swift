import SwiftUI

/// The watch app's entry point.
///
/// It owns one object — the link to the phone — and one screen. There is no
/// store, no timer, no alarm and no audio here, and that is the feature rather
/// than an omission: D2 puts the only timer engine on the phone, so anything the
/// watch could decide for itself is a way for two devices to disagree about the
/// one number this app exists to produce.
@main
struct ZenTomatoWatchApp: App {
  var body: some Scene {
    WindowGroup {
      WatchTimerScreen(link: link)
    }
  }

  /// Created once, for the life of the app.
  ///
  /// `WCSession` is a singleton owned by the system and activating it twice is a
  /// programmer error, so the object that wraps it is made here and handed down
  /// rather than constructed by a view. A view can be rebuilt many times a
  /// second; a session cannot.
  @State private var link = WatchLink()
}
