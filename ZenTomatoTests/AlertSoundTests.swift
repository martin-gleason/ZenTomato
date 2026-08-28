import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// The sound catalogue, and the two promises made when `D24` and `D25` were
/// ratified: an upgrade changes nothing, and every borrowed sound is credited.
@Suite("AlertSound")
struct AlertSoundTests {
  // MARK: The upgrade promise

  /// **A row written before `D24` reads back as the system default.**
  ///
  /// This is why `alertSoundRawValue` is optional rather than a `String` with a
  /// default: SwiftData writes a default into *new* rows, but the rows already on
  /// the owner's phone were written by a schema that had no such column at all.
  /// `nil` is what those rows actually produce, and `nil` must mean *the sound
  /// this app has always made* — otherwise upgrading changes the alarm without
  /// anybody asking for it.
  @Test("aRowFromBeforeThisFeatureSoundsExactlyAsItDid")
  @MainActor
  func aRowFromBeforeThisFeatureSoundsExactlyAsItDid() throws {
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext

    // Constructed the way a pre-D24 row arrives: the column is simply absent.
    let settings = AppSettings()
    context.insert(settings)
    try context.save()
    #expect(settings.alertSoundRawValue == nil)
    #expect(settings.alertSound == .systemDefault)

    // And the scheduler turns that into the system sound, not a named file that
    // is not in the bundle — which would be silence on the device.
    #expect(settings.alertSound.fileName == nil)
  }

  /// A value this build has never heard of is the system default, not a crash.
  ///
  /// The stored value is a `String` so that a future build can add a sound
  /// without a migration. The cost of that choice is that *this* build can be
  /// handed a name it does not know — by a downgrade, or by a synced row — and
  /// the only safe reading of an unknown sound is the one that always works.
  @Test("anUnknownNameFallsBackRatherThanFailing")
  func anUnknownNameFallsBackRatherThanFailing() {
    #expect(AlertSound.stored(nil) == .systemDefault)
    #expect(AlertSound.stored("") == .systemDefault)
    #expect(AlertSound.stored("gongFromVersionThree") == .systemDefault)
    // Round-trips for every sound this build can actually play. A case whose
    // file is not in the bundle deliberately does NOT round-trip — see
    // `anUnplayableSoundIsNeverReachable` for the reason.
    for known in AlertSound.playable {
      #expect(AlertSound.stored(known.rawValue) == known)
    }
  }

  /// Setting the choice writes the raw value, and reading it gives it back.
  @Test("theAccessorRoundTrips")
  @MainActor
  func theAccessorRoundTrips() throws {
    let container = try TestStore.inMemoryContainer()
    let settings = AppSettings()
    container.mainContext.insert(settings)

    for sound in AlertSound.playable {
      settings.alertSound = sound
      #expect(settings.alertSoundRawValue == sound.rawValue)
      #expect(settings.alertSound == sound)
    }

    // Writing an unplayable sound stores the name — a later build that ships the
    // file will honour it — but reads back as the default, because *this* build
    // would play nothing. The setter is storage; the getter is what can be heard.
    for sound in AlertSound.allCases where sound.isPlayable == false {
      settings.alertSound = sound
      #expect(settings.alertSoundRawValue == sound.rawValue)
      #expect(settings.alertSound == .systemDefault)
    }
  }

  /// **A sound whose file is not in the bundle is unreachable from every
  /// direction.** It is not offered, it is not stored, and it cannot be
  /// scheduled.
  ///
  /// This is the feature turning into its own bug. `named(_:)` resolves against
  /// the bundle and, when the file is missing, produces no error and no
  /// fallback — just silence. An alarm that makes no noise is precisely the
  /// defect `D24` was ratified to fix, so the one thing this code must never do
  /// is reintroduce it by offering a sound it has not got.
  @Test("anUnplayableSoundIsNeverReachable")
  func anUnplayableSoundIsNeverReachable() {
    for sound in AlertSound.allCases where sound.isPlayable == false {
      #expect(AlertSound.playable.contains(sound) == false)
      #expect(AlertSound.stored(sound.rawValue) == .systemDefault)
    }
    // The default is always available, so the picker can never be empty and
    // there is always something for an unplayable value to fall back to.
    #expect(AlertSound.systemDefault.isPlayable)
    #expect(AlertSound.playable.first == .systemDefault)
    #expect(AlertSound.playable.isEmpty == false)
    // Playable is a filter of the catalogue, never a separate list that could
    // drift from it.
    #expect(AlertSound.playable.allSatisfy(AlertSound.allCases.contains))
  }

  // MARK: The attribution promise

  /// **Every sound that is not ours carries a credit, and every credit points at
  /// a real sound.** Asserted in both directions on purpose.
  ///
  /// One direction alone is a test that passes while the promise is broken: check
  /// only that credits are well-formed and a new sound may ship with none; check
  /// only that sounds have credits and a credit may name a file nobody ships.
  /// The owner's condition for ratifying `D25` was "we must attribute with a link
  /// to each alarm sound", and that is a statement about the pairing.
  @Test("everyBorrowedSoundIsCreditedAndEveryCreditIsRealBothWays")
  func everyBorrowedSoundIsCreditedAndEveryCreditIsRealBothWays() throws {
    for sound in AlertSound.allCases {
      // Forwards: a sound that ships a file is a sound somebody else made.
      if sound.fileName != nil {
        let attribution = try #require(
          sound.attribution, "\(sound.rawValue) ships a sound file with no credit.")
        #expect(attribution.author.isEmpty == false)
        #expect(attribution.licence.isEmpty == false)
        #expect(
          attribution.source.hasPrefix("https://"),
          "\(sound.rawValue)'s credit must be a link somebody can follow.")
        #expect(URL(string: attribution.source) != nil)
      }
      // Backwards: a credit that names nothing is a credit for a sound we do not
      // actually play, which is worse than none — it says we borrowed something
      // we did not.
      if sound.attribution != nil {
        #expect(
          sound.fileName != nil,
          "\(sound.rawValue) carries a credit but ships no sound file.")
      }
    }
  }

  /// The system sound is Apple's, so it is the one case with nothing to credit.
  @Test("theSystemSoundIsNotCreditedToAnybody")
  func theSystemSoundIsNotCreditedToAnybody() {
    #expect(AlertSound.systemDefault.attribution == nil)
    #expect(AlertSound.systemDefault.fileName == nil)
  }

  /// Names are what a person reads on the settings screen, so no two may match
  /// and none may be blank.
  @Test("everySoundHasADistinctReadableName")
  func everySoundHasADistinctReadableName() {
    let names = AlertSound.allCases.map(\.name)
    #expect(names.allSatisfy { $0.isEmpty == false })
    #expect(Set(names).count == names.count)
    // Raw values are storage and must never be shown; names are prose.
    #expect(names.contains("systemDefault") == false)
  }
}
