import Foundation

/// The two ways playing music can fail.
///
/// **BOTH OF THESE LEAVE A WORKING TIMER.** That is the ratified decision this
/// whole feature is shaped around: music is an accessory, so every failure in
/// it degrades to a silent working timer and never to a broken one. Neither
/// case below stops a block, delays a block, changes a block's length, or
/// prevents a block from being recorded. The most either of them can do is
/// make the app quiet and put one plain muted line on the timer screen.
///
/// **WHY THERE ARE ONLY TWO, AND WHY NEITHER CARRIES THE UNDERLYING ERROR.**
/// Apple's player can fail for a dozen reasons — the network, the subscription,
/// a file that will not download, a device that is busy. This app does exactly
/// the same thing about every one of them: stay quiet, show one fixed sentence,
/// and try again at the start of the next focus block. Carrying a reason that
/// nothing reads and nothing displays would be a value invented to look
/// thorough. What matters is the distinction below, which the app *does* act
/// on differently — one of them tells the person to pick something else, and
/// the other tells them nothing is wrong.
///
/// The errors are not swallowed: `MusicCoordinator` catches both and turns them
/// into state the screen reads. Nothing is discarded silently.
enum MusicPlaybackError: Error, Equatable {
  /// The chosen playlist or song is not in the user's library any more.
  ///
  /// A playlist can be renamed or deleted in the Music app at any time, and
  /// this app finds out at the moment it tries to play it. This is the only
  /// route to the screen's *"'Deep Focus' isn't in your library any more"*
  /// line, and it is the one music failure the person can actually do something
  /// about — so it is the one case that is told apart from the rest.
  case selectionMissing

  /// The player refused, for a reason this app cannot act on.
  ///
  /// The screen's answer is one sentence — *"Music didn't start. The block is
  /// running as normal."* — and no retry button, because there is nothing to
  /// retry by hand: the start of the next focus block tries again on its own.
  case playbackFailed
}
