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
/// absorption preset are *"remembered between shapes"*, and the run is deleted the moment its
/// sprint ends. Nesting the controls inside the run would make forgetting them the default
/// behaviour of clearing it — a durability bug that would only show up as a preference quietly
/// resetting itself, which is the hardest kind to notice and the easiest kind to dismiss.
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

  /// The shape that is running, or `nil` when none is. **`nil` is the only spelling of "no shape".**
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
  init(shape: SprintShape, cursor: Int = 0) {
    blocks = shape.blocks.map { StoredBlock(kind: $0.kind, minutes: $0.minutes) }
    budgetMinutes = shape.budgetMinutes
    isUnderSuggestedMinimum = shape.isUnderSuggestedMinimum
    self.cursor = cursor
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
