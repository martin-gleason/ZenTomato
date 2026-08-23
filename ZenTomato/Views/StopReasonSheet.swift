import SwiftUI

/// Asks why, before a block is allowed to stop.
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

  /// Called when a reason has been written and the person confirmed. Not called
  /// otherwise — there is no path through this sheet that stops a block silently.
  let onConfirm: () -> Void

  /// Called when they decided to keep going after all. The block is untouched.
  let onCancel: () -> Void

  var body: some View {
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

      TextField("", text: $reason, axis: .vertical)
        .font(Typography.body)
        .foregroundStyle(Color(.textPrimary))
        .textInputAutocapitalization(.sentences)
        .lineLimit(3 ... 6)
        .padding(Spacing.sm)
        .background(Color(.surfaceInset), in: field)
        .overlay { field.strokeBorder(Color(.borderStrong), lineWidth: Spacing.borderHairline) }
        .focused($isWriting)
        .accessibilityLabel(Text("Reason for stopping"))

      Spacer(minLength: Spacing.none)

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
    .padding(Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color(.surfacePrimary).ignoresSafeArea())
    // The keyboard is up on arrival. Somebody who has decided to stop should not
    // have to hunt for the field as well.
    .onAppear { isWriting = true }
    // There is no swipe-to-dismiss. Every way out of this sheet is one of the
    // two buttons, so a block can never end without a reason and can never be
    // left in a state where the sheet is gone and the timer is undecided.
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
}

#Preview("Empty") {
  StopReasonSheetPreviewHost(reason: "")
}

#Preview("Written") {
  StopReasonSheetPreviewHost(reason: "Meeting got moved up an hour.")
}

#Preview("Dark") {
  StopReasonSheetPreviewHost(reason: "")
    .preferredColorScheme(.dark)
}

/// Gives the previews somewhere to hold the text, since the sheet binds to a
/// value its presenter owns.
private struct StopReasonSheetPreviewHost: View {
  init(reason: String) {
    _reason = State(initialValue: reason)
  }

  var body: some View {
    StopReasonSheet(reason: $reason, onConfirm: { }, onCancel: { })
  }

  @State private var reason: String
}
