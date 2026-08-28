import AVFoundation
import Foundation

/// Plays one bundled alert sound, once, so a person can hear it before choosing
/// it. `D28`.
///
/// **THIS IS A SECOND AUDIO SYSTEM, AND `F2c` REFUSED TO BUILD IT.** That plan's
/// words: *"playing an alarm inside Settings is a new audio path, `AlarmKit` does
/// not offer it, and `AVAudioPlayer` for it would be a second sound system."* The
/// reasoning was right and the cost was real — the owner then hit the gap it
/// bought: three sounds in a picker and no way to hear one without running a
/// block to its end. Choosing between sounds you cannot hear is not a choice.
///
/// So it is built, and kept as small as a thing can be: one file, one player, one
/// file at a time, no queue, no loop, no volume, no state anybody else can see.
/// It does not know about `MusicCoordinator` and `MusicCoordinator` does not know
/// about it.
///
/// WHY IT DOES NOT CONFIGURE THE AUDIO SESSION ITSELF
/// **Because this app already has exactly one audio-session policy, and a second
/// one broke it.** The first version of this file set `.playback` with
/// `.mixWithOthers` and called `setActive(false)` when it stopped. Both were
/// wrong, and the adversarial review found them before a phone did:
///
/// - `AudioSessionInterruptions.prepareForPlayback()` sets `.playback` with **no
///   options**, and its own comment says the session is *"deliberately never
///   turned off again"*. Overwriting the options left the process in a mixable
///   session for the rest of its life — and a mixable session is not interrupted
///   by other apps, so the interruption notices `F4`'s music-resume depends on
///   would stop arriving in the ordinary way.
/// - `stop()` deactivated the shared session unconditionally, including when
///   nothing had ever been previewed. Opening Settings and closing it again was
///   enough to hand back a session the app's own music needs.
///
/// So this file configures nothing of its own. It asks for the same preparation
/// the music path asks for, which is idempotent by design, and it never
/// deactivates. `.playback` is what makes a preview audible with the ringer
/// switch off — and that matters, because the sound being chosen certainly will
/// be audible then; a preview that goes quiet on a silent phone teaches the
/// opposite of the truth about the thing it is previewing.
///
/// **The trade-off, stated rather than hidden:** with one non-mixable policy, a
/// preview can interrupt audio from another app — exactly as starting a block's
/// music already does. One session, one policy, one place to change it.
@MainActor
final class AlertSoundPreview {
  // MARK: Internal

  /// Plays a sound once. Any previous preview stops first.
  ///
  /// Silently does nothing for a sound with no file of its own — `systemDefault`
  /// is iOS's alert sound, not something this app holds. The *screen* is what
  /// says so; this refuses rather than pretending.
  func play(_ sound: AlertSound) {
    stop()
    guard let fileName = sound.fileName else { return }
    let name = (fileName as NSString).deletingPathExtension
    let type = (fileName as NSString).pathExtension
    guard let url = Bundle.main.url(forResource: name, withExtension: type) else { return }

    do {
      // The app's own preparation, not a second one. Idempotent: calling it
      // again is what already happens on every music load.
      try AudioSessionInterruptions.prepareForPlayback()
      let player = try AVAudioPlayer(contentsOf: url)
      // **NO LOOP.** `numberOfLoops` defaults to zero, which is once; it is
      // written down because a preview that repeats is a sound somebody has to
      // hunt for an off switch for, and that is the defect `D26` exists to fix
      // arriving in the feature built to prevent choosing sounds blind.
      player.numberOfLoops = 0
      player.play()
      self.player = player
    } catch {
      // A preview that fails is a preview that does not happen. There is nothing
      // to tell the person that would help them, and an error banner on a
      // settings screen for a sound that did not play is noise about noise.
      player = nil
    }
  }

  /// Stops whatever is playing.
  ///
  /// **Called on every way out of the screen**, not only the tidy one — see
  /// `SettingsView`. A preview that outlives the screen it started from is a
  /// sound with no off switch.
  ///
  /// **Does nothing when nothing is playing, and touches the session never.**
  /// The version this replaced deactivated the shared session on every call, so
  /// merely opening and closing Settings handed back a session the app's own
  /// music depends on staying active.
  func stop() {
    guard let player else { return }
    player.stop()
    self.player = nil
  }

  // MARK: Private

  private var player: AVAudioPlayer?
}
