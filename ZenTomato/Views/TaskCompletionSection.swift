import SwiftUI

// swiftlint:disable file_length
//
// THE ONLY LINT RULE THIS FILE TURNS OFF, AND WHY.
// `file_length` counts documentation and previews, and this file is mostly
// both. It is the one control in the app that can change somebody else's data,
// so the argument for every state it can be in is written beside the state —
// and the eleven previews at the bottom exist because those states are the ones
// no test can look at: the failure wordings, the switched-off treatments, and
// the hard case of six reflection fields at the largest text size. Splitting the
// previews away from the view would put the states in one file and the reasons
// they exist in another. The same exemption, for the same reason, is already
// taken by `TimerScreen.swift`, `SettingsView.swift` and `TimerView.swift`.

/// The one control in this app that can change anything in Todoist.
///
/// It appears on the end-of-block sheets, above the reflection fields, and it
/// closes the task the block was attached to. **That is the only write this app
/// can make**, and every other Todoist request behind these screens is a read.
///
/// COMPLETING DOES NOT END THE POMODORO, AND ENDING DOES NOT COMPLETE THE TASK
/// Stated as build rules, because this is the part a reviewer checks line by
/// line:
///
///  1. Completing touches no timer state — not the engine, not the running
///     break, not the finished-block row, not the alarm.
///  2. It does not close the sheet. The sheet's exits are unchanged.
///  3. Done, swipe-to-dismiss, "Keep going" and "Stop the timer" complete
///     nothing. There is no combined "complete and close", no checkbox that a
///     confirm button acts on, and no completion implied by a dismissal.
///  4. Killing the app with the sheet open completes nothing. Nothing is queued
///     for later and the sheet is never re-offered.
///  5. There is exactly one close request per successful tap.
///
/// WHAT "OPTIMISTIC" MEANS HERE, AND WHAT IT DOES NOT
/// The plan asks for a control that is optimistic in the interface and
/// reconciled against the response. What is committed immediately is that the
/// control is **busy**. What is never claimed before Todoist confirms is
/// **success** — because a completion is recorded locally only when Todoist
/// confirms the close, and a tick drawn and then taken back is the same defect
/// as a false row on disk, arriving through the eye instead of the database.
///
/// WHY IT IS OUTLINED AND NEVER FILLED
/// A filled button in this design system means "this is the thing to do", and
/// on both sheets the thing to do is finish and go. The filled button stays
/// what it already is: Done on the reflection sheet, Keep going on the stop
/// sheet. This one is available, not urged — which also stops it reading as a
/// reward for having stopped early.
struct TaskCompletionSection: View {
  // MARK: Internal

  /// The task a block was attached to.
  ///
  /// **A project is not a subject.** There is nothing to close, there is no
  /// project-close endpoint on the allowlist, and there never will be — so a
  /// block attached to a project draws no section at all rather than a disabled
  /// button or an explanatory row.
  struct Subject: Equatable, Sendable {
    let taskID: String

    /// The snapshot taken when the block started — the same string the
    /// finished-block row stores, never a live lookup. A task renamed in
    /// Todoist during a twenty-five minute block must not silently change what
    /// the sheet claims you were working on.
    let title: String
  }

  /// The four states of the control.
  enum Control: Equatable, Sendable {
    /// Tappable. The resting state.
    case ready
    /// A close is in flight.
    case working
    /// Todoist confirmed it, at this instant.
    case completed(at: Date)
    /// It cannot be tapped, and this plain sentence says why. **Never amber** —
    /// nothing has failed.
    case unavailable(String)
  }

  let subject: Subject
  let control: Control

  /// What went wrong with the last attempt, if anything. Amber, and this
  /// sheet's one amber thing.
  var failure: String?

  let onComplete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.none) {
      Text("Task")
        .font(Typography.kicker)
        .textCase(.uppercase)
        .foregroundStyle(Color(.textMuted))
        // The control below says it.
        .accessibilityHidden(true)

      Text(subject.title)
        .font(Typography.body)
        .foregroundStyle(Color(hasCompleted ? .textMuted : .textPrimary))
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, Spacing.xxs)

      controlView
        .padding(.top, Spacing.sm)

      if let note {
        Text(note)
          .font(Typography.label)
          .foregroundStyle(Color(.textMuted))
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, Spacing.xs)
      }

      if let failure {
        failureRow(failure)
          .padding(.top, Spacing.xs)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    // SAID OUT LOUD, because the reader's focus is on the button and nothing
    // else would tell them a line appeared underneath it.
    .onChange(of: failure) { _, message in
      guard let message else { return }
      AccessibilityNotification.Announcement(message).post()
    }
  }

  // MARK: The state of the control, before anything has been tapped

  /// Whether the button can be offered at all.
  ///
  /// A pure function of three finished facts, which is what lets the rule be
  /// tested with no sheet, no network and no account.
  ///
  /// - Parameters:
  ///   - hasToken: whether there is a credential at all.
  ///   - todoistIsReachable: whether the last request got through. A completion
  ///     is a **write**, and a write we cannot see is the one thing forbidden —
  ///     so offline it is switched off rather than queued.
  ///   - taskIsInTodoist: whether the mirror still holds this task.
  ///     `.unknown` means the mirror has never been filled, which is not
  ///     evidence of anything — so the button is offered rather than refused.
  static func restingControl(
    hasToken: Bool,
    todoistIsReachable: Bool,
    taskIsInTodoist: SessionPlanStore.Presence) -> Control {
    // The credential is checked FIRST, and separately, because the two states
    // have different causes and different ways out. Folded together they read as
    // "can't reach Todoist", which blames the network for a credential that was
    // revoked and sends somebody to look for a signal they already have.
    guard hasToken else { return .unavailable(notConnected) }
    guard todoistIsReachable else { return .unavailable(cannotReach) }
    guard taskIsInTodoist != .absent else { return .unavailable(notInTodoist) }
    return .ready
  }

  /// What the control becomes once Todoist has answered.
  static func control(after outcome: TaskCompletion.Outcome, at instant: Date) -> Control {
    switch outcome {
    case .closed:
      .completed(at: instant)
    case .alreadyGone:
      // The one failure that does not offer a retry: tapping again cannot
      // succeed. It also does **not** say "completed" — a task that is simply
      // absent could have been completed or removed, and claiming one would be
      // a fabricated record.
      .unavailable(alreadyGone)
    case .tokenRejected:
      // NOT back to tappable. The credential has just been taken out of the
      // Keychain, so a second tap cannot succeed — it would fail again with a
      // message naming no cause, which is worse than the one already on screen.
      // The amber row above says what happened and where to fix it; the button
      // is switched off with the same sentence rather than left looking live.
      .unavailable(notConnected)

    case .offline, .rateLimited, .failed:
      // Back to tappable. **Tapping again is the retry, and it is the only
      // one.** No automatic retry, no backoff on this control, and above all no
      // queue: a completion the app performs later, unwatched, is a write
      // nobody can see.
      .ready
    }
  }

  /// The amber line under the button, or nothing when there is nothing to say.
  ///
  /// **Every one of these says what is true of the task in Todoist**, because
  /// the whole risk of a one-tap network write is leaving somebody unsure
  /// whether it went through.
  static func failureMessage(for outcome: TaskCompletion.Outcome) -> String? {
    switch outcome {
    case .closed, .alreadyGone:
      nil
    case .offline:
      "That didn't reach Todoist, so the task is still open there. Tap Complete again in a moment."
    case .tokenRejected:
      """
      Todoist no longer accepts your token, so the task is still open. Reconnect \
      in Settings, then try again.
      """
    case .rateLimited(let retryAfter):
      // The wait is named when Todoist named one, because "in a moment" against
      // a stated number is the sentence that invites the immediate second tap.
      Self.slowDown(retryAfter: retryAfter)
    case .failed:
      "Todoist couldn't tick that off just now, so the task is still open. Try again in a moment."
    }
  }

  // MARK: Private

  /// Shown before the tap, when Todoist cannot be reached. **Not amber** —
  /// nothing has failed, and the break is running either way.
  private static let cannotReach =
    "Can't reach Todoist right now, so this can't be ticked off. The break is running either way."

  private static let notInTodoist = "This task is no longer in Todoist, so there's nothing to tick off."

  /// Shown when there is no credential — including the moment after Todoist
  /// refused one, which is the state this sentence exists for. **Not amber**
  /// where it stands under the button; the amber row above already said what
  /// happened, and this names the way out.
  private static let notConnected =
    "ZenTomato isn't connected to Todoist, so this can't be ticked off. Reconnect in Settings."

  private static let alreadyGone =
    "That task isn't in Todoist any more — it was already completed or removed. Nothing to do here."

  /// One sentence, and it earns its place: this is a one-tap irreversible
  /// network write, and reopening a task is a second write that is not on the
  /// allowlist and is not being added. Better said before the tap than
  /// explained after it.
  private static let undoNote = "This can only be undone in Todoist."

  /// "Todoist asked us to slow down" — the *us* is correct and is the whole
  /// point. This is the app's own traffic, not something the reader did. No
  /// "you", no "too many requests", no status code.
  private static func slowDown(retryAfter: Duration?) -> String {
    guard let seconds = retryAfter.map({ Int($0.components.seconds) }), seconds > 0 else {
      return "Todoist asked us to slow down, so the task is still open. Try again shortly."
    }
    return "Todoist asked us to slow down, so the task is still open. Try again in \(seconds) seconds."
  }

  private var hasCompleted: Bool {
    if case .completed = control { return true }
    return false
  }

  private var note: String? {
    switch control {
    case .ready:
      Self.undoNote
    case .working, .completed:
      // The decision has been made; the warning has done its job.
      nil
    case .unavailable(let sentence):
      sentence
    }
  }

  @ViewBuilder
  private var controlView: some View {
    switch control {
    case .ready:
      // "Complete in Todoist", not "Mark complete" and not "Done": it names
      // the destination, so it cannot be read as "complete this sheet" — and
      // Done already means "close" one control away.
      Button("Complete in Todoist") { onComplete() }
        .buttonStyle(SecondaryButtonStyle(emphasis: .normal))
        .accessibilityLabel(Text("Complete “\(subject.title)” in Todoist"))
        .accessibilityHint(
          Text("Ticks the task off in Todoist. It doesn't end your break and doesn't close this sheet."))

    case .working:
      Button { } label: {
        HStack(spacing: Spacing.xs) {
          ProgressView()
            .controlSize(.small)
            .tint(Color(.textSubtle))
          Text("Completing…")
        }
      }
      .buttonStyle(SecondaryButtonStyle(emphasis: .normal))
      .disabled(true)

    case .completed(let instant):
      // The button is REPLACED rather than left switched off, because the thing
      // it offered has happened. No animation, no confetti, no haptic beyond
      // the tap — the sprint-complete note already sets that precedent.
      Label {
        Text("Completed in Todoist · \(instant.formatted(date: .omitted, time: .shortened))")
          .font(Typography.label)
          .foregroundStyle(Color(.action))
      } icon: {
        // The glyph is the non-colour signal, so the state does not depend on
        // sage alone.
        Image(systemName: "checkmark")
          .foregroundStyle(Color(.action))
      }
      .frame(maxWidth: .infinity, alignment: .leading)

    case .unavailable:
      Button("Complete in Todoist") { }
        .buttonStyle(SecondaryButtonStyle(emphasis: .normal))
        .disabled(true)
        .accessibilityLabel(Text("Complete “\(subject.title)” in Todoist, unavailable"))
    }
  }

  private func failureRow(_ message: String) -> some View {
    Label {
      Text(message)
        .font(Typography.label)
        .foregroundStyle(Color(.warningText))
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    } icon: {
      Image(systemName: "exclamationmark.triangle")
        .foregroundStyle(Color(.warningText))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Previews

#Preview("Before") {
  TaskCompletionPreviewHost(control: .ready)
    .preferredColorScheme(.light)
}

#Preview("Before, dark") {
  TaskCompletionPreviewHost(control: .ready)
    .preferredColorScheme(.dark)
}

#Preview("Completing") {
  TaskCompletionPreviewHost(control: .working)
    .preferredColorScheme(.light)
}

#Preview("Completed") {
  TaskCompletionPreviewHost(control: .completed(at: .previewAfternoon))
    .preferredColorScheme(.light)
}

/// Offline before any tap: switched off, with a plain sentence rather than
/// amber, because nothing has failed.
#Preview("Disabled, offline") {
  TaskCompletionPreviewHost(
    control: TaskCompletionSection.restingControl(
      hasToken: true,
      todoistIsReachable: false,
      taskIsInTodoist: .present))
    .preferredColorScheme(.light)
}

#Preview("Failed — offline") {
  TaskCompletionPreviewHost(
    control: .ready,
    failure: TaskCompletionSection.failureMessage(for: .offline))
    .preferredColorScheme(.light)
}

/// A revoked token: the amber row says what happened, and the button is
/// switched off rather than left live, because a second tap cannot succeed.
#Preview("Failed — token revoked") {
  TaskCompletionPreviewHost(
    control: TaskCompletionSection.control(after: .tokenRejected, at: .previewAfternoon),
    failure: TaskCompletionSection.failureMessage(for: .tokenRejected))
    .preferredColorScheme(.light)
}

/// Rate-limited: tappable again, with the wait Todoist named.
#Preview("Failed — asked to slow down") {
  TaskCompletionPreviewHost(
    control: TaskCompletionSection.control(after: .rateLimited(retryAfter: .seconds(30)), at: .previewAfternoon),
    failure: TaskCompletionSection.failureMessage(for: .rateLimited(retryAfter: .seconds(30))))
    .preferredColorScheme(.light)
}

/// No credential at all, before any tap.
#Preview("Disabled, not connected") {
  TaskCompletionPreviewHost(
    control: TaskCompletionSection.restingControl(
      hasToken: false,
      todoistIsReachable: true,
      taskIsInTodoist: .present))
    .preferredColorScheme(.light)
}

/// The task is gone. The button cannot succeed, so it is switched off and the
/// line says what is known — which is not "completed".
#Preview("Already gone") {
  TaskCompletionPreviewHost(
    control: TaskCompletionSection.control(after: .alreadyGone, at: .previewAfternoon))
    .preferredColorScheme(.light)
}

#Preview("Before, largest text") {
  TaskCompletionPreviewHost(control: .ready)
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility5)
}

/// Preview scaffolding, never part of what ships.
private struct TaskCompletionPreviewHost: View {
  var control: TaskCompletionSection.Control
  var failure: String?

  var body: some View {
    TaskCompletionSection(
      subject: TaskCompletionSection.Subject(taskID: "planned-item", title: "Draft the Q3 summary"),
      control: control,
      failure: failure,
      onComplete: { })
      .padding(Spacing.lg)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background(Color(.surfacePrimary))
  }
}

/// A fixed instant, so a preview looks the same every time it is opened rather
/// than drifting with the clock.
private extension Date {
  static var previewAfternoon: Date {
    let components = DateComponents(year: 2026, month: 8, day: 23, hour: 14, minute: 57)
    return Calendar(identifier: .gregorian).date(from: components) ?? Date(timeIntervalSince1970: 0)
  }
}
