import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// The sound catalogue, and the two promises `D24` made: an upgrade changes
/// nothing, and every borrowed sound is credited.
///
/// **Both are `D24`. `D25` is music during a break** — a different delta that
/// shipped as `F4f`. An earlier draft of this suite cited it here and in three
/// other places; a comment citing the wrong ratification is a corrupted audit
/// trail in a project whose contract is amended only by numbered deltas.
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

  /// **Every sound file this app ships is accounted for, and every credit names a
  /// file that is really there.** Asserted against the directory, not against the
  /// source file the credits are written in.
  ///
  /// `D24`: *"every bundled sound file has exactly one attribution entry … the
  /// counts match in both directions — a sound with no credit fails, and a credit
  /// with no sound fails."* An earlier version of this test compared
  /// `AlertSound.fileName` with `AlertSound.attribution` — two `switch`
  /// statements in one file, which any edit touches together. It could not see a
  /// sound file added to the target and never listed, which is exactly how
  /// attribution rots, and it passed while the tree held two credits for files
  /// that did not exist.
  ///
  /// So it reads `ZenTomato/Resources` from the source tree via `#filePath`, the
  /// way `StatsMarkdownGoldenTests` reads its golden and `LaunchBackgroundTests`
  /// reads the launch colour. The directory is the thing that ships; a list is
  /// just a claim about it.
  @Test("everyShippedSoundFileIsAccountedForAndEveryCreditIsReal")
  func everyShippedSoundFileIsAccountedForAndEveryCreditIsReal() throws {
    let files = try Self.shippedSoundFileNames()
    #expect(files.isEmpty == false, "No sound files found at all — the fence is reading the wrong directory.")

    // Forwards: every file in the directory is either an AlertSound with a
    // credit, or one of the files below that are ours and have nobody to credit.
    for file in files where Self.soundsWeMadeOurselves.contains(file) == false {
      let sound = try #require(
        AlertSound.allCases.first { $0.fileName == file },
        """
        \(file) ships in the app and is not in the AlertSound catalogue. \
        Either credit it, or add it to soundsWeMadeOurselves with a reason.
        """)
      let attribution = try #require(
        sound.attribution, "\(file) ships with no credit.")
      #expect(attribution.author.isEmpty == false)
      #expect(attribution.licence.isEmpty == false)
      #expect(
        attribution.source.hasPrefix("https://"),
        "\(file)'s credit must be a link somebody can follow.")
      #expect(URL(string: attribution.source) != nil)
    }

    // Backwards: a credit that names a file we do not ship is a false statement
    // about somebody's work — worse than no credit, because it says we used
    // something we did not.
    for sound in AlertSound.allCases where sound.attribution != nil {
      let fileName = try #require(sound.fileName, "\(sound.rawValue) carries a credit but names no file.")
      #expect(
        files.contains(fileName),
        "\(sound.rawValue) credits \(fileName), which is not in ZenTomato/Resources.")
    }

    // And the counts match, which is the sentence D24 actually wrote. Stated
    // separately because the two loops above could both pass on an empty set.
    let credited = AlertSound.allCases.filter { $0.attribution != nil }
    let borrowedFiles = files.filter { Self.soundsWeMadeOurselves.contains($0) == false }
    #expect(credited.count == borrowedFiles.count)
  }

  /// **The credits a person can actually read, not just the data behind them.**
  ///
  /// `D24`: *"a list nobody can reach is not attribution, so if About is not
  /// ready, the sound picker carries it."* The fence above proves every bundled
  /// sound has a well-formed credit; this proves the credit reaches the screen,
  /// and that the heading does not stand over an empty list when the app ships
  /// nothing borrowed.
  @Test("theCreditsOnScreenMatchTheSoundsThatShip")
  func theCreditsOnScreenMatchTheSoundsThatShip() throws {
    let borrowed = AlertSound.playable.filter { $0.attribution != nil }

    guard borrowed.isEmpty == false else {
      #expect(AlertSound.credits == nil, "A credits heading appeared with nothing to credit.")
      return
    }

    let text = try #require(AlertSound.credits)
    for sound in borrowed {
      let attribution = try #require(sound.attribution)
      #expect(text.contains(sound.name))
      #expect(text.contains(attribution.author))
      #expect(text.contains(attribution.licence))
      #expect(text.contains(attribution.source), "\(sound.name)'s link is not on screen.")
    }
    // Nobody unplayable is credited on screen — that would name an author whose
    // work this build does not actually play.
    for sound in AlertSound.allCases where sound.isPlayable == false {
      #expect(text.contains(sound.name) == false)
    }
  }

  /// The sound files this app ships, read from the source tree.
  ///
  /// `#filePath` is this file's own path as compiled, so the repository is two
  /// directories up. Reading the tree rather than the bundle is deliberate: the
  /// question is "what did we commit and did we credit it", which a reviewer can
  /// check against the same directory in a pull request.
  private static func shippedSoundFileNames() throws -> Set<String> {
    let resources = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()      // ZenTomatoTests
      .deletingLastPathComponent()      // the repository
      .appending(path: "ZenTomato")
      .appending(path: "Resources")

    let contents = try FileManager.default.contentsOfDirectory(
      at: resources, includingPropertiesForKeys: nil)
    return Set(contents.map(\.lastPathComponent).filter { $0.hasSuffix(".caf") })
  }

  /// Sound files this app made rather than borrowed, and therefore has nobody to
  /// credit.
  ///
  /// **A named list, not a silence in the fence.** `Silence.caf` is half a second
  /// of digital nothing generated for the sound-off setting; it is not an alert
  /// sound, is not offered in the picker and belongs to no author. Every other
  /// file in that directory must be credited, and adding one here is a decision
  /// somebody has to write down rather than something a test quietly permits.
  private static let soundsWeMadeOurselves: Set<String> = ["Silence.caf"]

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
