import SwiftUI

/// Asks why, before a block is allowed to stop — and, in the same sheet, offers
/// a sentence for each distraction tapped during it.
///
/// WHY THIS SHEET EXISTS AT ALL
/// A pomodoro is indivisible: it finishes or it is void. There is exactly one way
/// out of a running block, and this is the toll on it.
///
/// The exit has to exist — a mistyped two-hour focus length would otherwise be
/// inescapable, and the only remaining way out would be force-quitting the app,
/// which the engine reconciles from the stored end time and records as a
/// *finished* pomodoro. That is a false count in the one number the whole app
/// exists to produce. So rather than removing the exit, this makes it cost
/// something.
///
/// WHY THE SENTENCE IS REQUIRED, WHEN THE DISTRACTION PROMPT'S IS NOT
/// The distraction prompt treats saying nothing as a perfectly good answer, and
/// that is right there: the tap has already recorded the fact, and the sentence
/// only adds colour. This is the opposite case. The fact of stopping is a single
/// bit. The reason is the entire content — and the day somebody least wants to
/// write it, the day they bailed out and would rather not think about why, is
/// the day it is worth the most.
///
/// WHY BOTH REQUIREMENT LEVELS NOW LIVE IN ONE SHEET
/// Ratified decision D14. Stopping mid-block and the end of a block that had
/// taps both want the same instant, and two modal sheets back to back — at the
/// moment somebody has decided to quit — is the surest way to train them to
/// dismiss both without reading. The one that would get dismissed is the one
/// that matters. So there is one sheet: the required reason on top, under the
/// question, with no header of its own; the skippable sentences below a rule,
/// under a header that announces itself as a subordinate topic.
///
/// The two levels stay exactly as their own deltas set them. Five signals tell
/// them apart before anything has been typed, and all five are additive rather
/// than corrective — position, resting height, outline weight, one quiet word on
/// the gate only, and the confirm button being visibly switched off. There is no
/// red, no amber, no asterisk, no badge, no count of what is missing, and
/// nothing appears, moves or changes colour if the switched-off button is
/// tapped. Stopping is not an error and the person is not in trouble.
///
/// **A block stopped with no taps shows only the top half.** The rule, the
/// header, the instruction and the rows are omitted entirely — not rendered
/// empty, not collapsed to nothing, not replaced by "no distractions". Stopping
/// with nothing tapped is the commonest case by far, and it keeps the structure,
/// the copy and the two buttons that shipped in F2.
///
/// **It is not, however, byte-for-byte the F2 sheet, and saying it was would be
/// the sentence that stops the next reader checking.** Four things about the
/// top half changed under D14, each of them a signal that tells the required
/// field from the skippable ones: the reason field's outline went from one point
/// to two, an uppercase "Required" marker appeared above it, the field gained a
/// spoken requirement level, and the two buttons moved out of the scrolling
/// content so they stay reachable with six rows above them. All four are visible
/// or audible on a stop with no taps.
///
/// WHAT IT IS NOT
/// This is a reflection field, not a way of entering a task. The app never
/// accepts a new task from anybody; it only ever reads them. A sentence about
/// why you stopped creates nothing, goes nowhere, and is stored beside the block
/// it belongs to.
struct StopReasonSheet: View {
  // MARK: Internal

  /// What has been typed so far. Held by the screen presenting this sheet, so
  /// that a dismissal cannot strand a half-written sentence somewhere invisible.
  @Binding var reason: String

  /// The taps recorded during the block being stopped, oldest first. Empty for
  /// most stops, and then nothing below the reason field is drawn at all.
  var prompts: [DistractionPrompt] = []

  /// The sentences for those taps, keyed by the id of the tap each belongs to.
  ///
  /// **Kept whichever button is pressed.** These sentences are about taps that
  /// really happened; they are not conditional on the stop, so changing your
  /// mind and going back to work must not throw away real reflection. The *stop
  /// reason* is the thing discarded on "Keep going", because no stop occurred.
  @Binding var notes: [UUID: String]

  /// Called when a reason has been written and the person confirmed. Not called
  /// otherwise — there is no path through this sheet that stops a block silently.
  let onConfirm: () -> Void

  /// Called when they decided to keep going after all. The block is untouched.
  let onCancel: () -> Void

  var body: some View {
    VStack(spacing: Spacing.lg) {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.lg) {
          gate

          // Omitted entirely when nothing was tapped — nothing empty is drawn
          // and nothing is collapsed to zero height. See the note at the top
          // for what did and did not change about the zero-tap sheet.
          if prompts.isEmpty == false {
            sectionRule
            annotationHeader
            ReflectionFieldList(prompts: prompts, notes: $notes)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      // Dragging the content pushes the keyboard away. With the keyboard up and
      // three tap fields there is very little sheet left, and a person needs to
      // be able to see what they are answering.
      .scrollDismissesKeyboard(.interactively)

      footer
    }
    .padding(Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color(.surfacePrimary).ignoresSafeArea())
    // One size, for the same reason as the other sheet: a medium detent with
    // six tap rows at the largest text size shows about one and a half of them.
    .presentationDetents([.large])
    // The keyboard is up on arrival. Somebody who has decided to stop should not
    // have to hunt for the field — least of all past a list of their own
    // distractions. The scroll starts at the top, so the question, the marker
    // and the field are all on screen at every text size.
    .onAppear { isWriting = true }
    // There is no swipe-to-dismiss. Every way out of this sheet is one of the
    // two buttons, so a block can never end without a reason and can never be
    // left in a state where the sheet is gone and the timer is undecided.
    //
    // Its absence is now meaningful in a second way: the end-of-block sheet
    // shows a drag indicator and this one does not, so the two are told apart
    // before a word of either is read.
    .interactiveDismissDisabled()
  }

  // MARK: Private

  @FocusState private var isWriting: Bool

  /// Whitespace is not a reason. A space bar tapped once would otherwise unlock
  /// the button and store a blank sentence, which is worse than no row at all —
  /// it looks like a reflection that happened.
  private var isWritten: Bool {
    reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
  }

  private var field: RoundedRectangle {
    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
  }

  /// The question, the one word that states the requirement level, and the field
  /// that has to be filled in.
  ///
  /// It is the sheet's first content and it has no header of its own. That is
  /// the strongest available statement that it *is* the sheet's subject:
  /// everything optional lives below a rule, under a header, in a section that
  /// announces itself as a subordinate topic.
  private var gate: some View {
    VStack(alignment: .leading, spacing: Spacing.lg) {
      VStack(alignment: .leading, spacing: Spacing.xs) {
        Text("Why are you stopping?")
          .font(Typography.title)
          .foregroundStyle(Color(.textPrimary))

        // No blame, and no lecture. The person is already stopping; a sheet that
        // argues with them is a sheet they learn to dismiss without reading, and
        // then it stops collecting anything.
        Text("One line is enough. This is the part you'll want to read back.")
          .font(Typography.body)
          .foregroundStyle(Color(.textMuted))
          .fixedSize(horizontal: false, vertical: true)
      }

      // ONE WORD, ON THE GATE ONLY, AND IT NEVER CHANGES.
      //
      // It does not disappear when satisfied and does not turn into a tick: it
      // is a label on a field, not a scoreboard. The tap fields below carry no
      // marker at all — labelling them "Optional" would be nagging by
      // inversion, because it says something is being counted, whereas absence
      // says nothing.
      HStack(spacing: Spacing.none) {
        Spacer(minLength: Spacing.none)
        Text("Required")
          .textCase(.uppercase)
          .font(Typography.kicker)
          .foregroundStyle(Color(.textMuted))
      }
      // Spoken as part of the field below rather than as a stray word of its
      // own, so a VoiceOver reader meets the requirement level attached to the
      // thing it governs.
      .accessibilityHidden(true)

      TextField("", text: $reason, axis: .vertical)
        .font(Typography.body)
        .foregroundStyle(Color(.textPrimary))
        .textInputAutocapitalization(.sentences)
        // RESTS THREE LINES TALL, WHERE A TAP FIELD RESTS ONE. A field that
        // rests three lines tall looks like a place a paragraph is expected;
        // one line that grows looks like a place a sentence could go. This is
        // the signal that reads from across the room, before any text is
        // parsed.
        .lineLimit(3 ... 6)
        .padding(Spacing.sm)
        .background(Color(.surfaceInset), in: field)
        // TWO POINTS, WHERE A TAP FIELD CARRIES ONE. Same colour, and both
        // clear the 3:1 floor for a control boundary on every ground in both
        // appearances — the step between them is the signal, not the colour.
        .overlay { field.strokeBorder(Color(.borderStrong), lineWidth: Spacing.borderThin) }
        .focused($isWriting)
        // THE REQUIREMENT LEVEL IS IN THE LABEL, NOT ONLY IN THE HINT.
        //
        // Hints can be switched off in VoiceOver's settings, and a reader who
        // has done that would otherwise hear "Reason for stopping, text field"
        // and nothing else — no marker, no requirement, on the one sheet where
        // the requirement level is the whole design problem. The drawn kicker
        // says the same word, so nothing is spoken that is not also on screen.
        // The hint keeps the consequence, which is the part that is genuinely
        // supplementary.
        .accessibilityLabel(Text("Reason for stopping, required"))
        .accessibilityHint(Text("Stop the timer stays switched off until this is written."))
    }
  }

  /// The only decorative line in the feature, and the only use of the `border`
  /// role anywhere on this sheet.
  ///
  /// `border` is documented as decorative-only; using it on a control boundary
  /// would be a defect, which is why every field above and below is outlined in
  /// `borderStrong` instead. This is genuinely decoration — it separates two
  /// topics and carries no information — so VoiceOver is told to skip it.
  private var sectionRule: some View {
    Rectangle()
      .fill(Color(.border))
      .frame(maxWidth: .infinity)
      .frame(height: Spacing.borderHairline)
      .padding(.vertical, Spacing.xs)
      .accessibilityHidden(true)
  }

  private var annotationHeader: some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      Text("During this block")
        .textCase(.uppercase)
        .font(Typography.kicker)
        .foregroundStyle(Color(.textMuted))

      // The same fact, in the same grammar, as the end-of-block sheet: it
      // states that the taps are recorded rather than granting permission to
      // skip. There is no tally line here, unlike that sheet — the rows
      // immediately below already enumerate the same taps, and somebody mid-quit
      // should have one fewer line to read before the field they have to fill in.
      Text("Skip any of them — the taps are already recorded.")
        .font(Typography.label)
        .foregroundStyle(Color(.textMuted))
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  /// Pinned outside the scrolling content, which is the one structural change to
  /// this file.
  ///
  /// It used to be the bottom of a single stack. With up to six tap rows above
  /// it at the largest text size, the buttons would be somewhere off the end of
  /// a long scroll — and a person who has decided to quit would have to scroll
  /// through a list of their own distractions to reach "Keep going". The escape
  /// from a stop must be one reachable tap at all times.
  private var footer: some View {
    VStack(spacing: Spacing.sm) {
      // The confirm sits BELOW the escape, and is the quieter of the two. The
      // reading order is the recommendation: the first thing offered is going
      // back to work.
      Button("Keep going") { onCancel() }
        .buttonStyle(StartButtonStyle())

      Button("Stop the timer") { onConfirm() }
        .buttonStyle(SecondaryButtonStyle(emphasis: .quiet))
        .disabled(isWritten == false)
        .accessibilityHint(Text(isWritten
          ? "Ends the block and the sprint."
          : "Write a reason first."))
    }
  }
}

// MARK: - Previews

/// The commonest case: a question, a field, two buttons, and nothing else. It
/// keeps F2's structure and copy; the field's two-point outline, the "Required"
/// marker and the pinned buttons are D14's, and are the difference between this
/// preview and the one that shipped.
///
/// Compare it with "Zero taps, written" below: the footer must differ, because
/// "Stop the timer" is switched off here and live there.
#Preview("Zero taps, empty") {
  StopReasonSheetPreviewHost(reason: "")
    .preferredColorScheme(.light)
}

#Preview("Zero taps, written") {
  StopReasonSheetPreviewHost(reason: "Meeting got moved up an hour.")
    .preferredColorScheme(.light)
}

/// D14's shape: a required reason above a rule, two skippable sentences below.
#Preview("Two taps, empty") {
  StopReasonSheetPreviewHost(reason: "", prompts: .previewTwoTaps)
    .preferredColorScheme(.light)
}

#Preview("Two taps, empty, dark") {
  StopReasonSheetPreviewHost(reason: "", prompts: .previewTwoTaps)
    .preferredColorScheme(.dark)
}

/// The hard case: the longest plausible list at the largest text size. Both
/// buttons must still be on screen without scrolling.
#Preview("Six taps, empty, largest text") {
  StopReasonSheetPreviewHost(reason: "", prompts: .previewSixTaps)
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}

#Preview("Zero taps, largest text") {
  StopReasonSheetPreviewHost(reason: "")
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}

/// Gives the previews somewhere to hold the text, since the sheet binds to
/// values its presenter owns.
private struct StopReasonSheetPreviewHost: View {
  init(reason: String, prompts: [DistractionPrompt] = []) {
    self.prompts = prompts
    _reason = State(initialValue: reason)
    _notes = State(initialValue: [:])
  }

  let prompts: [DistractionPrompt]

  var body: some View {
    StopReasonSheet(
      reason: $reason,
      prompts: prompts,
      notes: $notes,
      onConfirm: { },
      onCancel: { })
  }

  @State private var reason: String
  @State private var notes: [UUID: String]
}

/// Fixtures for this file's previews. Never part of what ships; private for the
/// reason given in `ReflectionFieldList.swift`.
private extension [DistractionPrompt] {
  static var previewTwoTaps: [DistractionPrompt] {
    [
      prompt(.internalInterruption, minute: 32),
      prompt(.externalInterruption, minute: 41)
    ]
  }

  static var previewSixTaps: [DistractionPrompt] {
    [
      prompt(.internalInterruption, minute: 32),
      prompt(.externalInterruption, minute: 35),
      prompt(.internalInterruption, minute: 41),
      prompt(.internalInterruption, minute: 47),
      prompt(.externalInterruption, minute: 52),
      prompt(.externalInterruption, minute: 58)
    ]
  }

  static func prompt(_ kind: DistractionKind, minute: Int) -> DistractionPrompt {
    let components = DateComponents(year: 2026, month: 8, day: 23, hour: 14, minute: minute)
    let instant = Calendar(identifier: .gregorian).date(from: components)
    return DistractionPrompt(
      id: UUID(),
      kind: kind,
      timestamp: instant ?? Date(timeIntervalSince1970: 0))
  }
}
