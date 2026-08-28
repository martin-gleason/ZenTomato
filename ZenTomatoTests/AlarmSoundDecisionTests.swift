import Foundation
import Testing

@testable import ZenTomato

/// The one rule `F2c.md` singled out as *"the rule most likely to be got
/// backwards"*, held still.
@Suite("AlarmSoundDecision")
struct AlarmSoundDecisionTests {
  /// **SOUND OFF BEATS EVERY CHOICE, INCLUDING ONE MADE LAST WEEK.**
  ///
  /// Exhaustive over the catalogue rather than a spot check on one case: the way
  /// this rule gets inverted is a tidy-up that swaps two guards, and a swap shows
  /// up on whichever case happens to be tested last. `allCases` means adding a
  /// sound cannot quietly add an exception.
  @Test("soundOffIsSilentWhateverIsChosen")
  func soundOffIsSilentWhateverIsChosen() {
    for choice in AlertSound.allCases {
      #expect(
        AlarmSoundDecision.decide(soundEnabled: false, choice: choice) == .silent,
        "\(choice.rawValue) spoke over a person who had turned sound off.")
    }
  }

  /// With sound on, the choice is honoured — and the default is not a file.
  ///
  /// The second half matters as much as the first. `.systemDefault` has no
  /// filename, and asking the framework for a named file that does not exist is
  /// silence, so a decision that turned the default into `.bundled` would be an
  /// alarm nobody hears.
  @Test("soundOnPlaysWhatWasChosen")
  func soundOnPlaysWhatWasChosen() {
    #expect(AlarmSoundDecision.decide(soundEnabled: true, choice: .systemDefault) == .systemDefault)

    for choice in AlertSound.playable where choice != .systemDefault {
      let fileName = choice.fileName
      #expect(fileName != nil)
      #expect(AlarmSoundDecision.decide(soundEnabled: true, choice: choice) == .bundled(fileName ?? ""))
    }
  }

  /// A sound this build cannot play falls to the system default, never to a
  /// named file that resolves to nothing.
  ///
  /// This is the same failure as the one above arriving from the other side: a
  /// file dropped from the target, or a value stored by a build that shipped a
  /// sound this one does not. Either way the alarm must make a noise.
  @Test("anUnplayableChoiceStillMakesANoise")
  func anUnplayableChoiceStillMakesANoise() {
    // **THE BUNDLE STATE IS HANDED IN, NOT WAITED FOR.** Every sound in the
    // catalogue ships a file today, so `for … where isPlayable == false` runs
    // zero times and asserts nothing while still counting as a passing test.
    // This is the path the picker's whole design rests on, so it is exercised on
    // a day when nothing is missing.
    for choice in AlertSound.allCases {
      #expect(
        AlarmSoundDecision.decide(soundEnabled: true, choice: choice, isPlayable: false)
          == .systemDefault,
        "\(choice.rawValue) resolved to a file this build cannot play, which is silence.")
    }

    // And never silence — that is reserved for the person having asked for it.
    for choice in AlertSound.allCases {
      #expect(AlarmSoundDecision.decide(soundEnabled: true, choice: choice, isPlayable: false) != .silent)
      #expect(AlarmSoundDecision.decide(soundEnabled: true, choice: choice) != .silent)
    }

    // Sound off still wins, even over a sound that would have played.
    for choice in AlertSound.allCases {
      #expect(
        AlarmSoundDecision.decide(soundEnabled: false, choice: choice, isPlayable: true) == .silent)
    }
  }

  /// The two-argument form is the three-argument form asking the bundle.
  ///
  /// Stated so the seam cannot drift into a second implementation of the rule,
  /// which is the usual way a testability seam stops describing the code.
  @Test("theSeamAndTheRealCallAgree")
  func theSeamAndTheRealCallAgree() {
    for choice in AlertSound.allCases {
      for soundEnabled in [true, false] {
        #expect(
          AlarmSoundDecision.decide(soundEnabled: soundEnabled, choice: choice)
            == AlarmSoundDecision.decide(
              soundEnabled: soundEnabled, choice: choice, isPlayable: choice.isPlayable))
      }
    }
  }
}
