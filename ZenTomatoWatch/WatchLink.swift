import Foundation
import WatchConnectivity

/// The wrist's end of the connection to the phone.
///
/// **TWO JOBS, TWO APIS, AND THE DISTINCTION IS THE WHOLE OF THIS FILE.**
///
/// *State arriving from the phone* uses `applicationContext`: latest-value-wins,
/// no queue, and the system drops anything superseded before it is delivered.
/// That is exactly right for "what block is running", because a stale
/// intermediate state is worthless — nobody wants the block before last — and
/// dropping it is correct rather than data loss.
///
/// *Taps going to the phone* use `transferUserInfo`: queued, persisted by the
/// system, delivered in order once the phone is reachable again, and surviving
/// this app being killed in between. This is the load-bearing choice in F7.
/// `sendMessage` requires live reachability and fails outright when the phone is
/// unreachable — which is precisely the scenario D2's *Done when* describes, with
/// the phone in another room. **A dropped tap is silent data loss in the one
/// feature `SPEC.md` calls the point of the app.**
///
/// Using the wrong one of these two would not fail loudly. It would work on a
/// desk, next to the phone, every time it was tried.
@MainActor
@Observable
final class WatchLink: NSObject {
  /// What the phone last said is running. Empty until the first context arrives.
  private(set) var state = WatchBlockState()

  /// Taps made during the block now running.
  ///
  /// **Shown so that a press is visibly answered.** The phone has drawn this
  /// beside its capture buttons since F5 — *"the count drawn beside each capture
  /// button is about this block and never about the day"* — and the wrist now
  /// matches it. It is a receipt, not a score: it resets at every boundary and
  /// never sums a day.
  private(set) var tapsThisBlock = 0

  /// The split, so the wrist can phrase the tally the way the phone does.
  private(set) var internalThisBlock = 0
  private(set) var externalThisBlock = 0

  /// Taps this watch has handed to the system but not yet seen acknowledged.
  ///
  /// Shown as a quiet "will sync" count, never as an error. The tap is already
  /// safe — the system has taken responsibility for delivering it — so the
  /// wording has to say *waiting*, not *failed*.
  private(set) var pendingTaps = 0

  /// Whether the phone is reachable right now.
  ///
  /// **Observed, never used to gate a tap.** A button that refuses while the
  /// phone is in another room defeats the entire feature. This exists only so the
  /// screen can be honest about what it is showing.
  private(set) var isReachable = false

  override init() {
    super.init()
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  /// Records a distraction and hands it to the system for delivery.
  ///
  /// Returns `false` when there is no running block to attach it to, which the
  /// screen prevents by hiding the buttons — the guard is here as well because a
  /// tap with no session is unattributable, and the phone would have to guess.
  @discardableResult
  func record(_ kind: DistractionKind) -> Bool {
    guard let block = state.block, state.acceptsTaps else { return false }

    let tap = WatchTap(id: UUID(), kind: kind, tappedAt: Date(), sessionID: block.sessionID)
    guard let payload = try? JSONEncoder().encode(tap) else { return false }

    // COUNTED BEFORE IT IS SENT, AND THE ORDER IS THE WHOLE FIX.
    //
    // These two lines used to sit *after* the transfer below, which is a
    // synchronous call into the system's queue and was measured on a real wrist
    // at over two seconds. Nothing on screen moved until it returned, so the
    // button read as dead — and the owner did the only sensible thing and pressed
    // it again. Several times. Each press was a real tap and each became a real
    // row, so a laggy button quietly inflated the one number this app exists to
    // produce.
    //
    // The tap is already a finished fact by this point: its identity, its kind
    // and its moment are all in `tap`, stamped before anything slow happens.
    // Counting it here is therefore not optimism about delivery — it is a
    // statement about something that has already occurred.
    tapsThisBlock += 1
    switch kind {
    case .internalInterruption: internalThisBlock += 1
    case .externalInterruption: externalThisBlock += 1
    }
    pendingTaps += 1

    // transferUserInfo, NOT sendMessage. See the note at the top of this file:
    // this call is what makes a tap survive the phone being in another room.
    //
    // OFF THE MAIN ACTOR. It is thread-safe, it does not need to be awaited, and
    // whatever it costs must not be paid by the screen. `payload` is `Data` and
    // the call returns nothing worth having, so nothing comes back here.
    Task.detached {
      // Discarded explicitly. The returned transfer object is not `Sendable`, and
      // without this the closure's result type becomes it and the compiler
      // refuses. Nothing here wants it: progress is reported through the
      // delegate, not through a handle held on the wrist.
      _ = WCSession.default.transferUserInfo([WatchLinkKeys.tap: payload])
    }
    return true
  }

}

// MARK: - WCSessionDelegate

/// **Decode and hand off. No logic lives in here.**
///
/// Every method below is called by the system on a background thread, and the
/// only thing each does is get the work onto the main actor and give it to the
/// object above. A delegate that decides things is a delegate whose decisions are
/// unreachable from a test.
extension WatchLink: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?) {
    let reachable = session.isReachable
    Task { @MainActor in self.isReachable = reachable }
  }

  nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
    let reachable = session.isReachable
    Task { @MainActor in self.isReachable = reachable }
  }

  nonisolated func session(
    _ session: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]) {
    guard
      let payload = applicationContext[WatchLinkKeys.state] as? Data,
      let decoded = try? JSONDecoder().decode(WatchBlockState.self, from: payload)
    else { return }
    Task { @MainActor in
      // A new block starts its own count. The check is on the session rather than
      // on the whole state, because the phone re-sends the same block whenever
      // the attached task changes and that must not wipe the tally.
      if decoded.block?.sessionID != self.state.block?.sessionID {
        self.tapsThisBlock = 0
        self.internalThisBlock = 0
        self.externalThisBlock = 0
      }
      self.state = decoded
    }
  }

  nonisolated func session(
    _ session: WCSession,
    didFinish userInfoTransfer: WCSessionUserInfoTransfer,
    error: Error?) {
    // The system has delivered it, or given up. Either way it is no longer this
    // app's problem: `transferUserInfo` persists across launches, so a failure
    // here does not mean the tap is gone.
    Task { @MainActor in self.pendingTaps = max(0, self.pendingTaps - 1) }
  }
}
