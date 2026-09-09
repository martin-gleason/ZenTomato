import Foundation

/// One block in a shape, and how long it runs.
///
/// **Deliberately not `TimerSettingsSnapshot`.** A snapshot answers "how long is *a* focus block",
/// which assumes every focus block in a sprint is the same length. A shape exists precisely because
/// they are not: fitting four poms into two hours leaves odd minutes, and those minutes have to land
/// somewhere. They land on individual blocks, so a block carries its own length.
struct ShapedBlock: Equatable, Sendable {
  let kind: BlockKind
  let minutes: Int
}

/// A sprint fitted to a stretch of time.
///
/// **What a shape is, in one sentence:** you say how long you have, and this says how to cut it up.
///
/// **A shape is one sprint.** It is poms separated by short breaks, ending — when the person wants
/// it to — with the long break that completing a sprint earns. It is not a schedule, not a plan, and
/// not a saved object. `docs/specs/definitions.md` holds those words apart, because `SessionPlan`
/// already means *what you will work on* and this means *how the time is divided*.
///
/// **It fills the budget exactly.** Never over, never under. The remainder from a division that does
/// not come out even is absorbed by the blocks rather than left on the floor, which is how both
/// promises — *"I will fill your two hours"* and *"I will not overrun your two hours"* — are kept at
/// once. `docs/plans/F8.md`, Ruling C.
struct SprintShape: Equatable, Sendable {
  /// Every block, in the order it runs.
  let blocks: [ShapedBlock]

  /// The budget this was fitted to. `totalMinutes` always equals it.
  let budgetMinutes: Int

  /// True when the shape holds fewer poms than a full sprint, because the budget could not hold one
  /// even with every block squeezed to its floor.
  ///
  /// **This is the warning, not an error.** A short shape is a real shape and it runs. The person is
  /// told what the suggested minimum is and left to decide, because somebody with twenty minutes
  /// still has twenty minutes.
  let isUnderSuggestedMinimum: Bool

  /// How many focus blocks. What the log counts, and what "3 poms" means on screen.
  var pomCount: Int { blocks.filter { $0.kind == .work }.count }

  /// Minutes of actual work. **Not** the budget — the difference is the rest.
  var focusMinutes: Int { blocks.filter { $0.kind == .work }.reduce(0) { $0 + $1.minutes } }

  /// Every block added up. Equal to `budgetMinutes` for any shape this app produces; asserted rather
  /// than assumed, because "fills the budget exactly" is a promise and not a hope.
  var totalMinutes: Int { blocks.reduce(0) { $0 + $1.minutes } }

  /// Whether the final pom is followed by the long break it earned.
  var endsWithLongBreak: Bool { blocks.last?.kind == .longBreak }
}

/// Which blocks get the minutes left over, and how much each may take.
///
/// **The presets differ by cap, not by order** — a distinction that had to be corrected once. They
/// were first described as differing by which bucket absorbs first, with "more rest" meaning *breaks
/// first*; but breaks-first is exactly what `balanced` already does, so two of the three named the
/// same rule. What actually separates them is **how much** a break is allowed to swell.
///
/// **`balanced`'s caps come from the technique's published ranges** — a long break of 15–30 minutes,
/// a short one of 5–10 — rather than from invention. The other two widen or narrow that window.
///
/// **They are kept in order to be tested.** Arithmetic can say a three-hour session yields 150 focus
/// minutes under one preset and 102 under another; it cannot say which one feels better. Only using
/// it can. See `docs/plans/F8.md`.
enum AbsorptionPreset: String, Codable, Sendable, CaseIterable {
  /// Long break first, then short breaks, then focus. The default, and the agreed rule.
  case balanced

  /// Focus first. Breaks stay near their settings values and the work blocks swell.
  case moreFocus

  /// Long break first with a much wider ceiling, so rest absorbs before work does.
  case moreRest

  /// The most a long break may grow to under this preset.
  var longBreakCap: Int {
    switch self {
    case .balanced: 30
    case .moreFocus: 20
    case .moreRest: 45
    }
  }

  /// The most a short break may grow to under this preset.
  var shortBreakCap: Int {
    switch self {
    case .balanced: 10
    case .moreFocus: 6
    case .moreRest: 15
    }
  }

  /// The order the three buckets absorb in.
  var order: [AbsorptionBucket] {
    switch self {
    case .balanced, .moreRest: [.longBreak, .shortBreak, .focus]
    case .moreFocus: [.focus, .longBreak, .shortBreak]
    }
  }

  /// The name a person reads.
  var displayName: String {
    switch self {
    case .balanced: "Balanced"
    case .moreFocus: "More focus"
    case .moreRest: "More rest"
    }
  }
}

/// One of the three places a leftover minute can go.
///
/// A named type rather than a tuple of booleans, so the absorption order is a *list of these* and
/// cannot be built wrong — there is no way to spell an order that omits a bucket or repeats one
/// without it being visible in the source.
enum AbsorptionBucket: Sendable {
  case longBreak
  case shortBreak
  case focus
}
