@preconcurrency import MusicKit
import Combine
import Foundation

/// The only file in this app that talks to Apple's music player.
///
/// Everything above it speaks the eight members of `MusicPlaying` and knows
/// nothing about Apple Music. That is what makes the whole of this feature's
/// logic provable against a stand-in on a machine with no music library, no
/// subscription and no speaker, and it is what confines a framework this app
/// depends on to three files out of a hundred.
///
/// **`@preconcurrency import` IS DELIBERATE AND IT IS THE PRESCRIBED REMEDY.**
/// This app is built in Swift 6 with the strictest thread-safety checking the
/// compiler offers. The music framework was built in an older language mode and
/// says nothing about which thread its types belong to, so the compiler assumes
/// the worst about every one of them. The import above says "this framework
/// predates those rules; hold it to the older ones" — and the safety is then
/// supplied here instead, by this class being main-thread-only and by Apple's
/// player being reached through the one accessor below. The alternative that
/// engineers reach for under time pressure is an escape hatch that switches the
/// checking off at the point of use, which would move the player off the main
/// thread and quietly reintroduce exactly the ordering defect the timer's own
/// review spent a blocking finding on. It does not appear anywhere in this
/// feature.
///
/// **THE SYSTEM'S OWN CONTROLS CANNOT BE SWITCHED OFF.** Control Centre, the
/// Lock Screen, headphones and CarPlay all offer play, pause and go-back for
/// whatever is playing, because that is iOS's contract with the person holding
/// the phone. What this app controls is its own screen. `isPlaying` below is
/// read from the player every time rather than remembered, so that when the two
/// disagree this app follows what is actually happening.
@MainActor
final class AppleMusicPlayer: MusicPlaying {
  // MARK: What the coordinator reads

  /// What is queued right now, or `nil` when nothing is.
  ///
  /// This app's own record of what it put in the queue, rather than a question
  /// asked of the player — because the question that matters is *"is what is
  /// queued the thing the person chose"*, and only this app knows what they
  /// chose. Cleared by `stop()`, which is what makes the first focus block of a
  /// new sprint start the playlist from the top.
  private(set) var loaded: MusicSelection?

  /// Holds the subscription to the player's status. Releasing it stops listening.
  private var statusObservation: AnyCancellable?

  /// Whether sound is actually coming out right now.
  ///
  /// Asked of the player each time. Anything other than playing — paused,
  /// stopped, or taken away by a phone call — is not playing, and the skip
  /// button on the timer screen follows this and nothing else.
  var isPlaying: Bool {
    player.state.playbackStatus == .playing
  }

  /// Both readings, taken off the main actor.
  ///
  /// **This is the fix for the watchdog kill.** Each of the two properties above
  /// is a synchronous cross-process call to the media server; on the main thread,
  /// a wedged media daemon becomes a dead app in ten seconds. Here the wait
  /// happens on a background executor, where being slow costs a late row rather
  /// than the process.
  ///
  /// `ApplicationMusicPlayer.shared` is reached inside the detached task rather
  /// than captured, so nothing main-actor-isolated crosses the boundary.
  /// `MusicPlayer.State` is not main-actor isolated in the SDK — checked in
  /// `MusicKit.swiftinterface` rather than assumed — so reading it here is
  /// allowed.
  ///
  /// **Order is not this function's problem.** It answers about the moment it is
  /// asked; `MusicCoordinator` decides whether a late answer is still wanted.
  nonisolated func playbackSnapshot() async -> PlaybackSnapshot {
    await Task.detached(priority: .utility) {
      let shared = ApplicationMusicPlayer.shared
      let playing = shared.state.playbackStatus == .playing
      // Same rule as the property: no track name while nothing is playing, or
      // the row would name a song that is making no sound.
      let title = playing ? shared.queue.currentEntry?.title : nil
      return PlaybackSnapshot(isPlaying: playing, nowPlayingTitle: title)
    }.value
  }

  /// The track the player is on, asked of the player rather than remembered.
  ///
  /// `nil` while nothing is playing, which includes a break: the row says
  /// "paused" in its own words then, and a track name beside it would be the
  /// name of something that is not making a sound.
  var nowPlayingTitle: String? {
    guard isPlaying else { return nil }
    return player.queue.currentEntry?.title
  }

  /// Told when the player's status changes, so the screen can catch up.
  ///
  /// **Setting this starts listening.** `MusicPlayer.State` is a Combine
  /// `ObservableObject`, which is the only honest way to know when playback
  /// actually begins: `play()` returns before the status flips, so a reading
  /// taken at the end of it records "not playing" and is never corrected.
  ///
  /// That bug shipped. The skip button appeared in one sprint and not the next,
  /// because whether the single reading landed before or after the flip was a
  /// race. Listening replaces guessing at the timing.
  var onPlaybackStatusChanged: (() -> Void)? {
    didSet { observeStatus() }
  }

  // MARK: Listening

  /// Subscribes to the player's own status changes.
  ///
  /// `receive(on:)` IS LOAD-BEARING, and not for the reason it looks like. Combine
  /// publishes `objectWillChange` BEFORE the value changes, so a callback run
  /// synchronously would read the OLD `playbackStatus` and stay one event behind
  /// for ever. Deferring to a later turn is what makes it read the new one.
  /// Delete the hop and all 294 tests stay green while every reading is stale.
  ///
  /// It also happens that the callback touches
  /// `@Observable` state that the screen reads, and everything in this feature
  /// is main-actor bound. Cancelled and replaced rather than accumulated, so
  /// setting the callback twice does not deliver twice.
  private func observeStatus() {
    statusObservation?.cancel()
    guard let onPlaybackStatusChanged else { return }
    // TWO PUBLISHERS, BECAUSE THERE ARE TWO OBJECTS.
    //
    // `MusicPlayer.State` and `MusicPlayer.Queue` are separate ObservableObjects
    // and they announce different things. State says whether sound is coming out;
    // the QUEUE says which track it is coming from. Observing only the state
    // meant the track name changed only when something else happened to cause a
    // refresh — so it sat one song behind, for ever. Reported from the device
    // exactly that way: "Heroes plays and Heroes is listed… when the song
    // advances to Cool It Down, it is listed as By This River."
    //
    // Merged rather than two sinks, so there is one subscription to cancel and
    // no way for the two to get out of step with each other.
    statusObservation = Publishers.Merge(
      player.state.objectWillChange,
      player.queue.objectWillChange)
      .receive(on: RunLoop.main)
      .sink { onPlaybackStatusChanged() }
  }

  // MARK: The verbs

  /// Queues the chosen item, sets it to loop for ever, and starts it.
  ///
  /// **The order of the four steps matters and is the whole of the risk in this
  /// file.** The session has to be claimed before anything is queued; the queue
  /// has to be assigned before the looping is set, because the looping belongs
  /// to the player's playback state and setting it against a queue that has not
  /// been assigned yet is dropped without complaint; and starting comes last.
  /// Only the last of those makes a noise, which is what makes this the moment
  /// this app takes the speaker from whatever else was using it — the ratified
  /// decision that switching music on means this app handles the audio.
  ///
  /// - Parameter selection: the playlist or song to play.
  /// - Throws: `MusicPlaybackError.selectionMissing` when the item is not in the
  ///   person's library any more, `MusicPlaybackError.playbackFailed` for
  ///   anything else. Both leave a silent working timer.
  func load(_ selection: MusicSelection) async throws {
    // Cleared first: if any step below fails, this app must not go on believing
    // the right thing is queued, or the next focus block would try to continue
    // something that is not there.
    loaded = nil

    do {
      try AudioSessionInterruptions.prepareForPlayback()
    } catch {
      throw MusicPlaybackError.playbackFailed
    }

    // **NO ERROR FROM APPLE'S FRAMEWORK LEAVES THIS FILE.** The whole
    // architecture of this feature is that the framework is confined to three
    // files and everything above them speaks the two words in
    // `MusicPlaybackError`. A library lookup can throw, and until this was
    // wrapped, whatever it threw travelled straight out through the protocol —
    // past two doc comments promising it could not — and was saved only by a
    // catch-all one level up. The next caller to handle the two known cases
    // properly would have mis-read a real library failure as something else.
    //
    // A cancellation is re-thrown untouched, because it is not a failure: it is
    // the coordinator calling this off, and the coordinator's own handling of
    // it depends on recognising it.
    switch selection.kind {
    case .playlist:
      let found: Playlist?
      do {
        found = try await playlist(withIdentifier: selection.identifier)
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        throw MusicPlaybackError.playbackFailed
      }
      guard let item = found else { throw MusicPlaybackError.selectionMissing }
      player.queue = ApplicationMusicPlayer.Queue(for: [item])

    case .song:
      let found: Song?
      do {
        found = try await song(withIdentifier: selection.identifier)
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        throw MusicPlaybackError.playbackFailed
      }
      guard let item = found else { throw MusicPlaybackError.selectionMissing }
      player.queue = ApplicationMusicPlayer.Queue(for: [item])
    }

    // Loop for ever, which is the contract's "playlist loops when it ends". A
    // single chosen song loops the same way. This is the one place in the whole
    // app where the looping is set, and there is no way to unset it: nothing
    // above this file has a word for it.
    player.state.repeatMode = .all

    do {
      try await player.play()
    } catch {
      throw MusicPlaybackError.playbackFailed
    }

    loaded = selection
  }

  /// Continues from wherever the queue already stands.
  ///
  /// Takes no position, because there is no position to take: starting the
  /// player again from a paused state continues the same track at the same
  /// second. That is the whole of "resumes mid-track" and it needs no
  /// bookkeeping of this app's own.
  func resume() async throws {
    guard loaded != nil else { return }
    do {
      try await player.play()
    } catch {
      throw MusicPlaybackError.playbackFailed
    }
  }

  /// Silence, keeping the queue and the place in it. This is what a break is.
  func pause() {
    player.pause()
  }

  /// Silence, and let the queue go. This is what the end of a sprint is.
  ///
  /// After this the player is left alone: this app is no longer holding
  /// anybody's audio, which is the ratified decision that at sprint end it
  /// stops and leaves the system's player to itself.
  func stop() {
    player.stop()
    loaded = nil
  }

  /// Moves to the next track.
  ///
  /// - Throws: `MusicPlaybackError.playbackFailed` if the player refused.
  func skipForward() async throws {
    do {
      try await player.skipToNextEntry()
    } catch {
      throw MusicPlaybackError.playbackFailed
    }
  }

  // MARK: Private

  /// Apple's player, scoped to this app alone.
  ///
  /// **THIS IS THE APPLICATION PLAYER, NOT THE ONE THE MUSIC APP USES.** The
  /// framework offers two. The other one drives the queue the person sees in
  /// the Music app itself, so choosing it would mean that starting a pomodoro
  /// wipes out whatever they had lined up elsewhere — they would come back to
  /// their own music replaced by this app's playlist, with nothing to undo it.
  /// This one has its own queue that begins and ends with this app. The name of
  /// the other player appears nowhere in this repository, which is checkable
  /// with a search, and this comment is the record of why.
  private var player: ApplicationMusicPlayer {
    ApplicationMusicPlayer.shared
  }

  /// Finds a playlist in the person's own library by its identifier.
  ///
  /// A library request and never a catalogue one. The contract's wording is
  /// *"an existing playlist or song from their library"*, and something from
  /// the Apple Music catalogue is something the person does not own.
  ///
  /// - Returns: the playlist, or `nil` when it is not in the library any more.
  private func playlist(withIdentifier identifier: String) async throws -> Playlist? {
    var request = MusicLibraryRequest<Playlist>()
    request.filter(matching: \.id, equalTo: MusicItemID(identifier))
    // One item is being looked for by its identifier, so one is all that is
    // wanted back. On a library of several thousand this is the difference
    // between an instant answer and a visible pause at the start of a block.
    request.limit = 1
    return try await request.response().items.first
  }

  /// Finds a song in the person's own library by its identifier.
  ///
  /// - Returns: the song, or `nil` when it is not in the library any more.
  private func song(withIdentifier identifier: String) async throws -> Song? {
    var request = MusicLibraryRequest<Song>()
    request.filter(matching: \.id, equalTo: MusicItemID(identifier))
    request.limit = 1
    return try await request.response().items.first
  }
}
