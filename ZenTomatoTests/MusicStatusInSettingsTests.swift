import Foundation
import Testing

@testable import ZenTomato

/// Whether Apple Music can be used is answerable from Settings, in words.
///
/// **WHAT WENT WRONG, AND WHY IT IS A TEST RATHER THAN A NOTE.** The four
/// sentences explaining an unusable music service already existed and were
/// already correct. They were drawn as a footer *underneath the library list* —
/// so on an account with a few hundred playlists they sat behind more than two
/// minutes of scrolling. The owner found them by scrolling to the end on
/// purpose. Copy nobody can reach is copy that does not exist, and no assertion
/// in the suite noticed, because every one of them tested the string rather than
/// the route to it.
///
/// So these tests are about *reachability and agreement*: the state is on the
/// screen people check a service on, and the two places that describe it cannot
/// come to describe it differently.
///
/// **This is a move, not a feature.** `AppSettings` gains no field — `PolishFence`
/// holds it at six — because nothing here is a setting. It is a report. The test
/// below that reads the source tree is what keeps that true.
@Suite("MusicStatusInSettings")
struct MusicStatusInSettingsTests {
  // MARK: The words themselves

  /// `everyStateHasAWordAndASentence` — including the states nobody plans for.
  ///
  /// `MusicAvailability` is `CaseIterable`, so this is exhaustive **by
  /// construction rather than by diligence**: a seventh case added next year
  /// fails here on the day it is added, instead of shipping as an empty row.
  /// That is the failure this whole change is about — a state with nothing
  /// legible attached to it.
  @Test("everyStateHasAWordAndASentence")
  func everyStateHasAWordAndASentence() {
    for state in MusicAvailability.allCases {
      let status = MusicCopy.settingsStatus(for: state)
      let footer = MusicCopy.settingsFooter(for: state)

      #expect(status.isEmpty == false, "\(state) has no status word.")
      #expect(footer.isEmpty == false, "\(state) has no explanation.")
      // A status is a value in a row, not a paragraph. Anything longer is a
      // footer that has drifted into the wrong slot.
      #expect(status.count <= 24, "\(state)'s status is a sentence: \(status)")
      #expect(status.hasSuffix(".") == false, "A trailing value takes no full stop.")
    }
  }

  /// `theSixStatusesAreDistinct` — six states, six different answers.
  ///
  /// Two states sharing a word would be worse than no word: somebody would read
  /// "Unavailable", check the thing it usually means, and find nothing wrong.
  @Test("theSixStatusesAreDistinct")
  func theSixStatusesAreDistinct() {
    let statuses = MusicAvailability.allCases.map { MusicCopy.settingsStatus(for: $0) }
    #expect(Set(statuses).count == statuses.count, "Two states read the same: \(statuses)")
  }

  /// `nothingHereSoundsLikeAnError` — the rule the music row already follows.
  ///
  /// This app not being able to play music is not a fault and the timer is
  /// unaffected either way. Settings must not raise the temperature of a
  /// situation the timer screen deliberately keeps calm; an alarmed Settings
  /// screen and a serene timer screen describing the same state is worse than
  /// either alone.
  @Test("nothingHereSoundsLikeAnError")
  func nothingHereSoundsLikeAnError() {
    for state in MusicAvailability.allCases {
      let text = MusicCopy.settingsStatus(for: state) + " " + MusicCopy.settingsFooter(for: state)
      for alarming in ["Error", "error", "Failed", "failed", "failure", "Warning", "invalid", "!"] {
        #expect(text.contains(alarming) == false, "\(state) says \(alarming).")
      }
    }
  }

  // MARK: Agreement between the two screens

  /// `thePickerAndSettingsCannotDisagree` — one function, two callers.
  ///
  /// The obvious implementation of this change was to copy four strings into
  /// Settings, which would have worked on the day and drifted by the third edit:
  /// somebody improves the sentence about subscriptions on one screen and the
  /// other keeps the old one, and now the app contradicts itself about a fact.
  ///
  /// So the picker was changed to call the same function. This test reads the
  /// source tree to keep it that way, because the agreement is invisible at
  /// runtime — two copies of identical strings pass every behavioural test there
  /// is right up until they diverge.
  @Test("thePickerAndSettingsCannotDisagree")
  func thePickerAndSettingsCannotDisagree() throws {
    let picker = try Self.source("ZenTomato/Views/MusicPickerView.swift")

    #expect(
      picker.contains("MusicCopy.settingsFooter"),
      "The music picker no longer shares Settings' words, so the two can drift apart.")
    for privatelyHeld in ["MusicCopy.deniedFooter", "MusicCopy.restrictedFooter",
                          "MusicCopy.noSubscriptionFooter", "MusicCopy.couldNotBeCheckedFooter"] {
      #expect(
        picker.contains(privatelyHeld) == false,
        "The picker reaches past the shared function to \(privatelyHeld).")
    }
  }

  // MARK: That it is actually on the screen

  /// `settingsShowsTheState` — the route, which is the entire point.
  ///
  /// A `View` body cannot be asserted on without a snapshot harness this project
  /// does not have and does not want. What can be checked is that the screen
  /// takes the state in and renders the shared copy — which is exactly the fact
  /// that was missing before, and the fact that would silently stop being true
  /// if somebody tidied the section away.
  @Test("settingsShowsTheState")
  func settingsShowsTheState() throws {
    let settings = try Self.source("ZenTomato/Views/SettingsView.swift")

    #expect(settings.contains("musicAvailability"), "Settings cannot see the music state.")
    #expect(settings.contains("MusicCopy.settingsStatus"), "Settings shows no status.")
    #expect(settings.contains("MusicCopy.settingsFooter"), "Settings shows no explanation.")
  }

  /// `settingsIsGivenTheRealState` — wired to the coordinator, not to a default.
  ///
  /// `SettingsForm` defaults `musicAvailability` to `.notAsked` so the screen can
  /// be drawn in a preview with nothing behind it, which is the arrangement the
  /// Todoist collaborators already use. That default is also a way this change
  /// could quietly become a lie: a screen that always reports "Not set up"
  /// reads as working and answers nothing. The timer screen must pass the live
  /// value in.
  @Test("settingsIsGivenTheRealState")
  func settingsIsGivenTheRealState() throws {
    let timer = try Self.source("ZenTomato/Views/TimerView.swift")
    #expect(
      timer.contains("musicAvailability: music.availability"),
      "Settings is presented without the live music state, so it reports a default forever.")
  }

  /// `thisAddedNoSetting` — a report, not a control.
  ///
  /// `PolishFence` pins `AppSettings` at six fields, and this states the same
  /// boundary from the other side: nothing on the new section writes. The music
  /// switch stays on the timer screen, where `D19` puts the decision — before a
  /// sprint, not inside one.
  @Test("thisAddedNoSetting")
  func thisAddedNoSetting() throws {
    let settings = try Self.source("ZenTomato/Views/SettingsView.swift")
    guard let section = settings.range(of: "private var music: some View {") else {
      Issue.record("The music section is gone.")
      return
    }
    guard let end = settings.range(of: "private var todoist:", range: section.upperBound..<settings.endIndex)
    else {
      Issue.record("Could not find the end of the music section.")
      return
    }
    let body = String(settings[section.upperBound..<end.lowerBound])

    for control in ["Toggle", "Stepper", "Picker", "TextField", "Button", "$settings"] {
      #expect(body.contains(control) == false, "The music section holds a \(control); it must only report.")
    }
  }

  // MARK: Private

  private static func source(_ path: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    return try String(contentsOf: root.appending(path: path), encoding: .utf8)
  }
}
