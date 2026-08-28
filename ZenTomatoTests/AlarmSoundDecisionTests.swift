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
    for choice in AlertSound.allCases where choice.isPlayable == false {
      #expect(AlarmSoundDecision.decide(soundEnabled: true, choice: choice) == .systemDefault)
    }
    // And never silence — silence is reserved for the person having asked for it.
    for choice in AlertSound.allCases {
      #expect(AlarmSoundDecision.decide(soundEnabled: true, choice: choice) != .silent)
    }
  }
}
