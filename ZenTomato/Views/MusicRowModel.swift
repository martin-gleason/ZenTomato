import Foundation

// swiftlint:disable file_length
//
// THE ONLY LINT RULE THIS FILE TURNS OFF, AND WHY.
// `file_length` counts documentation, and this file is nearly all of it: the
// whole vocabulary of the feature with the argument for each sentence beside it,
// and then the one rule that turns five facts into a row. The two belong
// together — every line of copy is chosen by that rule, and separating them
// would put the wording in one file and the decision about when it is used in
// another. The same exemption, for the same reason, is already taken by
// `TimerScreen.swift`, `TimerView.swift` and `SettingsView.swift`. Every other
// rule stays on, including all of the ones that catch actual defects.

/// Every sentence this feature can put in front of somebody.
///
/// WHY THEY ARE ALL IN ONE PLACE
/// The music row on the timer screen and the Music sheet describe the same seven
/// situations from two different distances. Written inline in each view they
/// would eventually disagree — one of them saying music is unavailable while the
/// other said it was merely off — and nobody would notice, because the two are
/// never on screen at the same time. Collected here, the whole vocabulary is
/// reviewable on one page and testable in one file, which is the same argument
/// `PickerScreenModel` already makes for the Todoist picker's strings.
///
/// THE RULES EVERY LINE BELOW OBEYS
/// It says what happened. It says what to do, or that there is nothing to do. It
/// names no framework, no error code and no permission machinery. It blames
/// nobody. And — because every failure in this feature leaves **a working silent
/// timer** — not one of them may read as though the app is broken. None is amber
/// and none carries a warning triangle. The one exception is the note saying a
/// block is running, which is not a failure at all: it is a statement about when
/// this feature may be used, and it is the single amber thing on the sheet.
///
/// WHY THIS TYPE DOES NOT HAVE A FILE OF ITS OWN
/// The build contract fixes this feature's file list, and a new file is a change
/// to it. It sits above the row model because the row is where the wording is
/// most load-bearing: on the timer screen it is one line of quiet grey that has
/// to carry an entire failure on its own.
enum MusicCopy {
  // MARK: The row on the timer screen

  /// Nothing has been chosen yet.
  ///
  /// **An invitation, not a status.** It is the F3 lesson applied without waiting
  /// to relearn it: the attachment line used to read "No task attached", which is
  /// perfectly accurate and completely useless — it says where you are and not
  /// that you can leave. On a real phone that made an entire feature unreachable,
  /// because nobody taps a caption. This line is the only door to the picker, so
  /// it asks for something.
  static let chooseSomething = "Choose something to play"

  /// A block is running and the switch is off.
  static let musicOff = "Music off"

  /// A focus block is running, music is on, and nothing was ever chosen.
  ///
  /// **A statement, where the idle row has an invitation, and the difference is
  /// the point.** `chooseSomething` is written as an instruction because the
  /// line carrying it is a button — it is the only door into this feature, and
  /// the F3 lesson is that nobody taps a caption. Mid-block that same line is
  /// inert: the switch is dimmed and the line is plain text, because music is
  /// set before a sprint. Putting an instruction on a surface that cannot obey
  /// it is the same defect with its polarity reversed, and for twenty-five
  /// minutes at a stretch. So this block says what is true and nothing else.
  static let nothingChosenSoQuiet = "Nothing chosen, so this block is quiet."

  /// A focus block has begun and the first track has not started yet.
  static let starting = "Starting…"

  /// The block is running, music is on, and nothing came out.
  ///
  /// **No retry control goes with this line.** There is nothing to retry by hand:
  /// the start of the next focus block tries again on its own. A second control
  /// in the music row would also break the one claim this feature makes about
  /// itself, which is that skip forward is the only thing it offers.
  static let playbackDidNotStart = "Music didn't start. The block is running as normal."

  /// Either kind of break. **The line is never blank on a break**: a blank
  /// reserved band reads as a rendering fault, and this is the only place on the
  /// screen where the promise that music comes back is made at all.
  static let pausedForTheBreak = "Paused for the break. Back at the next focus block."

  /// The subscription ended while a block was running.
  ///
  /// The music stops, the switch drops to off and locks, the skip button leaves
  /// its reserved slot, and the block runs to its own end. The second sentence is
  /// the whole point of the line.
  static let subscriptionEnded = "Your Apple Music subscription ended. The block is still running."

  /// The library has nothing in it to play.
  static let emptyLibraryLine = "Nothing in your library to play yet."

  /// The chosen item has left the library.
  ///
  /// The phrasing is this app's existing idiom for the world moving on: the
  /// attachment line already produces "Draft the summary · not in Todoist any
  /// more", and its preview carries the note *"Not amber: the world moving on is
  /// not an error."* Same situation, same register, curly quotes as elsewhere.
  static func gone(_ title: String) -> String {
    "“\(title)” isn't in your library any more."
  }

  // MARK: The Music sheet

  static let sheetTitle = "Music"
  static let musicHeader = "Music"
  static let nowChosenHeader = "Now chosen"
  /// The verb on the search field **reads**. It does not offer to make anything.
  ///
  /// The Todoist picker's prompt is "Search your Todoist tasks" and this is the
  /// same sentence about the other library. `MusicNoCaptureTests` checks the
  /// vocabulary, because a prompt is a label and a label is where an offer to
  /// create something would have to appear.
  static let searchPrompt = "Search your music"

  /// A search that found nothing.
  ///
  /// **This is the single most likely place in this feature for the no-capture
  /// rule to break**, for the reason `PickerScreenModel` gives about the Todoist
  /// one: an empty result is where every other app on the phone offers to create
  /// the thing you just typed, and the framework's own empty-state view has a
  /// slot for exactly that action.
  ///
  /// It offers nothing. Not a button, not a disabled button, not a footer, not a
  /// row. `F4-contract.md` §7 made this the condition on the search field
  /// existing at all.
  static let noMatchHeading = "Nothing in your library matches."

  /// The line where every other app puts a create button.
  ///
  /// It points back at the place music actually comes from, which is the same
  /// move the Todoist picker makes: this app reads a library somebody else owns.
  static func noMatchDetail(for query: String) -> String {
    "Nothing in your playlists or songs matches “\(query.trimmedQuery)”. "
      + "Playlists are made in Apple Music."
  }

  static let playlistsHeader = "Playlists"
  static let songsHeader = "Songs"
  static let runningBlockHeader = "A block is running"

  /// The switch's own name, spoken. The visible switch carries no label of its
  /// own — the line beside it is the status — so VoiceOver gets the whole phrase.
  static let toggleLabel = "Play music during focus blocks"

  /// What the switch does, while it can be touched.
  static let toggleHint = "Music plays while you work and pauses on every break."

  /// What the switch is doing while a block runs.
  static let lockedHint = "Music is set before a sprint. This unlocks when the timer stops."

  /// The one amber thing on the sheet, and a copy of the note `SettingsView`
  /// already draws for the same reason: a statement of fact that has to be read
  /// *before* something is changed rather than after.
  static let runningBlockNote = "A block is running. Music is set before a sprint, not during one."

  /// The skip button, spoken.
  static let skipLabel = "Skip to the next track"
  /// Says what it silences and, just as importantly, what it does not.
  static let resumeLabel = "Start the music"
  static let resumeHint = "Plays the music again for the rest of this block."

  static let stopLabel = "Stop the music"
  static let stopHint = "Silences the music for the rest of this block. The timer keeps running."

  static let skipHint = "Plays the next track. Nothing else changes."

  /// While the library is being read.
  static let readingLibrary = "Reading your library…"

  /// The sheet was opened before music was ever switched on.
  ///
  /// Reachable by tapping the line rather than the switch, and it needs its own
  /// sentence: permission has not been asked yet, so the library genuinely cannot
  /// be read, and attempting it would put "couldn't read your library" in front
  /// of somebody on the very first thing they did. The switch is directly above
  /// this line, which is the whole instruction.
  static let notAskedYet = "Switch music on above and ZenTomato will show what's in your library."

  /// The library could not be read at all.
  ///
  /// **Copy the design did not specify, because the design assumed this read
  /// cannot fail.** It can: the framework's request throws. The register is the
  /// same as every other line here — a fact, no blame, and a sentence saying the
  /// timer is unaffected — and there is no retry control, because closing the
  /// sheet and opening it again is the retry.
  static let libraryUnreadable = """
    ZenTomato couldn't read your music library just now.

    The timer works exactly the same either way.
    """

  /// The chosen item is gone, said with room to say what to do about it.
  static func goneWithAdvice(_ title: String) -> String {
    "“\(title)” isn't in your library any more. Pick something else below and it'll play "
      + "from the next focus block."
  }

  // MARK: The seven ways this can go quiet

  /// Permission was refused.
  ///
  /// **Not modelled on F2.** The alarm permission takes over the whole screen,
  /// because a Pomodoro timer that cannot tell you a block ended has no working
  /// state to degrade into. This is one muted line and one footer, because a
  /// timer that is merely quiet works perfectly. The contrast is deliberate and
  /// should be legible in both places.
  static let deniedFooter = """
    ZenTomato doesn't have permission to use your music library, so it can't play anything. You can change \
    that in the Settings app, under Privacy & Security › Media & Apple Music.

    The timer works exactly the same either way.
    """

  /// The one button this feature offers that is not skip forward, and the reason
  /// it is not a transport control: it opens the Settings app, exactly as the
  /// alarm explainer already does for the alarm permission.
  static let openSettings = "Open Settings"

  /// Screen Time, or a device somebody else manages.
  ///
  /// **No button.** Telling somebody to go and grant a permission they are not
  /// allowed to grant is worse than saying nothing.
  static let restrictedFooter = """
    Access to music is turned off on this iPhone. That's a restriction on the device rather than something \
    ZenTomato can change.

    The timer works exactly the same without it.
    """

  /// No Apple Music subscription.
  ///
  /// **No offer to sell one, ever.** A commerce surface is not in `SPEC.md`'s
  /// F1–F6, and an app that answers "you can't use this" with "would you like to
  /// buy something" is not a calm one. The second sentence exists so that nobody
  /// spends a moment wondering whether the offer is about to appear.
  static let noSubscriptionFooter = """
    Playing music from your library needs an Apple Music subscription, and this iPhone doesn't have one. \
    ZenTomato doesn't sell subscriptions and won't ask you to.

    The timer works exactly the same without music.
    """

  /// The one word or phrase Settings shows beside "Apple Music".
  ///
  /// **The vocabulary is Todoist's, borrowed rather than invented.** That row
  /// says `Connected` / `Not connected` / `Couldn't sign out`, and an earlier
  /// version of this one said `Ready` / `Not set up` — two screens describing the
  /// same kind of thing, a service this app talks to, in two different dialects.
  /// The owner caught it on the device. Consistency was the entire argument for
  /// putting this section here, so failing to carry it into the words undercut
  /// the reason for the section.
  ///
  /// It never editorialises: "No subscription" is a fact, "Unavailable!" would be
  /// a verdict.
  static func settingsStatus(for availability: MusicAvailability) -> String {
    switch availability {
    case .ready: "Connected"
    case .notAsked: "Not connected"
    case .denied: "Permission off"
    case .restricted: "Restricted"
    case .noSubscription: "No subscription"
    case .couldNotBeChecked: "Couldn't be checked"
    }
  }

  /// The sentence under it, which is the one that was buried.
  ///
  /// These are the same words the music picker shows in its footer. They are not
  /// duplicated: the picker calls this too, so the two surfaces cannot drift into
  /// saying different things about the same state.
  static func settingsFooter(for availability: MusicAvailability) -> String {
    switch availability {
    case .denied: deniedFooter
    case .restricted: restrictedFooter
    case .noSubscription: noSubscriptionFooter
    case .couldNotBeChecked: couldNotBeCheckedFooter
    case .ready: readyFooter
    case .notAsked: notAskedFooter
    }
  }

  /// What Settings says before anybody has switched music on.
  ///
  /// **Separate from `readyFooter` because the two are not the same situation.**
  /// Permission is asked for at the moment somebody first switches music on and
  /// never at launch, so "Not set up" is the state every install begins in and is
  /// not a fault. Describing music playing during focus blocks — which is what
  /// `readyFooter` does — would read as a description of what the app is
  /// currently doing, when it is doing none of it.
  static let notAskedFooter = """
    Music is switched off. Turning it on from the timer screen asks for permission to read your \
    Apple Music library, and nothing is read until you do.
    """

  /// What Settings says when nothing is wrong — **including the way out.**
  ///
  /// **The app knew this path and only volunteered it once permission was already
  /// gone.** `deniedFooter` names Privacy & Security › Media & Apple Music, so a
  /// person who had refused was told where to change their mind, and a person who
  /// had agreed was told nothing at all. The owner went looking for how to undo it
  /// and found no answer.
  ///
  /// Todoist's section has a way out on it — a sign-out button — and MusicKit
  /// permission cannot be revoked from inside an app, so the honest equivalent is
  /// naming the one place it can be. A sentence is the whole fix; a button that
  /// deep-links elsewhere would be new machinery for something iOS already owns.
  static let readyFooter = """
    ZenTomato plays a playlist or song from your library during focus blocks and pauses it \
    during breaks. It only reads your library and never changes anything in it.

    To take that permission back, use the Settings app, under Privacy & Security › \
    Media & Apple Music.
    """

  /// The permission or the subscription could not be established at all.
  static let couldNotBeCheckedFooter = """
    ZenTomato couldn't tell whether it's able to play your music, so it hasn't tried.

    The timer works exactly the same either way.
    """

  /// Opened after a block in which nothing played.
  static let playbackFailedFooter = """
    Music didn't start last time. ZenTomato tries again at the start of the next focus block.
    """

  /// An empty library, in place of the two lists.
  ///
  /// **No control of any kind, not even one that opens the Music app.** The
  /// precedent is the Todoist picker's empty project: *"One sentence and no
  /// control of any kind. Not a button, not a greyed button, not a placeholder
  /// row."* The second line names where music comes from, which is the same job
  /// *"Tasks are created in Todoist, not here."* does one screen over — and it is
  /// simultaneously `SPEC.md`'s out-of-scope entry made visible on the one screen
  /// where somebody might otherwise go looking for it.
  static let emptyLibraryHeading = "Nothing in your library yet."
  static let emptyLibraryDetail = """
    ZenTomato plays playlists and songs you've already added to your library in the Music app.
    """

  /// The honesty item, in the last footer on the sheet, where a reader will look
  /// for it rather than discover it as a defect.
  ///
  /// The same paragraph is in the doc comment on `MusicRow` and in the pull
  /// request description.
  static let systemControlsNote = """
    Control Centre, the Lock Screen, your headphones and CarPlay will still show play, pause and back for \
    whatever is playing. iOS gives every app's audio those controls and no app can switch them off. Inside \
    ZenTomato, skip forward is the only one.
    """

  // MARK: Spoken labels for the picker's rows

  /// "Playlist. Deep Focus." / "Song. So What. Miles Davis."
  ///
  /// The distinguishing word first, which is the shape `DistractionButtons`
  /// already uses: a reader who is not looking at the screen learns what kind of
  /// thing this is before they learn what it is called.
  static func spokenRow(kind: String, title: String, detail: String?) -> String {
    var parts = [kind, title]
    if let detail, detail.isEmpty == false { parts.append(detail) }
    return parts.joined(separator: ". ") + "."
  }
}

/// The music row on the timer screen, as finished values.
///
/// **WHAT THIS TYPE IS FOR.** The row has nine states and one of them is drawn
/// sixty times a minute for twenty-five minutes at a stretch. Working out which
/// one applies is a rule about five facts, so the rule lives here as a pure
/// function over those five facts and the view draws whatever it is handed. That
/// is what lets every state — including every failure — be looked at in a preview
/// with no music, no timer and no database, and asserted in a test the same way.
/// It is the shape `TimerScreenModel.Capture` and `TimerScreenModel.Attachment`
/// already use.
///
/// **THE ROW IS PRESENT IN EVERY STATE OF A RUNNING TIMER, AND THAT IS D19.3.**
/// It never appears and never disappears between the start of a sprint and its
/// end, so it can never move the countdown. What changes inside it is the skip
/// button, which occupies reserved space — see `MusicRow`. The one state with no
/// row at all is the one where there is no settings row to read, where the screen
/// shows dashes and Start is switched off: a timer that cannot start has nothing
/// for an accessory to accessorise, and no cycle can run there for the rule to
/// govern.
struct MusicRowModel: Equatable {
  // MARK: Nested types

  /// What the player is actually doing, as far as anybody can honestly tell.
  ///
  /// **Taken from the player, never from what this app last asked for.** The
  /// system's own controls — Control Centre, the Lock Screen, headphones,
  /// CarPlay — can pause what this app started, and no app can switch those off.
  /// So "is sound coming out" is a question put to the player, re-asked at every
  /// moment it could have changed and whenever the app comes back to the front,
  /// which is what keeps the skip button honest.
  enum Playback: Equatable, Sendable {
    /// Nothing is playing and nothing is trying to.
    case silent
    /// A focus block has begun and the first track has not arrived yet.
    case starting
    /// Sound is coming out.
    case playing
    /// The block is running and the music could not be started.
    case didNotStart
  }

  // MARK: Stored properties

  /// Whether the switch is drawn in the on position.
  ///
  /// Forced to `false` whenever music is unavailable. A switch sitting in the on
  /// position while nothing can play is a control that lies about itself.
  let isOn: Bool

  /// Whether the switch may be touched.
  ///
  /// True only while the timer is idle **and** music is available. `SPEC.md` says
  /// music is toggled before a sprint, so mid-sprint it is present and dimmed
  /// rather than absent — which is the one place in this feature where a dimmed
  /// control is correct. The standing rule that a control is absent rather than
  /// greyed is about *transport*: this app does not offer back-a-track, or any
  /// way of moving through a track, at all — so a dimmed one would say it does.
  /// The music switch **is**
  /// something this app does; it is temporarily not the moment for it, and that
  /// is exactly what a disabled control means. Removing it mid-block would also
  /// make it appear and disappear at every boundary, which is the movement D19.3
  /// forbids.
  let isTogglable: Bool

  /// The one line of text in the row.
  let line: String

  /// Whether that line is a control that opens the Music sheet.
  ///
  /// **Tappable in every idle state, including every failed one.** That is what
  /// stops a failure becoming a dead end: denied, no subscription and an empty
  /// library are all still one tap from the sheet that explains them. Inert while
  /// a block runs, for a reason that is *not* the attachment line's reason — that
  /// one is frozen because a distraction row names its task, and changing it
  /// mid-block would put two task names on one block's records. Nothing in the
  /// log names a track. This one is inert because a screen offering a choice it
  /// will not honour is worse than one that offers none.
  let isLineTappable: Bool

  /// What the switch says about itself to somebody who is not looking at the
  /// screen.
  ///
  /// **Three answers, not two, and the third is the one that was wrong.** The
  /// switch is dimmed for two quite different reasons: a block is running, or
  /// music is unavailable on this phone. Spoken from a single "can it be
  /// touched?" test, both said *"Music is set before a sprint. This unlocks when
  /// the timer stops."* — so a reader who had refused the permission was told,
  /// in the app's own voice, to stop a timer that was not running, and the row's
  /// own visible line eight points away said something else entirely. The reason
  /// travels with the model now, so the two halves of one row cannot disagree.
  let toggleHint: String

  /// Whether the skip button is drawn.
  ///
  /// **`false` means "reserve the space and draw nothing", never "remove the
  /// row"** — see `MusicRow.skipSlot`, which draws the identical button hidden
  /// and unreachable so that the row measures the same height either way.
  ///
  /// A plain `Bool` rather than the optional-with-no-payload the build contract
  /// sketches by analogy with `TimerScreenModel.Capture`. That analogy holds for
  /// `Capture` because a capture pair carries two counts; skip carries nothing at
  /// all, and an `Optional` wrapping an empty value is a shape that reads as
  /// unfinished rather than as deliberate.
  let canSkip: Bool

  /// Whether the stop control is offered (D20).
  ///
  /// The same conditions as `canSkip`: both are transport, both need something
  /// actually playing to act on. They appear and disappear together, which is
  /// what keeps the reserved row a single decision rather than two.
  let canStop: Bool

  /// Whether that control is currently offering to START rather than to stop.
  ///
  /// One control with two states, not two controls. The row still offers exactly
  /// two things — skip, and this — which is what D20 ratified; what changed is
  /// that Stop stopped being a one-way door.
  let stopIsResume: Bool

  // MARK: Derived

  /// How many things in this row can actually be operated.
  ///
  /// **This is the claim the adversarial reviewer will test**, so it is stated as
  /// a number a test can read rather than as a sentence in a comment. While a
  /// focus block runs and music is playing it is 2 — skip and stop. During a
  /// break it is 0. While idle it is 2 — the switch and the line — and neither of
  /// those is a transport control, because nothing is playing.
  var interactiveControlCount: Int {
    (isTogglable ? 1 : 0) + (isLineTappable ? 1 : 0) + (canSkip ? 1 : 0) + (canStop ? 1 : 0)
  }

  // MARK: The rule

  /// What the music row shows, given everything that decides it.
  ///
  /// A pure function of finished facts, with no music framework, no timer and no
  /// database anywhere near it. Every state below is covered by
  /// `MusicRowModelTests` and drawn by a preview in `MusicRow.swift`.
  ///
  /// - Parameters:
  ///   - isRunning: whether any block is counting at all.
  ///   - kind: which kind of block that is. Both kinds of break behave
  ///     identically here; there is no separate long-break behaviour anywhere in
  ///     this feature.
  ///   - isEnabled: whether music is switched on.
  ///   - availability: whether this app may play music at all, and the one plain
  ///     sentence to show when it may not.
  ///   - selection: the chosen playlist or song, or `nil`.
  ///   - selectionIsGone: whether that chosen item has left the library. `false`
  ///     when it is there, and also when the library has not been read — absent
  ///     from a library nobody has looked at is not evidence, which is the same
  ///     three-answer caution the session plan takes with Todoist.
  ///   - libraryIsEmpty: whether the library was read and held nothing.
  ///   - playback: what the player is doing right now.
  static func forTimer(
    isRunning: Bool,
    kind: BlockKind,
    isEnabled: Bool,
    availability: MusicAvailability,
    selection: MusicSelection?,
    selectionIsGone: Bool = false,
    libraryIsEmpty: Bool = false,
    playback: Playback = .silent,
    nowPlayingTitle: String? = nil,
    isSilenced: Bool = false
  ) -> MusicRowModel {
    let isAvailable = availability == .ready || availability == .notAsked
    let isOn = isEnabled && isAvailable
    // What the chosen item is called, or the sentence saying it has gone.
    // Worked out once, because both halves of the row below say the same thing
    // about it and two copies of that decision could disagree.
    let chosenLine = selection.map { selectionIsGone ? MusicCopy.gone($0.title) : $0.title }

    guard isRunning else {
      return MusicRowModel(
        isOn: isOn,
        isTogglable: isAvailable,
        line: idleLine(
          availability: availability,
          chosenLine: chosenLine,
          libraryIsEmpty: libraryIsEmpty),
        // The one thing that is true in every idle state, however badly the rest
        // of it has gone.
        isLineTappable: true,
        toggleHint: availability.explanation ?? MusicCopy.toggleHint,
        canSkip: false,
        canStop: false,
        stopIsResume: false)
    }

    // Both transport controls answer the same question — is there sound to act
    // on — so they are one decision rather than two that could drift apart.
    let transportIsLive = kind == .work
      && isEnabled
      && availability == .ready
      && selection != nil
      && playback == .playing

    return MusicRowModel(
      isOn: isOn,
      isTogglable: false,
      line: runningLine(
        kind: kind,
        isEnabled: isEnabled,
        availability: availability,
        chosenLine: chosenLine,
        sound: Sound(playback: playback, nowPlayingTitle: nowPlayingTitle)),
      isLineTappable: false,
      toggleHint: availability.explanation ?? MusicCopy.lockedHint,
      canSkip: transportIsLive,
      // Offered while sound is playing (to stop it) AND while this block has
      // been silenced (to start it again). Skip is offered only in the first
      // case: there is nothing to skip to when nothing is playing.
      canStop: transportIsLive || isSilenced,
      stopIsResume: isSilenced)
  }

  /// What the player is doing, and what it is doing it to.
  ///
  /// One value rather than two parameters, because they are never useful apart:
  /// a track name only means anything alongside "playing", and the linter's
  /// parameter limit is a fair prompt to notice that.
  struct Sound {
    let playback: Playback
    let nowPlayingTitle: String?
  }

  // MARK: Private

  /// The line while nothing is counting.
  ///
  /// The order of these questions is the order of their consequences: a reason
  /// music cannot play at all outranks anything about a particular item, and an
  /// item that has left the library outranks the invitation to choose one,
  /// because it explains why the thing you chose is not going to play.
  private static func idleLine(
    availability: MusicAvailability,
    chosenLine: String?,
    libraryIsEmpty: Bool
  ) -> String {
    if let explanation = availability.explanation { return explanation }
    if let chosenLine { return chosenLine }
    if libraryIsEmpty { return MusicCopy.emptyLibraryLine }
    return MusicCopy.chooseSomething
  }

  /// The line while a block is counting.
  ///
  /// **While a focus block plays, the line is the chosen item's name rather than
  /// the track's.** The design asked for the track title, and the ratified
  /// playback protocol has eight members, none of which can answer what is
  /// playing — deliberately, because the members that could answer it are the
  /// same ones that would let somebody build a way of moving through a track.
  /// The chosen name is true,
  /// stable, and does not change under a person's eye mid-block.
  private static func runningLine(
    kind: BlockKind,
    isEnabled: Bool,
    availability: MusicAvailability,
    chosenLine: String?,
    sound: Sound
  ) -> String {
    guard isEnabled else { return MusicCopy.musicOff }

    if availability == .noSubscription { return MusicCopy.subscriptionEnded }
    if let explanation = availability.explanation { return explanation }
    guard kind == .work else { return MusicCopy.pausedForTheBreak }
    guard let chosenLine else { return MusicCopy.nothingChosenSoQuiet }

    switch sound.playback {
    case .playing:
      // THE TRACK, NOT THE PLAYLIST — when we know it.
      //
      // The person chose the playlist, so its name tells them nothing they did
      // not already know. Which song is on is the one thing they cannot get
      // without leaving the app, which is the opposite of what a focus screen is
      // for. Falls back to the playlist name when the player has not said yet.
      return sound.nowPlayingTitle ?? chosenLine
    case .silent: return chosenLine
    case .starting: return MusicCopy.starting
    case .didNotStart: return MusicCopy.playbackDidNotStart
    }
  }
}
