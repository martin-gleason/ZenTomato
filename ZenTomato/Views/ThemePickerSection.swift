import SwiftUI

/// The theme picker in Settings (`D58`, `F12-T4`) — the handoff's rows, in the handoff's order.
///
/// **What each row shows, for a reader who does not write Swift.** A three-colour chip — the page,
/// the ink and the accent — then the theme's name and one line about it, and a checkmark on the one
/// in use. **The chip is drawn in the row's own theme, not the app's current one**, so every row
/// previews itself: the whole screen is Sage and the Plum row's chip is still plum. That is one line
/// — `.environment(\.theme, …)` on the chip — because the chip asks for the same roles every screen
/// does, and the theme decides what they are.
///
/// **Not locked while a block runs, deliberately.** `D27` locks the timer's settings mid-block
/// because a running block must not have its arithmetic changed underneath it. A colour changes no
/// arithmetic, and `SettingsLockTests.theThemePickerIsNotLocked` keeps this section out of the
/// locked group.
///
/// **Two departures from the handoff, both to stay inside the design system.** The description is set
/// in `Typography.data`, not the handoff's 13-point regular, because the type scale has no such step
/// and `theTokenLayerDoesNotGrow` pins it; and the three rows the handoff also puts under *Theme* —
/// block style, and moving the sound row here — belong to the Settings restructure, which is not `F12`.
struct ThemePickerSection: View {
  // MARK: Internal

  /// The settings row. Writing its choice is the whole of what a tap does.
  @Bindable var settings: AppSettings

  var body: some View {
    Section {
      ForEach(ThemeChoice.allCases) { choice in
        row(for: choice)
      }
    } header: {
      Text("Theme")
        .font(Typography.kicker)
        .textCase(.uppercase)
        .foregroundStyle(Color(.textMuted))
    } footer: {
      // The handoff's footnote, verbatim.
      Text(
        """
        Auto follows the season and the clock: harvest reds in August–September daylight, \
        ink after dark. Light and dark still follow the phone.
        """)
        .font(Typography.body)
        .foregroundStyle(Color(.textMuted))
    }
    .listRowBackground(Color(.surfaceRaised))
  }

  // MARK: Private

  private func row(for choice: ThemeChoice) -> some View {
    let isChosen = settings.themeChoice == choice
    let shown = choice.resolved(at: .now)
    return Button {
      settings.themeChoice = choice
    } label: {
      HStack(spacing: Spacing.sm) {
        Self.chip.environment(\.theme, shown)
        VStack(alignment: .leading, spacing: Spacing.xxxs) {
          Text(Self.name(of: choice))
            .font(Typography.label)
            .foregroundStyle(Color(.textPrimary))
          Text(Self.summary(of: choice, now: shown))
            .font(Typography.data)
            .foregroundStyle(Color(.textSubtle))
        }
        Spacer(minLength: Spacing.xs)
        if isChosen {
          Image(systemName: "checkmark")
            .font(Typography.bodyEmphasis)
            .foregroundStyle(Color(.action))
        }
      }
      .frame(minHeight: 56)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isChosen ? [.isButton, .isSelected] : .isButton)
  }

  /// The page, the ink and the accent, 12 × 24 points each — the handoff's chip. Its colours are
  /// roles, so whichever theme the caller puts on it is the one it shows.
  private static var chip: some View {
    HStack(spacing: Spacing.none) {
      Color(.surfacePrimary).frame(width: 12, height: 24)
      Color(.textPrimary).frame(width: 12, height: 24)
      Color(.action).frame(width: 12, height: 24)
    }
    .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
    .overlay(
      RoundedRectangle(cornerRadius: Radius.xs)
        .strokeBorder(Color(.borderStrong), lineWidth: Spacing.borderHairline))
    .accessibilityHidden(true)
  }

  private static func name(of choice: ThemeChoice) -> String {
    choice.fixed?.name ?? "Auto"
  }

  /// Auto's line names what it is drawing right now — the handoff's *"now: {Theme}"*.
  private static func summary(of choice: ThemeChoice, now: Theme) -> String {
    choice.fixed?.summary ?? "Season and clock decide — now: \(now.name)"
  }
}
