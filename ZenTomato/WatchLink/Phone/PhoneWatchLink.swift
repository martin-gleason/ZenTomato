import Foundation
import SwiftData
import WatchConnectivity

/// The phone's end of the connection to the wrist.
///
/// **Two jobs, and the delegate does neither of them.** It decodes and hands off;
/// everything that decides anything is in `WatchTapInbox` or in the state this
/// object is asked to send. A delegate that decides things is a delegate whose
/// decisions cannot be reached from a test.
///
/// **This is strictly additive and must stay that way.** An unpaired watch, one
/// left on a charger, or one that was never bought must not change how the phone
/// behaves in any respect. Every method below is a no-op when no session is
/// supported, and nothing in the app is allowed to wait on this class.
@MainActor
@Observable
final class PhoneWatchLink: NSObject {
  /// How many taps have arrived from the wrist this launch. Diagnostic only —
  /// nothing on any screen depends on it.
  private(set) var receivedTaps = 0

  init(context: ModelContext, engine: TimerEngine? = nil) {
    inbox = WatchTapInbox(context: context)
    self.engine = engine
    super.init()
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  /// Tells the wrist what is running now.
  ///
  /// **`updateApplicationContext`, not `sendMessage`.** Latest-value-wins with no
  /// queue is exactly right here: an old block is worthless to a wrist, so the
  /// system dropping a superseded state is correct behaviour rather than data
  /// loss. It also costs nothing when the watch is not listening.
  ///
  /// Called at block boundaries and when the attached task changes — a handful of
  /// times per sprint, not once a second. The watch draws its own countdown from
  /// the `endsAt` inside, so silence between blocks is free.
  func send(_ state: WatchBlockState) {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    guard session.activationState == .activated else { return }
    guard let payload = try? JSONEncoder().encode(state) else { return }
    // `try?` and not a thrown error: the only documented failures are "not
    // paired" and "not installed", and neither is a fault in this app. A phone
    // with no watch is the normal case.
    try? session.updateApplicationContext([WatchLinkKeys.state: payload])
  }

  // MARK: Private

  private let inbox: WatchTapInbox

  /// The running timer, so a tap that arrives during its own block can still be
  /// asked about in the end-of-block sheet. Optional because the link is useful
  /// without it — the row is written either way — and because a test should be
  /// able to exercise ingest with no engine at all.
  private weak var engine: TimerEngine?
}

// MARK: - WCSessionDelegate

extension PhoneWatchLink: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?) {}

  /// Required on iOS. The session must be reactivated so a second watch can pair.
  nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

  nonisolated func sessionDidDeactivate(_ session: WCSession) {
    WCSession.default.activate()
  }

  /// A tap, delivered whenever the system managed it.
  ///
  /// This may fire long after the tap was made, after this app was relaunched,
  /// and more than once for the same tap. All three are normal; the inbox handles
  /// the third.
  nonisolated func session(
    _ session: WCSession,
    didReceiveUserInfo userInfo: [String: Any] = [:]) {
    guard
      let payload = userInfo[WatchLinkKeys.tap] as? Data,
      let tap = try? JSONDecoder().decode(WatchTap.self, from: payload)
    else { return }
    Task { @MainActor in
      guard self.inbox.receive(tap) == .recorded else { return }
      self.receivedTaps += 1
      // The row is already safe. This only decides whether the end-of-block
      // sheet asks for a sentence about it, and it is refused when the tap
      // belongs to a block that has already ended.
      self.engine?.adoptWristTap(
        id: tap.id, kind: tap.kind, at: tap.tappedAt, sessionID: tap.sessionID)
    }
  }
}
