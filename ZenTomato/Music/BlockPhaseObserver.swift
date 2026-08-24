import Foundation
import Observation

/// Turns the timer engine's own changes into the one call the music
/// coordinator understands.
///
/// **F4 READS THE TIMER. IT DOES NOT ADD ANYTHING TO IT.**
/// `ZenTomato/Timer/TimerEngine.swift` has zero changed lines in this feature,
/// and this file is why that was possible. The engine already announces itself
/// — it is marked `@Observable`, which means anything that reads one of its
/// values is told when that value changes — so music subscribes to what is
/// already there rather than having a music hook wired into the middle of the
/// timer. A second notion of "the block changed", living inside the engine and
/// maintained for the benefit of an accessory, is exactly the coupling that
/// makes an accessory able to break a timer.
///
/// **A NOTE ON WHAT THE PLAN SAID.** The feature plan says the engine "already
/// publishes block transitions for the Live Activity" and that music subscribes
/// to the same signal. It does not: the Lock Screen countdown is the alarm
/// framework's own, driven by the scheduled alarm, and the app never posts an
/// update to it. The real signal is the one used here. The behaviour the plan
/// asked for is unchanged; only the mechanism it named was wrong.
///
/// **WHAT IT ACTUALLY SENDS.** Three facts, and the third is the interesting
/// one. `kind` and `isRunning` are read straight off the engine. `sprintIsOver`
/// is worked out here, from three engine values, because the difference between
/// *"the sprint is finished"* and *"you are standing between two blocks of a
/// sprint with auto-start switched off"* is invisible in `kind` and `isRunning`
/// alone — and it is the difference between letting the music queue go and
/// holding your place in the track. Working it out here keeps that arithmetic
/// next to the engine it is about, and keeps the coordinator asking a plain
/// question of a finished fact.
///
/// `@MainActor` on both ends: the engine is main-actor bound because it holds
/// the database handle, and the coordinator is main-actor bound because
/// everything in this feature is. The hand-off is therefore a plain method
/// call, with no thread hop and nothing that can arrive out of order.
@MainActor
final class BlockPhaseObserver {
  // MARK: Lifecycle

  /// - Parameters:
  ///   - engine: the timer. Read only; never written to, never called into.
  ///   - coordinator: what gets told.
  init(engine: TimerEngine, coordinator: MusicCoordinator) {
    self.engine = engine
    self.coordinator = coordinator
  }

  /// Nothing this object started outlives it.
  ///
  /// `isolated deinit` is what lets this clean-up reach a value belonging to
  /// the main thread; see the same keyword on `MusicCoordinator` for the longer
  /// explanation. Without it, following the timer would carry on after the
  /// thing doing the following had gone.
  isolated deinit {
    task?.cancel()
  }

  // MARK: Internal

  /// Begins following the timer, and reports where it stands right now.
  ///
  /// The first report is made straight away rather than waiting for something
  /// to change, so that an app launched while a block is already running does
  /// the right thing immediately instead of at the next boundary.
  ///
  /// Calling it twice does nothing the second time.
  func start() {
    guard task == nil else { return }
    deliver(Self.phase(of: engine))

    // `Observations` is the standard library's own re-arming loop over an
    // observable object: it yields a fresh value every time one of the values
    // read inside the closure changes, and it re-subscribes itself. Doing that
    // by hand is possible and is what the build contract sketched, but the
    // hand-written version has to smuggle a reference to this object through a
    // closure the compiler treats as belonging to no thread — which is the kind
    // of code that ends up reaching for an unsafe escape hatch. This has none.
    //
    // Values are coalesced rather than queued, which is right here: what is
    // wanted is the block the timer is on now, never a backlog of the ones it
    // passed through.
    let changes = Observations<BlockPhase, Never> { [engine] in
      Self.phase(of: engine)
    }

    task = Task { @MainActor [weak self] in
      for await phase in changes {
        guard let self else { return }
        deliver(phase)
      }
    }
  }

  /// Stops following the timer. The coordinator is not told anything more.
  func stop() {
    task?.cancel()
    task = nil
  }

  // MARK: Private

  /// Everything the coordinator needs to know about where the timer stands.
  private struct BlockPhase: Equatable, Sendable {
    let kind: BlockKind
    let isRunning: Bool
    let sprintIsOver: Bool
  }

  private let engine: TimerEngine
  private let coordinator: MusicCoordinator
  private var task: Task<Void, Never>?

  /// The last thing sent, so that the same phase is never sent twice.
  private var lastSent: BlockPhase?

  /// Reads the engine.
  ///
  /// **How `sprintIsOver` is decided, and why it takes three facts.** The engine
  /// comes to rest in three quite different situations and only says `kind` and
  /// `isRunning` about all of them:
  ///
  ///   * **A sprint has just finished.** The engine sets the size of the sprint
  ///     that ended, and clears it at the start of anything else. It is the
  ///     engine's own words for *"the last thing that happened was the end of a
  ///     sprint"*, so it is taken at face value.
  ///   * **Somebody abandoned a sprint.** Stopping returns the tally to zero and
  ///     queues a focus block. An abandoned sprint is a sprint that is over, so
  ///     the queue should go — and "at rest, a focus block queued, nothing
  ///     completed" is what that looks like from outside.
  ///   * **Between two blocks of a live sprint, with auto-start off.** Either a
  ///     break is queued, or a focus block is queued with at least one pomodoro
  ///     already completed. Neither matches the line above, so the queue and the
  ///     place in the track are kept — which is what makes the music carry on
  ///     from the same second when the person presses Start again.
  ///
  /// A timer that has never been started reads as "over", which is correct:
  /// nothing is queued, so there is nothing to hold on to.
  private static func phase(of engine: TimerEngine) -> BlockPhase {
    let atRest = !engine.isRunning
    let sprintJustEnded = engine.lastCompletedSprintSize != nil
    let nothingInProgress = engine.kind == .work && engine.completedInSprint == 0

    return BlockPhase(
      kind: engine.kind,
      isRunning: engine.isRunning,
      sprintIsOver: atRest && (sprintJustEnded || nothingInProgress))
  }

  /// Passes a phase on, unless it is the one already passed on.
  private func deliver(_ phase: BlockPhase) {
    guard phase != lastSent else { return }
    lastSent = phase
    coordinator.blockChanged(to: phase.kind, isRunning: phase.isRunning, sprintIsOver: phase.sprintIsOver)
  }
}
