import SwiftUI

/// Asked once, at the end of a focus block that had at least one tap.
///
/// WHAT THIS SHEET IS FOR
/// The taps are already recorded. Each one became a durable row the instant a
/// button was pressed, before anything buzzed, and none of them depends on this
/// sheet appearing, being answered, or being closed. What is collected here is
/// an optional sentence per tap — the colour, not the fact.
///
/// **Leaving every field blank and tapping Done is a completely normal
/// outcome.** The counts alone are the data `SPEC.md` asks for. Nothing in the
/// copy, the layout or the spoken description implies a preference, and there is
/// no state in which the Done button is switched off.
///
/// WHY NO SHEET APPEARS AT ALL FOR A BLOCK WITH NO TAPS
/// A modal that says "nothing happened, is that right?" at the end of every
/// undisturbed pomodoro would be the app interrupting a person to ask whether
/// they were interrupted. So this sheet is presented only when there is
/// something to ask about, which is also why the value that drives it is
/// `nil` rather than a reflection with an empty list.
///
/// WHY IT IS NEVER SHOWN AGAIN
/// Killed with this open, or swiped away and regretted, the rows survive and
/// their notes stay `nil`. Nothing queues them up for later. A sentence written
/// an hour after the fact is not the self-knowledge data the spec is asking for,
/// and a backlog of nagging prompts would be a capture surface by another name.
///
/// THE BREAK IS ALREADY RUNNING BEHIND THIS
/// Ratified decision D4. The block ended, the break's end time was set in the
/// same instant, and this was presented over the top of a clock that is already
/// counting. Reflection never consumes break time, and a sheet left open while
/// somebody walks away cannot silently stretch their day. The footer says so out
/// loud, so nobody feels they have to hurry.
struct BlockReflectionSheet: View {
  // MARK: Internal

  /// The block that just ended, and its taps in the order they happened.
  let reflection: BlockReflection

  /// The sentences, keyed by the id of the tap each belongs to. Owned by the
  /// screen presenting this sheet, so that closing it cannot strand anything.
  @Binding var notes: [UUID: String]

  /// Whether a break actually started behind this sheet.
  ///
  /// Almost always `true`. It is `false` in one real case: a boundary the app
  /// was too late to serve, where the engine records the block and goes idle
  /// rather than auto-starting anything. The footer line is then omitted rather
  /// than lying about a clock that is not running.
  let breakIsRunning: Bool

  /// Done was pressed, or the sheet was swiped away. Both mean the same thing —
  /// see the note on `body`.
  let onDone: () -> Void

  var body: some View {
    VStack(spacing: Spacing.lg) {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.lg) {
          header
          ReflectionFieldList(prompts: reflection.prompts, notes: $notes)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      // Dragging the list pushes the keyboard away, so a person on a small
      // phone with six rows can reach a field below the one they are in.
      .scrollDismissesKeyboard(.interactively)

      footer
    }
    .padding(Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color(.surfacePrimary).ignoresSafeArea())
    // ONE SIZE. A sheet that resizes itself while you type is a distraction
    // inside a distraction logger, and the number of rows is unbounded — a
    // medium detent at the largest text size shows about one and a half fields,
    // which reads as a broken sheet rather than as a short one.
    .presentationDetents([.large])
    // SWIPING THIS AWAY IS ALLOWED, AND THE HANDLE SAYS SO.
    //
    // This is the opposite of the stop sheet, which disables swipe-to-dismiss
    // because a block would otherwise be left undecided. Here there is nothing
    // undecided: the rows exist either way. The presence of a drag indicator on
    // one sheet and its absence on the other is also how the two are told apart
    // before a word of either is read.
    .presentationDragIndicator(.visible)
    // NO AUTO-FOCUS AND NO KEYBOARD ON ARRIVAL, DELIBERATELY.
    //
    // The stop sheet focuses its field, because somebody who opened it has
    // already decided to write. Here the honest default is silence: raising the
    // keyboard would say a sentence is expected, and anybody intending to skip
    // would have to dismiss a keyboard before they could leave. It also means
    // VoiceOver lands on the title and reads the header — including the line
    // saying the taps are already recorded, which is the first thing that
    // reader needs to hear. The first tap on a field is what raises the
    // keyboard.
  }

  // MARK: Private

  /// The question, what was tallied, and the permission that is phrased as a
  /// fact.
  private var header: some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      Text("What pulled you away?")
        .font(Typography.title)
        .foregroundStyle(Color(.textPrimary))

      // THE FIRST REAL CONSUMER OF `DistractionTally.summary(of:)`.
      //
      // "2 internal · 1 external", built by the one hand-written function in
      // this project rather than assembled again here. A summary line spelled
      // twice is a summary line that will one day disagree with itself, and a
      // hand-written function with no caller is one nobody would notice going
      // wrong.
      Text(DistractionTally.summary(of: reflection.prompts.map(\.kind)))
        .font(Typography.data)
        .foregroundStyle(Color(.textMuted))

      // THE GRAMMAR OF THIS LINE IS DOING THE WORK.
      //
      // It states a FACT — "the taps are already recorded" — rather than
      // granting a PERMISSION — "you may skip these if you like". Permission
      // implies a preference was disappointed; a fact does not. There is no
      // "optional", no "(if you want)", and above all no "you can always come
      // back to this", which would be a lie: this sheet is never presented
      // again.
      Text("A line each if you can remember. Skip any of them — the taps are already recorded.")
        .font(Typography.body)
        .foregroundStyle(Color(.textMuted))
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  /// Pinned below the scrolling rows, and that is the most important layout
  /// decision on this sheet: at the largest text size with six taps the content
  /// is several screens tall, and nobody may have to scroll past six giant
  /// fields to find the way out.
  private var footer: some View {
    VStack(spacing: Spacing.sm) {
      if breakIsRunning {
        // D4's load-bearing fact, said out loud so nobody rushes.
        Text("Your break is already running.")
          .font(Typography.label)
          .foregroundStyle(Color(.textMuted))
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity)
      }

      // NEVER `.disabled(...)`, under any condition, ever. A confirm button
      // that can be switched off is the sheet implying an obligation, and there
      // is none: the block is over and the break is running, so the thing to do
      // is finish here and go. That is why this is the one filled button.
      //
      // There is no "Complete task" button beside it. That control belongs to
      // the Todoist feature, which does not exist yet — and a disabled stub or
      // a reserved gap would be that feature starting early, which is worse
      // than absent because it looks finished.
      Button("Done") { onDone() }
        .buttonStyle(StartButtonStyle())
        // Restates the first-class-skip contract for somebody who cannot see
        // the instruction line without swiping back up through six rows.
        .accessibilityHint(Text("Closes. Anything you left blank stays blank."))
    }
  }
}

// MARK: - Previews

#Preview("One tap") {
  BlockReflectionSheetPreviewHost(first: .previewInternal(at: 32))
    .preferredColorScheme(.light)
}

#Preview("Three taps") {
  BlockReflectionSheetPreviewHost(first: .previewInternal(at: 32), rest: .previewTwoMore)
    .preferredColorScheme(.light)
}

#Preview("Three taps, dark") {
  BlockReflectionSheetPreviewHost(first: .previewInternal(at: 32), rest: .previewTwoMore)
    .preferredColorScheme(.dark)
}

/// The hard case. Nothing may be cut off, and Done must still be one reachable
/// tap without scrolling.
#Preview("Six taps, largest text") {
  BlockReflectionSheetPreviewHost(first: .previewInternal(at: 32), rest: .previewFiveMore)
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}

#Preview("One tap, largest text") {
  BlockReflectionSheetPreviewHost(first: .previewInternal(at: 32))
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}

/// The boundary the app was too late to serve: the block was recorded, the
/// engine went idle, and no break is counting. The footer line is absent rather
/// than wrong.
#Preview("Break did not start") {
  BlockReflectionSheetPreviewHost(
    first: .previewInternal(at: 32),
    rest: .previewTwoMore,
    breakIsRunning: false)
    .preferredColorScheme(.light)
}

/// Preview scaffolding, never part of what ships.
private struct BlockReflectionSheetPreviewHost: View {
  /// Built through the initialiser that takes the first tap separately, which is
  /// the one that cannot express an empty list — so no preview here has to
  /// unwrap an optional, and none of them reaches for a force unwrap to do it.
  init(first: DistractionPrompt, rest: [DistractionPrompt] = [], breakIsRunning: Bool = true) {
    reflection = BlockReflection(
      sessionID: UUID(),
      firstPrompt: first,
      rest: rest)
    self.breakIsRunning = breakIsRunning
    _notes = State(initialValue: [:])
  }

  let reflection: BlockReflection
  let breakIsRunning: Bool

  var body: some View {
    BlockReflectionSheet(
      reflection: reflection,
      notes: $notes,
      breakIsRunning: breakIsRunning,
      onDone: { })
  }

  @State private var notes: [UUID: String]
}

/// Fixtures for this file's previews. Never part of what ships; private for the
/// reason given in `ReflectionFieldList.swift`.
private extension DistractionPrompt {
  /// A tap at a fixed minute past two in the afternoon, so a preview looks the
  /// same every time it is opened rather than drifting with the clock.
  static func previewInternal(at minute: Int) -> DistractionPrompt {
    preview(.internalInterruption, minute: minute)
  }

  static func previewExternal(at minute: Int) -> DistractionPrompt {
    preview(.externalInterruption, minute: minute)
  }

  private static func preview(_ kind: DistractionKind, minute: Int) -> DistractionPrompt {
    let components = DateComponents(year: 2026, month: 8, day: 23, hour: 14, minute: minute)
    let instant = Calendar(identifier: .gregorian).date(from: components)
    return DistractionPrompt(
      id: UUID(),
      kind: kind,
      timestamp: instant ?? Date(timeIntervalSince1970: 0))
  }
}

private extension [DistractionPrompt] {
  static var previewTwoMore: [DistractionPrompt] {
    [.previewExternal(at: 41), .previewInternal(at: 58)]
  }

  static var previewFiveMore: [DistractionPrompt] {
    [
      .previewExternal(at: 35),
      .previewInternal(at: 41),
      .previewInternal(at: 47),
      .previewExternal(at: 52),
      .previewExternal(at: 58)
    ]
  }
}
