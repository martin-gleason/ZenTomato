import Foundation

/// The whole of what this app may ask of a music player.
///
/// **THIS PROTOCOL IS A FENCE, AND THE FENCE IS THE TYPE.**
/// The contract says one thing about music during a sprint, and says it twice:
/// skip-forward is the *only* control. That is a rule prose cannot hold. The
/// concrete Apple player this app sits on hands an engineer, on the same
/// object, methods for going back a track, for moving the play position by
/// hand, for restarting the current track from its beginning, for random order,
/// for loudness, and for turning the looping off. Any of those is one line
/// away, would compile, and would work.
///
/// So none of them is written down here. Seven members, listed below, are the
/// entire vocabulary the rest of this app has for sound. An engineer who wants
/// a progress bar cannot add one without editing this file, and that edit is a
/// diff the owner reads. That is the mechanism — not a review, not a comment,
/// not a note in a plan.
///
/// **WHY `resume()` TAKES NO ARGUMENT.** The contract says music pauses on
/// every break and resumes at the next focus block, and *resume* means resume:
/// the same track, at the same second it was interrupted, not the playlist
/// starting over. Because this method accepts no position and there is no
/// position to read anywhere in this file, "start again from the beginning" is
/// not a sentence this protocol can say. Mid-track resume is therefore not a
/// behaviour anybody has to remember to implement; it is the only behaviour
/// available.
///
/// **WHY `pause()` AND `stop()` ARE TWO WORDS.** `pause` keeps the queue and
/// the position, which is what a break is. `stop` lets the queue go, which is
/// what the end of a sprint is — the ratified decision reads *"at sprint end it
/// stops and leaves the system player alone"*. That difference is the whole of
/// the distinction, and it lives here rather than being re-decided at each call
/// site.
///
/// **PLAYBACK ITSELF IS NOT UNIT-TESTABLE, AND THE SPLIT IS STATED RATHER THAN
/// GLOSSED.** There is no simulator for "sound came out of the phone": the
/// build machine has no music library and no Apple Music subscription. So the
/// split is explicit and it is the reason this protocol exists at all. Every
/// decision this app makes about *when* to play, pause, resume, stop and skip
/// is proved against a stand-in that records what it was asked to do, with no
/// framework linked and no sound produced. Whether the sound actually comes out
/// is covered by the device check on the owner's phone, and by nothing else.
/// A test in this repository claiming that music played would be a lie.
///
/// **THE SYSTEM'S OWN CONTROLS CANNOT BE SWITCHED OFF, AND THIS IS THE HONEST
/// STATEMENT OF IT.** Control Centre, the Lock Screen, a set of headphones and
/// CarPlay will all offer play, pause and go-back for whatever is playing.
/// That is iOS's contract with the person holding the phone and no app is
/// allowed to opt out of it. What this app controls is its own screen, where
/// skip-forward is the only control there is. If somebody uses one of the
/// system's controls, this app's idea of what is happening and the player's can
/// disagree until the next block boundary, at which point the coordinator
/// re-states the truth. `isPlaying` below is answered by the player itself
/// rather than by this app's memory of what it last asked for — the coordinator
/// asks it again at every moment sound could have started or stopped, and again
/// whenever the app comes back to the front, and the skip button follows that.
///
/// `@MainActor` puts every music decision on one thread, for the same reason
/// the alarm protocol gives: it removes any question about whether a pause
/// issued at a block boundary and a resume issued when a phone call ends can
/// arrive out of order. `AnyObject` means only a class may implement it — a
/// player holds state, and a value type would copy it.
@MainActor
protocol MusicPlaying: AnyObject {
  /// What is queued right now, or `nil` when nothing is.
  ///
  /// This is what makes resume-rather-than-restart decidable without asking the
  /// player where it is: if what is already queued is what we want, we resume;
  /// otherwise we load. `stop()` clears it, which is why the first focus block
  /// of a new sprint always starts the playlist from the top and a focus block
  /// after a break never does.
  var loaded: MusicSelection? { get }

  /// Whether sound is actually coming out right now.
  ///
  /// Answered by the player rather than by this app's record of what it last
  /// asked for, so that a pause tapped in Control Centre is reflected here. The
  /// skip button's presence on screen comes from this and nothing else —
  /// through `MusicCoordinator.isPlaying`, which asks this question again at
  /// every moment it could have changed and stores the answer, because a screen
  /// can only redraw on a stored value.
  var isPlaying: Bool { get }

  /// Called when the player's own playback status changes, for any reason.
  ///
  /// **This is a notification, not a control**, and it is the reason the skip
  /// button is ever visible. `isPlaying` is read from the player rather than
  /// inferred from what this app last asked for — but a player reports that it
  /// is playing *asynchronously*, some time after `resume()` or `load()` has
  /// already returned. A single reading taken at the end of those calls catches
  /// the moment before the status flips, records "not playing", and is never
  /// corrected; the skip button then stays hidden for the whole block.
  ///
  /// That is not a hypothetical. It shipped, and it presented as a skip button
  /// that appeared in one sprint and not the next — a race, so it looked
  /// intermittent rather than wrong.
  ///
  /// Adding this does **not** widen the skip-only fence: it carries nothing and
  /// commands nothing. Nobody can seek, scrub or go back through a callback that
  /// takes no arguments.
  var onPlaybackStatusChanged: (() -> Void)? { get set }

  /// Queues this selection, sets it to loop for ever, and starts it.
  ///
  /// **The only thing in this app that can start a track from its beginning.**
  /// Looping is not a mode anybody can turn off: it is a fixed property of
  /// loading, set inside the one file that talks to Apple's player and named
  /// nowhere else. The contract's wording is *"playlist loops when it ends"*,
  /// and a single chosen song loops the same way.
  ///
  /// - Parameter selection: the playlist or song to play.
  /// - Throws: `MusicPlaybackError.selectionMissing` when the item is no longer
  ///   in the user's library, and `MusicPlaybackError.playbackFailed` when the
  ///   player refused for any other reason. Both leave a silent working timer.
  func load(_ selection: MusicSelection) async throws

  /// Continues from wherever the queue already stands.
  ///
  /// Does nothing at all when nothing is loaded, rather than failing: a resume
  /// with nothing to resume is a no-op, not an error, and the caller has no
  /// different action to take either way.
  ///
  /// - Throws: `MusicPlaybackError.playbackFailed` if the player refused.
  func resume() async throws

  /// Silence, keeping the queue and the position. This is what a break is.
  func pause()

  /// Silence, and let the queue go. This is what the end of a sprint is.
  func stop()

  /// Moves to the next track.
  ///
  /// The single transport control this app has, in its own screen and in its
  /// own vocabulary. There is no counterpart going the other way, and adding
  /// one means adding a line to this file.
  ///
  /// - Throws: `MusicPlaybackError.playbackFailed` if the player refused.
  func skipForward() async throws
}
