import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI
import WidgetKit

/// The running block as it appears on the Lock Screen and around the front
/// camera.
///
/// WHERE THE COUNTDOWN COMES FROM, AND WHY THE APP NEVER SENDS AN UPDATE
/// iOS hands this program the instant the block ends. `Text(timerInterval:)` then
/// counts down to it *by itself*, on the Lock Screen, once a second, with the app
/// asleep and possibly not running at all. Nothing is pushed, nothing is
/// refreshed, and there is no per-second message from the app.
///
/// That is not an optimisation, it is the same idea the whole feature rests on:
/// the end time is the truth and nothing counts towards it. If a future change
/// finds itself wanting to push updates into this card, the design has drifted
/// and the fix is upstream, not here. It is checkable — a search for `.update(`
/// across the app and this extension must find nothing.
///
/// WHAT IT CAN AND CANNOT SEE
/// This is a separate program from the app. It cannot open the database, cannot
/// see the timer, and cannot ask the app a question. Every value it draws arrived
/// with the alarm: the end time from iOS, and the block kind and sprint position
/// from `FocusAlarmMetadata`.
struct BlockLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: AlarmAttributes<FocusAlarmMetadata>.self) { context in
      LockScreenCard(readout: BlockReadout(context.state, context.attributes.metadata))
        // The card's own ground and the tint iOS uses for the controls it draws
        // itself. Both come from the design system's roles, so a Lock Screen card
        // and the app screen cannot end up different colours.
        .activityBackgroundTint(Color(.surfacePrimary))
        .activitySystemActionForegroundColor(Color(.action))
    } dynamicIsland: { context in
      let readout = BlockReadout(context.state, context.attributes.metadata)

      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: Spacing.xs) {
            BlockSymbol(kind: readout.kind)
            BlockKicker(readout: readout)
          }
          .islandInk()
        }
        DynamicIslandExpandedRegion(.trailing) {
          Group {
            if let metadata = readout.metadata {
              SprintCount(completed: metadata.completedInSprint, total: metadata.pomodorosPerSprint)
            }
          }
          .islandInk()
        }
        DynamicIslandExpandedRegion(.center) {
          CountdownNumeral(readout: readout, font: Typography.title)
            .islandInk()
        }
        DynamicIslandExpandedRegion(.bottom) {
          DismissButton(fillsWidth: true)
            .islandInk()
        }
      } compactLeading: {
        BlockSymbol(kind: readout.kind)
          .islandInk()
      } compactTrailing: {
        CountdownNumeral(readout: readout, font: Typography.data)
          // The island's trailing region is narrow, and a two-hour block prints
          // an hours field it was not sized for. Shrinking is correct here and
          // truncating is not, so the numeral is allowed to get smaller and is
          // never allowed to lose a digit.
          .minimumScaleFactor(Self.compactMinimumScale)
          .frame(maxWidth: Self.compactNumeralWidth)
          .islandInk()
      } minimal: {
        BlockSymbol(kind: readout.kind)
          .accessibilityLabel(Text("\(readout.kind.displayName) block running"))
          .islandInk()
      }
    }
  }

  /// How far the compact countdown may shrink before it would overflow.
  private static let compactMinimumScale: CGFloat = 0.7

  /// The widest the compact countdown may be, in points. The island's budget is
  /// not this app's to expand.
  private static let compactNumeralWidth: CGFloat = 56
}

// MARK: - LockScreenCard

/// The card on the Lock Screen.
///
/// ```
/// ┌───────────────────────────────────────────────┐
/// │  FOCUS                               2 OF 4   │
/// │  24:58                              Dismiss   │
/// └───────────────────────────────────────────────┘
/// ```
///
/// WHAT GIVES WAY WHEN THE CARD IS TOO NARROW, IN ORDER
/// Stated here because it varies with the device and the language, and because
/// the answer is not obvious. The sprint count goes first and is dropped rather
/// than clipped. The block name goes second — one line, allowed to shrink, then
/// truncated. The Dismiss button never shrinks, because a control with half a
/// word in it is worse than no control. **The countdown never gives at all**: a
/// countdown missing a digit is wrong information, not small information.
private struct LockScreenCard: View {
  let readout: BlockReadout

  var body: some View {
    HStack(alignment: .lastTextBaseline, spacing: Spacing.sm) {
      VStack(alignment: .leading, spacing: Spacing.xxs) {
        BlockKicker(readout: readout)
        CountdownNumeral(readout: readout, font: Typography.title)
          // The one element on the card that is never allowed to be sacrificed.
          .layoutPriority(1)
      }

      Spacer(minLength: Spacing.sm)

      VStack(alignment: .trailing, spacing: Spacing.xs) {
        if let metadata = readout.metadata {
          SprintCount(completed: metadata.completedInSprint, total: metadata.pomodorosPerSprint)
            // The first thing to be dropped when the card runs out of room.
            .layoutPriority(0)
        }
        DismissButton()
      }
    }
    .padding(Spacing.md)
  }
}

// MARK: - BlockReadout

/// Everything the three presentations draw, worked out once.
///
/// The alarm arrives in two halves — what iOS knows (which stage the alarm is at,
/// and when it fires) and what the app told it (which block, and where in the
/// sprint) — and every view below needs a bit of each. Combining them once here
/// means the Lock Screen and the Dynamic Island cannot draw different answers.
private struct BlockReadout {
  // MARK: Lifecycle

  init(_ state: AlarmPresentationState, _ metadata: FocusAlarmMetadata?) {
    self.metadata = metadata

    switch state.mode {
    case .countdown(let countdown):
      // A closed range needs its start to come before its end. It always does in
      // practice; clamping means a moment of nonsense from iOS produces a frozen
      // countdown rather than a crash on somebody's Lock Screen.
      mode = .running(from: countdown.startDate, to: max(countdown.fireDate, countdown.startDate))

    case .paused(let paused):
      // UNREACHABLE, AND DRAWN ANYWAY.
      // This app never offers a pause control: the alarm is configured with no
      // pause button and no paused presentation, so neither the app nor iOS can
      // put a block into this state. It is drawn as a stopped clock rather than
      // left blank, because an empty branch would be an invisible bug on the one
      // screen nobody is watching if the assumption ever stops holding.
      mode = .frozen(secondsRemaining: paused.totalCountdownDuration - paused.previouslyElapsedDuration)

    case .alert:
      // The block is over and the alarm is sounding.
      mode = .ended

    @unknown default:
      // A stage of an alarm that did not exist when this was written. It is the
      // only branch here with no data behind it, so it is drawn as a finished
      // block: a stopped clock and the word "ended". Anything else would be this
      // program guessing at how much time is left, on a locked phone, from
      // nothing.
      mode = .ended
    }
  }

  // MARK: Internal

  enum Mode {
    case running(from: Date, to: Date)
    case frozen(secondsRemaining: TimeInterval)
    case ended
  }

  /// What the app sent with the alarm. Absent only if iOS hands back an activity
  /// with nothing attached, which it should never do; the views draw a focus
  /// block with no sprint count in that case rather than inventing a number.
  let metadata: FocusAlarmMetadata?

  let mode: Mode

  var kind: BlockKind {
    metadata?.kind ?? .work
  }

  /// Whether the block has finished and the alarm is sounding.
  var isEnded: Bool {
    if case .ended = mode { return true }
    return false
  }

  /// The small word above the countdown.
  var kicker: String {
    switch mode {
    case .running, .frozen: kind.displayName
    case .ended: "Block ended"
    }
  }
}

// MARK: - Pieces

/// The small capitalised word naming the block.
private struct BlockKicker: View {
  let readout: BlockReadout

  var body: some View {
    Text(readout.kicker)
      .font(Typography.kicker)
      .textCase(.uppercase)
      .foregroundStyle(Color(.action))
      .lineLimit(1)
      .minimumScaleFactor(Self.minimumScale)
  }

  private static let minimumScale: CGFloat = 0.7
}

/// The countdown itself.
///
/// While a block runs this is not a number the app calculated — it is a range of
/// time handed to SwiftUI, which draws it counting down on its own. Fixed-width
/// digits are not optional: without them the Dynamic Island changes width on
/// every tick and the whole capsule jitters once a second.
private struct CountdownNumeral: View {
  // MARK: Internal

  let readout: BlockReadout
  let font: Font

  var body: some View {
    numeral
      .font(font)
      .monospacedDigit()
      .foregroundStyle(readout.isEnded ? Color(.textMuted) : Color(.textPrimary))
      .lineLimit(1)
  }

  // MARK: Private

  @ViewBuilder
  private var numeral: some View {
    switch readout.mode {
    case .running(let from, let to):
      Text(timerInterval: from...to, countsDown: true)
    case .frozen(let secondsRemaining):
      Text(Self.clockLabel(seconds: secondsRemaining))
    case .ended:
      Text(Self.clockLabel(seconds: 0))
    }
  }

  /// Formats a number of seconds as `mm:ss`.
  ///
  /// Deliberately a few lines here rather than shared with the app's timer
  /// screen. The two programs are compiled separately and the only thing that may
  /// be shared between them is the data that crosses between them; a formatting
  /// helper is not that, and putting one in the shared folder would invite the
  /// database or the timer to follow it there.
  private static func clockLabel(seconds: TimeInterval) -> String {
    let whole = max(0, Int(seconds.rounded(.up)))
    return String(format: "%02d:%02d", whole / 60, whole % 60)
  }
}

/// The symbol that stands in for the block name where there is no room for words.
///
/// Both kinds of break share one symbol on purpose. The compact region is about
/// twenty points wide; it has room for one fact — *focusing* or *resting* — and a
/// third glyph splitting two kinds of rest would be a distinction nobody could
/// see at that size. The words are on the Lock Screen for anyone who needs them.
private struct BlockSymbol: View {
  let kind: BlockKind

  var body: some View {
    Image(systemName: kind == .work ? "timer" : "cup.and.saucer")
      .font(Typography.data)
      .foregroundStyle(Color(.action))
  }
}

/// The only control on the card.
///
/// Quiet, for the same reason Skip and Stop are quiet inside the app: glancing at
/// a locked phone during a focus block, the right thing to do is put the phone
/// down. A filled button here would advertise stopping as the encouraged action.
///
/// The same command runs whether it is tapped here or on the full-screen alert
/// iOS draws when the alarm goes off — see `DismissBlockIntent`.
private struct DismissButton: View {
  // MARK: Internal

  var fillsWidth = false

  var body: some View {
    Button(intent: DismissBlockIntent()) {
      Text("Dismiss")
        .font(Typography.button)
        .foregroundStyle(Color(.textMuted))
        .lineLimit(1)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: fillsWidth ? CGFloat.infinity : nil, minHeight: Spacing.controlHeight)
        .overlay {
          shape.strokeBorder(Color(.borderStrong), lineWidth: Spacing.borderHairline)
        }
        .contentShape(shape)
    }
    // Without this the system draws its own filled capsule around the label and
    // the outline above ends up inside a button that looks nothing like the rest
    // of the app.
    .buttonStyle(.plain)
    .accessibilityLabel(Text("Dismiss"))
    .accessibilityHint(Text("Ends this block now."))
  }

  // MARK: Private

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
  }
}

// MARK: - Dynamic Island ink

extension View {
  /// Forces the design system's dark colours inside the Dynamic Island.
  ///
  /// THE ONE VISUAL TRAP IN THIS WHOLE FEATURE
  /// The Dynamic Island is black, always, in both appearances. In light
  /// appearance the app's main ink is near-black — which on a black capsule is
  /// invisible. Every region of the island therefore has to resolve the *dark*
  /// half of each colour role regardless of what the phone is set to.
  ///
  /// This does it without naming a single colour. Every role in this design
  /// system is a rule iOS applies when it draws — "dark or light, pick
  /// accordingly" — so telling one small part of the screen that its
  /// surroundings are dark changes which half is chosen. Nothing is hard-coded
  /// and the values still come from the one token table.
  func islandInk() -> some View {
    environment(\.colorScheme, .dark)
  }
}
