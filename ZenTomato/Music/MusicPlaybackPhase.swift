import Foundation

/// The one rule that decides whether there is sound.
///
/// **EVERYTHING IN THIS FEATURE IS DERIVED FROM THE FIRST FUNCTION BELOW.**
/// Not "checked against it" — derived from it. A block boundary, a phone call
/// ending, a subscription lapsing, the switch being flipped and a playlist being
/// chosen are five different events, and all five go through one method on
/// `MusicCoordinator`, which asks this question and does what the answer says.
/// There is no second path to the player.
///
/// That is what makes the feature's sharpest requirement — *music must never
/// resume into a break* — a structural fact rather than a condition somebody
/// remembered to write. A phone call that ends nine minutes into a fifteen-
/// minute long break arrives at a coordinator that asks this function, is told
/// the block is not a focus block, and stays quiet. There is no line anywhere in
/// the interruption path that could have said otherwise, because the
/// interruption path contains no way to start sound at all.
///
/// **WHY IT IS A FREE FUNCTION OVER FINISHED VALUES.** No timer, no player, no
/// database and no framework are needed to ask it. Five plain facts go in and a
/// yes or no comes out, which means every combination — including the ones that
/// only happen on a real phone with no subscription at 3pm on the fourth
/// pomodoro — is provable in a test that runs in microseconds. It is the shape
/// `TimerCycle.next(after:…)` already uses for the timer's own hardest rule, for
/// the same reason: the part most worth proving is the part with no machinery in
/// it.
///
/// An `enum` with no cases: a namespace holding two functions, never an instance
/// of anything.
enum MusicPlaybackPhase {
  /// Whether sound is permitted right now. Everywhere else is silence.
  ///
  /// All five conditions must hold, and each one is somebody's ratified
  /// decision rather than an implementation detail:
  ///
  ///   * **A block is running.** An idle timer plays nothing, including
  ///     between blocks when the next one has not been started.
  ///   * **It is a focus block.** Music pauses on every break, short and long
  ///     alike. There is no separate long-break behaviour anywhere in this
  ///     feature and this is why.
  ///   * **Music is switched on.** The switch is the person's standing
  ///     intention and it is set before a sprint.
  ///   * **Music is available.** No permission, no subscription, or a check
  ///     that failed, all mean silence — and mean nothing else at all. The
  ///     timer never sees this.
  ///   * **Something has been chosen.** "On, nothing chosen, plays nothing" is
  ///     a control that silently does nothing, which D19.1 rejects by name.
  ///
  /// - Parameters:
  ///   - isRunning: whether any block is counting.
  ///   - kind: which kind of block that is.
  ///   - isEnabled: whether music is switched on.
  ///   - availability: whether this app may play music at all.
  ///   - selection: the chosen playlist or song, or `nil`.
  /// - Returns: `true` only in the one situation where music belongs.
  static func shouldSound(
    isRunning: Bool,
    kind: BlockKind,
    isEnabled: Bool,
    availability: MusicAvailability,
    selection: MusicSelection?
  ) -> Bool {
    isRunning
      && kind == .work
      && isEnabled
      && availability.permitsPlayback
      && selection != nil
  }

  /// When there is to be silence, whether the queue is let go of or kept.
  ///
  /// **This is the only judgement in the whole of the playback path, and it is
  /// made once, here.** The difference matters for exactly one reason: a kept
  /// queue is what makes the next focus block resume the same track at the same
  /// second, and a released queue is what makes the first focus block of a new
  /// sprint start the playlist from the top.
  ///
  ///   * **A break** keeps the queue. That is the whole of "resumes mid-track".
  ///   * **The gap between blocks with auto-start switched off** keeps it too.
  ///     The sprint is still going; the person is standing up for a minute.
  ///   * **The end of a sprint** lets it go. The ratified wording is *"at
  ///     sprint end it stops and leaves the system player alone"*, and an
  ///     abandoned sprint is a sprint that is over.
  ///   * **Music being switched off** lets it go. Holding a queue for a feature
  ///     the person has just turned off would mean the app was still holding
  ///     the audio it said it had given back.
  ///
  /// **WHY MUSIC BECOMING *UNAVAILABLE* IS NOT ON THAT LIST, THOUGH IT ONCE
  /// WAS.** A subscription lapsing, a check that could not be completed, a
  /// library that would not answer for a moment: those are conditions of the
  /// phone, and this feature says so in the one other place it has to decide —
  /// the person's switch is deliberately left where they put it, because *"a
  /// device condition is not a change of mind"*. Letting the queue go on the
  /// same condition contradicted that in the same feature, and it did it
  /// audibly: a subscription that flickers during a renewal, or a network blip
  /// clearing, would throw the place in the track away and start the playlist
  /// from the top in the middle of the afternoon. That is precisely the defect
  /// pause-and-resume exists to prevent, reached from a different direction.
  /// Unavailable mid-sprint now pauses; when the sprint ends, `sprintIsOver`
  /// releases the queue as it always did.
  ///
  /// - Parameters:
  ///   - sprintIsOver: whether the timer is at rest with no sprint in progress.
  ///   - isEnabled: whether music is switched on.
  /// - Returns: `true` to let the queue go, `false` to keep it and the position
  ///   in it.
  static func releasesQueue(sprintIsOver: Bool, isEnabled: Bool) -> Bool {
    sprintIsOver || !isEnabled
  }
}
