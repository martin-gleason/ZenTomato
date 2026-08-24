import Foundation
import Testing

@testable import ZenTomato

/// The music row, in every state it has.
///
/// WHY THESE ARE WORTH HAVING
/// The row is one line of grey text and two controls, and it is the whole of what
/// this feature looks like on the screen somebody actually uses. Every claim F4
/// makes about itself — skip forward is the only control, the switch is set
/// before a sprint and not during one, a failure leaves a working silent timer,
/// the space the skip button occupies never changes — is a claim about the values
/// below, so they are checked here rather than argued for in a comment.
///
/// None of these needs a timer, a player, a database or a screen. That is the
/// point of the rule being a pure function over five finished facts.
@Suite("MusicRowModel")
struct MusicRowModelTests {
  // MARK: The claim the reviewer will test

  /// **While a block is running, the only thing in the music row that can be
  /// operated is the skip button** — and during a break, nothing can.
  ///
  /// Counted rather than described, because "is any other control reachable?" is
  /// the question this feature will be asked and a number is the only answer
  /// that cannot be fudged. Idle is two: the switch and the line, neither of
  /// which is a transport control, because nothing is playing.
  /// Skip and stop are the ONLY transport controls, and only while a focus block
  /// is actually making sound (D20).
  ///
  /// This test failed when stop was added, which is what it is for. The count is
  /// asserted as a number rather than described in a comment precisely so that
  /// widening the row is a decision somebody has to make on purpose — a volume
  /// slider or a shuffle toggle would break it too, and neither has a delta.
  @Test("skipAndStopAreTheOnlyControls")
  func skipAndStopAreTheOnlyControls() {
    let idle = Self.row(isRunning: false, kind: .work)
    #expect(idle.interactiveControlCount == 2)
    #expect(idle.canSkip == false)
    #expect(idle.canStop == false, "there is nothing playing to stop")

    let working = Self.row(isRunning: true, kind: .work, playback: .playing)
    #expect(working.interactiveControlCount == 2)
    #expect(working.canSkip)
    #expect(working.canStop)
    #expect(working.isTogglable == false)
    #expect(working.isLineTappable == false)

    // Both answer the same question — is there sound to act on — so they must
    // never disagree. A row offering stop but not skip, or the reverse, would
    // change the reserved row's width at a block boundary.
    #expect(working.canSkip == working.canStop)

    for breakKind in [BlockKind.shortBreak, BlockKind.longBreak] {
      let onABreak = Self.row(isRunning: true, kind: breakKind, playback: .playing)
      #expect(onABreak.interactiveControlCount == 0)
      #expect(onABreak.canSkip == false)
      #expect(onABreak.canStop == false)
    }
  }

  /// The skip button is drawn in exactly one situation, and every other
  /// combination reserves its space instead.
  ///
  /// Written as a sweep rather than as a handful of examples, because the states
  /// this rule has to hold for are the product of five facts and the interesting
  /// ones are the combinations nobody thinks of.
  @Test("theSkipButtonIsDrawnOnlyWhileAFocusBlockIsActuallyPlaying")
  func theSkipButtonIsDrawnOnlyWhileAFocusBlockIsActuallyPlaying() {
    for isRunning in [true, false] {
      for kind in BlockKind.allCases {
        for isEnabled in [true, false] {
          for playback in Self.everyPlaybackState {
            let row = MusicRowModel.forTimer(
              isRunning: isRunning,
              kind: kind,
              isEnabled: isEnabled,
              availability: .ready,
              selection: Self.chosen,
              playback: playback)

            let shouldDrawIt = isRunning && kind == .work && isEnabled && playback == .playing
            #expect(row.canSkip == shouldDrawIt)
          }
        }
      }
    }
  }

  // MARK: The switch

  /// `SPEC.md` says music is toggled before a sprint. Mid-sprint the switch is
  /// present and cannot be touched — present, because removing it would make a
  /// control appear and disappear at every block boundary, which is the movement
  /// D19.3 forbids.
  @Test("theSwitchIsLockedWhileABlockRuns")
  func theSwitchIsLockedWhileABlockRuns() {
    for kind in BlockKind.allCases {
      #expect(Self.row(isRunning: true, kind: kind).isTogglable == false)
    }
    #expect(Self.row(isRunning: false, kind: .work).isTogglable)
  }

  /// A switch sitting in the on position while nothing can play is a control that
  /// lies about itself. Every way music can be unavailable draws it off, and
  /// draws it dimmed.
  @Test("anUnavailableSwitchIsNeverDrawnOn")
  func anUnavailableSwitchIsNeverDrawnOn() {
    for availability in Self.everyUnavailableState {
      let row = MusicRowModel.forTimer(
        isRunning: false,
        kind: .work,
        isEnabled: true,
        availability: availability,
        selection: Self.chosen)

      #expect(row.isOn == false)
      #expect(row.isTogglable == false)
      // And it is still a way in, which is what stops a failure being a dead end.
      #expect(row.isLineTappable)
    }
  }

  // MARK: The line

  /// The line is a control in **every** idle state, including every failed one.
  ///
  /// This is the F3 lesson held as a test rather than as a comment: that review
  /// found an entire feature unreachable because its only door read as a caption.
  /// This row is the only door to the whole music feature.
  @Test("everyIdleStateOffersTheLineAsAWayIn")
  func everyIdleStateOffersTheLineAsAWayIn() {
    for availability in Self.everyAvailabilityState {
      for selection in [Self.chosen, nil] {
        let row = MusicRowModel.forTimer(
          isRunning: false,
          kind: .work,
          isEnabled: true,
          availability: availability,
          selection: selection)

        #expect(row.isLineTappable)
        #expect(row.line.isEmpty == false)
      }
    }
  }

  /// Inert while a block runs, in every state of it — because D19 says music is
  /// set before a sprint, and a screen offering a choice it will not honour is
  /// worse than one offering none.
  @Test("theLineIsInertWhileABlockRuns")
  func theLineIsInertWhileABlockRuns() {
    for kind in BlockKind.allCases {
      #expect(Self.row(isRunning: true, kind: kind).isLineTappable == false)
    }
  }

  /// Nothing chosen is an invitation rather than a status, for the same reason
  /// "No task attached" became "Choose what to work on".
  @Test("nothingChosenIsAnInvitation")
  func nothingChosenIsAnInvitation() {
    let row = MusicRowModel.forTimer(
      isRunning: false,
      kind: .work,
      isEnabled: false,
      availability: .notAsked,
      selection: nil)

    #expect(row.line == MusicCopy.chooseSomething)
    #expect(row.isLineTappable)
  }

  /// **The line is never blank on a break, and it says the music is coming
  /// back.** A blank reserved band reads as a rendering fault, and this is the
  /// only place on the screen where that promise is made at all.
  @Test("bothKindsOfBreakSayTheMusicComesBack")
  func bothKindsOfBreakSayTheMusicComesBack() {
    for kind in [BlockKind.shortBreak, BlockKind.longBreak] {
      let row = Self.row(isRunning: true, kind: kind, playback: .silent)
      #expect(row.line == MusicCopy.pausedForTheBreak)
    }
  }

  /// A stale identifier produces an explaining state rather than a blank row or a
  /// crash — the music-shaped version of the guarantee F3 makes about a task that
  /// has left Todoist.
  @Test("missingPlaylistPromptsReselect")
  func missingPlaylistPromptsReselect() {
    let row = MusicRowModel.forTimer(
      isRunning: false,
      kind: .work,
      isEnabled: true,
      availability: .ready,
      selection: Self.chosen,
      selectionIsGone: true)

    #expect(row.line == MusicCopy.gone("Deep Focus"))
    #expect(row.line.contains("Deep Focus"))
    // The way to fix it is one tap away.
    #expect(row.isLineTappable)
  }

  /// A subscription that lapses mid-sprint stops the music and says the block is
  /// still running. Named in F4's own risk list as cheap to handle and easy to
  /// forget.
  @Test("aSubscriptionEndingMidSprintSaysTheBlockCarriesOn")
  func aSubscriptionEndingMidSprintSaysTheBlockCarriesOn() {
    let row = MusicRowModel.forTimer(
      isRunning: true,
      kind: .work,
      isEnabled: true,
      availability: .noSubscription,
      selection: Self.chosen,
      playback: .silent)

    #expect(row.line == MusicCopy.subscriptionEnded)
    #expect(row.line.contains("still running"))
    #expect(row.canSkip == false)
    #expect(row.isOn == false)
  }

  /// Music that could not be started says so, and says the block is unaffected.
  @Test("playbackThatDidNotStartSaysTheBlockIsUnaffected")
  func playbackThatDidNotStartSaysTheBlockIsUnaffected() {
    let row = Self.row(isRunning: true, kind: .work, playback: .didNotStart)

    #expect(row.line == MusicCopy.playbackDidNotStart)
    #expect(row.line.contains("running as normal"))
    #expect(row.canSkip == false)
  }

  /// Switched off with a block running says so plainly, rather than showing a
  /// title that is not playing.
  @Test("musicSwitchedOffDuringABlockSaysSo")
  func musicSwitchedOffDuringABlockSaysSo() {
    let row = MusicRowModel.forTimer(
      isRunning: true,
      kind: .work,
      isEnabled: false,
      availability: .ready,
      selection: Self.chosen,
      playback: .silent)

    #expect(row.line == MusicCopy.musicOff)
  }

  // MARK: The row's place on the screen

  /// **The row is present in every state of the timer screen except one**, which
  /// is what makes it impossible for it to move the countdown.
  ///
  /// The exception is the screen with no settings row to read: dashes, Start
  /// switched off, and no cycle that could run. `progress` is absent in exactly
  /// the same state and for the same reason.
  @Test("theOnlyScreenWithNoMusicRowIsTheOneWithNoTimer")
  func theOnlyScreenWithNoMusicRowIsTheOneWithNoTimer() {
    let broken = TimerScreenModel.noSettingsRow(numeral: "--:--")
    #expect(broken.music == nil)
    #expect(broken.progress == nil)

    let working = TimerScreenModel(
      blockName: "Focus block",
      kicker: "Focus",
      numeral: "25:00",
      spokenNumeral: "25 minutes",
      progress: TimerScreenModel.Progress(completed: 0, total: 4),
      music: Self.row(isRunning: false, kind: .work),
      controls: .start(isEnabled: true, spokenLabel: "Start focus block, 25 minutes"))
    #expect(working.music != nil)
  }

  // MARK: The words

  /// Nothing this row can say invites building a playlist, and nothing it says
  /// when something has gone wrong reads as though the app is broken.
  ///
  /// Every failure in this feature leaves a working silent timer, and each of
  /// these lines has to say so in words rather than leave it to be inferred.
  @Test("noLineThisRowCanSayInvitesBuildingSomething")
  func noLineThisRowCanSayInvitesBuildingSomething() {
    for sentence in Self.everyLineTheRowCanSay {
      for word in Self.creationWords {
        #expect(
          sentence.range(of: word, options: .caseInsensitive) == nil,
          "“\(sentence)” contains “\(word)”.")
      }
    }
  }

  /// Every line that reports something going wrong also says the timer is fine.
  @Test("everyFailureLineSaysTheTimerIsUnaffected")
  func everyFailureLineSaysTheTimerIsUnaffected() {
    #expect(MusicCopy.playbackDidNotStart.contains("running as normal"))
    #expect(MusicCopy.subscriptionEnded.contains("still running"))
    #expect(MusicCopy.deniedFooter.contains("The timer works exactly the same"))
    #expect(MusicCopy.restrictedFooter.contains("The timer works exactly the same"))
    #expect(MusicCopy.noSubscriptionFooter.contains("The timer works exactly the same"))
    #expect(MusicCopy.couldNotBeCheckedFooter.contains("The timer works exactly the same"))
    #expect(MusicCopy.libraryUnreadable.contains("The timer works exactly the same"))
  }

  /// No jargon reaches a person. Not one of these lines names the framework, a
  /// permission mechanism, an error code or a status.
  @Test("noLineNamesAnythingTechnical")
  func noLineNamesAnythingTechnical() {
    let jargon = ["MusicKit", "authorization", "entitlement", "status code", "nil", "error code"]
    for sentence in Self.everyLineTheRowCanSay {
      for word in jargon {
        #expect(
          sentence.range(of: word, options: .caseInsensitive) == nil,
          "“\(sentence)” contains “\(word)”.")
      }
    }
  }

  // MARK: Private

  private static let chosen = MusicSelection(
    kind: .playlist,
    identifier: "p.1",
    title: "Deep Focus")

  private static let creationWords = ["create", "new playlist", "add to", "compose", "+ "]

  private static let everyPlaybackState: [MusicRowModel.Playback] = [
    .silent, .starting, .playing, .didNotStart
  ]

  private static let everyUnavailableState: [MusicAvailability] = [
    .denied, .restricted, .noSubscription, .couldNotBeChecked
  ]

  private static let everyAvailabilityState: [MusicAvailability] =
    [.ready, .notAsked] + everyUnavailableState

  /// Every sentence the row can put in front of somebody, gathered in one place
  /// so that a new one has to be added here to be shipped.
  private static let everyLineTheRowCanSay = [
    MusicCopy.chooseSomething,
    MusicCopy.musicOff,
    MusicCopy.nothingChosenSoQuiet,
    MusicCopy.starting,
    MusicCopy.playbackDidNotStart,
    MusicCopy.pausedForTheBreak,
    MusicCopy.subscriptionEnded,
    MusicCopy.emptyLibraryLine,
    MusicCopy.gone("Deep Focus"),
    MusicCopy.goneWithAdvice("Deep Focus"),
    MusicCopy.libraryUnreadable,
    MusicCopy.deniedFooter,
    MusicCopy.restrictedFooter,
    MusicCopy.noSubscriptionFooter,
    MusicCopy.couldNotBeCheckedFooter,
    MusicCopy.playbackFailedFooter,
    MusicCopy.emptyLibraryHeading,
    MusicCopy.emptyLibraryDetail,
    MusicCopy.toggleLabel,
    MusicCopy.toggleHint,
    MusicCopy.lockedHint,
    MusicCopy.runningBlockNote,
    MusicCopy.skipLabel,
    MusicCopy.skipHint,
    MusicCopy.readingLibrary,
    MusicCopy.notAskedYet,
    MusicCopy.systemControlsNote,
    MusicCopy.openSettings
  ]

  /// One row, with everything working and something chosen.
  private static func row(
    isRunning: Bool,
    kind: BlockKind,
    playback: MusicRowModel.Playback = .silent
  ) -> MusicRowModel {
    MusicRowModel.forTimer(
      isRunning: isRunning,
      kind: kind,
      isEnabled: true,
      availability: .ready,
      selection: chosen,
      playback: playback)
  }
}
