import Foundation
import SwiftData

/// Where a tap made on the wrist becomes a row in the database.
///
/// **THE PHONE IS THE ONLY WRITER.** The watch holds nothing and decides nothing;
/// it hands over a small value and this turns it into the same `Distraction` a
/// thumb on the phone would have produced. One kind of row, one shape, one place
/// F6 has to count.
///
/// **WHY THIS IS NOT `TimerEngine.recordDistraction(_:)`.** That method refuses
/// unless a work block is running *right now*, and it is right to: a tap on the
/// phone happens in the instant it is made, so a tap arriving after the block
/// ended would be a tap in a break dressed up as work.
///
/// A wrist tap is the opposite case. It was made inside the block and may arrive
/// long afterwards — `transferUserInfo` promises eventual delivery, not prompt
/// delivery, and the phone being in another room is the whole scenario D2's
/// *Done when* describes. **Late delivery does not change when something
/// happened.** So this path takes the moment and the block from the payload
/// rather than from the clock, and a block that has since ended is normal rather
/// than exceptional.
@MainActor
struct WatchTapInbox {
  /// What happened to a delivered tap. Every case is a fact, not an error.
  enum Outcome: Equatable {
    /// A new row was written.
    case recorded
    /// This exact tap is already in the database and was ignored.
    case duplicate
    /// The row could not be saved. The system will not redeliver, so this is the
    /// one case where a tap is genuinely lost, and it is reported rather than
    /// swallowed.
    case failed
  }

  let context: ModelContext

  /// Takes one tap and, if it is new, writes it down.
  ///
  /// **The tap's own id becomes the row's id, and that is what makes redelivery
  /// harmless.** WatchConnectivity guarantees delivery *at least* once: the
  /// system may hand the same payload over twice, after a relaunch or a flaky
  /// link, and nothing marks the second copy as a repeat. Without a stable
  /// identity the phone cannot tell a resend from a second real tap, and two rows
  /// where there was one tap inflates the counts the fortnightly review reads —
  /// quietly, plausibly, and always upward.
  ///
  /// Reusing the tap's id rather than storing a separate "watch tap id" means the
  /// check is a lookup on a column that already exists, and there is no second
  /// identifier to keep in step.
  @discardableResult
  func receive(_ tap: WatchTap) -> Outcome {
    // Bound to a local constant first: a database predicate may only capture a
    // plain value, never a path through another object.
    let identity = tap.id
    var existing = FetchDescriptor<Distraction>(
      predicate: #Predicate<Distraction> { $0.id == identity })
    existing.fetchLimit = 1
    if let found = try? context.fetch(existing), found.isEmpty == false {
      return .duplicate
    }

    // THE MOMENT COMES FROM THE WATCH, NEVER FROM THIS DEVICE'S CLOCK.
    // A tap that waited eleven minutes in a queue must still say when it was
    // made. Using the arrival time here would silently rewrite the one number
    // this feature exists to capture, and it would do it invisibly — the row
    // would look perfectly ordinary.
    //
    // THE BLOCK COMES FROM THE WATCH TOO, and is not second-guessed from the
    // timestamp. The tap happened during that pomodoro. If the block has since
    // ended, that is expected rather than suspicious, and F6 already renders a
    // tap whose block it cannot find.
    let row = Distraction(
      id: tap.id,
      kind: tap.kind,
      timestamp: tap.tappedAt,
      sessionID: tap.sessionID)

    context.insert(row)
    do {
      try context.save()
      return .recorded
    } catch {
      // Do not leave it waiting in the context. A later successful save — the
      // next block boundary — would commit it minutes afterwards, in no sheet
      // and no reflection, which is the same reasoning `TimerEngine` applies to
      // a refused tap on the phone.
      context.delete(row)
      return .failed
    }
  }
}
