import Foundation
import Observation
import SwiftData

/// Keeps the wrist told what the phone is doing.
///
/// **It sends on change, not on a schedule.** The block state carries an absolute
/// `endsAt`, so the watch draws its own countdown and nothing needs saying while
/// a block runs — a handful of messages per sprint rather than one a second,
/// which is the difference between a watch app and a battery complaint.
///
/// Built on `Observations`, the same re-arming loop `SprintBoundaryObserver`
/// uses. Values are coalesced rather than queued, which is exactly right here:
/// what matters is what is running *now*, never a backlog of blocks already
/// finished. That coalescing is also why `updateApplicationContext` is the
/// matching API on the other side — both drop superseded states on purpose.
@MainActor
final class WatchStatePublisher {
  init(engine: TimerEngine, link: PhoneWatchLink, plan: SessionPlanStore, context: ModelContext) {
    self.engine = engine
    self.link = link
    self.plan = plan
    self.context = context
  }

  /// Starts following the timer. Idempotent.
  ///
  /// The first reading is sent immediately rather than waiting for a change, so
  /// a watch that opens while a block is already running is told about it
  /// instead of showing nothing until the next boundary.
  func start() {
    guard task == nil else { return }
    link.send(current())

    let changes = Observations<Signature, Never> { [engine] in
      Signature(isRunning: engine.isRunning, kind: engine.kind, endsAt: engine.endsAt)
    }

    task = Task { @MainActor [weak self] in
      for await _ in changes {
        guard let self else { return }
        link.send(current())
      }
    }
  }

  func stop() {
    task?.cancel()
    task = nil
  }

  // MARK: Private

  /// The facts whose change is worth a message.
  ///
  /// Deliberately not the whole state: the task title is read when a message is
  /// sent rather than watched, because it only ever changes at a boundary, and
  /// watching it would wake this loop for a plan edit that changes nothing the
  /// wrist can see.
  private struct Signature: Equatable {
    let isRunning: Bool
    let kind: BlockKind
    let endsAt: Date?
  }

  private func current() -> WatchBlockState {
    guard
      engine.isRunning,
      let endsAt = engine.endsAt,
      // Read the way the rest of the app reads it. The engine keeps its state
      // private, and a second copy of the session id kept in step by hand is a
      // second thing that can be wrong about which block is running.
      let sessionID = try? TimerState.current(in: context).sessionID
    else { return WatchBlockState() }

    return WatchBlockState(block: .init(
      kind: engine.kind,
      endsAt: endsAt,
      // Resolved to a title here, on the phone. The watch has no cache to look
      // an identifier up against and no business holding Todoist's ids.
      taskTitle: plan.runningBlockAttachment()?.taskTitle,
      sessionID: sessionID))
  }

  private let engine: TimerEngine
  private let link: PhoneWatchLink
  private let plan: SessionPlanStore
  private let context: ModelContext
  private var task: Task<Void, Never>?
}
