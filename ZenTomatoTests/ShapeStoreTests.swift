import Foundation
import Testing

@testable import ZenTomato

/// `F8-T2` — the shape store on its own, before anything reads it.
///
/// **What this suite is for:** the store is the only place in the app where a value crosses a
/// process boundary and possibly a *build* boundary, so it is the only place where "what happens
/// when this cannot be read" is a question with more than one answer. Every test below picks the
/// answer `F8`'s acceptance condition names: anything unreadable is no shape, and no shape is v1.0.
@Suite("ShapeStore")
struct ShapeStoreTests {
  /// Today's shipped defaults: 25 / 5 / 15, four poms to a sprint.
  private static let settings = TimerSettingsSnapshot(
    workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15,
    pomodorosPerSprint: 4, soundEnabled: true, alertSound: .systemDefault, autoStartNextBlock: false)

  private static func twoHourShape(endsWithLongBreak: Bool = true) throws -> SprintShape {
    try #require(
      SprintShaper.shape(
        budgetMinutes: 120, settings: settings, endsWithLongBreak: endsWithLongBreak))
  }

  // MARK: It survives being written down

  /// A shape written down comes back with every block intact.
  ///
  /// The assertion is on the **blocks**, not on a summary of them: a store that lost the odd
  /// minutes and kept the totals would pass a check on `pomCount` and `budgetMinutes` while
  /// serving a person the wrong length four times in a row.
  @Test("aShapeIsReadBackBlockForBlock")
  func aShapeIsReadBackBlockForBlock() throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let shape = try Self.twoHourShape()

    harness.store.start(shape)

    let run = try #require(harness.store.runningShape())
    #expect(run.shape == shape)
    #expect(run.cursor == 0)
    #expect(run.currentBlock == shape.blocks.first)
  }

  /// An empty store is no shape, and that is not an error.
  @Test("anEmptyStoreIsNoShape")
  func anEmptyStoreIsNoShape() throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }

    #expect(harness.store.load() == nil)
    #expect(harness.store.runningShape() == nil)
  }

  // MARK: It refuses what it cannot read

  /// A value written by a build this one has never met reads back as nothing at all.
  ///
  /// **The bytes are a literal, and that is the test.** They carry a version tag no build has
  /// written and never will, so the right implementation and one that reaches for a default give
  /// different answers. Encoding this through the app's own encoder would have tested the encoder.
  @Test("aValueFromAnotherBuildReadsBackAsNothing")
  func aValueFromAnotherBuildReadsBackAsNothing() throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }

    harness.write(
      raw: """
        {"version":99,"preset":"balanced","endsWithLongBreak":true,\
        "run":{"blocks":[{"kind":"work","minutes":22}],"budgetMinutes":22,\
        "isUnderSuggestedMinimum":false,"cursor":0}}
        """)

    #expect(harness.store.load() == nil)
    #expect(harness.store.runningShape() == nil)
    // The bytes are still there. "Cannot read it" is a decision taken on every read, not a repair
    // performed once — a store that deleted what it could not understand would make the failure
    // unobservable the second time anybody looked.
    #expect(harness.storedBytes != nil)
  }

  /// Bytes that are not the app's format at all are no shape either.
  @Test("nonsenseIsNoShape")
  func nonsenseIsNoShape() throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }

    harness.write(raw: "{\"shape\":\"whatever this is\"}")

    #expect(harness.store.load() == nil)
  }

  /// A run whose blocks no longer add up to its budget is refused, while the controls beside it
  /// are kept.
  ///
  /// **This is the invariant the domain type promises**, re-checked at the boundary the value
  /// crosses rather than assumed to have survived it. The controls are unaffected on purpose:
  /// losing a preference because a shape was corrupt would be a second failure caused by the first.
  @Test("anIncoherentRunIsNoShapeAndTheControlsRemain")
  func anIncoherentRunIsNoShapeAndTheControlsRemain() throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }

    harness.write(
      raw: """
        {"version":1,"preset":"moreRest","endsWithLongBreak":false,\
        "run":{"blocks":[{"kind":"work","minutes":22}],"budgetMinutes":120,\
        "isUnderSuggestedMinimum":false,"cursor":0}}
        """)

    let stored = try #require(harness.store.load())
    #expect(stored.run == nil)
    #expect(stored.preset == .moreRest)
    #expect(stored.endsWithLongBreak == false)
  }

  /// A control this build cannot read falls back to its own default, and the shape beside it is
  /// still served.
  ///
  /// **The opposite direction to every test above, and that asymmetry is the design.** A preset
  /// nobody recognises costs a person nothing; a shape nobody recognises costs them their
  /// afternoon.
  @Test("anUnknownPresetFallsBackWithoutLosingTheShape")
  func anUnknownPresetFallsBackWithoutLosingTheShape() throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }

    harness.write(
      raw: """
        {"version":1,"preset":"whateverComesNext","endsWithLongBreak":true,\
        "run":{"blocks":[{"kind":"work","minutes":22},{"kind":"longBreak","minutes":8}],\
        "budgetMinutes":30,"isUnderSuggestedMinimum":true,"cursor":1}}
        """)

    let stored = try #require(harness.store.load())
    #expect(stored.preset == .balanced)
    #expect(stored.run?.cursor == 1)
    #expect(stored.run?.currentBlock == ShapedBlock(kind: .longBreak, minutes: 8))
  }

  // MARK: It is cleared when the shape is spent

  /// Running a shape to its end leaves nothing stored.
  ///
  /// Advanced one block at a time, the way a boundary advances it, rather than jumped to the end —
  /// a clear that only fires when somebody skips to the last index is a clear that never fires.
  @Test("aSpentShapeIsCleared")
  func aSpentShapeIsCleared() throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let shape = try Self.twoHourShape()
    harness.store.start(shape)

    for _ in shape.blocks { harness.store.advance() }

    #expect(harness.store.runningShape() == nil)
  }

  /// **A shape that does not end with a long break is cleared too**, and it is the case a clear
  /// keyed on the timer cycle would miss for ever.
  ///
  /// `TimerCycle` raises "the sprint has ended" only when a long break finishes. With the trailing
  /// break switched off the shape's last block is a focus block, so that signal never arrives — and
  /// a store keyed on it would hold the shape until the end of time. Both settings of the toggle
  /// are run because one of them passing is not evidence about the other.
  @Test("aShapeWithNoTrailingLongBreakIsAlsoCleared")
  func aShapeWithNoTrailingLongBreakIsAlsoCleared() throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let shape = try Self.twoHourShape(endsWithLongBreak: false)
    #expect(shape.endsWithLongBreak == false)
    harness.store.start(shape)

    for _ in shape.blocks { harness.store.advance() }

    #expect(harness.store.runningShape() == nil)
  }

  /// Clearing the shape keeps the two controls, because they are remembered between shapes.
  @Test("theControlsOutliveTheShape")
  func theControlsOutliveTheShape() throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    harness.store.save(
      StoredShape(preset: .moreFocus, endsWithLongBreak: false, run: StoredRun(shape: try Self.twoHourShape())))

    harness.store.clearRun()

    let stored = try #require(harness.store.load())
    #expect(stored.run == nil)
    #expect(stored.preset == .moreFocus)
    #expect(stored.endsWithLongBreak == false)
  }

  // MARK: The medium is a real seam

  /// **The only test that proves `KeyValueMedium` is an abstraction rather than a decoration.**
  ///
  /// The medium protocol was added to buy sync-readiness: `NSUbiquitousKeyValueStore` should drop in
  /// for v2.0 without the store being rewritten. Every other test here hands the real store a
  /// disposable `UserDefaults` suite, so all of them would still pass if `ShapeStore` had
  /// `UserDefaults` welded into it. This one drives the whole round trip — encode, store, decode,
  /// advance, clear — through a conformer that is not `UserDefaults` and shares no code with it.
  ///
  /// If this test is ever deleted, the delta that bought the protocol has no evidence left.
  @Test("theStoreWorksThroughAMediumThatIsNotUserDefaults")
  func theStoreWorksThroughAMediumThatIsNotUserDefaults() throws {
    let medium = InMemoryMedium()
    let store = ShapeStore(medium: medium)
    let shape = try #require(SprintShaper.shape(budgetMinutes: 120, settings: Self.settings))

    #expect(store.load() == nil, "a fresh medium holds no shape")

    store.start(shape)
    #expect(medium.writes == 1, "the save reached the medium rather than being swallowed")

    let readBack = try #require(store.runningShape())
    #expect(readBack.pomCount == shape.pomCount)
    #expect(readBack.cursor == 0)

    store.advance()
    #expect(try #require(store.runningShape()).cursor == 1, "the cursor survives a round trip")

    store.clearRun()
    #expect(store.runningShape() == nil, "clearing reaches the medium too")
  }
}
