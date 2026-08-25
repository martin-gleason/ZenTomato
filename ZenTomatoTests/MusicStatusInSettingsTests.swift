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
  /// **This is the weakest test here and it is worth being straight about why.**
  /// An earlier draft claimed it catches a seventh `MusicAvailability` case
  /// shipping with no words attached. It does not: both switches in `MusicCopy`
  /// are exhaustive over a non-frozen local enum, so a seventh case is a compile
  /// error and the compiler gets there first.
  ///
  /// What is left is the part the compiler cannot check — that the words are
  /// non-empty, short enough to be a value in a row rather than a paragraph that
  /// has drifted into the wrong slot, and punctuated like a value. Thin, but not
  /// nothing, and stated honestly rather than oversold.
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

    // `.ready` and `.notAsked` are the two that most invite being collapsed, and
    // an earlier draft did collapse them. "Not set up" above a sentence
    // describing music playing during focus blocks reads as a description of
    // what the app is doing right now, when it is doing none of it.
    #expect(
      MusicCopy.settingsFooter(for: .notAsked) != MusicCopy.settingsFooter(for: .ready),
      "Music switched off and music working are being explained with the same words.")
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

  /// `settingsShowsTheState` — the section is **in the form**, not merely written.
  ///
  /// **The first version of this test was the bug it was written to prevent.** It
  /// searched the whole file for `MusicCopy.settingsStatus` and passed as long as
  /// the string appeared anywhere in it — so deleting `music` from the `Form`
  /// body would have left the section orphaned, unreachable, and all seven tests
  /// green. Copy that exists, is correct, is tested, and cannot be reached: the
  /// exact defect F4c was opened to fix, reproduced inside the fix. Caught in
  /// adversarial review, not by the suite.
  ///
  /// So this reads the `Form` body specifically. A `View` cannot be asserted on
  /// without a snapshot harness this project does not have, but the difference
  /// between "rendered" and "merely declared" is one line in the form, and that
  /// line is checkable.
  @Test("settingsShowsTheState")
  func settingsShowsTheState() throws {
    let settings = try Self.source("ZenTomato/Views/SettingsView.swift")
    let form = try #require(Self.formBody(of: settings), "The Settings form is gone.")

    #expect(
      form.contains(where: { $0 == "music" }),
      """
      The music section is declared but not placed in the Settings form, so nobody \
      can reach it. The form renders: \(form.joined(separator: ", "))
      """)
    // The neighbours, so that a form emptied wholesale cannot pass the line above
    // by coincidence, and so the ordering decision is written down: music sits
    // beside Todoist because both are this app's outside services.
    #expect(form.contains(where: { $0 == "todoist" }))
    #expect(
      form.firstIndex(of: "music") ?? 0 < form.firstIndex(of: "todoist") ?? 0,
      "Music is meant to sit directly above Todoist.")

    #expect(settings.contains("MusicCopy.settingsStatus"), "Settings shows no status.")
    #expect(settings.contains("MusicCopy.settingsFooter"), "Settings shows no explanation.")
  }

  /// `settingsAsksAgainWhenItOpens` — it must not answer from launch-time memory.
  ///
  /// `OPEN.md` now advertises this row as the faster way to answer `O14`, which
  /// makes staleness a correctness problem rather than a nicety: somebody grants
  /// permission in iOS Settings, comes straight back, reads the answer from
  /// launch, and concludes the app is broken. The picker already refreshes on
  /// appear; this asserts Settings does too, and that it is given the real call
  /// rather than the no-op preview default.
  @Test("settingsAsksAgainWhenItOpens")
  func settingsAsksAgainWhenItOpens() throws {
    let settings = try Self.source("ZenTomato/Views/SettingsView.swift")
    let timer = try Self.source("ZenTomato/Views/TimerView.swift")

    #expect(
      settings.contains(".task { refreshMusicAvailability() }"),
      "Settings never asks again, so it can report a state stale since launch.")
    #expect(
      timer.contains("refreshMusicAvailability: { music.refreshAvailability() }"),
      "Settings is given the do-nothing default, so its refresh is decorative.")
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
    // Bounded by the next declaration in source order. If the file is ever
    // reordered this widens rather than narrows, so it cannot silently pass.
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

  /// The identifiers the Settings `Form` actually renders, in order.
  private static func formBody(of settings: String) -> [String]? {
    guard let start = settings.range(of: "    Form {") else { return nil }
    guard let end = settings.range(of: "\n    }\n", range: start.upperBound..<settings.endIndex)
    else { return nil }
    return settings[start.upperBound..<end.lowerBound]
      .components(separatedBy: "\n")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { $0.isEmpty == false }
  }

  private static func source(_ path: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    return try String(contentsOf: root.appending(path: path), encoding: .utf8)
  }
}
