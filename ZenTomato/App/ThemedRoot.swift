import SwiftData
import SwiftUI
import UIKit

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
      content.appTheme(choice.resolved(at: context.date))
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

// MARK: - The theme, set on the window scene as well

extension View {
  /// Applies a theme to everything beneath this view **and to the window it is shown in.**
  ///
  /// **Why both, for a reader who does not write Swift.** Setting the theme in SwiftUI's environment
  /// reaches almost everything, but not quite: a few pieces of a screen are drawn by iOS's older
  /// UIKit machinery on SwiftUI's behalf, and inside a sheet those pieces read their surroundings from
  /// the *window*, not from the view that asked for them. The selected row in "Choose what to work
  /// on" was one — its background is a list-row background, and under Ripen it painted Sage's pale
  /// green while the checkmark beside it painted Ripen's red. Setting the same theme on the window
  /// scene closes that gap for every such piece at once, rather than one screen at a time.
  ///
  /// Reproduced and verified by `ThemeReachesSheetsTests` before this was written: the row painted
  /// `#E7EBDC` (Sage) without the scene override and `#FAEFEE` (Ripen) with it.
  func appTheme(_ theme: Theme) -> some View {
    environment(\.theme, theme)
      .background(SceneThemeBridge(theme: theme).allowsHitTesting(false))
  }
}

/// An invisible view whose only job is to write the theme onto the window scene it lands in.
private struct SceneThemeBridge: UIViewRepresentable {
  let theme: Theme

  func makeUIView(context _: Context) -> SceneThemeView {
    SceneThemeView()
  }

  func updateUIView(_ view: SceneThemeView, context _: Context) {
    view.theme = theme
  }
}

/// Writes when it joins a window and whenever the theme changes — the window is not known until
/// the view is on screen, so either moment may be the first one that can.
private final class SceneThemeView: UIView {
  var theme = Theme.sage {
    didSet { apply() }
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    apply()
  }

  private func apply() {
    guard let scene = window?.windowScene else { return }
    // Reading an override that was never set is an assertion failure in UIKit, not a default —
    // found by the first run of `ThemeReachesSheetsTests`, which crashed the app at launch. Ask first.
    if scene.traitOverrides.contains(ThemeTrait.self), scene.traitOverrides[ThemeTrait.self] == theme { return }
    scene.traitOverrides[ThemeTrait.self] = theme
  }
}
