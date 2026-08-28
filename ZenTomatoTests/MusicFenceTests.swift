import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// The fence around F4, as tests rather than as promises.
///
/// WHY THIS FILE EXISTS
/// Music is the feature in this app with the most obvious next step at every
/// point. A volume control. A now-playing row with the artwork. A shuffle
/// switch. A "smart" default playlist — which `SPEC.md` names in its
/// out-of-scope list by name. None of those arrives as a bad decision; each
/// arrives as one small, obviously useful commit on a different afternoon.
///
/// Prose did not hold that line in F3 or in F5. So the rules that can be
/// mechanical are mechanical: the database is asked what columns exist, the
/// screen model is asked how many controls it offers, and the vocabulary is
/// asked whether it invites anybody to build something. The rest are greps the
/// reviewer runs, and they are listed in `docs/plans/F4-contract.md` §6.
@Suite("MusicFence")
struct MusicFenceTests {
  // MARK: The four columns

  /// F4's own row has exactly four columns: whether music is on, which of the two
  /// kinds of thing is chosen, its identifier, and the title it had when it was
  /// chosen.
  ///
  /// **A fifth cannot be added quietly.** How often it was played, when it was
  /// last used, which track it reached — each is one column, each looks harmless,
  /// and together they are a small local copy of somebody's music library with
  /// opinions of its own. Adding one means deliberately changing this test as
  /// well, in a diff the owner reads.
  @Test("musicPreferenceHasFourStoredProperties")
  func musicPreferenceHasFourStoredProperties() throws {
    let entity = try #require(Schema([MusicPreference.self]).entities.first)
    let columns = Set(entity.properties.map(\.name))

    #expect(columns == ["isEnabled", "selectionKind", "selectionID", "selectionTitle"])
  }

  /// **The position inside a track is deliberately not one of those columns.**
  ///
  /// Mid-track position lives in the player's own queue and dies with the
  /// process, so an app that is killed mid-sprint starts the chosen item from its
  /// beginning at the next focus block. Persisting it would need the player's
  /// playback position, which the playback protocol makes unreachable on purpose
  /// — the same member that would let somebody build a way of moving through a
  /// track. Stated here rather than discovered in a review.
  @Test("nothingRemembersWhereATrackHadGotTo")
  func nothingRemembersWhereATrackHadGotTo() throws {
    let entity = try #require(Schema([MusicPreference.self]).entities.first)
    let columns = entity.properties.map(\.name)

    for column in columns {
      for word in ["position", "elapsed", "time", "offset", "track"] {
        #expect(
          column.range(of: word, options: .caseInsensitive) == nil,
          "MusicPreference gained a column called \(column).")
      }
    }
  }

  // MARK: The six-field rule, from the other side

  /// **`AppSettings` gains nothing from F4.** Its own doc comment names the
  /// absence of a music switch by name, and `SPEC.md`'s customisation list is six
  /// items long and ends with the words "Nothing else."
  ///
  /// `AppSettingsTests` asserts the six columns are the six columns; this asserts
  /// the specific thing F4 was most likely to do to it, which is to add a seventh
  /// because it was the obvious place.
  @Test("appSettingsHasNoMusicColumn")
  func appSettingsHasNoMusicColumn() throws {
    let entity = try #require(Schema([AppSettings.self]).entities.first)
    let columns = entity.properties.map(\.name)

    #expect(columns.count == 6)
    for column in columns {
      for word in ["music", "playlist", "song", "audio", "volume"] {
        #expect(
          column.range(of: word, options: .caseInsensitive) == nil,
          "AppSettings gained a column called \(column).")
      }
    }
  }

  /// F4's row can actually be saved.
  ///
  /// A saved type left out of the schema is not a compile error: it is a crash on
  /// the first insert, in the app and in every test, with a message naming
  /// SwiftData rather than the missing line. Six types were added at once in F3
  /// and this is the check that caught them.
  @Test("theMusicRowIsInTheSchema")
  @MainActor
  func theMusicRowIsInTheSchema() throws {
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext

    context.insert(MusicPreference(
      isEnabled: true,
      selectionKind: "playlist",
      selectionID: "p.1",
      selectionTitle: "Deep Focus"))
    try context.save()

    #expect(try context.fetch(FetchDescriptor<MusicPreference>()).count == 1)
  }

  // MARK: One transport control

  /// **The row exposes exactly one transport action, and only in one state.**
  ///
  /// The switch and the line are configuration rather than transport, and both
  /// are unreachable for the whole duration of a sprint. So across every state
  /// the row has, the number of *transport* controls is one while a focus block
  /// is playing and zero everywhere else — including on a break, where the row
  /// has no interactive element at all.
  @Test("theRowOffersSkipAndStopAndOnlyWhileAFocusBlockPlays")
  func theRowOffersSkipAndStopAndOnlyWhileAFocusBlockPlays() {
    var statesWithSkip = 0
    var statesWithTooManyControls = 0
    var statesWithAControlDuringABreak = 0
    var statesWithTransportDuringABreak = 0

    for isRunning in [true, false] {
      for kind in BlockKind.allCases {
        for isEnabled in [true, false] {
          for availability in Self.everyAvailabilityState {
            let row = MusicRowModel.forTimer(
              isRunning: isRunning,
              kind: kind,
              isEnabled: isEnabled,
              availability: availability,
              selection: Self.chosen,
              playback: .playing)

            if row.canSkip { statesWithSkip += 1 }
            // THE COUNT, NOT JUST THE FLAGS. Counting `canSkip` alone lets a
            // third transport control — a volume slider, a shuffle toggle —
            // appear on a focus block with this test still green. It is the
            // number that has to be asserted, because a new flag is exactly
            // what nobody would think to add a check for.
            if isRunning, kind == .work, row.interactiveControlCount > 2 {
              statesWithTooManyControls += 1
            }
            // **ONE CONTROL IS PERMITTED IN A BREAK NOW, AND ONLY ONE.**
            //
            // `D25` re-opened the switch during a break — `SPEC.md` line 27,
            // "pauses, and can be switched back on by hand". The transport did
            // not come with it, and that is what this still guards: the count
            // may be one, and the one must be the switch.
            //
            // Counting rather than flag-checking is the same insight as the
            // work-block clause above: a second control arriving in a break is
            // exactly what nobody would think to add a check for.
            if isRunning, kind != .work {
              if row.interactiveControlCount > 1 { statesWithAControlDuringABreak += 1 }
              if row.canSkip || row.canStop { statesWithTransportDuringABreak += 1 }
            }
          }
        }
      }
    }

    // One combination out of all of them: running, a focus block, music on, and
    // available.
    #expect(statesWithSkip == 1)
    // Skip and stop, and nothing else (D20). This is the assertion that fails
    // when the row widens — the one above only watches skip.
    #expect(statesWithTooManyControls == 0,
            "a focus block offers skip and stop and no third control")
    #expect(statesWithAControlDuringABreak == 0,
            "a break offers the switch and nothing beside it")
    #expect(statesWithTransportDuringABreak == 0,
            "skip or stop appeared during a break; D25 re-opened the switch, not the transport")
  }

  /// An instruction is never put on a line that cannot be obeyed.
  ///
  /// Reachable in three taps — switch on, swipe the sheet away without choosing,
  /// press Start — and it used to show *"Choose something to play"* for the next
  /// twenty-five minutes beside a dimmed switch and a line that is plain text
  /// rather than a button. That string carries a doc comment explaining that it
  /// is an invitation rather than a status precisely because nobody taps a
  /// caption; putting it where nothing can be tapped is the same defect with its
  /// polarity reversed. Every other running-state line is a statement of fact,
  /// and now so is this one.
  @Test("aRunningBlockNeverAsksForSomethingThatCannotBeDone")
  func aRunningBlockNeverAsksForSomethingThatCannotBeDone() {
    let row = MusicRowModel.forTimer(
      isRunning: true,
      kind: .work,
      isEnabled: true,
      availability: .ready,
      selection: nil,
      playback: .silent)

    #expect(row.line == MusicCopy.nothingChosenSoQuiet)
    #expect(row.line != MusicCopy.chooseSomething)
    #expect(row.isLineTappable == false)
    #expect(row.isTogglable == false)
  }

  // MARK: What the switch says about itself

  /// **The switch is dimmed for two different reasons and now says which.**
  ///
  /// Spoken from a single "can it be touched?" test, both said *"Music is set
  /// before a sprint. This unlocks when the timer stops."* — so a VoiceOver
  /// reader who had refused the permission was told, in the app's own voice, to
  /// stop a timer that was not running, while the visible line eight points to
  /// its right said the true reason. Two halves of one row disagreeing is
  /// exactly what collecting this feature's words into one file was meant to
  /// prevent.
  @Test("aDimmedSwitchSaysWhichOfTheTwoReasonsItIs")
  func aDimmedSwitchSaysWhichOfTheTwoReasonsItIs() {
    #expect(Self.row(isRunning: false, kind: .work).toggleHint == MusicCopy.toggleHint)
    #expect(Self.row(isRunning: true, kind: .work).toggleHint == MusicCopy.lockedHint)

    for unavailable in Self.everyUnavailableState {
      for isRunning in [true, false] {
        let row = MusicRowModel.forTimer(
          isRunning: isRunning,
          kind: .work,
          isEnabled: true,
          availability: unavailable,
          selection: Self.chosen)

        #expect(row.toggleHint == unavailable.explanation)
        #expect(row.toggleHint != MusicCopy.lockedHint)
        // What is said matches what is shown, in the one state where the two
        // are on screen together.
        if !isRunning { #expect(row.toggleHint == row.line) }
      }
    }
  }

  // MARK: The vocabulary

  /// Nothing this feature says invites building, renaming or buying anything.
  ///
  /// The words are the ones such a control would have to be labelled with. The
  /// check is deliberately blunt: it would object to a perfectly innocent
  /// sentence containing "create", and that is the right trade on the rule this
  /// project cares most about. An objection costs a rewording; a miss costs the
  /// rule.
  @Test("nothingThisFeatureSaysInvitesBuildingOrBuying")
  func nothingThisFeatureSaysInvitesBuildingOrBuying() {
    let forbidden = [
      "create", "new playlist", "make a playlist", "add to", "compose",
      "subscribe", "free trial", "upgrade", "buy", "try apple music"
    ]

    for sentence in Self.everySentenceThisFeatureCanSay {
      for word in forbidden {
        #expect(
          sentence.range(of: word, options: .caseInsensitive) == nil,
          "“\(sentence)” contains “\(word)”.")
      }
    }
  }

  /// The sheet says where music comes from, in the place another app would put a
  /// button — and there is no button.
  @Test("theEmptyLibraryStateSaysWhereMusicComesFrom")
  func theEmptyLibraryStateSaysWhereMusicComesFrom() {
    #expect(MusicCopy.emptyLibraryHeading == "Nothing in your library yet.")
    #expect(MusicCopy.emptyLibraryDetail.contains("Music app"))
  }

  /// The one thing this feature cannot fix is named out loud, where a reader will
  /// find it rather than discover it as a defect.
  @Test("theSystemsOwnControlsAreDocumentedRatherThanClaimedAway")
  func theSystemsOwnControlsAreDocumentedRatherThanClaimedAway() {
    #expect(MusicCopy.systemControlsNote.contains("Control Centre"))
    #expect(MusicCopy.systemControlsNote.contains("no app can switch them off"))
    #expect(MusicCopy.systemControlsNote.contains("skip forward is the only one"))
  }

  /// No subscription is answered with a fact, not with a sales pitch — and the
  /// copy says so explicitly, so nobody spends a moment wondering whether the
  /// offer is about to appear.
  @Test("noSubscriptionIsNotACommerceSurface")
  func noSubscriptionIsNotACommerceSurface() {
    #expect(MusicCopy.noSubscriptionFooter.contains("doesn't sell subscriptions"))
    #expect(MusicCopy.noSubscriptionFooter.contains("won't ask you to"))
  }

  // MARK: Private

  private static let chosen = MusicSelection(
    kind: .playlist,
    identifier: "p.1",
    title: "Deep Focus")

  private static let everyUnavailableState: [MusicAvailability] = [
    .denied, .restricted, .noSubscription, .couldNotBeChecked
  ]

  private static let everyAvailabilityState: [MusicAvailability] =
    [.ready, .notAsked] + everyUnavailableState

  /// One idle-or-running row with everything else working and something chosen.
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

  /// Every sentence this feature can put in front of somebody, on either surface.
  private static let everySentenceThisFeatureCanSay = [
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
    MusicCopy.openSettings,
    MusicCopy.sheetTitle,
    MusicCopy.musicHeader,
    MusicCopy.nowChosenHeader,
    MusicCopy.playlistsHeader,
    MusicCopy.songsHeader,
    MusicCopy.runningBlockHeader,
    MusicCopy.spokenRow(kind: "Playlist", title: "Deep Focus", detail: nil),
    MusicCopy.spokenRow(kind: "Song", title: "So What", detail: nil)
  ]
}
