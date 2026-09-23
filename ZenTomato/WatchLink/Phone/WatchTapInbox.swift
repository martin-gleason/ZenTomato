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
    /// one case where a tap is genuinely lost.
    ///
    /// **It is returned, not surfaced.** `PhoneWatchLink` drops every outcome
    /// that is not `.recorded`, so nothing in the app tells anybody this
    /// happened. The same is true of `.unreadable`. That asymmetry against the
    /// phone's own amber line — *"That tap wasn't saved. Tap again."* — is real,
    /// is `O47`, and is not this unit's to settle. Saying so here is cheaper
    /// than a doc comment that claims a surface the caller does not have.
    case failed
    /// The database refused the duplicate check, so the tap was dropped.
    ///
    /// **This is not `failed`.** Nothing was written and nothing was refused a
    /// write: the phone could not find out whether this tap is already here.
    /// Writing it anyway risks a second row for one press — permanently, because
    /// this app has no surface that can delete one — and an inflated distraction
    /// count is invisible, plausible and always flatters. Dropping loses one tap,
    /// which is absent rather than wrong. `StatsQuery` makes the same call in the
    /// same word: a read it cannot complete is `unreadable`, never an empty
    /// fortnight.
    case unreadable
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
    // A REFUSED READ IS NOT AN EMPTY ONE, AND `try?` MADE THEM THE SAME BRANCH.
    // `try?` turns a thrown error into `nil`, the `if let` then fails, and
    // control falls through to the insert below — writing the second row this
    // check exists to prevent. Nothing about the result looks wrong afterwards:
    // the row is ordinary, the count is plausible, and it is wrong upward.
    //
    // THIS LINE IS THE ONE THE APP RUNS, AND IT IS THE ONE THE TESTS DRIVE.
    // There is no injected closure here and no branch for a test to take: the
    // two refused-read tests point a real `ModelContext` at a real store file
    // whose bytes have been overwritten, and this `fetch` really throws
    // (`NSCocoaErrorDomain` 259, *"isn't in the correct format"*). A seam would
    // have left this exact line — the only one that ships — uncovered, which is
    // how the swallowed error got here in the first place.
    let found: [Distraction]
    do {
      found = try context.fetch(existing)
    } catch {
      // Nothing is inserted. `Outcome.unreadable` carries the reasoning: a tap
      // that may already be here is dropped rather than written twice, because
      // this app can never delete the second one.
      return .unreadable
    }
    if found.isEmpty == false {
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
