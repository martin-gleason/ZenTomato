import SwiftUI

/// The two capture buttons on the running focus screen.
///
/// WHAT THIS VIEW IS AND IS NOT
/// It is a pair of buttons drawn from two finished numbers, with two closures
/// out. It owns no database, no timer and no decision about whether a tap is
/// allowed — it does not know what a distraction *is*. Handed a count it draws
/// a count; tapped, it calls back. That is what lets every state of it be looked
/// at in a preview with nothing running, including the accessibility sizes that
/// are the hard case here.
///
/// **There is no `Task` in this file, and there must never be one.** Everything
/// downstream of these closures is synchronous: the tap reaches the engine, a
/// row is written and committed to disk, and only then does anything buzz. A
/// piece of asynchronous work started here would reopen exactly the gap the
/// whole feature exists to close — a tap that has happened and a row that has
/// not. The Start and Stop buttons two files away *do* start one, correctly and
/// for their own reasons; copying that habit into this file is the single most
/// likely way to break this feature. The search that proves it has not happened
/// is `grep -n "Task" ZenTomato/Views/DistractionButtons.swift`.
///
/// WHY THE BUTTONS SAY "Internal" AND "External" RATHER THAN "I" AND "E"
/// The spec names the data I and E. That is the name of the *datum*, not of the
/// glyph, and five things make the word the better label:
///
/// 1. In San Francisco a capital `I` is a bare vertical stroke, indistinguishable
///    from a lowercase `l` and from the digit `1`. On a screen whose entire
///    subject is a 96-point numeral, a lone vertical stroke on a button reads as
///    a number.
/// 2. `DistractionTally.summary(of:)` already prints "2 internal · 1 external",
///    so the button, the end-of-block sheet and the tally all speak one
///    vocabulary and nothing has to translate a mnemonic into a word.
/// 3. Recognition beats recall. The person pressing this has just noticed their
///    attention is gone; a taught mnemonic costs the second the button exists to
///    save.
/// 4. Voice Control. "Tap Internal" resolves. "Tap I" collides with "eye", "aye"
///    and the letter, which for a hands-free reader is the difference between
///    the feature working and not.
/// 5. Dynamic Type. A word reflows; a letter beside a word is a two-element
///    layout that has to be re-solved at every accessibility size.
struct DistractionButtons: View {
  // MARK: Internal

  /// How many internal distractions have been recorded **in the block running
  /// now**. Reset at every block boundary by the thing that supplies it; this
  /// view never accumulates anything of its own.
  let internalCount: Int

  /// The same, for external ones.
  let externalCount: Int

  var onInternal: () -> Void = { }
  var onExternal: () -> Void = { }

  var body: some View {
    // `AnyLayout` swaps the arrangement without swapping the views, so the two
    // buttons keep their identity — and therefore their receipt state — across
    // a change of text size. Rebuilding them inside an `if` would reset that.
    pairLayout {
      button(
        Self.internalWords,
        count: internalCount,
        receiptTrigger: internalReceipts,
        action: onInternal)

      button(
        Self.externalWords,
        count: externalCount,
        receiptTrigger: externalReceipts,
        action: onExternal)
    }
    // A RECEIPT IS ONLY EVER FOR SOMETHING THE PERSON JUST DID.
    //
    // The fill below is played when its trigger changes, so the trigger must
    // change on a tap and on nothing else. A count also changes at a block
    // boundary, where it drops back to zero — and a fill flashing across both
    // buttons the instant a focus block ends would be the app congratulating
    // somebody for a boundary they had no part in. So a receipt is counted only
    // when the number goes *up*, and the tally these triggers keep never
    // decreases for as long as the screen is on show.
    .onChange(of: internalCount) { previous, current in
      if current > previous { internalReceipts += 1 }
    }
    .onChange(of: externalCount) { previous, current in
      if current > previous { externalReceipts += 1 }
    }
  }

  // MARK: Private

  /// Everything one button says, drawn and spoken.
  ///
  /// Gathered into a value rather than passed as four separate arguments so the
  /// drawn word and the two spoken sentences that belong with it cannot be
  /// wired up to the wrong button — a mistake that would be silent, would be
  /// invisible to anyone who can see the screen, and would tell a VoiceOver
  /// reader they had just logged the opposite of what they logged.
  private struct Words {
    /// The word on the button.
    let title: String
    /// What VoiceOver calls it. The distinguishing word comes first.
    let spokenLabel: String
    /// What it means, in the vocabulary `DistractionKind`'s own documentation
    /// uses.
    let spokenHint: String
  }

  private static let internalWords = Words(
    title: DistractionKind.internalInterruption.captureLabel,
    spokenLabel: "Internal distraction",
    spokenHint: "Your own head — you drifted, or remembered something. "
      + "Recorded the moment you tap.")

  private static let externalWords = Words(
    title: DistractionKind.externalInterruption.captureLabel,
    spokenLabel: "External distraction",
    spokenHint: "Someone or something else — a person, a call, a knock. "
      + "Recorded the moment you tap.")

  /// The text size from which the pair stops sitting side by side.
  ///
  /// "Internal" and "External" are eight characters. At the largest
  /// accessibility sizes they need roughly 230 points and a half-width button
  /// on a 393-point phone offers about 174, so side by side they would shrink or
  /// truncate — and a truncated capture label is a wrong record waiting to
  /// happen. Full width also makes each button an enormous target at exactly the
  /// sizes where a reader's precision is likeliest to be reduced.
  private static let stackingThreshold: DynamicTypeSize = .accessibility1

  /// The reader's text-size setting, which decides the arrangement.
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  /// How many *increases* each count has seen while this view has been on
  /// screen. Monotonic on purpose — see the note in `body`.
  @State private var internalReceipts = 0
  @State private var externalReceipts = 0

  /// Side by side, or stacked at the accessibility sizes.
  ///
  /// **Deliberately not `ViewThatFits`.** That measures whether a candidate
  /// layout's ideal size fits the space offered, and both buttons here ask for
  /// `maxWidth: .infinity` — so the horizontal candidate always claims to fit,
  /// at every text size, and the fallback would never be used. A stated
  /// threshold is both honest about the decision and previewable.
  private var pairLayout: AnyLayout {
    dynamicTypeSize >= Self.stackingThreshold
      ? AnyLayout(VStackLayout(spacing: Spacing.sm))
      : AnyLayout(HStackLayout(spacing: Spacing.sm))
  }

  /// One capture button: a word, and under it the number of times it has been
  /// pressed during this block.
  private func button(
    _ words: Words,
    count: Int,
    receiptTrigger: Int,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: Spacing.xxs) {
        Text(words.title)
          .font(Typography.button)
          .foregroundStyle(Color(.textPrimary))
          .lineLimit(2)
          .multilineTextAlignment(.center)

        // THE RUNNING COUNT, AND WHY IT IS NOT DECORATION.
        //
        // Without it the only evidence a tap landed is a buzz and a fill that
        // vanishes with the finger. The premise of the feature is that the tap
        // *is* the record, and trust in that needs a receipt which survives
        // looking away.
        //
        // It cannot compete with the countdown: it is a footnote-sized
        // monospaced digit roughly one twelfth the height of the numeral, two
        // hundred points below it, off the vertical axis the numeral owns, and
        // it changes only when a finger causes it to.
        //
        // Drawn at zero opacity rather than removed before the first tap, so
        // the button's height and the whole screen's layout are identical
        // before and after. A resting `0` is rejected for a different reason:
        // it would put a second and third number on a screen that should have
        // one, and would read as a scoreboard from the first second of every
        // block.
        //
        // `.opacity` rather than `.hidden()` inside an `if`: the branch would
        // change the view's identity, and a view whose identity changes is a
        // view whose animations restart.
        Text(count, format: .number)
          .font(Typography.data)
          .foregroundStyle(Color(.textMuted))
          .lineLimit(1)
          .opacity(count > 0 ? 1 : 0)
      }
    }
    .buttonStyle(CaptureButtonStyle(receiptTrigger: receiptTrigger))
    // THE LABEL PUTS THE DISTINGUISHING WORD FIRST, AND THAT IS THE WHOLE
    // POINT OF ITS WORDING. Swiping through the screen a reader hears
    // "Internal…" and can stop listening and double-tap, rather than waiting
    // out a shared prefix like "Log a…". That is one saved second per capture,
    // on the one control whose entire justification is saving a second.
    .accessibilityLabel(Text(words.spokenLabel))
    // The hint carries the definition, lifted from `DistractionKind`'s own doc
    // comments so the spoken vocabulary and the source of truth cannot drift.
    // Hints can be switched off in VoiceOver's settings, which is why the label
    // above stands on its own without it.
    .accessibilityHint(Text(words.spokenHint))
    // THE VALUE IS SAFE HERE, AND IT IS LOAD-BEARING.
    //
    // F2's lesson was that a value on an element which changes once a second
    // makes a screen unusable, because the system may re-read a focused
    // element's value every time it changes. This value changes only when the
    // reader themself causes it to, a handful of times per block — so attaching
    // it costs nothing and buys the receipt: a value that changes as a result of
    // your own activation is re-read, and that re-reading is the confirmation.
    //
    // Empty before the first tap, which VoiceOver says nothing for. That
    // matches the drawn button, where the count is not shown either. An empty
    // string is used rather than a conditional modifier for the identity reason
    // given above.
    .accessibilityValue(Text(count > 0 ? "\(count) so far" : ""))
  }
}

// MARK: - CaptureButtonStyle

/// A third button weight, private to this file.
///
/// The app's button vocabulary was two words wide and is now three:
///
/// | Weight | Means | Where |
/// |---|---|---|
/// | filled sage | "this is the thing to do" | Start — absent while a block runs |
/// | 2pt outline, ordinary ink | "this is here" | capture — this style |
/// | 1pt outline, quiet ink | "this is available" | Stop |
///
/// **Nothing here is filled and nothing here is sage.** The ratified rule that
/// no button is filled while a block runs survives intact, and the small word
/// above the countdown keeps its status as the one piece of colour on the
/// screen. Capture buys its prominence with ink weight and outline weight
/// instead of hue — which is also why a colour-blind reader loses nothing.
///
/// **No new colour role was invented for it.** The role one would otherwise want
/// — "an enabled control that is neither the primary action nor a quiet
/// dismissal" — does not exist in the design system. `surfaceInset` was
/// considered as a resting ground and rejected: its own documentation says it
/// means *switched off*, and putting it under an enabled control would
/// contradict the single thing that role asserts. It appears here only as the
/// pressed and receipt fill, which is exactly what `SecondaryButtonStyle`
/// already does with it and exactly what it already means there.
private struct CaptureButtonStyle: ButtonStyle {
  // MARK: Internal

  /// Changes by one every time a tap of this kind is **committed to disk**.
  /// Never on a press, never on a block boundary. See `DistractionButtons.body`.
  let receiptTrigger: Int

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(.horizontal, Spacing.sm)
      .padding(.vertical, Spacing.md)
      // A *minimum* height applied after the padding, exactly as
      // `Spacing.controlHeight` is used on every other button in the app. On a
      // 393-point phone this gives each button about 174 × 64 points — roughly
      // six times the area of the 44-point touch-target floor, which is the
      // size a control gets when it is meant to be hit without being looked at.
      // A *fixed* height would clip its own label at large text sizes.
      .frame(maxWidth: .infinity, minHeight: Spacing.xxxl)
      // The ordinary pressed state: the ground sinks while the finger is down.
      .background {
        shape.fill(Color(.surfaceInset))
          .opacity(configuration.isPressed ? 1 : 0)
      }
      // The receipt, in the same colour and therefore the same meaning, so a
      // slow tap simply extends the pressed state rather than flickering
      // between two treatments.
      .background { receiptFill }
      .overlay { shape.strokeBorder(Color(.borderStrong), lineWidth: Spacing.borderThin) }
      // Without this only the glyphs would be tappable, and a button with no
      // resting fill is mostly not glyphs.
      .contentShape(shape)
  }

  // MARK: Private

  /// How long the receipt fill is held after the finger lifts, in seconds.
  ///
  /// It exists because the two-to-three case is a single glyph changing on a
  /// 64-point button, which is below the threshold of "confirmed at a glance by
  /// somebody whose attention has already moved on". Long enough to register,
  /// short enough that it is gone before it can be looked at.
  private static let receiptHold: TimeInterval = 0.18

  /// How long the receipt takes to leave. Not zero, because a keyframe timeline
  /// needs a final step with a duration to run at all; small enough that it
  /// reads as instant. **Nothing here animates in the sense that matters** —
  /// there is no movement, no scale and no colour flash, so there is no
  /// separate Reduce Motion path to get wrong.
  private static let receiptRelease: TimeInterval = 0.01

  private var shape: RoundedRectangle {
    // Six points: the same corner as every other button in the app.
    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
  }

  /// The fill that says a row was written.
  ///
  /// A keyframe timeline rather than a piece of scheduled work, because this
  /// file is not allowed to start any — see the note at the top. It rests
  /// invisible, jumps instantly to full when its trigger changes, holds, and
  /// goes.
  private var receiptFill: some View {
    shape.fill(Color(.surfaceInset))
      .keyframeAnimator(initialValue: 0.0, trigger: receiptTrigger) { view, opacity in
        view.opacity(opacity)
      } keyframes: { _ in
        MoveKeyframe(1.0)
        LinearKeyframe(1.0, duration: Self.receiptHold)
        LinearKeyframe(0.0, duration: Self.receiptRelease)
      }
  }
}

// MARK: - Previews

#Preview("Work running, no taps yet") {
  DistractionButtonsPreviewHost(internalCount: 0, externalCount: 0)
    .preferredColorScheme(.light)
}

#Preview("Work running, 2 internal 1 external") {
  DistractionButtonsPreviewHost(internalCount: 2, externalCount: 1)
    .preferredColorScheme(.light)
}

/// Together with the light preview above, the check that the colours actually
/// respond to the phone's setting rather than having been written down once.
#Preview("Work running, dark") {
  DistractionButtonsPreviewHost(internalCount: 2, externalCount: 1)
    .preferredColorScheme(.dark)
}

/// The reserved slot. During a break the pair keeps its exact height and is
/// unreachable by finger, by VoiceOver and by Full Keyboard Access — so the
/// countdown does not move at the work-to-break boundary, and a distraction can
/// never be logged against a break.
#Preview("Short break — the reserved slot") {
  DistractionButtonsPreviewHost(internalCount: 0, externalCount: 0, isReserved: true)
    .preferredColorScheme(.light)
}

/// The size at which the pair stops sitting side by side. Nothing may be cut
/// off, shrunk or overlapping here.
#Preview("Work running, largest text") {
  DistractionButtonsPreviewHost(internalCount: 12, externalCount: 3)
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}

/// Preview scaffolding, never part of what ships.
private struct DistractionButtonsPreviewHost: View {
  var internalCount: Int
  var externalCount: Int
  var isReserved = false

  var body: some View {
    VStack(spacing: Spacing.none) {
      Spacer(minLength: Spacing.xl)

      DistractionButtons(internalCount: internalCount, externalCount: externalCount)
        .hidden(isReserved)
        .allowsHitTesting(!isReserved)
        .accessibilityHidden(isReserved)

      Spacer(minLength: Spacing.xxl)
    }
    .padding(.horizontal, Spacing.md)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.surfacePrimary))
  }
}

private extension View {
  /// `.hidden()` as a condition, without the `if` that would change the view's
  /// identity. Private to this file and used only by the preview above.
  func hidden(_ isHidden: Bool) -> some View {
    opacity(isHidden ? 0 : 1)
  }
}
