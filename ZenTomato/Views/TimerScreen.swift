import SwiftUI

// swiftlint:disable file_length
//
// THE ONLY LINT RULE THIS FILE TURNS OFF, AND WHY.
// `file_length` counts documentation and previews, and this file is over half
// both: roughly two hundred lines of prose explaining decisions to a reviewer
// who reads code but does not write Swift, and a preview for every state the
// screen can be in — which is the whole reason the screen was split from its
// wiring in the first place. Splitting it further would separate a state from
// the picture of that state, and would make the private preview fixtures
// visible to the rest of the app to do it: real protection traded away for a
// line count. The same exemption, for the same reason, is already taken by
// `TimerEngine.swift`. Every other rule stays on, including all of the ones
// that catch actual defects.

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
  var onStop: () -> Void = { }
  var onOpenSettings: () -> Void = { }

  /// Silence the ringing alarm and move the sprint on. `D26`.
  ///
  /// **Not `onSilenceBlock`**, which is thirty lines below and silences the
  /// *music* for the rest of a block. Two callbacks with the word silence in them
  /// is one too many for a screen where one of them stops a bell nobody can
  /// otherwise stop, so this one says what it silences.
  var onSilenceAlarm: () -> Void = { }

  /// The history control was tapped. Reachable in every state, including while a
  /// block runs — see `historyButton`.
  var onOpenHistory: () -> Void = { }

  /// The attachment line was tapped. Only reachable while idle or on a break —
  /// see `TimerScreenModel.Attachment`.
  var onOpenPlan: () -> Void = { }

  /// A distraction from your own head was tapped. Called synchronously, and what
  /// is on the other end of it is synchronous all the way to the disk — see
  /// `DistractionButtons`.
  var onInternalDistraction: () -> Void = { }

  /// A distraction from outside was tapped.
  var onExternalDistraction: () -> Void = { }

  /// The music switch was flipped, to the position it carries. Only reachable
  /// while the timer is idle — see `MusicRowModel.isTogglable`.
  var onToggleMusic: @Sendable (Bool) -> Void = { _ in }

  /// The music line was tapped. Only reachable while the timer is idle.
  var onOpenMusic: () -> Void = { }

  /// Skip forward was pressed. **The only transport control in this app**, and
  /// only reachable while a focus block is actually playing something.
  var onSkipTrack: () -> Void = { }

  /// Silence the music for the rest of this block (D20).
  var onSilenceBlock: () -> Void = { }

  /// Start the music again for this block.
  var onResumeBlock: () -> Void = { }

  var body: some View {
    VStack(spacing: Spacing.none) {
      centreColumn

      silenceControl

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
    // The mirror image of the gear, in the one corner of this screen that is
    // empty in every state. Same argument as the line above: it costs zero
    // layout points, so the 96-point numeral does not move by so much as a
    // point, and the ratified rule that the countdown moves exactly once in a
    // cycle is untouched.
    .overlay(alignment: .topLeading) { historyButton }
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

  /// The text size from which the middle of the screen starts scrolling.
  ///
  /// A 96-point numeral on its own growth curve, plus a sprint rule, plus a
  /// capture pair that has by then stacked into two full-width buttons, does not
  /// fit on a phone at the largest accessibility sizes. There is no
  /// `.dynamicTypeSize(...)` cap anywhere on this screen — that rule is ratified
  /// and it stands — so the honest answer is that the column becomes scrollable
  /// and nothing is cut off. Stop stays pinned outside it, because the one exit
  /// from a running block must never be somewhere you have to go looking for.
  private static let scrollingThreshold: DynamicTypeSize = .accessibility1

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

  /// The reader's text-size setting, which decides whether the middle of the
  /// screen scrolls.
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  /// Everything above the Stop button, scrollable at the accessibility sizes and
  /// not before.
  ///
  /// `.scrollBounceBehavior(.basedOnSize)` means it does not rubber-band when
  /// the content already fits, so at the sizes where scrolling is unnecessary
  /// the screen behaves exactly as if there were no scroll view at all.
  @ViewBuilder
  private var centreColumn: some View {
    if dynamicTypeSize >= Self.scrollingThreshold {
      ScrollView {
        column
      }
      .scrollBounceBehavior(.basedOnSize)
    } else {
      column
    }
  }

  /// The word, the number, the sprint rule, any note, and the capture pair.
  ///
  /// The two spacers were once equal, and now the lower one has a larger floor.
  /// They are still equally *flexible*, so on a phone with room to spare the
  /// word-and-number pair still centres itself in the space above the Stop
  /// button — slightly above the true middle of the screen, which is where an
  /// eye expects a single focal element. What changed is the minimum: there are
  /// never fewer than forty-eight points of bare page between the bottom of a
  /// capture button and the top of Stop.
  ///
  /// That gap is a safety margin rather than a rhythm choice. A mis-tap between
  /// Internal and External costs one wrong row in a log that is read in
  /// aggregate, which this feature already accepts. A mis-tap onto Stop opens
  /// the exit sheet in the middle of a focus block. The two failure modes are
  /// not the same size, so the two gaps are not the same size: twelve points
  /// between the pair, forty-eight at minimum down to Stop.
  private var column: some View {
    VStack(spacing: Spacing.none) {
      Spacer(minLength: Spacing.xl)

      // OUTSIDE `focusBlock`, DELIBERATELY. That view collapses its children
      // into one element for VoiceOver, which would swallow a control — and
      // this line is a control in two of its states.
      if let attachment = model.attachment {
        attachmentLine(attachment)
          .padding(.bottom, Spacing.sm)
          // After the block name and the countdown, before the capture pair.
          .accessibilitySortPriority(2.75)
      }

      focusBlock
        .accessibilitySortPriority(3)

      if let progress = model.progress {
        SprintProgressView(completed: progress.completed, total: progress.total)
          .padding(.top, Spacing.lg)
          .accessibilitySortPriority(2)
      }

      // ONE FULL-WIDTH ROW, AND ITS HEIGHT DOES NOT CHANGE FOR A WHOLE CYCLE.
      //
      // It sits here rather than anywhere else for three reasons. Not above the
      // numeral: the top band already carries the attachment line, and a second
      // muted line there pushes the 96-point number down, which is the loudest
      // thing in every state. Not below the capture pair: the forty-eight points
      // between a capture button and Stop is a priced safety margin and is not
      // spendable. Above the notes, so that a failure or completion note
      // appearing mid-block pushes the capture pair — which already happens
      // today — and never the music row.
      //
      // The cost is about seventy-six points at the default text size (sixteen
      // above, forty-four of row, sixteen below), absorbed by the
      // column's two equally flexible spacers, so the word-and-number pair sits
      // a little higher than it did before F4. **That is a static difference
      // against the screen F3 shipped, not motion during a cycle**: the ratified
      // rule governs movement within a cycle, and this row never moves within
      // one. See `MusicRow` for how the height is held.
      if let music = model.music {
        MusicRow(
          model: music,
          onToggleMusic: onToggleMusic,
          onOpenMusic: onOpenMusic,
          onSkipTrack: onSkipTrack,
          onSilenceBlock: onSilenceBlock,
          onResumeBlock: onResumeBlock)
          .padding(.top, Spacing.md)
          // SIXTEEN POINTS BELOW IT AS WELL, AND THE SIXTEEN IS PRICED.
          //
          // The capture pair already carries thirty-two points above itself, so
          // without this the skip button's 44-point target sits thirty-two
          // points above the External capture button, directly in line with it.
          // A downward mis-tap from a transport control would then write a
          // distraction that never happened, into the one dataset this app
          // exists to produce. This screen already prices that kind of
          // adjacency: the gap above Stop is forty-eight, on the argument that
          // the two failure modes are not the same size, so the two gaps are not
          // the same size. Sixteen here brings this one to the same forty-eight.
          //
          // Constant across the whole cycle, and in particular not conditioned
          // on whether the skip button is drawn — which is what keeps D19.3
          // intact.
          .padding(.bottom, Spacing.md)
          // After the sprint rule and before Stop. A fraction is legal here and
          // avoids renumbering five elements that were reviewed already.
          .accessibilitySortPriority(1.5)
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

      capturePair

      Spacer(minLength: Spacing.xxl)
    }
    .frame(maxWidth: .infinity)
  }

  /// The two capture buttons, the space they leave behind during a break, or
  /// nothing at all.
  ///
  /// THREE STATES, AND THE MIDDLE ONE IS THE INTERESTING ONE
  ///
  /// | When | What is here |
  /// |---|---|
  /// | a focus block is running | the pair |
  /// | a break is running | the same height, empty and unreachable |
  /// | nothing is running | no slot at all |
  ///
  /// **The countdown moves exactly once in a whole cycle, and that is why the
  /// break keeps the space.** Adding the pair lifts the centred number by about
  /// half its height; if the slot were dropped at the work-to-break boundary the
  /// number would jump back down at the very moment a person glances over to see
  /// how long their break is. Reserving it means the only thing that changes
  /// across that boundary is the word above the number — which is the thing they
  /// should be reading. The one shift left in the cycle happens at Start, at the
  /// same instant the Start button becomes Stop, where a shift is attributable
  /// rather than mysterious.
  ///
  /// **Reserved means genuinely unreachable**, not merely invisible. Hidden,
  /// unhittable and removed from the accessibility tree, so a VoiceOver rotor,
  /// Full Keyboard Access and Voice Control all agree with the eye that there is
  /// nothing there. A distraction logged during a break would be a false row in
  /// the one dataset this app exists to produce.
  ///
  /// Two alternatives were rejected for the break: the just-ended block's tally,
  /// which is a reading-back surface that a later feature owns; and a line of
  /// break copy, which spends attention on the screen a break exists to get you
  /// off.
  @ViewBuilder
  private var capturePair: some View {
    if let capture = model.capture {
      DistractionButtons(
        internalCount: capture.internalCount,
        externalCount: capture.externalCount,
        onInternal: onInternalDistraction,
        onExternal: onExternalDistraction)
        // The padding lives inside each branch rather than on the pair as a
        // whole, so that the idle screen — which draws neither branch — does not
        // carry thirty-two points of space above a control that is not there.
        .padding(.top, Spacing.xl)
        // Read after the block name and the countdown, and before the sprint
        // rule, the Stop button and the gear. For a reader who is not looking at
        // the screen the two things worth reaching in a swipe or two are "how
        // long left" and "log this"; the sprint rule between them would cost a
        // swipe at exactly the wrong moment. A fraction is legal here and avoids
        // renumbering four elements that were reviewed already.
        .accessibilitySortPriority(2.5)
        // The Taptic Engine idles down between blocks, and the first thump
        // after that pays the cost of waking it — felt as the buzz arriving
        // after the finger has already lifted, on the one signal a person who
        // is not looking at the screen has to trust. Warming it when the
        // buttons appear starts no work and costs nothing if no tap follows.
        .onAppear { CaptureHaptic.warmUp() }
    } else if model.isRunning {
      DistractionButtons(internalCount: 0, externalCount: 0)
        .padding(.top, Spacing.xl)
        .hidden()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
  }

  /// What this pomodoro is attached to, in one line.
  ///
  /// **`textMuted`, never `action`.** The one piece of colour on this screen is
  /// the word above the number, and a green task title would be a second claim
  /// on it. The gone state is not amber either: this screen's amber belongs to
  /// the failure row, and amber marks exactly one thing per screen.
  ///
  /// **A chevron, but only on the states that are actually tappable.**
  ///
  /// This line carried no affordance at all, to protect the ratified rule that
  /// the countdown moves exactly once in a whole cycle — an indicator appearing
  /// at a block boundary would be that movement. The reasoning had a hole in it:
  /// `isTappable` is only ever true while the timer is IDLE, so a chevron drawn
  /// on tappable lines can never appear or disappear during a running block. The
  /// rule was suppressing an affordance in states it did not govern.
  ///
  /// The cost of that was total. Every Todoist surface — the picker, the plan,
  /// completing a task — is reached through this line and nothing else, and on a
  /// real phone it read as a caption, so none of them were ever found.
  ///
  /// The chevron is `textMuted`, not `action`: the one piece of colour on this
  /// screen is the word above the number, and a sage chevron would be a second
  /// claim on it. A chevron reads as "there is more here" without needing colour.
  ///
  /// The whole line is the target, at the 44-point floor.
  @ViewBuilder
  private func attachmentLine(_ attachment: TimerScreenModel.Attachment) -> some View {
    if attachment.isTappable {
      Button { onOpenPlan() } label: {
        HStack(spacing: Spacing.xs) {
          attachmentText(attachment.line)
          Image(systemName: "chevron.right")
            .font(Typography.label)
            .foregroundStyle(Color(.textMuted))
            .accessibilityHidden(true)
        }
      }
      .buttonStyle(.plain)
      .accessibilityHint(Text("Opens your Todoist plan."))
    } else {
      attachmentText(attachment.line)
    }
  }

  private func attachmentText(_ line: String) -> some View {
    Text(line)
      .font(Typography.label)
      .foregroundStyle(Color(.textMuted))
      .multilineTextAlignment(.center)
      .lineLimit(2)
      // WRAPS, NEVER SHRINKS. A truncated task title is a wrong record on
      // screen, in the one dataset this app exists to produce.
      .minimumScaleFactor(1.0)
      .frame(maxWidth: .infinity, minHeight: Spacing.controlHeight)
      .contentShape(Rectangle())
  }

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

  /// The one control that ends a ringing alarm. `D26`.
  ///
  /// **THE OWNER COULD NOT STOP A NOISE THIS APP STARTED.** *"This wasn't a stop
  /// the timer bug. stop the alarm bug."* Until now the only control that ended a
  /// ringing alarm belonged to iOS, so an alert that was missed — the app already
  /// open, the phone in a pocket — left the sound with no off switch here.
  ///
  /// WHY IT IS NOT IN THE START/STOP POSITION, WHICH IS THE DECISION
  /// That position changes identity on `isRunning`, and `isRunning` goes false at
  /// the exact instant an alarm begins. A control appearing *there* at *that*
  /// moment lands under a finger already travelling toward something else — which
  /// is how the report arrived in the first place. So it gets its own place above
  /// the primary control, and the primary control is disabled while it is
  /// showing: the thing that moves is inert, so a mis-tap does nothing rather
  /// than doing the wrong thing.
  ///
  /// Filled and loud, unlike everything else on this screen. The one piece of
  /// colour here is normally the word above the number, and that restraint is
  /// deliberate — but a button somebody is hunting for while a bell rings is the
  /// one case where being quiet is the wrong answer.
  @ViewBuilder
  private var silenceControl: some View {
    if model.alarmIsRinging {
      Button("Silence") { onSilenceAlarm() }
        .buttonStyle(StartButtonStyle())
        .padding(.bottom, Spacing.md)
        .accessibilityLabel(Text("Silence the alarm"))
        .accessibilityHint(Text("Stops the sound and moves on to the next block."))
        .accessibilitySortPriority(2)
    }
  }

  /// One or two buttons, depending on whether a block is running.
  @ViewBuilder
  private var controls: some View {
    switch model.controls {
    case .start(let isEnabled, let spokenLabel):
      Button("Start") { onStart() }
        .buttonStyle(StartButtonStyle())
        // Inert while the alarm rings — see `silenceControl`. The Silence button
        // above shifts this one downward, and a control that moves under a
        // finger must not be one that does something.
        .disabled(!isEnabled || model.alarmIsRinging)
        .accessibilityLabel(Text(spokenLabel))

    case .running:
      // ONE CONTROL, AND IT IS QUIET.
      //
      // A pomodoro is indivisible: it finishes or it is void. There was a Skip
      // button beside this one and it is gone — an exit that costs a single tap
      // is not an exit from a focus block, it is a way of not having one.
      //
      // Stop remains because an exit has to exist. A mistyped two-hour focus
      // length would otherwise be inescapable, and the only remaining way out
      // would be force-quitting the app — which the engine reconciles from the
      // stored end time and records as a *finished* pomodoro. That is the same
      // false count this app removed from the Lock Screen, arriving by another
      // door. So the exit exists, and instead of being cheap it is priced: it
      // asks why, and will not proceed until it is told.
      //
      // Quiet emphasis, deliberately. The one piece of colour on this screen is
      // the word above the number. A filled Stop button would advertise stopping
      // as an encouraged thing to do, sixty times an hour, for the whole block.
      Button("Stop") { onStop() }
        .buttonStyle(SecondaryButtonStyle(emphasis: .quiet))
        .disabled(model.alarmIsRinging)
        .accessibilityLabel(Text("Stop the timer"))
        .accessibilityHint(Text("Asks why, then ends the block and the sprint."))
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

  /// The way to yesterday.
  ///
  /// Drawn identically to the gear and in the same muted ink, for the same
  /// reason: the one piece of colour on this screen is the word above the
  /// number. Read as a pair, the two top corners say "settings" and "record" —
  /// one affordance each, which is a smaller load than one corner with a menu
  /// behind it.
  ///
  /// **Present and enabled in every state, including mid-block and with nothing
  /// recorded at all.** D19: when a rule about movement meets an affordance
  /// somebody needs, reserve the space. A history button that appeared only once
  /// there was history would be missing on exactly the day somebody wanted to
  /// check whether anything had been recorded — and F3 lost a whole feature to an
  /// affordance suppressed to protect something else.
  ///
  /// **No badge, ever.** No count, no dot, no "3 today". A number on a chrome
  /// glyph is the first step of a scoreboard, and it would make the button change
  /// size between states.
  ///
  /// A list glyph rather than a chart glyph: `chart.bar` promises a chart, and
  /// chart pressure is this feature's whole risk. `clock.arrow.circlepath` was
  /// rejected outright — on a *timer* screen a circular arrow round a clock reads
  /// as "restart", which is the most expensive misread available.
  private var historyButton: some View {
    Button { onOpenHistory() } label: {
      Image(systemName: "list.bullet.rectangle")
        .font(Typography.label)
        .foregroundStyle(Color(.textMuted))
        .frame(width: Spacing.controlHeight, height: Spacing.controlHeight)
        .contentShape(Rectangle())
    }
    .padding(.leading, Spacing.md)
    .padding(.top, Spacing.xs)
    .accessibilityLabel(Text("Pomodoro history"))
    .accessibilityHint(Text("How many pomodoros you've done, and the export."))
    // After Stop, before the gear. The timer is still the point of the screen.
    .accessibilitySortPriority(0.5)
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

/// The receipt in place: a word, and under it how many times it has been
/// pressed during this block.
#Preview("Focus running, 2 internal 1 external") {
  TimerScreen(model: .previewWorkWithTaps)
    .preferredColorScheme(.light)
}

#Preview("Focus running, dark") {
  TimerScreen(model: .previewWorkWithTaps)
    .preferredColorScheme(.dark)
}

/// A tap that was refused. Nothing buzzed, no count moved, and the amber row is
/// the only thing that says so.
#Preview("A tap that wasn't saved") {
  TimerScreen(model: .previewCaptureFailed)
    .preferredColorScheme(.light)
}

/// The reserved slot. The capture pair is absent, unreachable, and still
/// occupying its exact height — put this beside "Focus running" and the
/// countdown must be in the same place in both.
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
  TimerScreen(model: .previewWorkWithTaps)
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}

/// The same size with nothing running: no capture slot at all, and therefore
/// nothing to scroll.
#Preview("Idle, largest text") {
  TimerScreen(model: .previewIdle)
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

/// A task attached, and the line above the block name saying so. Compare with
/// "Focus running": the countdown must be in the same place in both, because the
/// line is present in every signed-in state.
#Preview("Focus running, task attached") {
  TimerScreen(model: .previewWithTask)
    .preferredColorScheme(.light)
}

/// On a break, with the next item up. The line is a control here and inert
/// during a focus block.
#Preview("Break, next item") {
  TimerScreen(model: .previewBreakWithNextItem)
    .preferredColorScheme(.light)
}

/// Connected, with nothing planned. The line stays, so the numeral does not
/// move as a plan empties.
#Preview("Idle, nothing planned") {
  TimerScreen(model: .previewNothingAttached)
    .preferredColorScheme(.light)
}

/// The task left Todoist while the block was running. Not amber: the world
/// moving on is not an error.
#Preview("Attached task is gone") {
  TimerScreen(model: .previewAttachedTaskGone)
    .preferredColorScheme(.light)
}

#Preview("Focus running, task attached, largest text") {
  TimerScreen(model: .previewWithTask)
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}

// MARK: The D19.3 pair
//
// THESE TWO ARE THE REGRESSION TEST FOR THE RESERVED HEIGHT, AND THEY ONLY WORK
// SIDE BY SIDE. Open "Focus running, music playing" and "Short break, music
// paused" together: the countdown must be at exactly the same height in both.
// The only difference between them is the word above the number and a skip
// button that has left its slot without taking the slot with it. If the number
// moves between these two, the music row's height is not being held and D19.3 is
// broken — see `MusicRow`.

#Preview("Focus running, music playing") {
  TimerScreen(model: .previewMusicPlaying)
    .preferredColorScheme(.light)
}

#Preview("Short break, music paused") {
  TimerScreen(model: .previewMusicPausedForBreak)
    .preferredColorScheme(.light)
}

#Preview("Focus running, music playing, dark") {
  TimerScreen(model: .previewMusicPlaying)
    .preferredColorScheme(.dark)
}

/// Music switched off, with a block running. The row stays, dimmed, and says so.
#Preview("Focus running, music off") {
  TimerScreen(model: .previewMusicOffWhileRunning)
    .preferredColorScheme(.light)
}

/// Muted, never amber: the block is running, the alarm is set, the capture
/// buttons work. Nothing is broken; it is quiet.
#Preview("Focus running, music didn't start") {
  TimerScreen(model: .previewMusicDidNotStart)
    .preferredColorScheme(.light)
}

/// Idle with no Apple Music subscription. One plain line, no warning triangle,
/// and a timer that is exactly as usable as it was before.
#Preview("Idle, no subscription") {
  TimerScreen(model: .previewNoSubscription)
    .preferredColorScheme(.light)
}

/// The same pair at the largest text size iOS offers, where the music row stacks
/// and the whole column scrolls. Nothing may be cut off, and the two must still
/// agree with each other.
#Preview("Focus running, music playing, largest text") {
  TimerScreen(model: .previewMusicPlaying)
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}

#Preview("Short break, music paused, largest text") {
  TimerScreen(model: .previewMusicPausedForBreak)
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
    music: .previewIdleOff,
    controls: .start(isEnabled: true, spokenLabel: "Start focus block, 25 minutes"))

  static let previewWorkRunning = TimerScreenModel(
    blockName: "Focus block",
    kicker: "Focus",
    numeral: "24:58",
    spokenNumeral: "24 minutes remaining",
    progress: Progress(completed: 2, total: 4),
    capture: Capture(internalCount: 0, externalCount: 0),
    music: .previewPlaying,
    controls: .running)

  /// The state the receipt exists for: a block that has already been
  /// interrupted, with a count under each word.
  static let previewWorkWithTaps = TimerScreenModel(
    blockName: "Focus block",
    kicker: "Focus",
    numeral: "18:04",
    spokenNumeral: "18 minutes remaining",
    progress: Progress(completed: 2, total: 4),
    capture: Capture(internalCount: 2, externalCount: 1),
    music: .previewPlaying,
    controls: .running)

  /// A tap that could not be written. No count, no receipt, and the same amber
  /// row the alarm failure uses — which is also announced to VoiceOver.
  static let previewCaptureFailed = TimerScreenModel(
    blockName: "Focus block",
    kicker: "Focus",
    numeral: "18:04",
    spokenNumeral: "18 minutes remaining",
    progress: Progress(completed: 2, total: 4),
    failureNote: "That tap wasn't saved. Tap again.",
    capture: Capture(internalCount: 1, externalCount: 0),
    music: .previewPlaying,
    controls: .running)

  static let previewShortBreakRunning = TimerScreenModel(
    blockName: "Short break",
    kicker: "Short break",
    numeral: "04:31",
    spokenNumeral: "4 minutes remaining",
    progress: Progress(completed: 3, total: 4),
    music: .previewBreakPaused,
    controls: .running)

  static let previewSprintComplete = TimerScreenModel(
    blockName: "Focus block",
    kicker: "Focus",
    numeral: "25:00",
    spokenNumeral: "25 minutes",
    progress: Progress(completed: 4, total: 4),
    completionNote: "Sprint complete — 4 pomodoros done.",
    music: .previewIdleOn,
    controls: .start(isEnabled: true, spokenLabel: "Start focus block, 25 minutes"))

  static let previewAlarmFailed = TimerScreenModel(
    blockName: "Focus block",
    kicker: "Focus",
    numeral: "24:58",
    spokenNumeral: "24 minutes remaining",
    progress: Progress(completed: 2, total: 4),
    failureNote: TimerEngineFailure.alarmSchedulingFailed.message,
    capture: Capture(internalCount: 0, externalCount: 0),
    music: .previewPlaying,
    controls: .running)

  static let previewLongestSprint = TimerScreenModel(
    blockName: "Focus block",
    kicker: "Focus",
    numeral: "24:58",
    spokenNumeral: "24 minutes remaining",
    progress: Progress(completed: 11, total: 12),
    capture: Capture(internalCount: 3, externalCount: 2),
    music: .previewPlaying,
    controls: .running)

  /// A focus block with a task attached.
  static let previewWithTask = TimerScreenModel(
    blockName: "Focus block",
    kicker: "Focus",
    numeral: "18:04",
    spokenNumeral: "18 minutes remaining",
    progress: Progress(completed: 2, total: 4),
    capture: Capture(internalCount: 0, externalCount: 0),
    attachment: Attachment.forTimer(
      hasToken: true,
      isFocusRunning: true,
      runningBlock: .previewDraft,
      nextItem: .previewReplyItem),
    music: .previewPlaying,
    controls: .running)

  static let previewBreakWithNextItem = TimerScreenModel(
    blockName: "Short break",
    kicker: "Short break",
    numeral: "04:31",
    spokenNumeral: "4 minutes remaining",
    progress: Progress(completed: 3, total: 4),
    attachment: Attachment.forTimer(
      hasToken: true,
      isFocusRunning: false,
      runningBlock: nil,
      nextItem: .previewReplyItem),
    music: .previewBreakPaused,
    controls: .running)

  static let previewNothingAttached = TimerScreenModel(
    blockName: "Focus block",
    kicker: "Focus",
    numeral: "25:00",
    spokenNumeral: "25 minutes",
    progress: Progress(completed: 0, total: 4),
    attachment: Attachment.forTimer(
      hasToken: true,
      isFocusRunning: false,
      runningBlock: nil,
      nextItem: nil),
    music: .previewIdleNothingChosen,
    controls: .start(isEnabled: true, spokenLabel: "Start focus block, 25 minutes"))

  /// A focus block with sound coming out. The skip button is drawn.
  static let previewMusicPlaying = TimerScreenModel(
    blockName: "Focus block",
    kicker: "Focus",
    numeral: "18:04",
    spokenNumeral: "18 minutes remaining",
    progress: Progress(completed: 2, total: 4),
    capture: Capture(internalCount: 0, externalCount: 0),
    music: .previewPlaying,
    controls: .running)

  /// The same screen one second into the break. The skip button has gone and its
  /// space has not.
  static let previewMusicPausedForBreak = TimerScreenModel(
    blockName: "Short break",
    kicker: "Short break",
    numeral: "04:31",
    spokenNumeral: "4 minutes remaining",
    progress: Progress(completed: 3, total: 4),
    music: .previewBreakPaused,
    controls: .running)

  static let previewMusicOffWhileRunning = TimerScreenModel(
    blockName: "Focus block",
    kicker: "Focus",
    numeral: "18:04",
    spokenNumeral: "18 minutes remaining",
    progress: Progress(completed: 2, total: 4),
    capture: Capture(internalCount: 0, externalCount: 0),
    music: .previewRunningOff,
    controls: .running)

  static let previewMusicDidNotStart = TimerScreenModel(
    blockName: "Focus block",
    kicker: "Focus",
    numeral: "24:58",
    spokenNumeral: "24 minutes remaining",
    progress: Progress(completed: 2, total: 4),
    capture: Capture(internalCount: 0, externalCount: 0),
    music: .previewDidNotStart,
    controls: .running)

  static let previewNoSubscription = TimerScreenModel(
    blockName: "Focus block",
    kicker: "Focus",
    numeral: "25:00",
    spokenNumeral: "25 minutes",
    progress: Progress(completed: 0, total: 4),
    music: .previewNoSubscription,
    controls: .start(isEnabled: true, spokenLabel: "Start focus block, 25 minutes"))

  static let previewAttachedTaskGone = TimerScreenModel(
    blockName: "Focus block",
    kicker: "Focus",
    numeral: "18:04",
    spokenNumeral: "18 minutes remaining",
    progress: Progress(completed: 2, total: 4),
    capture: Capture(internalCount: 0, externalCount: 0),
    attachment: Attachment.forTimer(
      hasToken: true,
      isFocusRunning: true,
      runningBlock: .previewReply,
      runningBlockIsGone: true,
      nextItem: nil),
    music: .previewPlaying,
    controls: .running)
}

/// Fixtures for this file's previews. Never part of what ships.
private extension SessionPlanStore.Item {
  static let previewReplyItem = SessionPlanStore.Item(
    todoistID: "preview-reply",
    titleSnapshot: "Reply to Anna",
    kind: .task,
    position: 1)
}

private extension SessionAttachment {
  static let previewDraft = SessionAttachment(
    taskID: "preview-draft",
    taskTitle: "Draft the Q3 summary")

  static let previewReply = SessionAttachment(
    taskID: "preview-reply",
    taskTitle: "Reply to Anna")
}

/// Music-row fixtures for this file's previews. Never part of what ships.
///
/// They are built through the same rule the running app uses rather than by
/// hand, so a preview cannot show a combination the rule would never produce —
/// which is what makes the two D19.3 previews a real check rather than two
/// pictures somebody drew.
private extension MusicRowModel {
  static let previewChoice = MusicSelection(
    kind: .playlist,
    identifier: "p.preview",
    title: "Deep Focus")

  static let previewIdleOff = MusicRowModel.forTimer(
    isRunning: false,
    kind: .work,
    isEnabled: false,
    availability: .ready,
    selection: previewChoice)

  static let previewIdleOn = MusicRowModel.forTimer(
    isRunning: false,
    kind: .work,
    isEnabled: true,
    availability: .ready,
    selection: previewChoice)

  static let previewIdleNothingChosen = MusicRowModel.forTimer(
    isRunning: false,
    kind: .work,
    isEnabled: false,
    availability: .notAsked,
    selection: nil)

  static let previewPlaying = MusicRowModel.forTimer(
    isRunning: true,
    kind: .work,
    isEnabled: true,
    availability: .ready,
    selection: previewChoice,
    playback: .playing)

  static let previewBreakPaused = MusicRowModel.forTimer(
    isRunning: true,
    kind: .shortBreak,
    isEnabled: true,
    availability: .ready,
    selection: previewChoice)

  static let previewRunningOff = MusicRowModel.forTimer(
    isRunning: true,
    kind: .work,
    isEnabled: false,
    availability: .ready,
    selection: previewChoice)

  static let previewDidNotStart = MusicRowModel.forTimer(
    isRunning: true,
    kind: .work,
    isEnabled: true,
    availability: .ready,
    selection: previewChoice,
    playback: .didNotStart)

  static let previewNoSubscription = MusicRowModel.forTimer(
    isRunning: false,
    kind: .work,
    isEnabled: true,
    availability: .noSubscription,
    selection: previewChoice)
}
