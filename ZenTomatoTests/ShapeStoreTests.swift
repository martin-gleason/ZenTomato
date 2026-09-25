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

    // **The timestamp is in the literal, and it has to be.** These bytes carry a cursor of one, and
    // the assertion below is about that cursor surviving an unreadable preset. Without a date the
    // 36-hour grace would rewind it to zero — correctly, since a position of unknown age is stale —
    // and this test would then be reporting a staleness rule under the name of a preset fallback.
    // Interpolated rather than typed, because the date's wire form is `JSONEncoder`'s business.
    let positionedAt = Date().timeIntervalSinceReferenceDate
    harness.write(
      raw: """
        {"version":1,"preset":"whateverComesNext","endsWithLongBreak":true,\
        "run":{"blocks":[{"kind":"work","minutes":22},{"kind":"longBreak","minutes":8}],\
        "budgetMinutes":30,"isUnderSuggestedMinimum":true,"cursor":1,\
        "positionedAt":\(positionedAt)}}
        """)

    let stored = try #require(harness.store.load())
    #expect(stored.preset == .balanced)
    #expect(stored.run?.cursor == 1)
    #expect(stored.run?.currentBlock == ShapedBlock(kind: .longBreak, minutes: 8))
  }

  // MARK: It is rewound when the shape is spent
  //
  // **THIS SECTION SAID "CLEARED" UNTIL 2026-09-24, AND THE TESTS ASSERTED IT.** Ruling E as first
  // written deleted a shape when its sprint ended. The owner superseded that — *"the rule to discard
  // a stored shape should last until a new shape is added"* — with a 36-hour grace on the position
  // only, so being spent now costs the shape its cursor and nothing else. The assertions are
  // inverted here rather than removed: every one of them still has to show that the sprint *ended*,
  // which is the half of the old test that was never about the lifetime.

  /// Running a shape to its end leaves the shape stored, back at its first block.
  ///
  /// Advanced one block at a time, the way a boundary advances it, rather than jumped to the end —
  /// a rewind that only fires when somebody skips to the last index is a rewind that never fires.
  ///
  /// **The pair of assertions is the point.** The blocks surviving alone would be true of a store
  /// that never ended a sprint; the cursor at zero alone was true of the old store, which deleted
  /// everything. Only both together say what the ruling says.
  @Test("aSpentShapeIsRewoundAndNotForgotten")
  func aSpentShapeIsRewoundAndNotForgotten() throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let shape = try Self.twoHourShape()
    harness.store.start(shape)

    var spent = [Bool]()
    for _ in shape.blocks { spent.append(harness.store.advance()) }

    let run = try #require(harness.store.runningShape())
    #expect(run.blocks.map(\.minutes) == shape.blocks.map(\.minutes))
    #expect(run.cursor == 0)
    // **`advance()` says "spent" exactly once, and on the last block.** The engine now takes the
    // end of a shaped sprint from this return value rather than from the store going `nil`, so a
    // store that returned `true` early — or never — would end the sprint in the wrong place while
    // every assertion above stayed green.
    #expect(spent == shape.blocks.indices.map { $0 == shape.blocks.count - 1 })
  }

  /// **A shape that does not end with a long break is rewound too**, and it is the case an end
  /// keyed on the timer cycle would miss for ever.
  ///
  /// `TimerCycle` raises "the sprint has ended" only when a long break finishes. With the trailing
  /// break switched off the shape's last block is a focus block, so that signal never arrives — and
  /// a store keyed on it would run the shape past its own budget. Both settings of the toggle
  /// are run because one of them passing is not evidence about the other.
  @Test("aShapeWithNoTrailingLongBreakIsAlsoRewound")
  func aShapeWithNoTrailingLongBreakIsAlsoRewound() throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let shape = try Self.twoHourShape(endsWithLongBreak: false)
    #expect(shape.endsWithLongBreak == false)
    harness.store.start(shape)

    var spent = [Bool]()
    for _ in shape.blocks { spent.append(harness.store.advance()) }

    #expect(try #require(harness.store.runningShape()).cursor == 0)
    #expect(spent == shape.blocks.indices.map { $0 == shape.blocks.count - 1 })
  }

  /// Rewinding the shape keeps the two controls, because they are remembered between shapes.
  @Test("theControlsOutliveThePosition")
  func theControlsOutliveThePosition() throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let shape = try Self.twoHourShape()
    harness.store.save(
      StoredShape(
        preset: .moreFocus, endsWithLongBreak: false,
        run: StoredRun(shape: shape, cursor: 3, positionedAt: Date())))

    harness.store.rewindRun()

    let stored = try #require(harness.store.load())
    #expect(stored.run?.cursor == 0)
    #expect(stored.run?.blocks.count == shape.blocks.count)
    #expect(stored.preset == .moreFocus)
    #expect(stored.endsWithLongBreak == false)
  }

  // MARK: The 36-hour grace on the position

  /// A shape whose cursor has not moved for longer than the grace is offered back **at its start**.
  ///
  /// **The fixture is 37 hours and the pair 35/37 is chosen so the two answers differ.** A test
  /// written at three weeks would pass against a grace of one hour, of one day, or of a fortnight —
  /// it would prove that *some* staleness rule exists and nothing about the number the owner ruled.
  @Test("aPositionOlderThanTheGraceIsDropped")
  func aPositionOlderThanTheGraceIsDropped() throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let shape = try Self.twoHourShape()
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    harness.store.save(
      StoredShape(
        preset: .balanced, endsWithLongBreak: true,
        run: StoredRun(shape: shape, cursor: 3, positionedAt: now.addingTimeInterval(-37 * 3600))))

    let run = try #require(harness.store(at: now).runningShape())

    #expect(run.cursor == 0, "the position is dropped")
    #expect(run.blocks.map(\.minutes) == shape.blocks.map(\.minutes), "the shape is not")
  }

  /// The same shape one hour younger is offered back **where it was left**.
  @Test("aPositionInsideTheGraceIsKept")
  func aPositionInsideTheGraceIsKept() throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    harness.store.save(
      StoredShape(
        preset: .balanced, endsWithLongBreak: true,
        run: StoredRun(
          shape: try Self.twoHourShape(), cursor: 3,
          positionedAt: now.addingTimeInterval(-35 * 3600))))

    #expect(try #require(harness.store(at: now).runningShape()).cursor == 3)
  }

  /// **A run written by a build that had no timestamp is stale**, and the bytes are a literal for
  /// the reason `anUnreadableShapeIsNoShape` gives: a value round-tripped through this build's own
  /// encoder cannot be missing a field this build writes.
  ///
  /// The shape itself still comes back. What a missing date costs is the position, which is the
  /// cheap direction — guessing *fresh* would resume exactly the ancient run the rule exists to drop.
  @Test("aPositionWithNoTimestampIsStale")
  func aPositionWithNoTimestampIsStale() throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    harness.write(
      raw: """
        {"version":1,"preset":"balanced","endsWithLongBreak":true,\
        "run":{"blocks":[{"kind":"work","minutes":22},{"kind":"longBreak","minutes":8}],\
        "budgetMinutes":30,"isUnderSuggestedMinimum":true,"cursor":1}}
        """)

    let run = try #require(harness.store.runningShape())

    #expect(run.cursor == 0)
    #expect(run.blocks.count == 2)
  }

  /// **The grace runs from the last move, not from the fitting**, so a sprint begun from an old
  /// shape is not rewound out from under itself.
  ///
  /// This is the defect the field name was changed for. Measured from the fitting, the first
  /// `advance()` would write cursor 1 and the very next read would find the *fitting* stale and put
  /// it back to 0 — a shaped sprint stuck on its first block for ever, on any shape older than a day
  /// and a half. Every assertion in the two tests above passes while that is true.
  @Test("advancingARewoundStaleShapeMakesThePositionFreshAgain")
  func advancingARewoundStaleShapeMakesThePositionFreshAgain() throws {
    let harness = try TestShapeStore.make()
    defer { harness.remove() }
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    harness.store.save(
      StoredShape(
        preset: .balanced, endsWithLongBreak: true,
        run: StoredRun(
          shape: try Self.twoHourShape(), cursor: 3,
          positionedAt: now.addingTimeInterval(-37 * 3600))))
    let store = harness.store(at: now)

    #expect(store.advance() == false)

    #expect(try #require(store.runningShape()).cursor == 1, "and it stays where the advance put it")
  }

  // MARK: The medium is a real seam

  /// **The only test that proves `KeyValueMedium` is an abstraction rather than a decoration.**
  ///
  /// The medium protocol was added to buy sync-readiness: `NSUbiquitousKeyValueStore` should drop in
  /// for v2.0 without the store being rewritten. Every other test here hands the real store a
  /// disposable `UserDefaults` suite, so all of them would still pass if `ShapeStore` had
  /// `UserDefaults` welded into it. This one drives the whole round trip — encode, store, decode,
  /// advance, rewind — through a conformer that is not `UserDefaults` and shares no code with it.
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

    #expect(store.advance() == false, "one block in, a seven-block shape is not spent")
    #expect(try #require(store.runningShape()).cursor == 1, "the cursor survives a round trip")

    store.rewindRun()
    #expect(try #require(store.runningShape()).cursor == 0, "rewinding reaches the medium too")
  }
}
