import AVFoundation
import Foundation

/// The app's arrangement with iOS about sound: what kind of audio this is, and
/// being told when something else takes it away.
///
/// WHAT A READER WHO DOES NOT WRITE SWIFT NEEDS TO KNOW
/// Only one app at a time really owns the speaker. iOS calls the arrangement an
/// audio session, and an app has to say what it is for before it makes a noise.
/// Saying "this is playback" is what allows the sound to keep going with the
/// screen locked — which, for a Pomodoro timer, is the entire point, since the
/// phone is meant to be face down. It is also what makes a phone call able to
/// take the sound away and give it back afterwards, which is the other half of
/// this file.
///
/// **WHY THIS IS A NAMESPACE OF FUNCTIONS AND NOT AN OBJECT.** There is exactly
/// one audio session on a phone; it is not something an app can have two of. An
/// object here would be a handle on a singleton, and — more practically — it
/// would be a thing the coordinator had to hold, and a thing held by the
/// coordinator cannot be cleaned up in the one place Swift lets a main-thread
/// object clean up after itself. As functions, there is nothing to hold and
/// nothing to release.
///
/// **WHAT THIS DOES NOT DO.** It never lowers, raises or reads the sound level,
/// it never moves the play position, and it never starts or stops anything. It
/// says what kind of audio this is, turns the session on, and reports
/// interruptions. Deciding what to do about an interruption belongs to
/// `MusicCoordinator`, and that decision goes through the same single rule as
/// every other event in this feature.
///
/// **THE HONEST LIMIT, STATED HERE RATHER THAN DISCOVERED LATER.** Declaring
/// playback audio keeps this app alive in the background **while sound is
/// actually coming out**. It does not keep it alive while paused. During a
/// break this app is silent, and iOS may suspend it — so what happens at the
/// end of a long break is that the alarm wakes the app and the music decision
/// is made then. Whether the music arrives at the boundary instant or a moment
/// after the alarm is a question only a real phone can answer, and it is what
/// the device check is for. Nothing here claims either way.
@MainActor
enum AudioSessionInterruptions {
  /// Something took the sound away, or gave it back.
  enum Event: Equatable, Sendable {
    /// Something else has the speaker now. Nothing to do: iOS has already
    /// silenced this app by the time anybody hears about it.
    case began

    /// The interruption is over.
    ///
    /// - Parameter mayResume: whether iOS considers it reasonable to make a
    ///   noise again. **This is a permission and never an instruction.** iOS
    ///   knows nothing about breaks; it only knows the speaker is free. The
    ///   coordinator uses it to decide whether to ask its own rule at all, and
    ///   the rule decides the rest.
    case ended(mayResume: Bool)
  }

  /// Tells iOS this app plays audio, and turns the session on.
  ///
  /// Called immediately before the first track of a block is queued, and never
  /// at launch — an app that claims the speaker before it has anything to play
  /// is an app that interrupts whatever the person was already listening to for
  /// no reason. Calling it again is harmless and is what happens on every
  /// subsequent load.
  ///
  /// The session is deliberately never turned off again. Handing it back
  /// between blocks would mean re-claiming it at every boundary, which is more
  /// moving parts on the path that has to work four times an hour, for the sake
  /// of a break during which this app is making no sound anyway.
  ///
  /// - Throws: whatever iOS says when it refuses. The caller turns that into a
  ///   music failure and a quiet timer; it never travels further.
  static func prepareForPlayback() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default)
    try session.setActive(true)
  }

  /// A stream of interruptions, for as long as the caller reads it.
  ///
  /// The caller owns it: cancelling the task it is read in ends the stream and
  /// stops listening. Nothing here runs unattended.
  static func events() -> AsyncStream<Event> {
    AsyncStream { continuation in
      let listener = Task { @MainActor in
        let notices = NotificationCenter.default.notifications(
          named: AVAudioSession.interruptionNotification)

        for await notice in notices {
          guard let event = event(from: notice) else { continue }
          continuation.yield(event)
        }
        continuation.finish()
      }

      continuation.onTermination = { _ in listener.cancel() }
    }
  }

  // MARK: Private

  /// Reads one of iOS's notifications.
  ///
  /// **Not private, so that it can be given a hand-built notification in a
  /// test.** This is the only place in the feature where a value arrives from
  /// outside in a shape nobody controls — a dictionary with two optional keys —
  /// and every branch of it decides whether music starts. Reachable only from
  /// this file and from the test bundle; nothing in the app calls it.
  ///
  /// Returns `nil` for anything it cannot make sense of, rather than guessing.
  /// A malformed notification is not evidence that an interruption began or
  /// ended, and acting on a guess here would mean starting or stopping music
  /// for no reason anybody could later explain.
  static func event(from notice: Notification) -> Event? {
    guard let rawType = notice.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return nil }

    switch type {
    case .began:
      return .began

    case .ended:
      // Absent means "no", which is the safe reading: with no permission to
      // make a noise, this app stays quiet and the block carries on regardless.
      let rawOptions = notice.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
      let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
      return .ended(mayResume: options.contains(.shouldResume))

    @unknown default:
      // A kind of interruption that did not exist when this was written. Doing
      // nothing leaves a silent timer, which is this feature's standing answer
      // to everything it does not understand.
      return nil
    }
  }
}
