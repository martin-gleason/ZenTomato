import SwiftUI

/// The timer screen, drawn from finished values.
///
/// It has no idea a timer exists. Everything it shows arrives in a
/// `TimerScreenModel`, and every button it draws calls back out through a
/// closure. That is what lets every state of the screen be looked at in a
/// preview, with no database and nothing counting — see the bottom of this file.
///
/// **The number is the loudest thing in every state.** There is no state in which
/// it is hidden, replaced by an icon, or demoted. Where there is nothing to count
/// it shows a static length or dashes; it never shows an empty box.
struct TimerScreen: View {
  // MARK: Internal

  let model: TimerScreenModel

  var onStart: () -> Void = { }
  var onSkip: () -> Void = { }
  var onStop: () -> Void = { }
  var onOpenSettings: () -> Void = { }

  var body: some View {
    VStack(spacing: Spacing.none) {
      // Two equal spacers, one above the block and one below it. Because they
      // are equal, the word-and-number pair centres itself in the space *above*
      // the buttons, which lands it slightly above the true middle of the
      // screen. That is where an eye expects a single focal element; a
      // mathematically centred number with a button underneath reads as low.
      Spacer(minLength: Spacing.xl)

      focusBlock
        .accessibilitySortPriority(3)

      if let progress = model.progress {
        SprintProgressView(completed: progress.completed, total: progress.total)
          .padding(.top, Spacing.lg)
          .accessibilitySortPriority(2)
      }

      if let completionNote = model.completionNote {
        // No animation, no confetti, no badge. The honest reward for finishing a
        // sprint is the filled rule and being left alone.
        Text(completionNote)
          .font(Typography.label)
          .foregroundStyle(Color(.textMuted))
          .multilineTextAlignment(.center)
          .padding(.top, Spacing.md)
          .accessibilitySortPriority(2)
      }

      if let failureNote = model.failureNote {
        failureRow(failureNote)
          .padding(.top, Spacing.md)
          .accessibilitySortPriority(2)
      }

      Spacer(minLength: Spacing.xl)

      controls
        .accessibilitySortPriority(1)
    }
    .padding(.horizontal, Spacing.md)
    .padding(.bottom, Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    // Only the *background* runs under the status bar and the home indicator.
    // The content stays inside the safe area, so the number never slides under
    // the camera cutout and the buttons never sit under the home bar.
    .background(Color(.surfacePrimary).ignoresSafeArea())
    // An overlay rather than a row in the stack: it sits in space that was
    // already empty and moves the number by zero points. There is no navigation
    // bar on this screen, and adding one to hold a settings button would cost
    // forty-four points of chrome, a background material and a divider across
    // the top of the calmest screen in the app.
    .overlay(alignment: .topTrailing) { settingsButton }
    // SAID OUT LOUD, NOT JUST DRAWN.
    // When an alarm cannot be set, a sighted reader sees an amber line appear
    // in the middle of the screen. A VoiceOver reader's attention is on the
    // button they just pressed and there is nothing to tell them a new line
    // exists — they would have to go exploring a screen they have no reason to
    // explore. Since the whole argument for showing this message at all is that
    // a block ending in silence must not be a surprise an hour later, the
    // message is announced when it appears. Only on the change, so a screen that
    // redraws once a second does not repeat it.
    .onChange(of: model.failureNote) { _, note in
      guard let note else { return }
      AccessibilityNotification.Announcement(note).post()
    }
  }

  // MARK: Private

  /// How far the small word may shrink. Its vocabulary now reaches "Long break",
  /// which cannot hold one line at the largest text sizes, so it is allowed two.
  private static let kickerMinimumScale: CGFloat = 0.7

  /// How far the large number may shrink.
  ///
  /// At the very largest accessibility text sizes it would otherwise ask for more
  /// width than the phone has. Shrinking is correct and truncating is not: a
  /// countdown missing a digit is wrong information, whereas a slightly smaller
  /// countdown is still — even after shrinking — by far the biggest thing on the
  /// screen.
  private static let numeralMinimumScale: CGFloat = 0.5

  /// The size of the countdown numeral, after the reader's text-size setting has
  /// been applied to it.
  ///
  /// `relativeTo: .largeTitle` picks *which* growth curve — the one for very
  /// large text, which flattens off at the top accessibility sizes instead of
  /// running away. That flattening is the reason a number starting at 96 points
  /// still reads correctly at the largest size.
  @ScaledMetric(relativeTo: .largeTitle) private var numeralSize = Typography.numeralBaseSize

  /// The word and the number, treated as one thing.
  private var focusBlock: some View {
    VStack(spacing: Spacing.sm) {
      Text(model.kicker)
        .font(Typography.kicker)
        .textCase(.uppercase)
        // The one piece of colour on the entire screen. Everything else is a
        // neutral grey, and scarcity is what makes it mean something — which is
        // also why a break is not given a colour of its own. The word here
        // already names the block, and `04:31` cannot be mistaken for `24:58`
        // from across the room, which is the range at which the number is the
        // only readable element anyway.
        .foregroundStyle(Color(.action))
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(Self.kickerMinimumScale)

      Text(model.numeral)
        .font(Typography.timerNumeral(size: numeralSize))
        // Pulls the characters fractionally closer together. At this size the
        // default spacing reads as gaps between words rather than between
        // digits. The amount is a fraction of the size, so it holds everywhere.
        .tracking(numeralSize * Typography.numeralTrackingRatio)
        .foregroundStyle(model.numeralIsAReading ? Color(.textPrimary) : Color(.textSubtle))
        .lineLimit(1)
        .minimumScaleFactor(Self.numeralMinimumScale)
    }
    // VoiceOver reads these two as one sentence rather than two fragments. Left
    // alone it would read the number as "twenty-four colon fifty-eight",
    // pronouncing the colon out loud.
    //
    // The printed number changes every second; the spoken one deliberately does
    // not. It is rounded to whole minutes while a block runs — see
    // `TimerView.spokenRemaining` — because a value attached to an element the
    // reader has focused is a value the system may read out again each time it
    // changes, and a sentence spoken once a second for twenty-five minutes would
    // make this screen unusable. Nothing here posts an announcement of its own.
    //
    // Whether iOS re-reads a changed value at all is a runtime behaviour rather
    // than something this file can settle, so the number of opportunities is
    // kept small instead of the question being assumed away. It is on the list
    // to watch with VoiceOver running on the phone.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(model.blockName))
    .accessibilityValue(Text(model.spokenNumeral))
  }

  /// One or two buttons, depending on whether a block is running.
  @ViewBuilder
  private var controls: some View {
    switch model.controls {
    case .start(let isEnabled, let spokenLabel):
      Button("Start") { onStart() }
        .buttonStyle(StartButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(Text(spokenLabel))

    case .running:
      // Skip leads and Stop follows, so that reading order matches escalation:
      // end this block, then end the session. There is no confirmation on
      // either, and that is a decision — the cost of a mis-tapped Stop is one
      // abandoned block and one tap to restart, while the cost of a confirmation
      // sheet is a modal interruption during every single focus block. Two
      // 44-point controls separated by a gap is the mitigation.
      HStack(spacing: Spacing.sm) {
        Button("Skip") { onSkip() }
          .buttonStyle(SecondaryButtonStyle())
          .accessibilityLabel(Text("Skip this block"))
          .accessibilityHint(Text("Ends the block now. It won't be counted."))

        Button("Stop") { onStop() }
          .buttonStyle(SecondaryButtonStyle(emphasis: .quiet))
          .accessibilityLabel(Text("Stop the timer"))
          .accessibilityHint(Text("Ends the block and the sprint."))
      }
    }
  }

  /// The gear.
  ///
  /// Muted grey rather than the action colour: the one piece of colour on this
  /// screen is the word above the number, and a green gear would be a second
  /// claim on it. Visible in every state, including while a block runs — hiding
  /// it then would imply settings cannot be changed mid-block, which is false.
  /// They can; they take effect at the next boundary.
  private var settingsButton: some View {
    Button { onOpenSettings() } label: {
      Image(systemName: "gearshape")
        // A named text style, so the glyph grows with the reader's text size. An
        // icon at a fixed point size is the classic failure at the accessibility
        // sizes.
        .font(Typography.label)
        .foregroundStyle(Color(.textMuted))
        // A 44-point hit area around a much smaller glyph.
        .frame(width: Spacing.controlHeight, height: Spacing.controlHeight)
        .contentShape(Rectangle())
    }
    .padding(.trailing, Spacing.md)
    .padding(.top, Spacing.xs)
    .accessibilityLabel(Text("Settings"))
    // Read last. The timer is the point of the screen; left alone VoiceOver
    // would announce the gear first, because it is the topmost element.
    .accessibilitySortPriority(0)
  }

  /// The one place amber appears on this screen, and only when something has
  /// actually gone wrong.
  ///
  /// The design system's discipline is that amber marks exactly one thing per
  /// screen. On the timer screen nothing is amber at all, which is why this row
  /// may spend it: when it is on screen it is the only warning there is.
  private func failureRow(_ message: String) -> some View {
    Label {
      Text(message)
        .font(Typography.label)
        .foregroundStyle(Color(.warningText))
        .multilineTextAlignment(.leading)
    } icon: {
      Image(systemName: "exclamationmark.triangle")
        .foregroundStyle(Color(.warningText))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Previews

#Preview("Idle, light") {
  TimerScreen(model: .previewIdle)
    .preferredColorScheme(.light)
}

/// Together with the light preview above, this is the check that the colour
/// system actually responds to the phone's setting: if a colour had been written
/// as a fixed value by mistake, these two would look identical.
#Preview("Idle, dark") {
  TimerScreen(model: .previewIdle)
    .preferredColorScheme(.dark)
}

#Preview("Focus running") {
  TimerScreen(model: .previewWorkRunning)
    .preferredColorScheme(.light)
}

#Preview("Short break running") {
  TimerScreen(model: .previewShortBreakRunning)
    .preferredColorScheme(.light)
}

#Preview("Sprint complete") {
  TimerScreen(model: .previewSprintComplete)
    .preferredColorScheme(.light)
}

#Preview("No settings row") {
  TimerScreen(model: .noSettingsRow(numeral: "--:--"))
    .preferredColorScheme(.light)
}

#Preview("Alarm could not be set") {
  TimerScreen(model: .previewAlarmFailed)
    .preferredColorScheme(.light)
}

/// The largest text size iOS offers, which is the one that breaks layouts.
/// Nothing here may be cut off or overlap at this size.
#Preview("Focus running, largest text") {
  TimerScreen(model: .previewWorkRunning)
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}

/// The widest sprint the settings allow, at the size where the rule becomes
/// words. This is the case that swap exists for.
#Preview("Twelve pomodoros, largest text") {
  TimerScreen(model: .previewLongestSprint)
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}

/// Preview fixtures, never part of what ships.
private extension TimerScreenModel {
  /// First launch, and after Stop.
  static let previewIdle = TimerScreenModel(
    blockName: "Focus block",
    kicker: "Focus",
    numeral: "25:00",
    spokenNumeral: "25 minutes",
    progress: Progress(completed: 0, total: 4),
    controls: .start(isEnabled: true, spokenLabel: "Start focus block, 25 minutes"))

  static let previewWorkRunning = TimerScreenModel(
    blockName: "Focus block",
    kicker: "Focus",
    numeral: "24:58",
    spokenNumeral: "24 minutes remaining",
    progress: Progress(completed: 2, total: 4),
    controls: .running)

  static let previewShortBreakRunning = TimerScreenModel(
    blockName: "Short break",
    kicker: "Short break",
    numeral: "04:31",
    spokenNumeral: "4 minutes remaining",
    progress: Progress(completed: 3, total: 4),
    controls: .running)

  static let previewSprintComplete = TimerScreenModel(
    blockName: "Focus block",
    kicker: "Focus",
    numeral: "25:00",
    spokenNumeral: "25 minutes",
    progress: Progress(completed: 4, total: 4),
    completionNote: "Sprint complete — 4 pomodoros done.",
    controls: .start(isEnabled: true, spokenLabel: "Start focus block, 25 minutes"))

  static let previewAlarmFailed = TimerScreenModel(
    blockName: "Focus block",
    kicker: "Focus",
    numeral: "24:58",
    spokenNumeral: "24 minutes remaining",
    progress: Progress(completed: 2, total: 4),
    failureNote: TimerEngineFailure.alarmSchedulingFailed.message,
    controls: .running)

  static let previewLongestSprint = TimerScreenModel(
    blockName: "Focus block",
    kicker: "Focus",
    numeral: "24:58",
    spokenNumeral: "24 minutes remaining",
    progress: Progress(completed: 11, total: 12),
    controls: .running)
}
