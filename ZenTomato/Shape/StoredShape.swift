import Foundation

/// The shape as it is written down, and the only thing that is.
///
/// **THIS IS A FORMAT, NOT A MODEL, AND THAT SEPARATION IS THE WHOLE FILE.**
/// `SprintShape` and `ShapedBlock` are deliberately *not* `Codable`. If they were, the persistence
/// format would be the domain type: a later change to the calculator — a field renamed, a value
/// computed rather than stored — would silently change what an install written by yesterday's build
/// decodes to, and nothing would say so. A separate transfer type means the format can be
/// version-tagged on its own and converted at one boundary, which is also the only place the
/// *"fills the budget exactly"* promise can be re-checked on the way back in.
///
/// **THE CONTROLS SIT OUTSIDE THE RUN ON PURPOSE.** `T3` says the trailing-break toggle and the
/// absorption preset are *"remembered between shapes"*. Nesting the controls inside the run would
/// make forgetting them the default behaviour of clearing it — a durability bug that would only show
/// up as a preference quietly resetting itself, which is the hardest kind to notice and the easiest
/// kind to dismiss. (When this was written the run *was* deleted at the end of its sprint. The
/// owner's ruling of 2026-09-24 replaced that with a rewind, so the two now live equally long; the
/// separation is kept because the argument for it never depended on the lifetimes differing.)
///
/// **THE ASYMMETRY IN `init(from:)` IS THE DESIGN.** The two controls decode *leniently*, falling
/// back to their own defaults, because a wrong preset costs a person nothing and the controls are
/// supposed to survive. The run decodes *strictly*: anything this build cannot read in full, or
/// reads as incoherent, becomes `nil`. **The only value this type can return for a shape it cannot
/// read is `nil`; there is no other spelling.** A wrong shape costs a person their afternoon, and
/// `F8`'s acceptance condition already names the safe state — no shape is v1.0 behaviour.
///
/// This is the same softening `AlertSound.stored(_:)` performs for a stored alarm tone, and the
/// direction is deliberately **opposite**: that one returns a default, this one returns nothing. A
/// reader arriving here from three files away should not copy the wrong precedent.
struct StoredShape: Codable, Equatable {
  /// The version this build writes, and the only version it reads.
  ///
  /// **Compared with `==` rather than `>=`, and the difference is not pedantry.** `>=` reads like
  /// leniency and is precisely backwards: the payload this build cannot understand is the one from
  /// a *later* version, written by a build installed over this one and then rolled back.
  static let version = 1

  /// Which blocks absorb the leftover minutes. Remembered between shapes.
  var preset: AbsorptionPreset

  /// Whether a shape ends with the long break the sprint earned. Remembered between shapes.
  var endsWithLongBreak: Bool

  /// **The shape you last fitted, wherever it has got to.** `nil` is the only spelling of "no shape".
  ///
  /// It is not *"the shape that is running"* any more, and the rename of the idea matters more than
  /// the name of the field. Under the owner's ruling of 2026-09-24 the shape survives its sprint
  /// finishing, being stopped early, and thirty-six hours of silence — what those three events cost
  /// it is its **position**, not its existence. A cursor of zero is what "not running" looks like
  /// now; the field going `nil` means only that nothing has ever been fitted, or that what was there
  /// could not be read.
  var run: StoredRun?

  private enum CodingKeys: String, CodingKey {
    case version
    case preset
    case endsWithLongBreak
    case run
  }

  /// Creates the value that is written.
  init(preset: AbsorptionPreset, endsWithLongBreak: Bool, run: StoredRun?) {
    self.preset = preset
    self.endsWithLongBreak = endsWithLongBreak
    self.run = run
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // Guarded before a single field of the payload is touched. A value this build has never
    // written is not partially readable, and treating it as partially readable is how a stored
    // format grows an accidental second dialect.
    guard try container.decode(Int.self, forKey: .version) == Self.version else {
      throw DecodingError.dataCorruptedError(
        forKey: .version, in: container, debugDescription: "Written by a build this one cannot read.")
    }
    preset = (try? container.decode(AbsorptionPreset.self, forKey: .preset)) ?? .balanced
    endsWithLongBreak = (try? container.decode(Bool.self, forKey: .endsWithLongBreak)) ?? true
    let decoded = try? container.decode(StoredRun.self, forKey: .run)
    // Coherence is checked here rather than trusted, because the invariant belongs to the boundary
    // the value crosses. A run whose blocks no longer add up to its budget is not a shape this app
    // produced, whoever wrote it.
    run = decoded?.isCoherent == true ? decoded : nil
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(Self.version, forKey: .version)
    try container.encode(preset, forKey: .preset)
    try container.encode(endsWithLongBreak, forKey: .endsWithLongBreak)
    try container.encodeIfPresent(run, forKey: .run)
  }
}

// MARK: - The running shape

/// One shape part-way through being run.
///
/// **The cursor is stored rather than derived, and that is a decision with a cost.** It could be
/// worked out from the timer row that already survives a kill — the block kind and the count of
/// completed poms together pick a slot. That derivation is total on the happy path and wrong off
/// it: `TimerCycle` leaves the pom tally unmoved when a focus block is skipped, so a derived cursor
/// re-serves a slot the shape has already spent and the sprint quietly overruns the budget the
/// shape exists to keep. The price of storing it is two writes at a boundary — this and SwiftData's
/// — with no transaction between them; `docs/plans/F8.md`'s checkpoint two is where that window is
/// measured on real hardware rather than argued about here.
struct StoredRun: Codable, Equatable {
  /// Every block, in the order it runs.
  let blocks: [StoredBlock]

  /// The budget the shape was fitted to.
  ///
  /// **Stored rather than recomputed from `blocks`, deliberately.** Re-deriving it would make the
  /// fills-the-budget-exactly check a tautology — an assertion that recomputes its expected value
  /// cannot see the path that produced the real one, which is this project's own named failure.
  let budgetMinutes: Int

  /// Whether the shape holds fewer poms than a full sprint. Carried rather than recomputed because
  /// the suggested minimum is a function of *settings*, and settings may change mid-shape while the
  /// shape wins — recomputing would let an edit flip the warning on a shape that was never short.
  let isUnderSuggestedMinimum: Bool

  /// The index of the block running now, or about to run.
  ///
  /// Allowed to reach `blocks.count`, which means the shape is spent — the same rule
  /// `SessionPlan.currentIndex` already follows for the neighbouring case.
  var cursor: Int

  /// When the cursor last moved — which is when the shape was fitted, if it has not moved since.
  ///
  /// **The grace is measured from the POSITION, not from the fitting, and the difference is a
  /// defect.** Measured from the fitting, a sprint begun from a shape fitted forty hours ago would
  /// be rewound by its own second read: `advance()` would write cursor 1, the next `load()` would
  /// find the fitting stale and rewind it to 0, and the sprint would run its first block for ever.
  /// Stamping this as the cursor moves means "stale" says what the rule means — *nobody has been
  /// here for a day and a half* — rather than *this shape is old*, and an old shape is exactly what
  /// the owner ruled should survive.
  ///
  /// **Optional, and a missing value means STALE rather than fresh.** A run written by a build
  /// before this field existed has an age nobody can know, and the whole purpose of the grace is to
  /// avoid resuming something ancient. Guessing *fresh* would resume exactly the run the rule is
  /// there to drop; guessing *stale* costs a position and keeps the shape, which is the cheap
  /// direction.
  ///
  /// **It is not a version bump**, deliberately. `StoredShape.version` is compared with `==`, so
  /// raising it would make every shape written by the shipping build unreadable — including the one
  /// the owner set on 2026-09-25 to prove the store survives an update. A leniently-decoded optional
  /// adds the field without discarding what is already there.
  var positionedAt: Date?

  /// Whether this is a shape this app could have produced.
  ///
  /// Checked on the way in rather than assumed, because the value crossed a process boundary and
  /// possibly a build boundary to get here.
  var isCoherent: Bool {
    guard !blocks.isEmpty, cursor >= 0, cursor <= blocks.count else { return false }
    guard blocks.allSatisfy({ $0.minutes >= 1 }) else { return false }
    return blocks.reduce(0) { $0 + $1.minutes } == budgetMinutes
  }

  /// The block the engine should run next, or `nil` when the shape is spent.
  var currentBlock: ShapedBlock? {
    guard cursor >= 0, cursor < blocks.count else { return nil }
    return ShapedBlock(kind: blocks[cursor].kind, minutes: blocks[cursor].minutes)
  }

  /// True when every block has been run and the shape has nothing left to say.
  var isSpent: Bool { cursor >= blocks.count }

  /// How many focus blocks the shape holds. What `pomodorosPerSprint` becomes while it runs, so
  /// that the long break lands where the shape says rather than where the setting says.
  var pomCount: Int { blocks.filter { $0.kind == .work }.count }

  /// Writes a freshly calculated shape down, at its first block.
  init(shape: SprintShape, cursor: Int = 0, positionedAt: Date? = nil) {
    blocks = shape.blocks.map { StoredBlock(kind: $0.kind, minutes: $0.minutes) }
    budgetMinutes = shape.budgetMinutes
    isUnderSuggestedMinimum = shape.isUnderSuggestedMinimum
    self.cursor = cursor
    self.positionedAt = positionedAt
  }

  /// How long a position stays resumable after the cursor last moved. **Ruled by the owner,
  /// 2026-09-24.**
  ///
  /// *"Only the definition. A grace period of 36 hours."* The shape itself — its blocks, its preset
  /// and its long-break toggle — lasts until a new shape replaces it. The **position in it** does
  /// not: resuming last night's sprint is right, resuming one from three weeks ago is not.
  ///
  /// **Thirty-six and not twenty-four**, and the difference is the ordinary case: stopping at six in
  /// the evening and coming back after nine the next morning is under a day of clock time and over a
  /// day of calendar. Thirty-six covers a night and the working day after it without reaching a
  /// second night.
  static let grace: TimeInterval = 36 * 60 * 60

  /// Whether this position is still inside its grace period.
  ///
  /// A run with no `positionedAt` is **not** fresh — see that property for why.
  func isFresh(at now: Date) -> Bool {
    guard let positionedAt else { return false }
    return now.timeIntervalSince(positionedAt) < Self.grace
  }

  /// The same shape, back at its first block. **What a spent, stopped or stale run becomes.**
  ///
  /// The timestamp goes with the position, because a rewound run has no position to have a date
  /// for — and leaving yesterday's date on a cursor of zero would make a rewind look, to the next
  /// read, like something that still needed rewinding.
  var rewound: StoredRun {
    var copy = self
    copy.cursor = 0
    copy.positionedAt = nil
    return copy
  }

  /// Reads it back as the domain type the rest of the app works in.
  var shape: SprintShape {
    SprintShape(
      blocks: blocks.map { ShapedBlock(kind: $0.kind, minutes: $0.minutes) },
      budgetMinutes: budgetMinutes,
      isUnderSuggestedMinimum: isUnderSuggestedMinimum)
  }
}

/// One block as it is written down.
///
/// `BlockKind` is stored rather than inferred from position, because position does not say which:
/// with the trailing break switched off the last element is a focus block, and with it switched on
/// it is a long break. It carries its own `String` raw value into the file for the reason
/// `BlockKind` already gives — a stored number means nothing to anybody reading the file, and
/// reordering the cases would silently change what every stored value meant.
struct StoredBlock: Codable, Equatable {
  let kind: BlockKind
  let minutes: Int
}
