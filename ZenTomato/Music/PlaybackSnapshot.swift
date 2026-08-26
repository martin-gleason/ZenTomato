import Foundation

/// What the player is doing, read once and carried across an actor hop.
///
/// **WHY THIS TYPE EXISTS, AND IT IS NOT TIDINESS.**
/// `docs/crashes/ZenTomato-2026-08-26-134602.ips` is the app being killed by the
/// watchdog — `0x8BADF00D`, ten seconds of wall clock against **53 milliseconds**
/// of our own CPU. Not looping: blocked. The main-thread stack ended in
/// `xpc_connection_send_message_with_reply_sync` underneath
/// `MPMusicPlayerController.playbackState`.
///
/// **`playbackStatus` reads like a property and behaves like a blocking call to
/// another process.** `F4-contract.md` §8 decided to read it live rather than
/// cache it, for a good reason — a cached value made the skip button lie about
/// whether there was anything to skip. What that decision did not price is that
/// asking costs an IPC round trip, and when the media daemon is wedged the
/// caller waits for it. On the main thread, that is a dead app.
///
/// The fix is **not** to cache. It is to ask somewhere the answer is allowed to
/// be late. Both values are read together, off the main actor, into this one
/// `Sendable` value — together because they are always used together, and a row
/// showing "playing" beside a stale track title would be a new way to be wrong.
struct PlaybackSnapshot: Equatable, Sendable {
  /// Whether sound is actually coming out.
  let isPlaying: Bool

  /// The track that is playing, or `nil` when nothing is.
  let nowPlayingTitle: String?

  /// Nothing playing, nothing to name. The value a read starts from and the one
  /// a failed read is entitled to assume, since "no sound" hides the transport
  /// controls rather than offering ones that would do nothing.
  static let silent = PlaybackSnapshot(isPlaying: false, nowPlayingTitle: nil)
}
