import Foundation
import Testing

@testable import ZenTomato

/// The row names the track, not the playlist.
///
/// Asked for from the device: "The title of the song playing should also play."
/// The playlist name tells you nothing you did not already know — you chose it.
/// Which song is on is the one thing you cannot get without leaving the app,
/// which is the opposite of what a focus screen is for.
@MainActor
struct MusicNowPlayingTests {
  @Test("a playing block names the track")
  func playingNamesTheTrack() {
    let row = Self.row(playback: .playing, nowPlaying: "An Ending (Ascent)")
    #expect(row.line == "An Ending (Ascent)")
  }

  /// The player does not always know yet — the status can flip before the queue
  /// has an entry. The playlist name is the honest fallback.
  @Test("an unknown track falls back to the playlist")
  func unknownTrackFallsBack() {
    let row = Self.row(playback: .playing, nowPlaying: nil)
    #expect(row.line == "Deep Focus")
  }

  /// Nothing is playing on a break, so nothing is named. A track name beside
  /// "paused" would be the name of something making no sound.
  @Test("a break names no track")
  func breakNamesNoTrack() {
    let row = MusicRowModel.forTimer(
      isRunning: true, kind: .shortBreak, isEnabled: true, availability: .ready,
      selection: Self.chosen, playback: .playing, nowPlayingTitle: "An Ending (Ascent)")
    #expect(row.line.contains("An Ending") == false)
  }

  /// The track name must come from the player every time it is asked for, not
  /// from something remembered at the last status change.
  ///
  /// The device symptom of getting this wrong was precise and easy to miss:
  /// "Heroes plays and Heroes is listed. But Heroes remains when the next song
  /// is By This River. Then when the song advances to Cool It Down, it is listed
  /// as By This River." Always exactly one behind.
  @Test("the track name follows the player, one refresh at a time")
  func trackNameIsNotOneBehind() async {
    let player = SpyMusicPlayer()
    let coordinator = MusicCoordinator(
      player: player,
      availability: StubMusicAvailability(),
      library: StubMusicLibrary(),
      preferences: StubMusicPreferenceStore(isEnabled: true, selection: Self.chosen))

    coordinator.blockChanged(to: .work, isRunning: true)
    for _ in 0 ..< 8 { await Task.yield() }

    player.nowPlayingTitle = "Heroes"
    player.announceStatusChange()
    #expect(coordinator.nowPlayingTitle == "Heroes")

    // The track advances. This is the moment that was silently missed, because
    // the queue announces it and only the state was being listened to.
    player.nowPlayingTitle = "By This River"
    player.announceStatusChange()
    #expect(coordinator.nowPlayingTitle == "By This River", "not the previous track")

    player.nowPlayingTitle = "Cool It Down"
    player.announceStatusChange()
    #expect(coordinator.nowPlayingTitle == "Cool It Down")
  }

  // MARK: Private

  private static let chosen = MusicSelection(
    kind: .playlist, identifier: "p.1", title: "Deep Focus")

  private static func row(
    playback: MusicRowModel.Playback,
    nowPlaying: String?
  ) -> MusicRowModel {
    MusicRowModel.forTimer(
      isRunning: true, kind: .work, isEnabled: true, availability: .ready,
      selection: chosen, playback: playback, nowPlayingTitle: nowPlaying)
  }
}
