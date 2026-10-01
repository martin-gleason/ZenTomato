import SwiftData
import SwiftUI

/// Sets the theme once, at the root, for every screen beneath it (`D58`, `F12-T3`).
///
/// **What this does, for a reader who does not write Swift.** It reads the owner's choice from the
/// settings row, turns Auto into an actual theme using the current time, and hands the result down
/// to everything below. Every `Color(.role)` in the app then resolves under it — the sheets included,
/// because SwiftUI passes this value into anything presented from beneath it.
///
/// **Auto changes on the hour, and nothing here runs a timer to make it.** `TimelineView` asks iOS
/// to redraw this one view at each hour boundary; the theme is recomputed then and only changes when
/// the rule's answer does. Coming back to the app after 9pm lands on a fresh timeline entry, so the
/// app is Ink the moment it is seen — the handoff's *"recomputed on foreground and hour change"*,
/// without an observer of the app's own.
struct ThemedRoot<Content: View>: View {
  // MARK: Lifecycle

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  // MARK: Internal

  var body: some View {
    TimelineView(.periodic(from: Self.startOfThisHour(), by: 3600)) { context in
      content.environment(\.theme, choice.resolved(at: context.date))
    }
  }

  // MARK: Private

  private let content: Content

  /// The settings row, watched so a pick in Settings repaints the app at once. Empty for the first
  /// frame of a first launch, before the row exists — which reads as Auto, the default anyway.
  @Query private var settings: [AppSettings]

  private var choice: ThemeChoice {
    ThemeChoice.stored(settings.first?.themeRawValue)
  }

  private static func startOfThisHour(_ now: Date = .now) -> Date {
    Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now
  }
}
