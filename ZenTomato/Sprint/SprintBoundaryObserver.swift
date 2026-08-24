import Foundation
import Observation

/// Empties the set of tasks completed this sprint, when the sprint ends.
///
/// **THE TIMER IS READ. IT IS NOT CHANGED.** `ZenTomato/Timer/TimerEngine.swift`
/// has zero changed lines in this feature, and this file is why that was
/// possible. The engine is already `@Observable`, which means anything that
/// reads one of its values is told when that value changes — so this subscribes
/// to what is already published rather than having a Todoist hook wired into
/// the middle of the timer. F4 established the pattern in
/// `BlockPhaseObserver`; this is the same shape for a different reader.
///
/// **THE WHOLE RULE IS ONE LINE**, and it is worth stating why it is enough:
///
/// ```
/// engine.isRunning == false  &&  engine.completedInSprint == 0
/// ```
///
/// | How the timer came to rest | `completedInSprint` | Cleared | Right? |
/// |---|---|---|---|
/// | A long break ended | `0` — the cycle resets it | yes | yes, the sprint ended |
/// | Somebody stopped | `0` — stopping returns it to zero | yes | yes, D21b says stopping clears it |
/// | A block ended mid-sprint, auto-start off | one or more | no | yes, the sprint continues |
/// | Launched, never started | `0` | yes | harmless, the set is already empty |
/// | A block is running | not asked | no | yes |
///
/// There is no sixth way: going idle is the only path to `isRunning == false`,
/// and it takes its count from the transition that caused it. Skip was removed
/// by D13, so there is no abandoned-but-sprint-continuing case left.
///
/// **Over-clearing is harmless; under-clearing is the bug D21b exists to fix.**
/// So the rule is written to err towards clearing, and clearing a set that is
/// already empty does nothing at all.
@MainActor
final class SprintBoundaryObserver {
  // MARK: Lifecycle

  /// - Parameters:
  ///   - engine: the timer. Read only — never written to, never called into.
  ///   - completions: the set to empty.
  init(engine: TimerEngine, completions: SprintCompletions) {
    self.engine = engine
    self.completions = completions
  }

  /// Nothing this object started outlives it.
  ///
  /// `isolated deinit` is what lets this clean-up reach a value belonging to
  /// the main thread; `BlockPhaseObserver` carries the same keyword for the
  /// same reason. Without it, following the timer would carry on after the
  /// thing doing the following had gone.
  isolated deinit {
    task?.cancel()
  }

  // MARK: Internal

  /// Begins following the timer, and acts on where it stands right now.
  ///
  /// The first reading is taken immediately rather than waiting for something
  /// to change, so an app launched while nothing is running starts from an
  /// empty set rather than from whatever the last process believed. Calling it
  /// twice does nothing the second time.
  func start() {
    guard task == nil else { return }
    evaluate()

    // `Observations` is the standard library's own re-arming loop over an
    // observable object: it yields a fresh value every time one of the values
    // read inside the closure changes, and re-subscribes itself. Values are
    // coalesced rather than queued, which is right here — what matters is
    // whether the timer is at rest now, never a backlog of states it passed
    // through.
    let changes = Observations<Bool, Never> { [engine] in
      Self.sprintHasEnded(isRunning: engine.isRunning, completedInSprint: engine.completedInSprint)
    }

    task = Task { @MainActor [weak self] in
      for await ended in changes {
        guard let self else { return }
        if ended { completions.clear() }
      }
    }
  }

  /// Stops following the timer. The set is left exactly as it is.
  func stop() {
    task?.cancel()
    task = nil
  }

  /// Reads the timer once and clears the set if the sprint has ended.
  ///
  /// The loop above does exactly this on every change. It is a method of its
  /// own so that a test can drive the engine and then ask the rule directly,
  /// with nothing waiting and nothing racing — the loop's plumbing is F4's,
  /// already proven; the rule is this feature's, and it is the part worth
  /// proving.
  func evaluate() {
    guard Self.sprintHasEnded(isRunning: engine.isRunning, completedInSprint: engine.completedInSprint)
    else { return }
    completions.clear()
  }

  /// Whether no sprint is in progress. See the table at the top of this file.
  static func sprintHasEnded(isRunning: Bool, completedInSprint: Int) -> Bool {
    isRunning == false && completedInSprint == 0
  }

  // MARK: Private

  private let engine: TimerEngine
  private let completions: SprintCompletions
  private var task: Task<Void, Never>?
}
