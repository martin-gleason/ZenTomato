import Foundation

@testable import ZenTomato

/// A stand-in for the music player that writes down everything it was asked to
/// do and makes no sound.
///
/// **THIS IS THE HONEST HALF OF A SPLIT THAT IS STATED RATHER THAN GLOSSED.**
/// There is no simulator for "sound came out of the phone": the build machine
/// has no music library and no Apple Music subscription, and no test in this
/// repository can prove a note was played. What *can* be proved, exhaustively
/// and in microseconds, is every decision this app makes about when to play,
/// pause, resume, stop and skip — and that is what this object is for. The
/// other half, whether the sound actually arrives, is covered by the device
/// check on the owner's phone and by nothing else.
///
/// **IT RECORDS ORDER, NOT JUST OUTCOMES.** Almost every requirement in this
/// feature is about sequence rather than result: pause must come at the break
/// and resume at the next focus block, and the queue must be loaded once per
/// sprint rather than once per block. `callLog` is what lets a test say that in
/// one line.
///
/// **`startedFromTheTopCount` IS THE RESTART DETECTOR.** Continuing a paused
/// track and starting a playlist over are indistinguishable from the outside —
/// both are "music is playing" — so this stand-in counts the one that matters.
/// A sprint in which it goes above one is a sprint in which somebody's track
/// started again from the beginning, which is the defect the pause-and-resume
/// requirement exists to prevent.
@MainActor
final class SpyMusicPlayer: MusicPlaying {
  /// One thing the coordinator asked for.
  enum Call: Equatable {
    case load(MusicSelection)
    case resume
    case pause
    case stop
    case skipForward
  }

  /// A plain error for the failure tests. Its type does not matter to the
  /// coordinator, which treats anything that is not a missing item the same way.
  struct Failure: Error {}

  /// Every call, in the order it was made.
  private(set) var calls: [Call] = []

  /// The calls as bare names, for asserting order without restating payloads.
  var callLog: [String] {
    calls.map { call in
      switch call {
      case .load: "load"
      case .resume: "resume"
      case .pause: "pause"
      case .stop: "stop"
      case .skipForward: "skipForward"
      }
    }
  }

  /// How many times a queue was loaded. One per sprint is correct; two means a
  /// track started over.
  var startedFromTheTopCount: Int {
    calls.filter { call in
      if case .load = call { true } else { false }
    }
    .count
  }

  /// What is queued, exactly as the real player reports it.
  private(set) var loaded: MusicSelection?

  /// Whether sound is coming out, as far as this stand-in is concerned.
  private(set) var isPlaying = false

  /// When set, loading throws it instead of succeeding.
  var loadError: (any Error)?

  /// When set, resuming throws it instead of succeeding.
  var resumeError: (any Error)?

  /// When set, skipping throws it instead of succeeding.
  var skipError: (any Error)?

  /// When true, the **next** load stops at a gate and does not finish until the
  /// test opens it with `releaseLoad()`.
  ///
  /// **THIS IS THE ONLY WAY THE ORDERING GUARD CAN BE TESTED AT ALL.** Every
  /// other method here finishes the instant it is called, which is not what a
  /// real queue load does: on a phone it is the one operation in this feature
  /// that genuinely takes hundreds of milliseconds, and a block boundary is
  /// exactly when it is in flight. Without a way to hold a load open, the
  /// generation counter, the re-check after every suspension and the
  /// re-statement of silence by superseded work are executed by no test — which
  /// is the top ordering risk in the build contract protected only by somebody
  /// reading the code and agreeing with it.
  var gateLoads = false

  func load(_ selection: MusicSelection) async throws {
    calls.append(.load(selection))
    // One-shot: only the load that finds the gate closed waits at it, so a
    // second load issued while the first is still held goes straight through
    // rather than replacing the first one's foothold.
    if gateLoads {
      gateLoads = false
      await withCheckedContinuation { loadGate = $0 }
    }
    if let loadError {
      loaded = nil
      isPlaying = false
      throw loadError
    }
    loaded = selection
    isPlaying = true
  }

  func resume() async throws {
    calls.append(.resume)
    if let resumeError {
      throw resumeError
    }
    // Exactly the real player's behaviour: resuming with nothing queued is a
    // no-op rather than an error.
    guard loaded != nil else { return }
    isPlaying = true
  }

  func pause() {
    calls.append(.pause)
    isPlaying = false
  }

  func stop() {
    calls.append(.stop)
    isPlaying = false
    loaded = nil
  }

  func skipForward() async throws {
    calls.append(.skipForward)
    if let skipError {
      throw skipError
    }
  }

  /// Lets a gated load finish.
  ///
  /// The gate is opened for good, so the load that was waiting runs to its end
  /// and any later one goes straight through.
  func releaseLoad() {
    gateLoads = false
    loadGate?.resume()
    loadGate = nil
  }

  // MARK: Private

  private var loadGate: CheckedContinuation<Void, Never>?
}
