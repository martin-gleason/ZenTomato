import SwiftUI

// How the app's buttons are drawn.
//
// WHY THESE TWO LIVE IN A FILE OF THEIR OWN
// `StartButtonStyle` used to sit at the bottom of `TimerView.swift`, where it
// was the only button in the app. It is now used on two screens — the timer and
// the alarm-permission explainer — and it has a quieter sibling for Skip and
// Stop. Two button styles shared by three screens is a small vocabulary rather
// than a detail of one screen, so it lives where both can see it.
//
// THE ONE RULE BOTH FOLLOW
// A FILLED button means "this is the thing to do". An OUTLINED button means
// "this is available". There is at most one filled button on any screen in this
// app, and while a block is running there is none at all — because while a focus
// block runs, the thing to do is nothing.

// MARK: - StartButtonStyle

/// The one prominent button in the app.
///
/// **Why the app defines this instead of using an iOS button.** The system's
/// prominent button is heavily rounded — sixteen to twenty-six points — which is
/// the opposite of this design system's sharp-cornered character. This style
/// changes three things and nothing else: the fill, the ink, and the corner
/// radius. Everything a button *does* — responding to a tap, reporting itself to
/// VoiceOver, growing with the reader's text size, meeting the minimum tappable
/// size — is still iOS's, untouched.
///
/// A second, quieter reason: iOS dims a *standard* button automatically when it
/// is switched off, by making it see-through. That lets the page show through the
/// button and reads as a rendering fault rather than as "off". A custom style
/// receives no automatic dimming, so the treatment below is the whole treatment
/// and it survives every accessibility setting, including Increase Contrast.
///
/// **The switched-off branch still earns its place.** The Start button is no
/// longer permanently disabled — it starts a block now — but it is still switched
/// off in one real case: a database that opened and holds no settings row, where
/// the screen has no block length to start. See `TimerScreen`.
struct StartButtonStyle: ButtonStyle {
  // MARK: Internal

  func makeBody(configuration: Configuration) -> some View {
    // `makeBody` is not itself a screen element, which means it cannot ask the
    // system whether the button is currently switched on. The small view below
    // can. Without this indirection a switched-off button would draw as if it
    // were switched on.
    Content(configuration: configuration)
  }

  // MARK: Private

  private struct Content: View {
    // MARK: Internal

    let configuration: ButtonStyleConfiguration

    var body: some View {
      configuration.label
        .font(Typography.button)
        .foregroundStyle(ink)
        // Two lines, because at the largest accessibility text sizes the label
        // no longer fits on one, and wrapping beats truncating.
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        // A *minimum* height applied after the padding, so 44pt is the floor for
        // the whole control while the label stays free to grow past it. A fixed
        // height would clip its own label at large text sizes.
        .frame(maxWidth: .infinity, minHeight: Spacing.controlHeight)
        .background(fill, in: shape)
        // The outline is what makes a switched-off button legible at all. Its
        // sunken fill is almost exactly the brightness of the page behind it
        // (measured at 1.17:1 in light and 1.06:1 in dark), so without an
        // outline the button would be effectively invisible — and in dark it
        // would read as a hole in the page rather than as a control. This
        // outline clears the 3:1 legibility floor against both the page and the
        // fill, in both appearances.
        .overlay {
          if !isEnabled {
            shape.strokeBorder(Color(.borderStrong), lineWidth: Spacing.borderHairline)
          }
        }
        .contentShape(shape)
    }

    // MARK: Private

    /// Whether the button is currently switched on. Set by `.disabled(_:)` at
    /// the place the button is used, and read from the surroundings here.
    @Environment(\.isEnabled) private var isEnabled

    /// Six points of corner radius, against the sixteen to twenty-six that iOS
    /// rounds its own buttons by. That sharpness is the design system's
    /// signature. Defined once so the fill, the outline and the tappable area
    /// can never disagree about the shape.
    private var shape: RoundedRectangle {
      RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
    }

    private var fill: Color {
      isEnabled ? Color(.action) : Color(.surfaceInset)
    }

    private var ink: Color {
      isEnabled ? Color(.onAction) : Color(.textSubtle)
    }
  }
}

// MARK: - SecondaryButtonStyle

/// The quiet button: Skip and Stop.
///
/// No fill at all — the page shows through — and a one-point outline in the
/// design system's functional border colour. Pressing it sinks the fill to the
/// recessed ground and leaves the ink and the outline where they were.
///
/// **Why nothing is filled while a block runs.** A filled button in this design
/// system means "this is the thing to do". While a focus block is running, the
/// thing to do is nothing. Drawing Skip as a prominent green button would
/// advertise abandonment as the encouraged action. Both controls are therefore
/// quiet, equal-weight outlines, and the running screen has no primary action for
/// the duration of the block. That is the design, not an omission.
///
/// **Stop is grey, not red.** Nothing irreversible happens: Skip and Stop both
/// record the block as abandoned and both are undone by one tap on Start. Red
/// would be the loudest thing on a screen whose whole premise is that the
/// countdown is the loudest thing, and it would spend the design system's alarm
/// colour on a routine action.
struct SecondaryButtonStyle: ButtonStyle {
  // MARK: Lifecycle

  /// - Parameter emphasis: which of the two inks to use. Skip carries the
  ///   ordinary reading ink; Stop is a shade quieter, so that the pair reads left
  ///   to right as an escalation — end this block, then end the session — rather
  ///   than as two identical choices.
  init(emphasis: Emphasis = .normal) {
    self.emphasis = emphasis
  }

  // MARK: Internal

  enum Emphasis {
    case normal
    case quiet
  }

  func makeBody(configuration: Configuration) -> some View {
    Content(configuration: configuration, emphasis: emphasis)
  }

  // MARK: Private

  private let emphasis: Emphasis

  private struct Content: View {
    // MARK: Internal

    let configuration: ButtonStyleConfiguration
    let emphasis: Emphasis

    var body: some View {
      configuration.label
        .font(Typography.button)
        .foregroundStyle(ink)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, minHeight: Spacing.controlHeight)
        // No fill at rest: the page shows through, which is what makes this
        // button quiet. Nothing is painted rather than something transparent
        // being painted, so it is correct on any ground.
        .background {
          if configuration.isPressed {
            shape.fill(Color(.surfaceInset))
          }
        }
        .overlay {
          shape.strokeBorder(Color(.borderStrong), lineWidth: Spacing.borderHairline)
        }
        // Without this only the glyphs themselves would be tappable, and a
        // button with no fill is mostly not glyphs.
        .contentShape(shape)
    }

    // MARK: Private

    private var shape: RoundedRectangle {
      RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
    }

    private var ink: Color {
      switch emphasis {
      case .normal: Color(.textPrimary)
      case .quiet: Color(.textMuted)
      }
    }
  }
}

// MARK: - Previews

#Preview("Light") {
  ButtonStylePreviewRows()
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  ButtonStylePreviewRows()
    .preferredColorScheme(.dark)
}

/// The size at which a button label wraps to two lines rather than shrinking.
#Preview("Largest text") {
  ButtonStylePreviewRows()
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}

/// Preview scaffolding, never part of what ships.
private struct ButtonStylePreviewRows: View {
  var body: some View {
    VStack(spacing: Spacing.md) {
      Button("Start") { }
        .buttonStyle(StartButtonStyle())

      // The switched-off appearance. This is the ONLY `.disabled(true)` left in
      // the tree — the Start button on the timer screen no longer carries one,
      // and this preview exists so that the branch it drives is still looked at.
      Button("Start") { }
        .buttonStyle(StartButtonStyle())
        .disabled(true)

      HStack(spacing: Spacing.sm) {
        Button("Skip") { }
          .buttonStyle(SecondaryButtonStyle())
        Button("Stop") { }
          .buttonStyle(SecondaryButtonStyle(emphasis: .quiet))
      }
    }
    .padding(.horizontal, Spacing.md)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.surfacePrimary))
  }
}
