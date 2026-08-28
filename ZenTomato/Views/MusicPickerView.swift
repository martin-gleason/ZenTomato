import SwiftUI
import UIKit

// swiftlint:disable file_length
//
// THE ONLY LINT RULE THIS FILE TURNS OFF, AND WHY.
// `file_length` counts documentation and previews, and this file is over half
// both. It is the one screen in this feature where somebody could reasonably
// expect to build a playlist, so the argument against each shape that would let
// them is written beside the code that avoids it — and every failure state of
// the whole feature has a preview here, which is the only way a reviewer who does
// not write Swift can see them. The small views at the bottom are the states of
// this one sheet; splitting them into their own files would separate each state
// from the screen it belongs to. The same exemption, for the same reason, is
// already taken by `ProjectPickerView.swift` and `TimerScreen.swift`.

/// The Music sheet: the switch, what is chosen now, and everything in the
/// library to choose from.
///
/// **WHAT THIS SCREEN CANNOT DO, AND WHY THAT IS THE DESIGN.**
/// It reads a library and selects one thing from it. It cannot build a playlist,
/// rename one, reorder one, put a song into one or take one out — and it cannot
/// reach the Apple Music catalogue, because `SPEC.md` says *"an existing playlist
/// or song from their library"* and a catalogue result is something the person
/// does not own. None of that is held back by a condition somebody has to
/// remember: the only door to a library in this app is `MusicLibraryReading`,
/// which has three methods and all three are reads.
///
/// **THERE IS NO TEXT FIELD ON THIS SHEET, OF ANY KIND.** Not a search field, not
/// a rename field, nothing. `CLAUDE.md`'s standing rule is that this app never
/// accepts typed input, and the ratified scope fence for this feature checks it
/// by name. A long library is handled by drawing rows a page at a time as
/// somebody scrolls — no field, no button, not even a "show more".
///
/// **NO CANCEL BUTTON**, for the reason `SettingsView` already gives: there is no
/// transaction to roll back. Choosing something saves it at the moment of the
/// tap, and Done and swiping the sheet away are the same action.
///
/// This view draws finished values and calls back out through closures, so every
/// state of it — including every failure — is a few lines in a preview rather
/// than a sequence of taps on a phone with the right thing wrong with it. The
/// wiring lives in `MusicPickerSheet` at the bottom of this file.
struct MusicPickerView: View {
  // MARK: Nested types

  /// How far the library read has got.
  enum LoadState: Equatable {
    /// The request is out.
    case reading
    /// It came back.
    case ready(MusicPickerScreenModel)
    /// It could not be made, or it threw. There is no retry button: closing the
    /// sheet and opening it again is the retry.
    case failed
  }

  // MARK: Internal

  let state: LoadState

  /// Whether music is switched on.
  let isEnabled: Bool

  /// Whether this app may play music at all, and the one sentence to show when it
  /// may not.
  let availability: MusicAvailability

  /// Whether a block is counting right now. Locks the switch and draws the one
  /// amber note on the sheet.
  ///
  /// **NO USER CAN REACH THIS STATE IN THE APP AS IT SHIPS, AND THAT IS SAID
  /// HERE RATHER THAN LEFT TO BE DISCOVERED.** Both doors to this sheet are
  /// idle-only: the row's line is inert while a block runs, and the switch that
  /// opens it is dimmed then. Start is on the timer screen, behind this sheet.
  /// So the amber note, the locked switch and their two previews depict a screen
  /// nobody arrives at today.
  ///
  /// It is kept, deliberately, for the reason `MusicCoordinator` gives for its
  /// own duplicate refusals: the screen's lock stops today's finger, and this
  /// one stops a caller nobody has written yet. Deleting it would mean that the
  /// first future path opening this sheet mid-block finds a live-looking switch
  /// that silently does nothing — strictly worse than a dimmed one with a
  /// sentence beside it.
  ///
  /// What it does **not** do is explain the dimmed switch on the timer screen
  /// mid-sprint, because it is not on that screen. A sighted reader gets a dead
  /// switch there and no words; a VoiceOver reader gets `lockedHint`. Whether
  /// that is worth a line of the timer screen's very small budget is the
  /// owner's call and is logged as open in `docs/reviews/F4.md`.
  let isBlockRunning: Bool

  /// Whether the running block is a break.
  ///
  /// `D25` re-opened the switch during a break, and this is what tells the two
  /// surfaces apart from each other's point of view: the timer row derives it
  /// from `kind`, and this sheet has no `kind`. Defaulted to `false` so every
  /// preview keeps the pre-`D25` behaviour, which is the safe one — a locked
  /// switch is never wrong, only unhelpful.
  var isBreak: Bool = false

  /// What is chosen, or `nil`.
  let chosen: MusicSelection?

  /// Whether music failed to start during the last focus block.
  let playbackDidNotStart: Bool

  /// **`@MainActor` is load-bearing, not decoration.** SwiftUI's `Binding` setter
  /// is `@isolated(any) @Sendable`, so handing it a plain closure warns that it
  /// "may introduce data races" — and every one of these closures does main-actor
  /// work on a main-actor view. Saying so is the honest fix; the alternative was
  /// a warning nobody saw, because until `C12` nothing ever compiled Release.
  var onToggleMusic: @Sendable (Bool) -> Void = { _ in }
  var onChoose: (MusicSelection) -> Void = { _ in }

  var body: some View {
    List {
      if isBlockRunning {
        runningBlockNote
      }

      musicSection

      if let chosen {
        nowChosenSection(chosen)
      }

      library

      systemControlsFooter
    }
    // iOS's own grouped-list grey fights this app's warm page. Dropping it and
    // painting the page underneath is what makes the sheet look like part of the
    // same app as the timer — the arrangement `SettingsView` already uses.
    .scrollContentBackground(.hidden)
    .background(Color(.surfacePrimary).ignoresSafeArea())
    // **Always shown rather than revealed by pulling down.** A field that has to
    // be discovered is no use to somebody who does not know it is there, and this
    // exists because the owner scrolled a real library for two minutes without
    // finding one.
    .searchable(
      text: $query,
      placement: .navigationBarDrawer(displayMode: .always),
      prompt: MusicCopy.searchPrompt)
    // **The reveal counters are counts, not positions.** Without this, filtering
    // four hundred playlists down to three leaves the list still believing it has
    // already revealed a hundred — so `hasMore` reports nothing left to show and
    // the reveal never re-arms when the field is cleared. Reset on every change.
    .onChange(of: query) {
      shownPlaylists = MusicPickerScreenModel.pageSize
      shownSongs = MusicPickerScreenModel.pageSize
    }
  }

  // MARK: Private

  /// Whether music is available at all. `.notAsked` counts as available: turning
  /// the switch on is what asks.
  private var isAvailable: Bool {
    availability == .ready || availability == .notAsked
  }

  @Environment(\.openURL) private var openURL

  /// How many rows of each list are drawn. Grows as somebody reaches the end of
  /// what is drawn; see `MusicPickerScreenModel.pageSize`.
  @State private var shownPlaylists = MusicPickerScreenModel.pageSize
  @State private var shownSongs = MusicPickerScreenModel.pageSize

  /// What has been typed into the search field.
  ///
  /// **View state, and deliberately nothing more.** It is not persisted, not
  /// remembered between sheets, and never leaves this screen. A remembered query
  /// would be state this app keeps about somebody's listening, which is exactly
  /// what `D16` says not to build.
  @State private var query = ""

  /// A statement of fact, pinned above everything else because it has to be read
  /// before somebody reaches for the switch rather than after.
  ///
  /// **This is the one amber thing on this sheet, and nothing else here may be
  /// amber.** On this screen amber means "something has gone wrong that affects
  /// the timer". Music being unavailable does not: it produces a working silent
  /// timer, which is a fact rather than a warning, and painting it amber would say
  /// the app is broken — the one thing D19.2 forbids. Keeping the colour for this
  /// note also designs out a collision that would otherwise be real: a block
  /// running *and* no subscription would put two amber rows on one sheet, which
  /// was a finding in F3's review on two other screens.
  private var runningBlockNote: some View {
    Section {
      Label {
        Text(MusicCopy.runningBlockNote)
          .font(Typography.label)
          .foregroundStyle(Color(.warningText))
      } icon: {
        Image(systemName: "clock")
          .foregroundStyle(Color(.warningText))
      }
    } header: {
      header(MusicCopy.runningBlockHeader)
    }
    .listRowBackground(Color(.surfaceRaised))
  }

  /// The switch, mirrored from the timer screen's row and bound to the same
  /// stored value.
  ///
  /// It is here as well as there because music is set immediately before Start,
  /// and a switch two taps away behind a sheet is a switch you forget the state
  /// of. It is **not** in Settings: that screen's own doc comment says there is
  /// "no music toggle, no seventh anything", and the six-field rule is defended
  /// by that screen looking like six things.
  private var musicSection: some View {
    Section {
      Toggle(MusicCopy.toggleLabel, isOn: Binding(get: { isEnabled && isAvailable }, set: onToggleMusic))
        .font(Typography.body)
        .tint(Color(.action))
        // Locked during a work block only. A break may still be switched — the
        // same relaxation as the timer row, so the two surfaces cannot disagree
        // about whether the control works. See `D25`.
        .disabled((isBlockRunning && !isBreak) || !isAvailable)
        // Three answers, not two. This switch is dimmed for two different
        // reasons and used to speak only one of them, so somebody who had been
        // refused the permission was told to stop a timer that was not running.
        // The reason, where there is one, outranks both.
        .accessibilityHint(Text(
          availability.explanation
            ?? (isBlockRunning ? MusicCopy.lockedHint : MusicCopy.toggleHint)))

      if availability == .denied {
        openSettingsRow
      }
    } header: {
      header(MusicCopy.musicHeader)
    } footer: {
      musicFooter
    }
    .listRowBackground(Color(.surfaceRaised))
  }

  /// The reason music is unavailable, or what the switch does, in the quiet ink.
  ///
  /// **Never amber and never a warning triangle**, however badly it has gone. See
  /// `runningBlockNote` for the whole argument.
  @ViewBuilder
  private var musicFooter: some View {
    switch availability {
    // The same words Settings shows, from the same function, so the two surfaces
    // cannot drift into describing one state differently.
    case .denied, .restricted, .noSubscription, .couldNotBeChecked:
      footer(MusicCopy.settingsFooter(for: availability))
    case .ready, .notAsked:
      if playbackDidNotStart {
        footer(MusicCopy.playbackFailedFooter)
      } else {
        footer(MusicCopy.toggleHint)
      }
    }
  }

  /// What is chosen right now, repeated at the top of the sheet.
  ///
  /// Two jobs, and the second is the one that earns the section: a choice made
  /// four thousand rows down a long library is visible without hunting for it —
  /// and **an item that has been deleted in the Music app has somewhere to be
  /// reported**. It will not appear in either list below, so without this it
  /// would vanish with no explanation at all.
  ///
  /// Not tappable. It is a report, and the row it duplicates further down is the
  /// control.
  private func nowChosenSection(_ chosen: MusicSelection) -> some View {
    let isGone = isChosenItemGone(chosen)
    return Section {
      HStack(spacing: Spacing.sm) {
        Text(chosen.title)
          .font(Typography.body)
          .foregroundStyle(Color(isGone ? .textMuted : .textPrimary))
          .lineLimit(2)
        Spacer(minLength: Spacing.xs)
        if isGone == false {
          Image(systemName: "checkmark")
            .font(Typography.body)
            .foregroundStyle(Color(.action))
            .accessibilityHidden(true)
        }
      }
      .frame(minHeight: Spacing.controlHeight)
    } header: {
      header(MusicCopy.nowChosenHeader)
    } footer: {
      if isGone {
        footer(MusicCopy.goneWithAdvice(chosen.title))
      }
    }
    .listRowBackground(Color(.surfaceRaised))
  }

  /// Whether the chosen item has left the library.
  ///
  /// Only decidable once the library has actually been read. While it is being
  /// read, or after a read that failed, the answer is no — absent from a library
  /// nobody has looked at is not evidence, which is the same three-answer caution
  /// the session plan takes with Todoist.
  private func isChosenItemGone(_ chosen: MusicSelection) -> Bool {
    guard case .ready(let model) = state else { return false }
    return model.contains(chosen) == false
  }

  /// The two lists, or the one thing there is to say instead of them.
  @ViewBuilder
  private var library: some View {
    if isAvailable == false {
      // Nothing is drawn. The footer above has already said why, and a list of
      // things that cannot be played would be a screen full of controls that
      // silently do nothing.
      EmptyView()
    } else if availability == .notAsked {
      // Nothing has been asked for yet, so there is nothing to read. Attempting
      // it would fail and would report a failure for something nobody has done.
      quietBlock(MusicCopy.notAskedYet)
    } else {
      switch state {
      case .reading:
        quietBlock(MusicCopy.readingLibrary)
      case .failed:
        quietBlock(MusicCopy.libraryUnreadable)
      case .ready(let model):
        if model.isEmpty {
          EmptyLibraryView()
        } else {
          let playlists = model.playlistRows(matching: query)
          let songs = model.songRows(matching: query)

          if model.hasNoMatches(for: query) {
            noMatches
          }

          list(
            MusicPickerScreenModel.page(playlists, shown: shownPlaylists),
            header: MusicCopy.playlistsHeader,
            hasMore: MusicPickerScreenModel.hasMore(playlists, shown: shownPlaylists),
            revealMore: { shownPlaylists += MusicPickerScreenModel.pageSize })

          list(
            MusicPickerScreenModel.page(songs, shown: shownSongs),
            header: MusicCopy.songsHeader,
            hasMore: MusicPickerScreenModel.hasMore(songs, shown: shownSongs),
            revealMore: { shownSongs += MusicPickerScreenModel.pageSize })
        }
      }
    }
  }

  /// One list of rows, with more revealed as the last drawn row appears.
  ///
  /// **The reveal is a scroll, not a control.** Nothing is drawn at the bottom of
  /// the list to tap — the last row simply asks for more when it comes on screen,
  /// which is why a long library costs nothing on opening and still shows every
  /// single item if somebody keeps going.
  @ViewBuilder
  private func list(
    _ rows: [MusicPickerScreenModel.Row],
    header title: String,
    hasMore: Bool,
    revealMore: @escaping () -> Void
  ) -> some View {
    if rows.isEmpty == false {
      Section {
        ForEach(rows) { row in
          MusicPickerRowView(
            row: row,
            isChosen: row.selection.identifier == chosen?.identifier,
            onChoose: { choose(row.selection) })
            .onAppear {
              guard hasMore, row.id == rows.last?.id else { return }
              revealMore()
            }
        }
      } header: {
        header(title)
      }
      .listRowBackground(Color(.surfaceRaised))
    }
  }

  /// The honesty item, in the last footer, where a reader will look for it rather
  /// than discover it as a defect.
  private var systemControlsFooter: some View {
    Section { } footer: {
      footer(MusicCopy.systemControlsNote)
    }
  }

  /// **Tapping the item that is already chosen does nothing.** It does not
  /// un-choose it: the switch is the off control, in one place, and a second way
  /// to reach "nothing will play" is a second off switch that looks like a
  /// mistake. Choosing something else replaces what was chosen, because exactly
  /// one thing is chosen, ever.
  ///
  /// Choosing does not close the sheet either — the switch lives here, and
  /// dismissing on a tap would strand somebody before they could turn music on.
  private func choose(_ selection: MusicSelection) {
    guard selection.identifier != chosen?.identifier else { return }
    onChoose(selection)
  }

  /// A search that matched nothing.
  ///
  /// **Two sentences and no control, which is the condition the search field
  /// exists under.** `F4-contract.md` §7 permitted a search field only if it
  /// "must offer nothing when it finds nothing", and this is that: it reuses
  /// `quietBlock`, which by construction draws text and cannot draw a button.
  ///
  /// There is no `ContentUnavailableView` here on purpose. Its initialiser takes
  /// an `actions` closure, and a slot for an action on the one screen where an
  /// offer to create a playlist would belong is a slot somebody eventually fills.
  @ViewBuilder
  private var noMatches: some View {
    quietBlock(MusicCopy.noMatchDetail(for: query))
      .accessibilityLabel(MusicCopy.noMatchHeading)
      .accessibilityValue(MusicCopy.noMatchDetail(for: query))
  }

  /// One line of quiet text where the lists would be, with no control of any
  /// kind.
  private func quietBlock(_ text: String) -> some View {
    Text(text)
      .font(Typography.body)
      .foregroundStyle(Color(.textMuted))
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, Spacing.md)
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
  }

  private func header(_ title: String) -> some View {
    Text(title)
      .font(Typography.kicker)
      .textCase(.uppercase)
      .foregroundStyle(Color(.textMuted))
  }

  private func footer(_ text: String) -> some View {
    Text(text)
      .font(Typography.body)
      .foregroundStyle(Color(.textMuted))
  }

  /// The one row on this sheet that is a control and is not about choosing
  /// something to play.
  ///
  /// **It is not a transport control**, so the skip-forward-only rule is
  /// untouched: it opens the Settings app, exactly as `AlarmPermissionView`
  /// already does for the alarm permission, and it is drawn only in the one state
  /// where there is a switch somewhere else for the reader to change. The `if
  /// let` is the same one that screen carries — this codebase uses Swift's
  /// crash-if-nil operator nowhere, and doing nothing in an impossible case beats
  /// stopping the app inside a screen whose whole job is to be calm about a
  /// failure.
  private var openSettingsRow: some View {
    Button(MusicCopy.openSettings) {
      if let url = URL(string: UIApplication.openSettingsURLString) {
        openURL(url)
      }
    }
    .font(Typography.body)
    .accessibilityHint(Text("Opens ZenTomato's page in the Settings app."))
  }
}

// MARK: - MusicPickerRowView

/// One row: a glyph saying what kind of thing this is, its title, and a tick when
/// it is the chosen one.
///
/// **THREE SIGNALS FOR "CHOSEN", ONLY ONE OF WHICH IS COLOUR** — the discipline
/// `PlanRowView` already follows. A tick, a heavier title, and the repeat of the
/// title in the section at the top of the sheet. Colour alone would fail anybody
/// who cannot see the difference between sage and grey.
///
/// **No artwork and no second line.** See `MusicPickerScreenModel`.
struct MusicPickerRowView: View {
  // MARK: Internal

  let row: MusicPickerScreenModel.Row
  let isChosen: Bool
  let onChoose: () -> Void

  var body: some View {
    Button(action: onChoose) {
      HStack(spacing: Spacing.sm) {
        Image(systemName: glyph)
          .font(Typography.label)
          .foregroundStyle(Color(.textMuted))
          // The kind is in the spoken label instead, where it reads as a word
          // rather than as the name of a picture.
          .accessibilityHidden(true)

        Text(row.selection.title)
          .font(isChosen ? Typography.bodyEmphasis : Typography.body)
          .foregroundStyle(Color(.textPrimary))
          // Two lines, matching `PlanRowView`. The design's argument for one
          // assumed a trailing detail beside it — a track count, an artist —
          // and that detail was cut, so the title is now the only thing in the
          // row. Clamped to one line, two playlists sharing a prefix ("Deep
          // Focus", "Deep Focus (long)") become the same row at large text on a
          // screen whose entire job is telling items apart. The row already
          // carries a minimum height, so a second line costs nothing on short
          // titles and there is no reserved height here to protect.
          .lineLimit(2)
          .truncationMode(.tail)
          .multilineTextAlignment(.leading)

        Spacer(minLength: Spacing.xs)

        if isChosen {
          Image(systemName: "checkmark")
            .font(Typography.body)
            .foregroundStyle(Color(.action))
            .accessibilityHidden(true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .frame(minHeight: Spacing.controlHeight)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(MusicCopy.spokenRow(
      kind: row.spokenKind,
      title: row.selection.title,
      detail: nil)))
    .accessibilityAddTraits(isChosen ? [.isSelected] : [])
  }

  // MARK: Private

  /// Written as an exhaustive switch with no catch-all, so a third kind of row
  /// would stop this file compiling as well as the tests.
  private var glyph: String {
    switch row {
    case .playlist: "music.note.list"
    case .song: "music.note"
    }
  }
}

// MARK: - EmptyLibraryView

/// A library with nothing in it.
///
/// **Two lines and no control of any kind — not even one that opens the Music
/// app.** The precedent is the Todoist picker's empty project: *"One sentence and
/// no control of any kind. Not a button, not a greyed button, not a placeholder
/// row."* The second line names where music comes from, which is the same job
/// *"Tasks are created in Todoist, not here."* does one screen over, and it is
/// `SPEC.md`'s out-of-scope entry made visible on the one screen where somebody
/// might otherwise go looking.
struct EmptyLibraryView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.sm) {
      Text(MusicCopy.emptyLibraryHeading)
        .font(Typography.bodyEmphasis)
        .foregroundStyle(Color(.textPrimary))
        .fixedSize(horizontal: false, vertical: true)

      Text(MusicCopy.emptyLibraryDetail)
        .font(Typography.body)
        .foregroundStyle(Color(.textMuted))
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, Spacing.xl)
    .listRowBackground(Color.clear)
    .listRowSeparator(.hidden)
  }
}

// MARK: - MusicPickerSheet

/// The Music sheet as it appears in the running app: the picker above, wired to
/// the library and to the thing that owns the switch.
///
/// **WHY THE WIRING IS A SEPARATE TYPE FROM THE SCREEN.** The same split the
/// timer screen already uses: everything that can go wrong with reading a library
/// is a state of `MusicPickerView`, which draws finished values, so all of them
/// can be looked at in a preview with nothing behind them. This type is the part
/// that cannot be previewed, and it is deliberately small enough to read in one
/// go.
struct MusicPickerSheet: View {
  // MARK: Internal

  /// The thing that owns the switch and the choice.
  let music: MusicCoordinator

  /// The library. Read once when the sheet opens, and never written to.
  let library: any MusicLibraryReading

  /// The remembered library, so this sheet opens at once.
  let cache: MusicLibraryCache

  /// Whether a block is counting. The switch is locked while one is.
  let isBlockRunning: Bool

  /// Set from what the library turned out to hold, so the timer screen's row can
  /// say "Nothing in your library to play yet" without reading the library itself
  /// on the calmest screen in the app.
  @Binding var libraryIsEmpty: Bool

  var body: some View {
    NavigationStack {
      MusicPickerView(
        state: state,
        isEnabled: music.isEnabled,
        availability: music.availability,
        isBlockRunning: isBlockRunning,
        // Read from the coordinator rather than passed down from the timer
        // screen: this sheet is presented from two places, and a fact derived
        // twice is a fact that can disagree with itself.
        isBreak: music.isBreak,
        chosen: music.selection,
        // Reported by the coordinator, which is the only thing that knows
        // whether the last attempt to make a sound worked.
        playbackDidNotStart: music.lastPlaybackFailed,
        onToggleMusic: { isOn in Task { await music.setEnabled(isOn) } },
        onChoose: { music.setSelection($0) })
        .navigationTitle(MusicCopy.sheetTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
              .accessibilityHint(Text("Closes music."))
          }
        }
    }
    // **THE SECOND OF THE TWO PLACES AVAILABILITY IS RE-READ**, the other being
    // the app coming back to the front. It matters here because this is the
    // sheet whose own words send somebody to the Settings app to grant the
    // permission — and before this existed, coming back and opening it again
    // changed nothing, because the answer had been read once at launch. A
    // separate `.task` from the read below, so that the refresh cannot re-arm
    // itself through the key on that one.
    .task { music.refreshAvailability() }
    // Tied to the sheet's own lifetime, so closing it stops the read rather than
    // leaving work running against a screen nobody is looking at. There is no
    // unattended work anywhere in this app.
    //
    // **Keyed on whether music is available, because that can change while this
    // sheet is open.** Somebody who opens it before ever switching music on has
    // granted no permission, so there is nothing to read; the moment they flip
    // the switch here and permission is granted, the lists have to appear
    // without them closing the sheet and opening it again.
    .task(id: music.availability) { await read() }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss

  @State private var state = MusicPickerView.LoadState.reading

  /// Reads both lists, once.
  ///
  /// The two reads are sequential rather than side by side. A library request is
  /// answered from the phone's own database, so the second is quick once the
  /// first has warmed the framework up — and two at once would double the peak
  /// cost of opening this sheet on the phone of somebody with a very large
  /// library, which is exactly the person this paging exists for.
  private func read() async {
    // Only when this app may actually play something. Every other state either
    // has its own sentence on the sheet or has not asked for permission yet, and
    // a request that is certain to fail is a failure reported for nothing.
    guard music.availability == .ready else { return }

    // SHOW WHAT WE HAVE, THEN GO AND CHECK.
    //
    // A library request is answered from the phone's own database, so it is not
    // slow the way a network call is slow — but it pages, and on a real library
    // that is hundreds of milliseconds of blank sheet every single time. Drawing
    // the remembered list first means the sheet opens instantly and corrects
    // itself a moment later if anything has changed.
    //
    // `hasEverRead` rather than "is the list empty", because an empty list means
    // two opposite things — nobody has looked yet, or the library really is
    // empty — and showing "no music" to somebody who has plenty would be worse
    // than a brief spinner.
    if cache.hasEverRead {
      let remembered = cache.remembered()
      state = .ready(MusicPickerScreenModel(
        playlists: remembered.filter { $0.kind == .playlist },
        songs: remembered.filter { $0.kind == .song }))
    } else {
      state = .reading
    }

    do {
      let fresh = try await cache.refresh()
      let model = MusicPickerScreenModel(
        playlists: fresh.filter { $0.kind == .playlist },
        songs: fresh.filter { $0.kind == .song })
      state = .ready(model)
      libraryIsEmpty = model.isEmpty
    } catch is CancellationError {
      // The sheet was closed while the read was out. Nothing failed and nothing
      // needs saying: the state stays as it was and the screen has gone.
      return
    } catch {
      // A refresh that fails while something is already on screen leaves it
      // there: a remembered library is better than an error page, and it is
      // almost certainly still correct. Only a first read with nothing to fall
      // back on becomes a failure state.
      //
      // Closing and reopening the sheet is the retry; there is no amber and no
      // retry button.
      if case .ready = state { return }
      state = .failed
      libraryIsEmpty = false
    }
  }
}

// MARK: - Previews

#Preview("Playlists and songs, light") {
  MusicPickerPreviewHost(state: .ready(.previewLibrary), chosen: nil)
}

#Preview("Playlists and songs, dark") {
  MusicPickerPreviewHost(state: .ready(.previewLibrary), chosen: nil, appearance: .dark)
}

#Preview("Something chosen") {
  MusicPickerPreviewHost(state: .ready(.previewLibrary), isEnabled: true, chosen: .previewChosen)
}

/// The chosen item has been deleted in the Music app. It is in no list below, so
/// the section at the top is the only place it can be reported at all.
#Preview("Chosen item gone from library") {
  MusicPickerPreviewHost(state: .ready(.previewLibrary), isEnabled: true, chosen: .previewGone)
}

/// The sheet reached before music was ever switched on. The switch is live; the
/// library has not been asked for and is not reported as broken.
#Preview("Nothing asked for yet") {
  MusicPickerPreviewHost(state: .reading, availability: .notAsked, chosen: nil)
}

#Preview("Reading the library") {
  MusicPickerPreviewHost(state: .reading, chosen: nil)
}

#Preview("Library could not be read") {
  MusicPickerPreviewHost(state: .failed, chosen: nil)
}

/// Two lines and nothing to tap.
#Preview("Empty library") {
  MusicPickerPreviewHost(state: .ready(MusicPickerScreenModel()), chosen: nil)
}

/// The switch is locked and the one amber thing on the sheet is on screen.
#Preview("A block is running") {
  MusicPickerPreviewHost(
    state: .ready(.previewLibrary),
    isEnabled: true,
    isBlockRunning: true,
    chosen: .previewChosen)
}

#Preview("No subscription") {
  MusicPickerPreviewHost(state: .ready(.previewLibrary), availability: .noSubscription, chosen: nil)
}

/// Denied is the one state with a button on it, and the button opens the Settings
/// app rather than doing anything to the music.
#Preview("Permission denied") {
  MusicPickerPreviewHost(state: .ready(.previewLibrary), availability: .denied, chosen: nil)
}

#Preview("Turned off on this iPhone") {
  MusicPickerPreviewHost(state: .ready(.previewLibrary), availability: .restricted, chosen: nil)
}

/// Opened after a block in which nothing played. Muted, not amber: the block ran.
#Preview("Music didn't start last time") {
  MusicPickerPreviewHost(
    state: .ready(.previewLibrary),
    isEnabled: true,
    chosen: .previewChosen,
    playbackDidNotStart: true)
}

#Preview("Largest text") {
  MusicPickerPreviewHost(state: .ready(.previewLibrary), isEnabled: true, chosen: .previewChosen)
    .dynamicTypeSize(.accessibility5)
}

#Preview("A block is running, largest text") {
  MusicPickerPreviewHost(
    state: .ready(.previewLibrary),
    isEnabled: true,
    isBlockRunning: true,
    chosen: .previewChosen)
    .dynamicTypeSize(.accessibility5)
}

/// Preview scaffolding, never part of what ships. It draws the sheet exactly as
/// the app presents it, with nothing behind it: no library, no player, no
/// permission, and no music framework anywhere in the process.
private struct MusicPickerPreviewHost: View {
  let state: MusicPickerView.LoadState
  var isEnabled = false
  var availability = MusicAvailability.ready
  var isBlockRunning = false
  let chosen: MusicSelection?
  var playbackDidNotStart = false
  var appearance: ColorScheme = .light

  var body: some View {
    NavigationStack {
      MusicPickerView(
        state: state,
        isEnabled: isEnabled,
        availability: availability,
        isBlockRunning: isBlockRunning,
        chosen: chosen,
        playbackDidNotStart: playbackDidNotStart)
        .navigationTitle(MusicCopy.sheetTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
    .preferredColorScheme(appearance)
  }
}

/// Preview fixtures, never part of what ships.
private extension MusicPickerScreenModel {
  static let previewLibrary = MusicPickerScreenModel(
    playlists: [
      MusicSelection(kind: .playlist, identifier: "p.1", title: "Deep Focus"),
      MusicSelection(kind: .playlist, identifier: "p.2", title: "Piano for the afternoon"),
      MusicSelection(kind: .playlist, identifier: "p.3", title: "Anything without words at all, a very long name")
    ],
    songs: [
      MusicSelection(kind: .song, identifier: "s.1", title: "So What"),
      MusicSelection(kind: .song, identifier: "s.2", title: "Blue in Green"),
      MusicSelection(kind: .song, identifier: "s.3", title: "Gymnopédie No. 1")
    ])
}

private extension MusicSelection {
  static let previewChosen = MusicSelection(kind: .playlist, identifier: "p.1", title: "Deep Focus")

  /// Chosen once, and no longer in either list.
  static let previewGone = MusicSelection(kind: .playlist, identifier: "p.gone", title: "Late nights")
}
