import Foundation
import SwiftData

/// Ticking one task off in Todoist — the only change this app can make to
/// anybody's Todoist account.
///
/// THE ORDER OF THE THREE STEPS IS THE WHOLE CONTRACT
///
///   1. Ask Todoist to close the task, and wait for it to say it did.
///   2. **Only then** write the local record of the completion.
///   3. **Only then** drop the task from the local copy of Todoist, so the
///      picker stops offering something that is no longer there.
///
/// Step 2 never happens before step 1 succeeds. A local row claiming a
/// completion that failed would be worse than no row: the log this app exists to
/// produce is worth having only because its numbers mean exactly what they say,
/// and one invented completion is enough to make a reader stop trusting all of
/// them. Moving that insert above the request is the single most tempting change
/// anybody could make to this file — it would make the button feel instant — and
/// `completionRecordedOnlyAfterTodoistConfirms` fails the moment it is made.
///
/// THINGS THIS DELIBERATELY DOES NOT DO
///   * It never queues. If the request fails, nothing is stored for later and
///     nothing retries in the background — tapping the button again is the only
///     retry there is. A write performed later, unwatched, is a write nobody can
///     see, and being able to see every write is this feature's one rule.
///   * It never touches the timer. Completing a task does not end a pomodoro,
///     and ending a pomodoro does not complete a task. They are independent; the
///     end-of-block sheet is merely where both happen to be reachable.
///   * It is a plain class with one method and no protocol behind it, on
///     purpose. A protocol here would be a shape for writes to Todoist to grow
///     into, and there is exactly one write.
@MainActor
final class TaskCompletion {
  // MARK: What came of it

  /// What happened, in terms a screen can act on.
  ///
  /// Each case answers the only question that matters after the tap — **is the
  /// task still open in Todoist?** — because the risk of a button that does
  /// something over the network is leaving somebody unsure whether it went
  /// through.
  enum Outcome: Equatable, Sendable {
    /// Todoist confirmed the close. The task is done and the record is written.
    case closed

    /// Todoist says there is no such task any more: it was finished or removed
    /// somewhere else. **The two cannot be told apart**, so nothing is claimed
    /// about which, and no local record is written — this app did not do it.
    case alreadyGone

    /// The request never reached Todoist. The task is still open there.
    case offline

    /// Todoist refused the token; it has been removed from this phone. The task
    /// is still open.
    case tokenRejected

    /// Something else went wrong at Todoist's end. The task is still open.
    case failed
  }

  // MARK: What it is built with

  private let context: ModelContext
  private let client: TodoistClient

  init(context: ModelContext, client: TodoistClient) {
    self.context = context
    self.client = client
  }

  // MARK: Completing

  /// Closes one task in Todoist and records that it happened.
  ///
  /// - Parameters:
  ///   - taskID: the task's opaque Todoist identifier.
  ///   - titleSnapshot: the title as it read when the block began — the same
  ///     words the finished-block row carries. Deliberately not read fresh from
  ///     the local copy: a task renamed during a 25-minute block must not
  ///     silently change what the record says was finished.
  ///   - now: the moment to record. Defaults to the real clock.
  /// - Returns: what happened, and by implication whether the task is still open.
  func complete(taskID: String, titleSnapshot: String, now: Date = Date()) async -> Outcome {
    do {
      // Exactly one request. Nothing is sent before it to check the task still
      // exists, and nothing after it to confirm the close: a second request is a
      // second thing that can fail, and it could not tell us anything the answer
      // to this one did not.
      try await client.closeTask(id: taskID)
    } catch TodoistError.server(status: 404) {
      return .alreadyGone
    } catch TodoistError.offline {
      return .offline
    } catch TodoistError.tokenRejected {
      return .tokenRejected
    } catch {
      return .failed
    }

    recordLocally(taskID: taskID, titleSnapshot: titleSnapshot, at: now)
    return .closed
  }

  // MARK: After Todoist has confirmed

  /// Writes the completion down and drops the task from the local copy.
  ///
  /// Removing the cached row is the mirror catching up early rather than a piece
  /// of state this app has invented: the next full refresh would remove it
  /// anyway, because Todoist's read addresses return open tasks only. **It is
  /// not a "completed" flag** — there is no such column anywhere, and a task
  /// that has gone is expressed by absence, exactly as it is in Todoist.
  private func recordLocally(taskID: String, titleSnapshot: String, at instant: Date) {
    context.insert(CompletedTaskRecord(
      taskID: taskID,
      titleSnapshot: titleSnapshot,
      completedAt: instant))

    do {
      try context.delete(model: CachedTask.self, where: #Predicate { $0.id == taskID })
      try context.save()
    } catch {
      // The task IS closed in Todoist — that already happened, and saying
      // otherwise would be the one lie this feature must not tell. So the
      // outcome stays `.closed` and this failure is not turned into one: what
      // has been lost is a row in this app's own history, not the completion.
      context.rollback()
    }
  }
}
