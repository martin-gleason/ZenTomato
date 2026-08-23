import Foundation

// swiftlint:disable file_length
//
// THE ONLY LINT RULE THIS FILE TURNS OFF, AND WHY.
// `file_length` counts documentation, and roughly two thirds of what follows is
// documentation. This project requires every type and every non-obvious member
// to be argued in prose for a reviewer who reads code but does not write Swift,
// and this file is the feature's one dense piece of behaviour: the single rule
// that produces sound, the ordering guard that stops a late resume winning, and
// the promise that no failure here can reach the timer all have to be explained
// where they are implemented. Splitting the class in two would only move the
// lines, and would force the private state that makes the ordering guard work to
// become visible to the rest of the app — real protection traded away for a line
// count. It is the same trade `TimerEngine`, `SessionPlanStore` and every long
// screen in this project already make. Every other rule stays on.

/// The one thing in this app that can make a sound, and the one thing that
/// decides when.
///
/// WHAT A READER WHO DOES NOT WRITE SWIFT NEEDS TO KNOW
/// Five different things can change whether music should be playing: the timer
/// moving from a focus block to a break, a phone call ending, an Apple Music
/// subscription lapsing, the switch being flipped, and a playlist being chosen.
/// Written the obvious way each of those would have its own little piece of
/// "…and now start the music" or "…and now stop it", five pieces that have to
/// agree with each other for ever. They would not. The commonest way that goes
/// wrong is audible and embarrassing: a phone call that ends in the middle of a
/// break, and the music comes back on while the person is away from the desk.
///
/// So none of those five does anything of its own. Every one of them records a
/// fact and calls `apply()`, and `apply()` asks one pure rule
/// (`MusicPlaybackPhase.shouldSound`) whether there should be sound, and then
/// makes the player agree. **`apply()` is the only method in this app that can
/// start music.** "Resuming into a break" is therefore not a bug that is
/// prevented; it is a sentence the code has no way of saying.
///
/// **THE TIMER CANNOT BE HURT BY ANYTHING IN HERE.** Nothing in this file is
/// ever called by the timer engine, nothing it does is awaited by the timer
/// engine, and no error it produces travels anywhere near one. It reads the
/// engine and never writes to it. Every failure below — a refused permission, a
/// lapsed subscription, a deleted playlist, a player that will not start — has
/// exactly one consequence: the app is quiet and one muted grey line on the
/// timer screen says why. That is D19.2, and it is the property the whole
/// feature is shaped to guarantee.
///
/// **HOW LATE ANSWERS ARE STOPPED FROM WINNING.** Loading and resuming suspend:
/// they take a moment, and in that moment the block can change. An older resume
/// finishing after a newer pause would leave sound running into a break. Two
/// mechanisms, both learned from the timer's own first blocking defect:
/// every `apply()` bumps a generation counter and cancels whatever is in
/// flight; and the suspended work re-checks that counter when it comes back and
/// — if it has been superseded — re-states the silence the newer decision asked
/// for rather than merely giving up. Cancelling alone is not enough, because
/// the player may already have started by the time the cancellation lands.
///
/// `@MainActor` puts every one of those events on one thread, so they queue
/// rather than interleave. `@Observable` is what lets the timer screen redraw
/// when any of the values below change.
@MainActor
@Observable
final class MusicCoordinator {
  // MARK: Lifecycle

  /// Builds the coordinator from its four collaborators.
  ///
  /// Every one of them is a protocol rather than a concrete type, which is what
  /// lets the whole of this class be driven in a test with no music framework
  /// linked, no database open and no sound produced anywhere.
  ///
  /// - Parameters:
  ///   - player: the seven-verb playback surface. The real one talks to Apple's
  ///     application-scoped player; the tests hand over a stand-in that writes
  ///     down what it was asked to do.
  ///   - availability: whether music may play at all, and permission-asking.
  ///   - library: the read-only view of the person's own library. Used here for
  ///     one thing only — finding out whether the chosen item is still there.
  ///   - preferences: where the switch and the chosen item are remembered.
  init(
    player: any MusicPlaying,
    availability: any MusicAvailabilityChecking,
    library: any MusicLibraryReading,
    preferences: any MusicPreferenceStoring
  ) {
    self.player = player
    self.availabilityChecker = availability
    self.library = library
    self.preferences = preferences
    // Read straight out of the store rather than awaited, so the screen has the
    // person's real switch position in its very first frame instead of drawing
    // "off" and correcting itself a moment later.
    isEnabled = preferences.isEnabled
    selection = preferences.selection
    self.availability = availability.current
  }

  /// Nothing this object started outlives it. There are five pieces of work it
  /// can have running and all five are called off here.
  ///
  /// **`isolated deinit` IS LOAD-BEARING AND NOT DECORATION.** Ordinarily the
  /// clean-up that runs when an object is released belongs to no thread, which
  /// means it cannot touch anything belonging to the main one — and everything
  /// in this class belongs to the main one. Marking it isolated is what allows
  /// this to reach its own five task handles at all. Without the keyword this
  /// does not compile, and the tempting fix is to delete the clean-up, which
  /// would leave two long-running pieces of work — the subscription to Apple
  /// and the one to audio interruptions — running for the rest of the process's
  /// life with nothing to report to.
  isolated deinit {
    availabilityTask?.cancel()
    interruptionTask?.cancel()
    libraryTask?.cancel()
    soundTask?.cancel()
    skipTask?.cancel()
  }

  // MARK: What the screens read

  /// Whether music is switched on. The person's standing intention, which is
  /// not the same as whether anything can actually play.
  private(set) var isEnabled: Bool

  /// The chosen playlist or song, or `nil` when nothing has been chosen.
  private(set) var selection: MusicSelection?

  /// Whether music may play at all, and the one line to show when it may not.
  private(set) var availability: MusicAvailability

  /// Whether the chosen item has left the person's library.
  ///
  /// `false` both when it is there and when nobody has looked — being absent
  /// from a library that has not been read is not evidence, and claiming
  /// otherwise would put "that playlist is gone" in front of somebody whose
  /// playlist is fine.
  private(set) var selectionIsMissing = false

  /// Whether a focus block has begun and the first track has not arrived yet.
  ///
  /// Loading a queue and starting it takes a moment on a real phone. Without
  /// this the row would sit on the chosen title in silence and look stuck.
  private(set) var isStarting = false

  /// Whether the last attempt to make sound failed.
  ///
  /// Cleared the next time anything plays. The screen's answer is one sentence
  /// and no retry control: the start of the next focus block tries again on its
  /// own, so there is nothing to retry by hand.
  private(set) var lastPlaybackFailed = false

  /// Whether sound is actually coming out right now.
  ///
  /// **A REMEMBERED COPY OF A LIVE ANSWER, AND THE DISTINCTION IS THE WHOLE
  /// POINT.** The player is the authority; this is asked of it again at every
  /// moment sound could have started or stopped — after a load, after a resume,
  /// at every silence, after a skip, and when the app comes back to the front —
  /// and the answer is stored here.
  ///
  /// It is stored rather than computed because the timer screen is redrawn by
  /// observing the values on this object, and observation follows *stored*
  /// values only. Written as a computed property it looked live and was in fact
  /// the opposite: the screen never redrew when it changed, so a pause tapped in
  /// Control Centre left a skip button on screen that did nothing until
  /// something else happened to redraw the row. That was a visible control that
  /// silently no-ops — the one thing this feature spent a protocol fence to
  /// avoid.
  ///
  /// **What this still cannot do**, and it is the honest limit: the system's own
  /// controls can pause what this app started at any moment, and iOS does not
  /// tell an app when they are used. So between one of the refresh points above
  /// and the next, this app's idea and the player's can disagree. Returning to
  /// the app refreshes it, and so does the next block boundary.
  private(set) var isPlaying = false

  /// Whether a block is counting right now. Read by the screen to decide
  /// whether the switch may be touched.
  private(set) var isTimerRunning = false

  // MARK: Starting up

  /// Begins listening for the two things that change underneath the app, and
  /// makes the first checks.
  ///
  /// Called once, by the app, at launch. Separate from `init` on purpose:
  /// building this object is free and safe anywhere, including in a preview and
  /// in a test, and none of those should start reading a subscription or
  /// subscribing to system notifications.
  ///
  /// Calling it twice does nothing the second time.
  func start() {
    guard !hasStarted else { return }
    hasStarted = true

    // The checker is captured, and `self` is not: the guard is **inside** the
    // loop rather than in front of it. Written the other way round the loop
    // header itself holds a strong reference for as long as the stream runs —
    // and this stream never finishes — so the `weak` would be defeated, this
    // object could never be released, and the clean-up above would never run.
    // The interruption loop below has always had it in the right place; this one
    // now matches it.
    availabilityTask = Task { @MainActor [weak self, availabilityChecker] in
      for await answer in availabilityChecker.changes() {
        guard let self else { return }
        availabilityChanged(to: answer)
      }
    }

    interruptionTask = Task { @MainActor [weak self] in
      for await event in AudioSessionInterruptions.events() {
        guard let self else { return }
        handleInterruption(event)
      }
    }

    refreshAvailabilityAndSelection()
  }

  /// Asks the world again: may this app play music, is the chosen item still
  /// there, and is sound actually coming out.
  ///
  /// **THIS IS THE WAY BACK FROM EVERY DEAD END IN THIS FEATURE.** Before it
  /// existed, availability was read once at launch and never again, and the two
  /// states most likely to be reached on a first run — permission refused, and a
  /// check that could not be completed because the phone was in a lift — were
  /// permanent for the life of the process. The app's own words made that worse:
  /// the sheet says to grant the permission in the Settings app and offers a
  /// button that opens it, and coming back afterwards changed nothing at all.
  /// Only force-quitting the app helped, and nothing said so.
  ///
  /// So it is called from the two moments that mean "the person may have just
  /// changed something": the app coming back to the front, and the Music sheet
  /// being opened. Both are reads with no side effect on the phone and neither
  /// can prompt for anything — the permission prompt is still reached only by
  /// switching music on.
  ///
  /// It also re-reads whether sound is coming out, which is the one honest
  /// answer to somebody having used Control Centre or their headphones while
  /// this app was in the background.
  func refreshAvailability() {
    refreshIsPlaying()
    refreshAvailabilityAndSelection()
  }

  // MARK: Events

  /// The timer has moved to a different block, or started, or come to rest.
  ///
  /// Called by `BlockPhaseObserver`, which is the only thing that calls it. The
  /// timer engine does not know this exists — F4 reads the engine and adds
  /// nothing to it.
  ///
  /// - Parameters:
  ///   - kind: the block now running, or the one that would start next.
  ///   - isRunning: whether it is actually counting.
  ///   - sprintIsOver: whether the timer is at rest with no sprint in progress,
  ///     as opposed to standing between two blocks of one. It is the difference
  ///     between letting the queue go and holding the position in it, and
  ///     working it out is the observer's job because it takes three facts from
  ///     the engine rather than one.
  func blockChanged(to kind: BlockKind, isRunning: Bool, sprintIsOver: Bool = false) {
    self.kind = kind
    isTimerRunning = isRunning
    self.sprintIsOver = sprintIsOver
    apply()
  }

  /// Switches music on or off.
  ///
  /// **Refused while a block is running**, because the contract says music is
  /// set before a sprint. That refusal is here, in the model, as well as on the
  /// screen — the switch is drawn dimmed and cannot be reached by a tap, by
  /// VoiceOver or by a keyboard. Two independent refusals, because the screen's
  /// one protects today's caller and this one protects every future caller.
  ///
  /// **Switching it on is the moment permission is asked for**, and the only
  /// moment. Three outcomes, and the important one is the third: if permission
  /// is refused the switch goes back to off rather than sitting in the on
  /// position while nothing can play, because a control that lies about itself
  /// is worse than one that says no.
  ///
  /// - Parameter enabled: where the person just put the switch.
  func setEnabled(_ enabled: Bool) async {
    guard !isTimerRunning else { return }

    guard enabled else {
      isEnabled = false
      preferences.setEnabled(false)
      apply()
      return
    }

    let answer = await availabilityChecker.requestAuthorization()
    // A block can have started while the system prompt was on screen. The rule
    // is asked again rather than assumed, exactly as it is after every other
    // suspension in this file.
    guard !isTimerRunning else { return }
    availability = answer

    guard answer.permitsPlayback else {
      isEnabled = false
      preferences.setEnabled(false)
      apply()
      return
    }

    isEnabled = true
    preferences.setEnabled(true)
    apply()
    refreshAvailabilityAndSelection()
  }

  /// Records the chosen playlist or song.
  ///
  /// **Also refused while a block is running**, for the same reason and with the
  /// same belt and braces. Choosing something does not start it: it will play
  /// from the next focus block, which is what the contract means by music being
  /// set before a sprint.
  ///
  /// - Parameter newSelection: what was chosen, or `nil` for nothing.
  func setSelection(_ newSelection: MusicSelection?) {
    guard !isTimerRunning else { return }
    selection = newSelection
    // Whatever was true of the old choice is not evidence about this one.
    selectionIsMissing = false
    lastPlaybackFailed = false
    preferences.setSelection(newSelection)
    apply()
  }

  /// Moves to the next track. The only transport control this app has.
  ///
  /// Does nothing when nothing is playing, which is also when the button that
  /// calls it is not on screen. A skip that fails asks `apply()` to re-state
  /// the truth rather than being ignored: if the music died underneath the
  /// skip, that is what starts it again.
  ///
  /// It deliberately does **not** bump the generation counter. A skip is not a
  /// change of mind about whether there should be sound, so it must not cancel
  /// a load that is in flight — but it still re-checks the counter afterwards,
  /// so a skip that lands after a break has begun cannot leave sound running.
  func skipForward() {
    guard player.isPlaying else { return }
    let mine = generation
    skipTask?.cancel()
    skipTask = Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        try await player.skipForward()
      } catch {
        // The one honest recovery: ask the rule what should be true now and
        // make it so. If the player has died, that resumes it; if the block has
        // changed, that keeps it quiet.
        apply()
        return
      }
      refreshIsPlaying()
      // A skip that lands after a break has begun must not leave sound running.
      if mine != generation {
        reassertSilenceIfWanted()
      }
    }
  }

  /// One audio interruption, routed to the only thing that can act on it.
  ///
  /// The two cases are deliberately lopsided and this method is where that is
  /// visible. An interruption **beginning** is not something this app does
  /// anything about: iOS has already silenced it by the time the notice
  /// arrives, and there is no state worth keeping, because what happens next is
  /// decided from scratch when the interruption ends or at the next block
  /// boundary, whichever comes first. An interruption **ending** is a fact
  /// worth asking the rule about.
  ///
  /// It is a method rather than a `switch` buried inside the listening loop so
  /// that "nothing happens when an interruption begins" is a claim a test can
  /// put to the real code — the whole path, from event to player — rather than
  /// a comment nobody can check.
  ///
  /// - Parameter event: what iOS reported.
  func handleInterruption(_ event: AudioSessionInterruptions.Event) {
    switch event {
    case .began:
      break
    case .ended(let mayResume):
      interruptionEnded(mayResume: mayResume)
    }
  }

  /// A phone call, or another app taking the audio, has finished.
  ///
  /// **`mayResume` is read as a permission, never as an instruction.** iOS says
  /// whether it would be reasonable to make a noise again; it knows nothing
  /// about breaks. So the answer is only ever used to decide whether to ask the
  /// rule at all, and the rule decides the rest. A call that ends nine minutes
  /// into a long break finds the block is not a focus block and the app stays
  /// silent.
  ///
  /// Note what is not in this method: there is no `resume()` here, and no way
  /// to reach one except through `apply()`, which cannot be argued with. That
  /// is the guarantee, not the comment.
  ///
  /// - Parameter mayResume: whether iOS says making a noise again is reasonable.
  func interruptionEnded(mayResume: Bool) {
    guard mayResume else { return }
    apply()
  }

  /// A new answer about whether music may play at all.
  ///
  /// The one that matters is a subscription lapsing mid-sprint: the music
  /// stops, the block runs to its own end, and the timer is never told. The
  /// person's switch is **not** turned off here — a device condition is not a
  /// change of mind, and when the subscription comes back the music returns
  /// without anybody having to switch it on again. The screen draws the switch
  /// off and dimmed while music is unavailable, which is a statement about the
  /// phone rather than a rewriting of what the person asked for.
  ///
  /// - Parameter answer: the new availability.
  func availabilityChanged(to answer: MusicAvailability) {
    guard answer != availability else { return }
    let wasReady = availability.permitsPlayback
    availability = answer
    apply()
    if answer.permitsPlayback, !wasReady {
      refreshAvailabilityAndSelection()
    }
  }

  // MARK: The one method that can produce sound

  /// Makes the player agree with the rule, whatever just happened.
  ///
  /// The whole of the feature's behaviour is these fifteen lines. Read it as:
  /// *should there be sound? If yes, continue what is already queued or queue
  /// the chosen thing and start it. If no, go quiet — keeping the position
  /// through a break, letting the queue go at the end of a sprint.*
  ///
  /// Silence is issued straight away and without suspending, which is why it can
  /// never lose a race with anything. Only starting sound has to wait, and only
  /// starting sound is guarded by the generation counter.
  private func apply() {
    generation &+= 1
    let mine = generation
    soundTask?.cancel()
    soundTask = nil

    let wantsSound = MusicPlaybackPhase.shouldSound(
      isRunning: isTimerRunning,
      kind: kind,
      isEnabled: isEnabled,
      availability: availability,
      selection: selection)

    guard wantsSound, let wanted = selection else {
      isStarting = false
      goQuiet()
      return
    }

    isStarting = true
    soundTask = Task { @MainActor [weak self] in
      await self?.makeSound(wanted, generation: mine)
    }
  }

  /// Starts or continues the chosen item, then records how it went.
  ///
  /// The two branches are the whole of "resume means resume": if what is queued
  /// is already what we want, the queue is left alone and merely continued, so
  /// the track carries on at the second the break began. Loading is reached only
  /// when the queue holds something else or nothing — which after a released
  /// queue is the top of the playlist, and that is the only way a sprint ever
  /// starts a playlist over.
  private func makeSound(_ wanted: MusicSelection, generation mine: Int) async {
    // From here on this app is holding somebody's audio, whatever happens next.
    // Silence has to be issued for real rather than skipped as unnecessary.
    hasTouchedThePlayer = true
    let outcome: MusicPlaybackOutcome
    do {
      // **IDENTITY, NEVER THE WHOLE VALUE.** A selection carries its title as
      // well as its identifier, and the title changes on its own: a playlist
      // renamed in the Music app is picked up and written down by
      // `checkSelectionIsStillThere`. Comparing whole values would call a
      // renamed playlist a *different* playlist, take the load branch, and start
      // it again from the top — the one audible defect this feature was shaped
      // to make unsayable, arriving through an equality operator that happens to
      // include a display string. What decides resume-or-load is whether this is
      // the same thing, and the same thing under a new name is the same thing.
      if player.loaded?.identifier == wanted.identifier, player.loaded?.kind == wanted.kind {
        try await player.resume()
      } else {
        try await player.load(wanted)
      }
      outcome = .sounded
    } catch is CancellationError {
      outcome = .abandoned
    } catch MusicPlaybackError.selectionMissing {
      outcome = .itemHasGone
    } catch {
      outcome = .refused
    }

    refreshIsPlaying()

    guard mine == generation else {
      // A newer decision was taken while this was suspended. It has already
      // issued whatever it wanted, but the work above may have started sound
      // after that — so the newer decision is re-stated rather than trusted to
      // have won the race.
      reassertSilenceIfWanted()
      return
    }

    isStarting = false
    switch outcome {
    case .sounded:
      lastPlaybackFailed = false
      selectionIsMissing = false
    case .abandoned:
      break
    case .itemHasGone:
      selectionIsMissing = true
      lastPlaybackFailed = true
    case .refused:
      lastPlaybackFailed = true
    }
  }

  /// Silence, of the kind the rule asks for.
  ///
  /// **NOTHING IS SAID TO THE PLAYER UNTIL THIS APP HAS SOMETHING TO SILENCE.**
  /// This is reached at launch, before anybody has switched music on, and at
  /// every block boundary of every sprint whether or not music is in use.
  /// Without the guard below, a person with no Apple Music subscription who
  /// never touches the switch still has this app reach into Apple's player and
  /// tell it to stop, four times an hour — which contradicts the posture stated
  /// in `AudioSessionInterruptions`, that this app does not touch the audio
  /// stack until it has something to play.
  ///
  /// Letting the queue go clears the flag again, so a run of quiet applies
  /// collapses to one call and then to none.
  private func goQuiet() {
    refreshIsPlaying()
    guard hasTouchedThePlayer else { return }

    let releases = MusicPlaybackPhase.releasesQueue(
      sprintIsOver: sprintIsOver,
      isEnabled: isEnabled)

    if releases {
      player.stop()
      hasTouchedThePlayer = false
    } else {
      player.pause()
    }
    refreshIsPlaying()
  }

  /// Asks the player whether sound is coming out, and remembers the answer.
  ///
  /// Called at every moment that could have changed it. See `isPlaying` for why
  /// the answer is stored rather than asked for on the spot.
  private func refreshIsPlaying() {
    isPlaying = player.isPlaying
  }

  /// Re-states silence if silence is what the rule currently wants.
  ///
  /// Called only by work that discovers it has been superseded. It never starts
  /// anything and it never bumps the generation counter, so it cannot loop and
  /// cannot overtake the decision it is deferring to.
  private func reassertSilenceIfWanted() {
    let wantsSound = MusicPlaybackPhase.shouldSound(
      isRunning: isTimerRunning,
      kind: kind,
      isEnabled: isEnabled,
      availability: availability,
      selection: selection)

    guard !wantsSound else { return }
    goQuiet()
  }

  // MARK: Reading the world

  /// Re-reads availability and then asks whether the chosen item is still in the
  /// library.
  ///
  /// Both are reads with no side effect on the person's phone. Neither can
  /// prompt for anything, so this is safe at launch — the permission prompt is
  /// reached only by switching music on.
  private func refreshAvailabilityAndSelection() {
    libraryTask?.cancel()
    libraryTask = Task { @MainActor [weak self] in
      guard let self else { return }
      let answer = await availabilityChecker.refresh()
      availabilityChanged(to: answer)
      await checkSelectionIsStillThere()
    }
  }

  /// Asks the library whether the chosen item is still there, and takes its
  /// current name if it has been renamed.
  private func checkSelectionIsStillThere() async {
    guard let wanted = selection, availability.permitsPlayback else { return }

    do {
      guard let found = try await library.resolve(wanted) else {
        selectionIsMissing = true
        return
      }
      selectionIsMissing = false
      guard found != wanted, !isTimerRunning else { return }
      // The item is still there under a new name. Taking it keeps the timer
      // screen showing what the Music app shows.
      selection = found
      preferences.setSelection(found)
    } catch {
      // A library that cannot be read is a library nothing can be played from,
      // so the honest answer is that this app does not know whether it can play
      // — which is one quiet line on the row and a timer that is unaffected.
      // The error is turned into that fact rather than discarded.
      availability = .couldNotBeChecked
      apply()
    }
  }

  // MARK: Private

  private let player: any MusicPlaying
  private let availabilityChecker: any MusicAvailabilityChecking
  private let library: any MusicLibraryReading
  private let preferences: any MusicPreferenceStoring

  /// The block the timer is on, as last reported by the observer.
  private var kind: BlockKind = .work

  /// Whether the timer is at rest with no sprint in progress. True at launch:
  /// nothing is queued, so there is nothing to hold on to.
  private var sprintIsOver = true

  /// Whether `start()` has run.
  private var hasStarted = false

  /// Whether this app has asked the player to do anything since it last let the
  /// queue go. See `goQuiet()`.
  private var hasTouchedThePlayer = false

  /// Bumped by every `apply()`. Work that comes back holding an older number
  /// knows a newer decision has been taken since it began.
  private var generation = 0

  private var soundTask: Task<Void, Never>?
  private var skipTask: Task<Void, Never>?
  private var availabilityTask: Task<Void, Never>?
  private var interruptionTask: Task<Void, Never>?
  private var libraryTask: Task<Void, Never>?
}

/// What one attempt to make sound did.
///
/// Outside the class rather than in it, because it is a description of an
/// outcome rather than a piece of the coordinator's state, and because the
/// coordinator's own body is held to a length the project checks.
private enum MusicPlaybackOutcome {
  /// The player accepted and is playing.
  case sounded
  /// The attempt was cancelled by a newer decision.
  case abandoned
  /// The chosen playlist or song is not in the library any more.
  case itemHasGone
  /// The player refused for some other reason.
  case refused
}
