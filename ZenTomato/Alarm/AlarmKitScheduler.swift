import ActivityKit
import AlarmKit
import Foundation
import SwiftUI

/// The one file in the app that talks to iOS's alarm system.
///
/// WHY THE ALARM SYSTEM AND NOT A NOTIFICATION
/// A person running a Pomodoro block is, by definition, trying not to be
/// interrupted — phone face down, silent switch on, a Focus turned on. Every one
/// of those swallows an ordinary notification. iOS's alarm system is the one
/// alert that is designed to get through all three, because it is what wakes you
/// up in the morning. That is the whole argument for using it, and it is why
/// there is no notification fallback anywhere in this app.
///
/// HOW FAR ALARMKIT REACHES INTO THIS APP, MEASURED RATHER THAN CLAIMED
/// AlarmKit is new — it arrived with iOS 26 — and new frameworks disappoint, so
/// the plan has always been to keep it swappable. What that is worth is a
/// question of how many files would have to change, and the honest count is
/// three, not one:
///
///   * this file, which does all the scheduling and cancelling;
///   * `FocusAlarmMetadata`, because the data that travels with an alarm has to
///     conform to one of AlarmKit's protocols to be allowed to travel;
///   * the widget's `BlockLiveActivity`, which is built out of AlarmKit's own
///     presentation types because the Lock Screen card *is* an AlarmKit
///     activity.
///
/// What genuinely names no Apple alarm type is everything that decides anything:
/// the engine, every screen, and every test. They talk to `AlarmScheduling`, a
/// four-method description of what a timer needs from an alerting system. So
/// replacing the framework would be a rewrite of the alerting layer and of
/// nothing else — which is a real containment, and a smaller one than "one file".
///
/// WHY IT IS `@MainActor`
/// Because everything that calls it already is, and keeping the whole alarm path
/// on one thread removes every question about whether a cancel and a reschedule
/// could overlap. They cannot: they run one after the other on the same thread.
@MainActor
final class AlarmKitScheduler: AlarmScheduling {
  // MARK: Internal

  /// Whether the person has allowed this app to set alarms.
  ///
  /// Reading this costs nothing and cannot fail — it is a plain value iOS keeps
  /// for us, not a request — so the app can check it at any moment without
  /// waiting and without a prompt appearing.
  var authorization: AlarmAuthorization {
    Self.translate(AlarmManager.shared.authorizationState)
  }

  /// Asks the person for permission to set alarms, showing the system prompt.
  ///
  /// **Called at the first tap on Start, never at launch.** Asking for an alarm
  /// permission before somebody has ever started a timer is the reliable way to
  /// have it refused: at launch the request has no context, and a prompt with no
  /// context gets dismissed.
  ///
  /// A refusal and a failure are reported the same way, on purpose. From where
  /// the person is standing they are the same outcome — no alarms — and the
  /// screen that explains it would be word-for-word identical either way.
  func requestAuthorization() async -> AlarmAuthorization {
    do {
      return Self.translate(try await AlarmManager.shared.requestAuthorization())
    } catch {
      return .denied
    }
  }

  /// Cancels anything outstanding and then sets one alarm for the end of this
  /// block.
  ///
  /// **Cancel first is part of the contract, not an implementation detail.** The
  /// most likely user-visible bug in this whole feature is an alarm that goes off
  /// four minutes after you skipped the block it belonged to. It cannot happen if
  /// nothing ever schedules without cancelling first, and this is the only place
  /// that schedules.
  ///
  /// - Parameter request: which block, when it ends, and whether it should make a
  ///   noise.
  /// - Throws: whatever iOS reports if the alarm cannot be cancelled or set. The
  ///   engine turns that into a visible warning on the timer screen; an alarm
  ///   that silently fails to be set is the worst thing this feature could ship.
  func schedule(_ request: BlockAlarmRequest) async throws {
    try cancelOutstanding()

    // THE ONE PLACE AN END TIME BECOMES A LENGTH.
    // The app's record of a block is the wall-clock instant it ends, because
    // that is the only thing that survives the app being suspended. iOS's alarm
    // system wants the opposite: how many seconds from now. Converting in
    // exactly one place means there is exactly one place for the two to drift
    // apart, and it happens at the moment of scheduling so the answer is always
    // fresh. Anything that reschedules recomputes it rather than reusing it.
    let secondsFromNow = max(request.endsAt.timeIntervalSinceNow, Self.shortestCountdown)

    let attributes = AlarmAttributes(
      presentation: Self.presentation(for: request.kind),
      metadata: FocusAlarmMetadata(
        kind: request.kind,
        completedInSprint: request.completedInSprint,
        pomodorosPerSprint: request.pomodorosPerSprint),
      // A plain colour, taken from the design system's action role rather than
      // written as a value. iOS tints the buttons it draws for us with it.
      tintColor: Color(.action))

    let configuration = AlarmManager.AlarmConfiguration.timer(
      duration: secondsFromNow,
      attributes: attributes,
      // The Dismiss button on the alert iOS draws when the alarm fires runs the
      // same command as the Dismiss button on our own Lock Screen card.
      stopIntent: DismissBlockIntent(),
      // Explicitly nothing. A second button on an alarm is how a snooze or a
      // repeat arrives, and this app has neither.
      secondaryIntent: nil,
      sound: Self.sound(enabled: request.soundEnabled))

    _ = try await AlarmManager.shared.schedule(id: request.id, configuration: configuration)
  }

  /// Cancels every alarm this app has set.
  ///
  /// **It asks iOS what is outstanding rather than remembering.** Remembering
  /// would be one line shorter and wrong: after the app has been closed and
  /// reopened this object is brand new and remembers nothing, while the alarm it
  /// set yesterday is still there. Asking iOS is the only version that heals
  /// itself, and it is also the defence against the one error AlarmKit
  /// reports — there is a cap on how many alarms an app may have outstanding,
  /// and a leak would eventually find it.
  ///
  /// - Throws: the first failure encountered. Every alarm is still attempted
  ///   first: stopping at the first failure would leave the rest outstanding,
  ///   which is the exact situation this method exists to prevent.
  func cancelOutstanding() throws {
    var firstFailure: (any Error)?

    for alarm in try AlarmManager.shared.alarms {
      do {
        try AlarmManager.shared.cancel(id: alarm.id)
      } catch {
        firstFailure = firstFailure ?? error
      }
    }

    if let firstFailure {
      throw firstFailure
    }
  }

  // MARK: Private

  /// The floor on how far ahead an alarm may be set, in seconds.
  ///
  /// Reached only when a block's end time has already passed by the time the
  /// alarm is being set — a phone that was busy, or a clock that moved. iOS will
  /// not accept an alarm for zero seconds away, so this asks for the smallest
  /// interval it will take rather than failing to set an alarm at all.
  private static let shortestCountdown: TimeInterval = 1

  /// The name of the bundled sound file used when the sound setting is off.
  ///
  /// **There is no "silent" option in the framework.** The alert sound is either
  /// the system default or a named file from the app's bundle — those are the
  /// only two things iOS offers here. Silence therefore has to be expressed as a
  /// file that contains silence, which is what `Silence.caf` is: half a second of
  /// digital nothing. The alarm still fires, the alert still appears, and the
  /// block still ends on time; the phone simply makes no noise.
  private static let silentSoundFileName = "Silence.caf"

  /// Turns iOS's answer about permission into the app's own.
  ///
  /// A deliberate translation rather than passing the framework's value around.
  /// It is what lets the engine, every screen and every test speak about
  /// authorization without any of them importing AlarmKit — which is the whole
  /// point of keeping this framework inside one file.
  private static func translate(_ state: AlarmManager.AuthorizationState) -> AlarmAuthorization {
    switch state {
    case .notDetermined: .notDetermined
    case .denied: .denied
    case .authorized: .authorized
    @unknown default: .denied
    }
  }

  /// Which sound the alarm makes.
  private static func sound(enabled: Bool) -> AlertConfiguration.AlertSound {
    enabled ? .default : .named(silentSoundFileName)
  }

  /// What iOS itself draws for a block: the title of the alert when the alarm
  /// fires, and the title on the countdown card.
  ///
  /// **This is a second copy of the block's name, and that is the framework's
  /// shape rather than a mistake.** Two different programs draw a running block.
  /// The alert screen when the alarm goes off is drawn by iOS, which can only see
  /// what is in here. The Lock Screen card is drawn by our own widget, which can
  /// only see the metadata. They are two renderers with two separate data paths.
  /// Both names come from the same `BlockKind`, so they cannot disagree.
  ///
  /// **There is no pause control, and its absence is deliberate.** AlarmKit's own
  /// guidance suggests offering pause and resume on a countdown, and the framework
  /// makes both optional precisely so an app can decline. This one declines: the
  /// spec's list of what the timer may be customised with does not include pause,
  /// a paused pomodoro is not a pomodoro under the method, and a pause button on a
  /// Lock Screen is the easiest way to turn a focus block into a twenty-minute
  /// negotiation with yourself. `pauseButton` is `nil` below and the paused
  /// presentation is left out entirely, which is how that is said in code. Please
  /// do not "fix" it.
  private static func presentation(for kind: BlockKind) -> AlarmPresentation {
    AlarmPresentation(
      alert: AlarmPresentation.Alert(
        title: alertTitle(for: kind),
        // iOS 26.1 stopped using this button and offers an initialiser without
        // it. This app's minimum is iOS 26.0, where the button is still what a
        // person taps, so the older initialiser is the correct one to call and
        // the deprecation does not apply at this deployment target. Raising the
        // minimum to avoid it would be a change to the spec, not a build fix.
        stopButton: AlarmButton(
          text: "Done",
          textColor: Color(.action),
          systemImageName: "checkmark")),
      countdown: AlarmPresentation.Countdown(
        title: LocalizedStringResource(stringLiteral: kind.displayName),
        pauseButton: nil))
  }

  /// The sentence iOS shows when the alarm goes off.
  ///
  /// Plain statements of fact. No exclamation marks and no encouragement: this
  /// alert sounds through silent mode and through a Focus, and something that
  /// loud should say the minimum.
  private static func alertTitle(for kind: BlockKind) -> LocalizedStringResource {
    switch kind {
    case .work: "Focus block finished"
    case .shortBreak: "Short break over"
    case .longBreak: "Long break over"
    }
  }
}
