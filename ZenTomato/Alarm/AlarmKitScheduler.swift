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
  func schedule(_ request: BlockAlarmRequest, sparing: UUID?) async throws {
    // **`sparingAlerting: false`, and that reversal is the point.**
    //
    // Sparing by state was added first, before identity sparing existed, and it
    // has now done more harm than the problem it solved. An alarm that has fired
    // and not been dismissed stays `.alerting` — the owner watched one sit for
    // over thirty seconds — so the state check spared it at every subsequent
    // boundary. Nothing ever cleared it, and a sprint accumulated one stale alarm
    // per block: alerts that reappeared during later blocks, and a dismiss that
    // silenced a stale alarm instead of the current one.
    //
    // Identity does the whole job and does it precisely: exactly one alarm needs
    // to survive a schedule — the block that just ended, whose alarm is ringing or
    // about to. Everything else is from a block that is over and must go.
    try cancelOutstanding(sparingAlerting: false, sparing: sparing)

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
      sound: Self.sound(enabled: request.soundEnabled, choice: request.alertSound))

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
  func cancelOutstanding(sparingAlerting: Bool) throws {
    try cancelOutstanding(sparingAlerting: sparingAlerting, sparing: nil)
  }

  func cancelOutstanding(sparingAlerting: Bool, sparing: UUID?) throws {
    var firstFailure: (any Error)?

    for alarm in try AlarmManager.shared.alarms {
      // **AN ALARM THAT IS RINGING IS NOT AN ALARM IN THE WAY.**
      //
      // Every schedule clears what is outstanding first, so that a stale alarm
      // cannot sound four minutes into the block after the one it belonged to.
      // That is right for an alarm still counting down and catastrophic for one
      // already making a noise: with auto-start on, the next block is scheduled
      // the instant the previous one ends — the same instant its alarm fires —
      // and clearing the way would silence the alarm to make room for the next.
      //
      // That is the same defect `boundaryReached()` used to have, arriving
      // through the door of a different method. `Alarm.State.alerting` is how
      // iOS distinguishes the two, and it is checked rather than inferred from
      // the clock.
      //
      // An explicit stop or dismiss passes `false` and silences everything,
      // because being asked for silence is exactly when silence is wanted.
      // **Identity first, because state is a race.** The alarm named here is the
      // one for the block that just ended: it is due at this instant, and asking
      // whether it has reached `.alerting` yet is asking who won a footrace.
      if let sparing, alarm.id == sparing { continue }
      if sparingAlerting, alarm.state == .alerting { continue }
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

  // MARK: An alarm that is ringing right now

  /// See `AlarmScheduling.alertingAlarmID`.
  /// See `AlarmScheduling.currentAlertingAlarmID`.
  func currentAlertingAlarmID() throws -> UUID? {
    try AlarmManager.shared.alarms.first { $0.state == .alerting }?.id
  }

  var alertingAlarmID: UUID? {
    // A read of `alarms` rather than of cached state. The cache would be one
    // more thing that can disagree with iOS, and this is not a hot path — it is
    // read when a screen appears and when the stream below says something moved.
    // The forgiving read, for the places where "could not ask" and "nothing is
    // ringing" really are the same thing — drawing a screen, and seeding the
    // stream below. `silenceAlarm()` uses the throwing one instead; see the
    // protocol for why that distinction matters there.
    try? currentAlertingAlarmID()
  }

  /// See `AlarmScheduling.alertingUpdates`.
  ///
  /// `AlarmManager.alarmUpdates` is the SDK's own sequence of the whole alarm
  /// list. **Checked in `AlarmKit.swiftinterface` rather than assumed** — the
  /// plan for this feature required that, because three framework assumptions
  /// about this alarm have already been wrong and each cost a device round trip.
  ///
  /// Reduced to "which of ours is ringing", and de-duplicated, so a screen
  /// re-renders when the answer changes and not every time any alarm ticks.
  func alertingUpdates() -> AsyncStream<UUID?> {
    AsyncStream { continuation in
      // **THE HANDLER IS INSTALLED BEFORE THE TASK EXISTS**, via a box, because
      // the other order leaves a window: a consumer that cancels between the
      // `Task` starting and `onTermination` being assigned leaves the task
      // running with nothing holding a reference to cancel it.
      let box = WatchBox()
      continuation.onTermination = { _ in box.cancel() }
      box.task = Task { @MainActor in
        // The current answer first, so a screen that starts listening after an
        // alarm has already begun still sees it.
        var last = alertingAlarmID
        continuation.yield(last)
        for await alarms in AlarmManager.shared.alarmUpdates {
          if Task.isCancelled { break }
          let ringing = alarms.first { $0.state == .alerting }?.id
          guard ringing != last else { continue }
          last = ringing
          continuation.yield(ringing)
        }
        continuation.finish()
      }
    }
  }

  /// Holds the watching task so a cancellation handler can be installed before
  /// the task is created.
  ///
  /// A tiny class rather than a captured `var`, because the handler must be able
  /// to reach a value that does not exist yet.
  private final class WatchBox: @unchecked Sendable {
    var task: Task<Void, Never>?
    func cancel() { task?.cancel() }
  }

  /// See `AlarmScheduling.stopAlerting`.
  func stopAlerting(id: UUID) throws {
    try AlarmManager.shared.stop(id: id)
  }

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

  /// Renders the decision into the two shapes the framework offers.
  ///
  /// **The rule itself is in `AlarmSoundDecision.decide`, not here**, because
  /// here it could not be tested: this function is unreachable from a test and
  /// `AlertConfiguration.AlertSound` is not usefully comparable. This is a
  /// translation with no judgement in it, and every judgement it used to hold is
  /// now asserted in `AlarmSoundDecisionTests`.
  ///
  /// `Silence.caf` is how "off" is expressed, because `AlarmKit` has no silent
  /// case — the alert sound is the system default or a named bundle file and
  /// nothing else, so silence has to be a file containing silence.
  private static func sound(enabled: Bool, choice: AlertSound) -> AlertConfiguration.AlertSound {
    switch AlarmSoundDecision.decide(soundEnabled: enabled, choice: choice) {
    case .silent: .named(silentSoundFileName)
    case .systemDefault: .default
    case .bundled(let fileName): .named(fileName)
    }
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
