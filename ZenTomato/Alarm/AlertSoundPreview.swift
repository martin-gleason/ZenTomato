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
/// WHY THE SESSION CATEGORY IS THE WHOLE OF THE RISK
/// Two requirements pull in opposite directions. The preview **must be audible
/// with the ringer switch off**, because the sound being chosen certainly will be
/// — that is what `AlarmKit` is for — and a preview that goes quiet on a silent
/// phone teaches the opposite of the truth about the thing it is previewing. And
/// it **must not stop the person's music**.
///
/// `.playback` with `.mixWithOthers` is the pair that does both: `.playback`
/// ignores the ringer switch, `.mixWithOthers` declines to interrupt anything
/// already playing. **This is the part that fails quietly** — a misconfigured
/// session does not crash, it just behaves differently on a device than in a
/// simulator — so `F2e`'s *Done when* checks it on a phone with the switch off
/// and a playlist running, rather than asserting it here.
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
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
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

  /// Stops whatever is playing and hands the audio session back.
  ///
  /// **Called on every way out of the screen**, not only the tidy one — see
  /// `SettingsView`. A preview that outlives the screen it started from is a
  /// sound with no off switch.
  func stop() {
    player?.stop()
    player = nil
    // Deactivating tells whatever was playing before that it may resume its
    // normal volume. Failing to is not worth reporting: the sound has already
    // stopped, which is what was asked for.
    try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
  }

  // MARK: Private

  private var player: AVAudioPlayer?
}
