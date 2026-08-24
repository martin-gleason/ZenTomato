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

    // transferUserInfo, NOT sendMessage. See the note at the top of this file:
    // this call is what makes a tap survive the phone being in another room.
    WCSession.default.transferUserInfo([WatchLink.tapKey: payload])
    pendingTaps += 1
    return true
  }

  /// The key the tap travels under. One constant, referred to by both sides.
  ///
  /// `nonisolated` because the session delegate reads them from a background
  /// thread. They are immutable strings, so there is nothing to race on.
  nonisolated static let tapKey = "tap"

  /// The key the block state travels under.
  nonisolated static let stateKey = "state"
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
      let payload = applicationContext[WatchLink.stateKey] as? Data,
      let decoded = try? JSONDecoder().decode(WatchBlockState.self, from: payload)
    else { return }
    Task { @MainActor in self.state = decoded }
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
