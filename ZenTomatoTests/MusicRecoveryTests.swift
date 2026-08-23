import Foundation
import Testing

@testable import ZenTomato

/// Getting back from a state music cannot play in.
///
/// **THE FEATURE'S ONE DESIGNED-IN DEAD END, AND THESE ARE THE TESTS FOR ITS
/// EXIT.** Whether this app may play music was read once, at launch, and never
/// again. So the commonest outcome of a first run — one mis-tap on the system
/// prompt — made music unreachable for the life of the process, and the switch
/// that would have asked again is dimmed by exactly the state it would have
/// cleared. The app's own words made it worse: the Music sheet says to grant the
/// permission in the Settings app and gives you a button that opens it. You
/// grant it, come back, and nothing has changed. Only force-quitting helped, and
/// nothing said so.
///
/// The same door is reached with no user action at all by a check that could not
/// be completed — a phone that launched in a lift, one failed library read.
///
/// The way out is that availability is re-read at the two moments that mean
/// somebody may have just changed something: the app coming back to the front,
/// and the Music sheet being opened. Both are reads, and neither can prompt for
/// anything — which is what the last assertion in each test below is for.
@Suite("MusicRecovery")
@MainActor
struct MusicRecoveryTests {
  private static let deepFocus = MusicSelection(
    kind: .playlist, identifier: "p.deepfocus", title: "Deep Focus")

  // MARK: The way back

  /// Permission granted in the Settings app takes effect on coming back to the
  /// app.
  ///
  /// **THIS IS THE TEST FOR THE FEATURE'S ONE DEAD END.** Whether music may play
  /// was read once at launch and never again, so the commonest first-run outcome
  /// — one mis-tap on the system prompt — killed music for the life of the
  /// process. And the switch, the only control that would have re-asked, is
  /// dimmed by exactly the state it would have cleared: `isTogglable` is false
  /// while music is unavailable, in the row and in the sheet alike. So the app
  /// told the person to go to the Settings app, gave them a button that opened
  /// it, and then could not see what they did there. Only force-quitting helped,
  /// and nothing said so.
  ///
  /// The assertion is deliberately made on the row as well as on the
  /// coordinator, because "the state changed" is not the claim — the claim is
  /// that the switch can be touched again.
  @Test("permissionGrantedElsewhereIsNoticedOnComingBack")
  func permissionGrantedElsewhereIsNoticedOnComingBack() async {
    let availability = StubMusicAvailability(current: .notAsked, authorizationAnswer: .denied)
    let coordinator = MusicCoordinator(
      player: SpyMusicPlayer(),
      availability: availability,
      library: StubMusicLibrary(),
      preferences: StubMusicPreferenceStore(isEnabled: false, selection: Self.deepFocus))

    await coordinator.setEnabled(true)
    #expect(coordinator.availability == .denied)
    #expect(Self.row(for: coordinator).isTogglable == false, "the dead end")

    // What the person did in the Settings app, and then came back.
    availability.refreshAnswer = .ready
    coordinator.refreshAvailability()
    await settle(until: { coordinator.availability == .ready })

    #expect(coordinator.availability == .ready)
    #expect(Self.row(for: coordinator).isTogglable, "the switch is still dead")
    #expect(availability.authorizationRequests == 1, "coming back must not re-prompt")
  }

  /// A check that could not be completed at all clears itself the next time it
  /// can be.
  ///
  /// The same dead end reached with no user action whatsoever: a phone that
  /// launched in a lift, or one failed library read. The doc comment on
  /// `MusicAvailability.couldNotBeChecked` promises *"it clears itself the next
  /// time the check succeeds"*, and until there was a next check that sentence
  /// was not true.
  @Test("aCheckThatCouldNotBeMadeClearsItselfOnTheNextOne")
  func aCheckThatCouldNotBeMadeClearsItselfOnTheNextOne() async {
    let availability = StubMusicAvailability(current: .couldNotBeChecked)
    let coordinator = MusicCoordinator(
      player: SpyMusicPlayer(),
      availability: availability,
      library: StubMusicLibrary(),
      preferences: StubMusicPreferenceStore(isEnabled: true, selection: Self.deepFocus))

    #expect(coordinator.availability == .couldNotBeChecked)
    #expect(Self.row(for: coordinator).isTogglable == false)

    availability.refreshAnswer = .ready
    coordinator.refreshAvailability()
    await settle(until: { coordinator.availability == .ready })

    #expect(coordinator.availability == .ready)
    #expect(Self.row(for: coordinator).isTogglable)
    #expect(availability.authorizationRequests == 0, "a re-check must never prompt")
  }

  // MARK: Helpers

  /// The idle music row as the timer screen would build it from this
  /// coordinator. What a reviewer is really asking about is the switch, not the
  /// value behind it.
  private static func row(for coordinator: MusicCoordinator) -> MusicRowModel {
    MusicRowModel.forTimer(
      isRunning: false,
      kind: .work,
      isEnabled: coordinator.isEnabled,
      availability: coordinator.availability,
      selection: coordinator.selection)
  }

  /// See `MusicTransitionTests.settle(until:limit:)`. Nothing here sleeps.
  private func settle(until isSettled: () -> Bool, limit: Int = 10_000) async {
    for _ in 0..<limit where !isSettled() {
      await Task.yield()
    }
  }
}
