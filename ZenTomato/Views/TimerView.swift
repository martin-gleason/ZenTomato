import SwiftData
import SwiftUI

/// The timer screen — and, in this first version, the whole app.
///
/// **What is on it.** Three things and nothing else: a small green word saying
/// what kind of block this is, a large number saying how long it lasts, and a
/// Start button that is switched off. No navigation bar, no toolbar, no settings
/// button, no card, no shadow.
///
/// **What is deliberately missing.** There is no timer behind this. Nothing
/// counts down, and the Start button does nothing when tapped because it cannot
/// be tapped. That is the agreed shape of this piece of work: it exists to prove
/// that the app launches, that the database opens, and that a saved setting comes
/// back out again. The countdown itself is the next piece of work.
///
/// **Where the number comes from.** The `25` is read out of the database, not
/// typed into this file. That is the point of the screen: if the store failed to
/// open, or the settings row failed to save, this number would be wrong — and it
/// is wrong in a way that is visible from across the room.
struct TimerView: View {
  // MARK: Internal

  var body: some View {
    VStack(spacing: Spacing.none) {
      // Two equal spacers, one above the block and one below it. Because they
      // are equal, the word-and-number pair centres itself in the space *above*
      // the button, which lands it slightly above the true middle of the screen.
      // That is where an eye expects a single focal element; a mathematically
      // centred number with a button underneath reads as sitting too low.
      Spacer(minLength: Spacing.xl)

      focusBlock

      Spacer(minLength: Spacing.xl)

      startButton
    }
    .padding(.horizontal, Spacing.md)
    .padding(.bottom, Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    // Only the *background* runs under the status bar and the home indicator.
    // The content stays inside the safe area, so the number never slides under
    // the camera cutout and the button never sits under the home bar.
    .background(Color(.surfacePrimary).ignoresSafeArea())
  }

  // MARK: Private

  /// Reads the settings row out of the database.
  ///
  /// This comes back as a list because that is the only shape SwiftData offers,
  /// but there is exactly one settings row by design — see `AppSettings`.
  @Query private var settings: [AppSettings]

  /// The size of the countdown numeral, after the reader's text-size setting has
  /// been applied to it.
  ///
  /// `@ScaledMetric` is the tool for exactly this job: it takes a number that
  /// means "points on screen" and grows it the way text grows, so the numeral
  /// tracks the reader's Settings choice even though its size is stated directly
  /// rather than taken from a named text style. `relativeTo: .largeTitle` picks
  /// *which* growth curve — the one for very large text, which flattens off at
  /// the top accessibility sizes instead of running away. That flattening is the
  /// reason this reads correctly at AX5: without it a number starting at 96
  /// points would ask for several times the width of the phone.
  @ScaledMetric(relativeTo: .largeTitle) private var numeralSize = Typography.numeralBaseSize

  /// What the screen shows when there is no settings row to read.
  ///
  /// **Why it is not just `25:00`.** This screen's job is to prove that the
  /// database opened and that a saved setting came back out of it. It used to
  /// fall back to the number 25 — which is also the number a healthy first
  /// launch produces — so a store that opened but held nothing looked exactly
  /// like a store that was working perfectly. The screen could not do the job it
  /// exists for. Dashes cannot be mistaken for a working timer from across the
  /// room, which is the whole point.
  ///
  /// It cannot happen in practice: the app creates the row at launch, before
  /// this screen is ever shown. This is what the code says instead of Swift's
  /// crash-on-purpose operator, which would take the whole app down over
  /// something a person could read past.
  private static let missingReading = "--:--"

  /// How far the small green word may shrink before it would otherwise overflow.
  /// It never needs to at any text size available today; the floor is here so a
  /// longer word later ("Long break") cannot be cut off.
  private static let kickerMinimumScale: CGFloat = 0.7

  /// How far the large number may shrink.
  ///
  /// At the very largest accessibility text sizes it would otherwise ask for more
  /// width than the phone has. Shrinking is correct and truncating is not: a
  /// countdown missing a digit is wrong information, whereas a slightly smaller
  /// countdown is still — even after shrinking — by far the biggest thing on the
  /// screen.
  private static let numeralMinimumScale: CGFloat = 0.5

  /// The number of minutes in a focus block, as saved by the user, or `nil` if
  /// there is no settings row to read one from.
  private var workMinutes: Int? {
    settings.first?.workMinutes
  }

  /// The word and the number, treated as one thing.
  private var focusBlock: some View {
    VStack(spacing: Spacing.sm) {
      Text("Focus")
        .font(Typography.kicker)
        .textCase(.uppercase)
        // The one piece of colour on the entire screen. Everything else is a
        // neutral grey. Scarcity is what makes it mean something.
        .foregroundStyle(Color(.action))
        .lineLimit(1)
        .minimumScaleFactor(Self.kickerMinimumScale)

      Text(workMinutes.map(Self.countdownLabel(minutes:)) ?? Self.missingReading)
        .font(Typography.timerNumeral(size: numeralSize))
        // Pulls the characters fractionally closer together. At this size the
        // default spacing reads as gaps between words rather than between digits.
        // The amount is a fraction of the size, so it holds at every text size.
        .tracking(numeralSize * Typography.numeralTrackingRatio)
        // Quieter ink for the dashes, so "there is nothing to show" reads
        // differently from "here is your time" at a glance as well as in words.
        .foregroundStyle(workMinutes == nil ? Color(.textSubtle) : Color(.textPrimary))
        .lineLimit(1)
        .minimumScaleFactor(Self.numeralMinimumScale)
    }
    // VoiceOver reads these two as one sentence rather than two fragments. Left
    // alone it would announce the word in isolation and then read the number as
    // "twenty-five colon zero zero", pronouncing the colon out loud. The spoken
    // value is built from the same saved setting as the printed one, so the two
    // can never disagree.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("Focus block"))
    .accessibilityValue(Text(workMinutes.map { "\($0) minutes" } ?? "length not available"))
  }

  /// The Start button, switched off in this version.
  ///
  /// VoiceOver announces it as "Start, dimmed, button". There is deliberately no
  /// spoken hint explaining *why* it is dimmed: that would bake a temporary state
  /// of this codebase into a sentence that ships.
  private var startButton: some View {
    // The action is empty because the button cannot be pressed. The countdown
    // that will fill it in is the next piece of work; landing it removes the
    // `.disabled` below and changes nothing else on this screen.
    Button("Start") { }
      .buttonStyle(StartButtonStyle())
      .disabled(true)
  }

  /// Formats a whole number of minutes as a clock reading, e.g. `25` → `"25:00"`.
  ///
  /// Deliberately a small private function rather than a shared helper: this
  /// screen is the only thing that needs it today, and inventing a shared
  /// formatting type for one caller would be building for a caller that does not
  /// exist.
  private static func countdownLabel(minutes: Int) -> String {
    String(format: "%02d:00", minutes)
  }
}

// MARK: - StartButtonStyle

/// How the Start button is drawn.
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
private struct StartButtonStyle: ButtonStyle {
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

// MARK: - Previews

/// Hosts `TimerView` inside Xcode's preview canvas.
///
/// A preview has no running app around it, so no database is open and the timer
/// would have nothing to read. This opens a throwaway store that lives in memory
/// only and disappears when the preview closes. It is preview scaffolding and
/// never part of what ships.
private struct TimerPreviewHost: View {
  // MARK: Internal

  /// Forces the preview into light or dark, so the pair of previews below is a
  /// real check that colours resolve for both.
  let appearance: ColorScheme

  /// The reader's chosen text size. Defaults to the standard one.
  var textSize: DynamicTypeSize = .large

  var body: some View {
    switch store {
    case .success(let container):
      TimerView()
        .modelContainer(container)
        .preferredColorScheme(appearance)
        .dynamicTypeSize(textSize)

    case .failure(let error):
      StoreUnavailableView(technicalDetail: error.localizedDescription)
    }
  }

  // MARK: Private

  /// Held as state so the throwaway store is opened once per preview rather than
  /// every time the canvas redraws.
  @State private var store: Result<ModelContainer, any Error> = Result {
    try AppModelContainer.make(.inMemory)
  }
}

/// Light appearance. Together with the dark preview below, this is the check that
/// the colour system actually responds to the phone's setting: if a colour had
/// been written as a fixed value by mistake, these two would look identical.
#Preview("Light") {
  TimerPreviewHost(appearance: .light)
}

/// Dark appearance.
#Preview("Dark") {
  TimerPreviewHost(appearance: .dark)
}

/// The largest text size iOS offers, which is the one that breaks layouts.
/// Nothing here may be cut off or overlap at this size.
#Preview("Largest text") {
  TimerPreviewHost(appearance: .light, textSize: .accessibility5)
}
