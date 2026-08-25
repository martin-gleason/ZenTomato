import SwiftUI

/// The whole of the watch app: what is running, and the two buttons.
///
/// **The countdown here is arithmetic, not a timer.** It is drawn from the
/// `endsAt` the phone sent, so the watch needs no engine and the two devices
/// cannot disagree about when a block ends. If the phone goes quiet the number
/// keeps ticking down — that is correct, because the block really is still
/// running — and when it reaches zero the watch says it has lost touch rather
/// than deciding the block finished. **Only the phone ends a block.**
struct WatchTimerScreen: View {
  let link: WatchLink

  var body: some View {
    VStack(spacing: 6) {
      if let block = link.state.block {
        running(block)
      } else {
        idle
      }
    }
    .padding(.horizontal, 4)
  }

  // MARK: Running

  @ViewBuilder
  private func running(_ block: WatchBlockState.Block) -> some View {
    Text(block.kind.displayName)
      .font(.caption2)
      .foregroundStyle(.secondary)
      .textCase(.uppercase)

    // `.timer` counts down without this view redrawing every second — watchOS
    // updates the label itself, which is the difference between a glanceable
    // number and a battery complaint.
    Text(block.endsAt, style: .timer)
      .font(.system(.title, design: .rounded).monospacedDigit())
      .minimumScaleFactor(0.6)
      .lineLimit(1)

    if let title = block.taskTitle {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .multilineTextAlignment(.center)
    }

    if link.state.acceptsTaps {
      captureButtons
      tally
    }

    footnote
  }

  /// Internal and external, side by side, sized to be hit without looking.
  ///
  /// Shown only during a work block. `SPEC.md` says the buttons are *"tappable
  /// during a pomodoro"*, and a break is not one — so they are hidden rather than
  /// shown-and-refusing, which is the answer F5 settled on the phone.
  private var captureButtons: some View {
    HStack(spacing: 6) {
      captureButton(.internalInterruption, letter: "I", label: "Internal distraction")
      captureButton(.externalInterruption, letter: "E", label: "External distraction")
    }
    .padding(.top, 2)
  }

  /// What this block has caught so far — the receipt for a press.
  ///
  /// **A tap has to be answered on screen, not only in a haptic.** Before this
  /// existed the only confirmation was a buzz, and when the send blocked the main
  /// actor for two seconds there was nothing at all: the owner pressed a button
  /// that appeared dead, pressed it again, and each press became a real row. A
  /// count that moves the instant you touch it is what stops that.
  ///
  /// It is deliberately about **this block** and resets at every boundary, which
  /// is the same rule the phone's own count follows. A running total for the day
  /// would be a score, and `SPEC.md` puts those out of scope.
  @ViewBuilder
  private var tally: some View {
    if link.tapsThisBlock > 0 {
      Text(DistractionTally.summary(of: kindsThisBlock))
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .contentTransition(.numericText())
        .animation(.snappy, value: link.tapsThisBlock)
    }
  }

  /// The kinds caught this block, for `DistractionTally` to phrase.
  ///
  /// The watch keeps counts rather than rows, so this rebuilds the shape the
  /// tally expects. Using the owner's own hand-written summary rather than
  /// spelling the sentence again here is the point: one phrasing, both devices.
  private var kindsThisBlock: [DistractionKind] {
    Array(repeating: .internalInterruption, count: link.internalThisBlock)
      + Array(repeating: .externalInterruption, count: link.externalThisBlock)
  }

  private func captureButton(
    _ kind: DistractionKind, letter: String, label: String) -> some View {
    Button {
      // The haptic is the confirmation. A tap on a wrist that gives nothing back
      // is one somebody repeats, and a repeated tap is a second row.
      WKInterfaceDevice.current().play(.click)
      link.record(kind)
    } label: {
      Text(letter)
        .font(.system(.title3, design: .rounded).weight(.semibold))
        .frame(maxWidth: .infinity, minHeight: 40)
    }
    .buttonStyle(.bordered)
    .accessibilityLabel(label)
  }

  // MARK: Nothing running

  /// **A fact, not a failure.** The watch shows nothing running because nothing
  /// is running; the phone is where a block is started, and saying so is more
  /// useful than an error.
  private var idle: some View {
    VStack(spacing: 4) {
      Text("No block running")
        .font(.headline)
      Text("Start one on your phone.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
  }

  // MARK: The quiet line at the bottom

  /// Says only what is true, and never that a tap was lost.
  ///
  /// A queued tap is already safe: the system has taken responsibility for
  /// delivering it and will do so after this app is killed, after a reboot, and
  /// whenever the phone next comes within reach. So the wording is *waiting*.
  /// **"Failed" would be a lie**, and on the one surface whose whole job is to be
  /// trusted with a moment of attention.
  @ViewBuilder
  private var footnote: some View {
    if link.pendingTaps > 0 {
      Text(link.pendingTaps == 1 ? "1 tap waiting to sync" : "\(link.pendingTaps) taps waiting to sync")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    } else if link.isReachable == false {
      Text("Not connected")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
  }
}
