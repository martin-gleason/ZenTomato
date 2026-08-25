import SwiftUI

// swiftlint:disable file_length
//
// THE ONLY LINT RULE THIS FILE TURNS OFF, AND WHY.
// `file_length` counts documentation and previews, and this file is nearly all
// of both: the argument for the reserved height — which is the whole of D19.3 —
// and a preview for every state the row can be in, including every failure.
// Those previews are the only way a reviewer who does not write Swift can see
// what this feature looks like when something has gone wrong, and the pair that
// proves the countdown does not move only works if both halves are in the same
// file. The same exemption, for the same reason, is already taken by
// `TimerScreen.swift`. Every other rule stays on.

/// The music row on the timer screen: a switch, one line, and a slot the skip
/// button lives in.
///
/// **THE HEIGHT OF THIS ROW DOES NOT CHANGE FOR A WHOLE CYCLE, AND THAT IS THE
/// WHOLE POINT OF IT (D19.3).** The ratified rule for the timer screen is that
/// the countdown moves exactly once in a cycle, at Start. The skip button appears
/// when a focus block begins playing and goes when a break starts — four times a
/// sprint — so if it were allowed to take its space with it, the number above it
/// would move four times a sprint, at exactly the moments somebody glances over
/// to see how long is left.
///
/// Two things hold the height, and neither of them is a number anybody has to
/// keep in step:
///
///   * the line is always exactly one `Text` with room reserved for a fixed
///     number of lines — two at most text sizes, four at the largest
///     accessibility ones, where the longest sentence needs four — so a
///     one-line state and a full one occupy the same height, and so does a
///     state with nothing to say. The count changes with the reader's text
///     size and never within a cycle, which is what the rule governs;
///   * the skip slot always contains a skip button — the identical button, drawn
///     hidden and made unreachable when there is nothing to skip. The space it
///     takes is therefore whatever a real button measures at the reader's own
///     text size.
///
/// That is the exact idiom `TimerScreen.capturePair` already uses to reserve the
/// capture buttons' space during a break, for the exact reason stated there.
/// **Reserved means genuinely unreachable**, not merely invisible: hidden,
/// unhittable, and out of the accessibility tree, so a VoiceOver rotor, Full
/// Keyboard Access and Voice Control all agree with the eye that there is nothing
/// there.
///
/// F3 protected this same movement rule by suppressing an affordance and made an
/// entire feature unreachable in the process. D19 answers that with "reserve the
/// space" rather than "hide the control", and this file is that answer.
///
/// **SKIP FORWARD IS THE ONLY CONTROL HERE, AND ONE THING WE CANNOT DO ABOUT IT.**
/// Control Centre, the Lock Screen, your headphones and CarPlay will still show
/// play, pause and back for whatever is playing. iOS gives every app's audio
/// those controls and no app can switch them off. Inside ZenTomato, skip forward
/// is the only one. If one of the system's own controls is used, this app's idea
/// of what is happening and the player's can disagree until this app next asks —
/// which it does after every load, resume, silence and skip, and again whenever
/// the app comes back to the front. Between those moments the disagreement
/// stands, and nothing can be done about it: iOS does not tell an app when its
/// own controls are used.
///
/// **ONE PIECE OF COLOUR, AND IT IS NOT ON THIS ROW.** The one coloured thing on
/// the timer screen is the small word above the number. The line, the chevron and
/// the skip glyph are all the muted grey. The single exception is the switch
/// itself when it is on, which is argued for where it is drawn.
///
/// **Nothing here is ever announced.** The screen announces its amber failure
/// line, because an alarm that silently failed means a block ends in silence an
/// hour later. A music failure produces a working silent timer, and interrupting
/// a VoiceOver reader mid-block to tell them a track did not start would be this
/// app treating its accessory as an emergency.
struct MusicRow: View {
  // MARK: Internal

  let model: MusicRowModel

  /// The switch was flipped. Carries the position it was flipped to.
  /// **`@MainActor` is load-bearing, not decoration.** SwiftUI's `Binding` setter
  /// is `@isolated(any) @Sendable`, so handing it a plain closure warns that it
  /// "may introduce data races" — and every one of these closures does main-actor
  /// work on a main-actor view. Saying so is the honest fix; the alternative was
  /// a warning nobody saw, because until `C12` nothing ever compiled Release.
  var onToggleMusic: @Sendable (Bool) -> Void = { _ in }

  /// The line was tapped. Only reachable while the timer is idle.
  var onOpenMusic: () -> Void = { }

  /// The skip button was pressed. Only reachable while a focus block is playing.
  var onSkipTrack: () -> Void = { }

  /// Silence the music for the rest of this block (D20). The timer is untouched.
  var onSilenceBlock: () -> Void = { }

  /// Start the music again for this block, after Stop.
  var onResumeBlock: () -> Void = { }

  var body: some View {
    Group {
      if dynamicTypeSize >= Self.stackingThreshold {
        VStack(alignment: .leading, spacing: Spacing.sm) {
          lineLabel
          HStack(spacing: Spacing.sm) {
            musicSwitch
            Spacer(minLength: Spacing.xs)
            transportSlots
          }
        }
      } else {
        HStack(spacing: Spacing.sm) {
          musicSwitch
          lineLabel
          Spacer(minLength: Spacing.xs)
          transportSlots
        }
      }
    }
    // A floor, never a fixed height: a fixed one clips its own contents the
    // moment somebody turns their text size up. The two-line reserve inside the
    // label is what actually holds the height steady; this only stops the row
    // being shorter than a control is allowed to be.
    .frame(minHeight: Spacing.controlHeight)
    .frame(maxWidth: .infinity)
  }

  // MARK: Private

  /// The text size at which the row stops being one line.
  ///
  /// Side by side, a switch and a 44-point button leave the line about 246
  /// points on a 393-point phone. Stacked, the line gets the whole 361.
  ///
  /// **`.xxLarge` rather than `.accessibility1`, which is where this parts
  /// company with `DistractionButtons` and its shared threshold, and the reason
  /// is measured rather than argued.** Every sentence this line has to carry
  /// when something has gone wrong is a whole sentence, and several of them need
  /// three lines in 246 points from `.xLarge` upwards — ordinary text sizes,
  /// not accessibility ones. With a two-line reserve their tails were being cut
  /// off, and the halves that disappeared were the load-bearing ones: *"The
  /// block is still running"*, *"Back at the next focus block"*, and the second
  /// half of the sentence explaining a refused permission. A line that says what
  /// happened but not what to do fails the rule every sentence in `MusicCopy` is
  /// written to. Stacked, all of them fit in two lines.
  ///
  /// D19.3 is untouched by the change: the reserve is a fixed number of lines
  /// *at any one text size*, and the rule governs movement within a cycle, never
  /// the difference between one reader's text size and another's.
  ///
  /// **Not `ViewThatFits`**, for the reason stated on `DistractionButtons`: the
  /// horizontal candidate always claims to fit, so the fallback would never be
  /// used. A stated threshold is honest about the decision and can be previewed.
  ///
  /// **Not `AnyLayout` either**, which is where this differs from that file. The
  /// two arrangements here are not the same children in a different direction —
  /// the stacked one groups the switch and the skip button together on their own
  /// row — so there is no single set of children for a layout to rearrange. The
  /// cost of the two branches is that the views are rebuilt when the reader
  /// changes their text size, and nothing in this row holds state that could be
  /// lost by that: the switch's position comes from the model, and the skip
  /// button counts nothing.
  private static let stackingThreshold: DynamicTypeSize = .xxLarge

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  /// The switch.
  ///
  /// **THE ONE PLACE THIS FEATURE SPENDS COLOUR, AND IT IS ARGUED FOR RATHER THAN
  /// SLIPPED IN.** Everything else in this row is the muted grey, because the one
  /// coloured thing on the timer screen is the word above the number. A switch is
  /// the exception for three reasons: iOS offers no monochrome switch, so the
  /// alternative to tinting is the system's own green — which `SettingsView`
  /// already names as the failure mode, *"an untinted switch is the app's one
  /// colour arriving from somewhere other than the token table"*; a switch's fill
  /// is the switch reporting its own position rather than a bid for attention;
  /// and it is off for anybody who has not turned music on, which is the default.
  ///
  /// The binding only ever writes outwards. What the switch shows comes from the
  /// model, so a flip that is refused — permission denied, for instance — springs
  /// straight back to off on the next redraw rather than sitting in a position
  /// that is not true.
  private var musicSwitch: some View {
    Toggle(MusicCopy.toggleLabel, isOn: Binding(get: { model.isOn }, set: onToggleMusic))
      .labelsHidden()
      .tint(Color(.action))
      .disabled(!model.isTogglable)
      // The reason comes from the model, which knows *which* of the two reasons
      // this switch is dimmed for. Deciding it here from "can it be touched?"
      // could only ever produce one answer, and it was the wrong one for
      // somebody who had refused the permission.
      .accessibilityHint(Text(model.toggleHint))
  }

  /// The one line: a control while the timer is idle, plain text while a block
  /// runs.
  ///
  /// The chevron is drawn only on the states that are actually tappable — the
  /// rule the attachment line above already ships and the F3 review ratified.
  /// Because the row's height is reserved, the chevron arriving and leaving
  /// changes no layout: it can only happen at Start and at Stop, where the
  /// screen is already allowed to move.
  @ViewBuilder
  private var lineLabel: some View {
    if model.isLineTappable {
      Button { onOpenMusic() } label: {
        HStack(spacing: Spacing.xs) {
          lineText
          Image(systemName: "chevron.right")
            .font(Typography.label)
            .foregroundStyle(Color(.textMuted))
            .accessibilityHidden(true)
        }
      }
      .buttonStyle(.plain)
      .accessibilityHint(Text("Opens music."))
    } else {
      lineText
    }
  }

  /// **`lineLimit(2, reservesSpace: true)` is the reservation**, and it is the
  /// reason there is no height constant in this file. It makes the label occupy
  /// exactly two lines' worth of height whatever it contains, including nothing
  /// at all, and it grows correctly with the reader's text size because it is
  /// measured in lines rather than in points.
  ///
  /// **A title here may truncate, and one line above may not.** The attachment
  /// line wraps and never shrinks, because a truncated task title is a wrong
  /// record on screen in the one dataset this app exists to produce. A playlist
  /// name is Apple's data, not a record this app produces, so nothing is
  /// falsified by an ellipsis — which is exactly what lets the two-line reserve
  /// be safe here and wrong twenty points higher up.
  private var lineText: some View {
    Text(model.line)
      .font(Typography.label)
      .foregroundStyle(Color(.textMuted))
      // Two lines everywhere the sentences fit in two, four at the largest
      // accessibility sizes where the widest of them needs four. Still a
      // reserve, still a count of lines rather than a number of points, and
      // still fixed for the whole of a cycle at any one text size — which is
      // the thing D19.3 governs.
      .lineLimit(dynamicTypeSize >= .accessibility3 ? 4 : 2, reservesSpace: true)
      .truncationMode(.tail)
      .multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
  }

  /// The two transport controls, together.
  ///
  /// **They appear and disappear as one.** Both answer the same question — is
  /// there sound to act on — so splitting them into two independent decisions
  /// would be two chances for the reserved row to change width, and the whole
  /// point of the reserved row is that nothing moves.
  private var transportSlots: some View {
    HStack(spacing: Spacing.none) {
      skipSlot
      stopSlot
    }
  }

  /// Silence for the rest of this block. `stop.circle` rather than `stop`,
  /// because an unfilled square alone reads as a placeholder at this size.
  ///
  /// Muted grey like its neighbour: the screen's one piece of colour is the word
  /// above the number, and a red stop button would claim it AND imply something
  /// destructive. Nothing is destroyed — the block runs on and the next one plays.
  @ViewBuilder
  private var stopSlot: some View {
    if model.canStop {
      stopButton(
        isResume: model.stopIsResume,
        action: model.stopIsResume ? onResumeBlock : onSilenceBlock)
    } else {
      stopButton(isResume: false, action: { })
        .hidden()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
  }

  /// One control, two states. `play.circle` when the block has been silenced and
  /// this would start it again; `stop.circle` while sound is coming out.
  ///
  /// The same slot either way, so the reserved row cannot change width — which is
  /// the whole reason the row is reserved.
  private func stopButton(isResume: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: isResume ? "play.circle" : "stop.circle")
        .font(Typography.label)
        .foregroundStyle(Color(.textMuted))
        .frame(width: Spacing.controlHeight, height: Spacing.controlHeight)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(isResume ? MusicCopy.resumeLabel : MusicCopy.stopLabel))
    .accessibilityHint(Text(isResume ? MusicCopy.resumeHint : MusicCopy.stopHint))
  }

  /// The skip button, or the exact space it would take.
  ///
  /// **The same button in both branches**, so the reserved width and height are
  /// whatever the real button measures at the reader's own text size rather than
  /// a number somebody guessed. Hidden here means unreachable by eye, by rotor,
  /// by Full Keyboard Access and by Voice Control — not merely transparent.
  @ViewBuilder
  private var skipSlot: some View {
    if model.canSkip {
      skipButton(action: onSkipTrack)
    } else {
      skipButton(action: { })
        .hidden()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
  }

  /// `forward.end` is the platform's "next track". **Not `forward`**, which means
  /// fast-forward and would imply this app offers a way of moving through a
/// track. It does not.
  ///
  /// Unfilled, like every other glyph on this screen. Muted grey, never the
  /// action colour: a sage skip button would be a second claim on the screen's
  /// one piece of colour, which is the same argument the gear and the attachment
  /// chevron each carry in their own doc comments. A glyph inside a 44-point
  /// target reads as a control without needing colour.
  private func skipButton(action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: "forward.end")
        // A named text style, so the glyph grows with the reader's text size. An
        // icon at a fixed point size is the classic accessibility failure.
        .font(Typography.label)
        .foregroundStyle(Color(.textMuted))
        // A 44-point hit area around a much smaller glyph — the gear's pattern.
        .frame(width: Spacing.controlHeight, height: Spacing.controlHeight)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(MusicCopy.skipLabel))
    .accessibilityHint(Text(MusicCopy.skipHint))
  }
}

// MARK: - Previews

#Preview("Idle, nothing chosen") {
  MusicRowPreviewHost(model: .previewIdleNothingChosen)
}

#Preview("Idle, music off, something chosen") {
  MusicRowPreviewHost(model: .previewIdleOff)
}

#Preview("Idle, music on") {
  MusicRowPreviewHost(model: .previewIdleOn)
}

#Preview("Idle, music on, dark") {
  MusicRowPreviewHost(model: .previewIdleOn, appearance: .dark)
}

/// A focus block with sound coming out: the one state in the whole cycle that
/// draws the skip button.
#Preview("Focus running, playing") {
  MusicRowPreviewHost(model: .previewPlaying)
}

/// The reserved slot. Put this beside "Focus running, playing" — the row is the
/// same height in both, and only the button has gone.
#Preview("Short break, paused") {
  MusicRowPreviewHost(model: .previewBreakPaused)
}

#Preview("Focus running, music off") {
  MusicRowPreviewHost(model: .previewRunningOff)
}

#Preview("Focus running, starting") {
  MusicRowPreviewHost(model: .previewStarting)
}

/// Muted, not amber. The block is running, the alarm is set, the capture buttons
/// work. Nothing is broken; it is quiet.
#Preview("Focus running, music didn't start") {
  MusicRowPreviewHost(model: .previewDidNotStart)
}

#Preview("Idle, permission denied") {
  MusicRowPreviewHost(model: .previewDenied)
}

#Preview("Idle, no subscription") {
  MusicRowPreviewHost(model: .previewNoSubscription)
}

/// Not amber: the world moving on is not an error, which is the register the
/// attachment line above already uses for a task that has left Todoist.
#Preview("Idle, chosen playlist gone") {
  MusicRowPreviewHost(model: .previewGone)
}

#Preview("Idle, empty library") {
  MusicRowPreviewHost(model: .previewEmptyLibrary)
}

/// The subscription ended with a block already running. The switch drops to off
/// and locks; the block carries on to its own end.
#Preview("Focus running, subscription ended") {
  MusicRowPreviewHost(model: .previewSubscriptionEnded)
}

#Preview("Focus running, playing, largest text") {
  MusicRowPreviewHost(model: .previewPlaying)
    .dynamicTypeSize(.accessibility5)
}

#Preview("Short break, paused, largest text") {
  MusicRowPreviewHost(model: .previewBreakPaused)
    .dynamicTypeSize(.accessibility5)
}

/// The size the two-line reserve used to start cutting sentences in half. The
/// row stacks here, so the line has the whole width.
#Preview("Focus running, subscription ended, xLarge") {
  MusicRowPreviewHost(model: .previewSubscriptionEnded)
    .dynamicTypeSize(.xLarge)
}

#Preview("Short break, paused, xxLarge") {
  MusicRowPreviewHost(model: .previewBreakPaused)
    .dynamicTypeSize(.xxLarge)
}

#Preview("Idle, permission denied, largest text") {
  MusicRowPreviewHost(model: .previewDenied)
    .dynamicTypeSize(.accessibility5)
}

/// Preview scaffolding, never part of what ships. It draws the row on the app's
/// own page so the muted ink is judged against the ground it will really sit on.
private struct MusicRowPreviewHost: View {
  let model: MusicRowModel
  var appearance: ColorScheme = .light

  var body: some View {
    VStack(spacing: Spacing.none) {
      Spacer(minLength: Spacing.xl)
      MusicRow(model: model)
      Spacer(minLength: Spacing.xl)
    }
    .padding(.horizontal, Spacing.md)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.surfacePrimary))
    .preferredColorScheme(appearance)
  }
}

/// Preview fixtures, never part of what ships.
private extension MusicRowModel {
  static let previewSelection = MusicSelection(
    kind: .playlist,
    identifier: "p.preview",
    title: "Deep Focus")

  static let previewIdleNothingChosen = MusicRowModel.forTimer(
    isRunning: false,
    kind: .work,
    isEnabled: false,
    availability: .notAsked,
    selection: nil)

  static let previewIdleOff = MusicRowModel.forTimer(
    isRunning: false,
    kind: .work,
    isEnabled: false,
    availability: .ready,
    selection: previewSelection)

  static let previewIdleOn = MusicRowModel.forTimer(
    isRunning: false,
    kind: .work,
    isEnabled: true,
    availability: .ready,
    selection: previewSelection)

  static let previewPlaying = MusicRowModel.forTimer(
    isRunning: true,
    kind: .work,
    isEnabled: true,
    availability: .ready,
    selection: previewSelection,
    playback: .playing)

  static let previewStarting = MusicRowModel.forTimer(
    isRunning: true,
    kind: .work,
    isEnabled: true,
    availability: .ready,
    selection: previewSelection,
    playback: .starting)

  static let previewBreakPaused = MusicRowModel.forTimer(
    isRunning: true,
    kind: .shortBreak,
    isEnabled: true,
    availability: .ready,
    selection: previewSelection)

  static let previewRunningOff = MusicRowModel.forTimer(
    isRunning: true,
    kind: .work,
    isEnabled: false,
    availability: .ready,
    selection: previewSelection)

  static let previewDidNotStart = MusicRowModel.forTimer(
    isRunning: true,
    kind: .work,
    isEnabled: true,
    availability: .ready,
    selection: previewSelection,
    playback: .didNotStart)

  static let previewDenied = MusicRowModel.forTimer(
    isRunning: false,
    kind: .work,
    isEnabled: true,
    availability: .denied,
    selection: previewSelection)

  static let previewNoSubscription = MusicRowModel.forTimer(
    isRunning: false,
    kind: .work,
    isEnabled: true,
    availability: .noSubscription,
    selection: nil)

  static let previewGone = MusicRowModel.forTimer(
    isRunning: false,
    kind: .work,
    isEnabled: true,
    availability: .ready,
    selection: previewSelection,
    selectionIsGone: true)

  static let previewEmptyLibrary = MusicRowModel.forTimer(
    isRunning: false,
    kind: .work,
    isEnabled: true,
    availability: .ready,
    selection: nil,
    libraryIsEmpty: true)

  static let previewSubscriptionEnded = MusicRowModel.forTimer(
    isRunning: true,
    kind: .work,
    isEnabled: true,
    availability: .noSubscription,
    selection: previewSelection)
}
