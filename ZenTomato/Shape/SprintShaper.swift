import Foundation

/// Fits a sprint to a stretch of time.
///
/// **A pure function over numbers.** No SwiftData, no clock, no engine, no UI. That is deliberate and
/// it is why this is the first task of `F8`: the arithmetic is the part that can be got right before
/// anything is drawn, and the part where being wrong is invisible until somebody misses a meeting.
///
/// ## The rule, and the two rules that were rejected
///
/// Choosing *how many poms* is the whole design, and the two obvious objectives both degenerate.
///
/// **"Maximise focus minutes"** returns **one 120-minute pom** for a two-hour budget — every break
/// deleted, the technique abandoned, and genuinely the most focus minutes available. The correct
/// answer to the question, and the wrong question.
///
/// **"Maximise the number of poms"** fails the other way: with the floors below it returns **eight
/// 10-minute poms** for the same budget. Maximum fragmentation.
///
/// **The rule that works: a shape is one sprint.** It targets `pomodorosPerSprint` poms and flexes
/// the *pom length* to fit, reducing the count only when the budget cannot hold a full sprint even
/// with every block squeezed flat. Both rejected rules are kept as tests, so neither is re-derived
/// later and mistaken for reasonable.
enum SprintShaper {
  // MARK: The floors

  /// The shortest a pom may be squeezed to, however tight the budget.
  ///
  /// **Shortening below the person's settings is allowed rather than refused** — twenty minutes
  /// should produce a real shape, not an error — but without a floor "fit as many poms as possible"
  /// degenerates into twenty one-minute poms, which is the same failure as the rejected objectives
  /// above wearing a different hat.
  static let pomFloorMinutes = 10

  /// The shortest any break may be squeezed to.
  static let breakFloorMinutes = 5

  // MARK: The suggested minimum

  /// The smallest budget that holds a full sprint at the floors.
  ///
  /// **Derived, never hardcoded.** For the default four-pom sprint this is
  /// `4×10 + 3×5 + 5 = 60` — exactly the minimum the owner stated independently, from the other
  /// direction. Computing it means the number stays true if `pomodorosPerSprint` is ever changed,
  /// instead of becoming a lie that reads like a fact.
  static func suggestedMinimumMinutes(for settings: TimerSettingsSnapshot) -> Int {
    let poms = settings.pomodorosPerSprint
    return poms * pomFloorMinutes + max(poms - 1, 0) * breakFloorMinutes + breakFloorMinutes
  }

  // MARK: Shaping

  /// Fits a sprint into `budgetMinutes`, or returns `nil` when not even one pom fits.
  ///
  /// - Returns: a shape whose `totalMinutes` equals `budgetMinutes` exactly, or `nil` when
  ///   `budgetMinutes` cannot hold a single pom at its floor. **`nil` is a real answer** and the
  ///   caller must say so out loud; silently returning an empty shape is how a screen ends up
  ///   claiming a person has no time at all.
  static func shape(
    budgetMinutes budget: Int,
    settings: TimerSettingsSnapshot,
    preset: AbsorptionPreset = .balanced,
    endsWithLongBreak: Bool = true
  ) -> SprintShape? {
    guard budget > 0 else { return nil }

    // Try a full sprint first and give up poms only when forced to. Descending, because reducing the
    // count is the last resort rather than the search.
    for poms in stride(from: settings.pomodorosPerSprint, through: 1, by: -1) {
      guard
        var draft = squeeze(
          poms: poms, into: budget, settings: settings, endsWithLongBreak: endsWithLongBreak)
      else { continue }

      draft.absorb(budget - draft.totalMinutes, preset: preset)

      return SprintShape(
        blocks: draft.blocks,
        budgetMinutes: budget,
        isUnderSuggestedMinimum: poms < settings.pomodorosPerSprint)
    }

    return nil
  }

  /// Builds the tightest draft of `poms` poms that fits in `budget`, or `nil` if none does.
  ///
  /// Squeezes only as far as it must, and the **long break goes first** because it is one block —
  /// shortening it costs the person less than shortening every short break in the sprint.
  private static func squeeze(
    poms: Int, into budget: Int, settings: TimerSettingsSnapshot, endsWithLongBreak: Bool
  ) -> Draft? {
    let shorts = max(poms - 1, 0)
    let pomFloorTotal = poms * pomFloorMinutes
    let floorTotal =
      pomFloorTotal + shorts * breakFloorMinutes + (endsWithLongBreak ? breakFloorMinutes : 0)
    guard floorTotal <= budget else { return nil }

    var short = settings.shortBreakMinutes
    var long = endsWithLongBreak ? settings.longBreakMinutes : 0

    while pomFloorTotal + shorts * short + long > budget, long > breakFloorMinutes {
      long -= 1
    }
    while pomFloorTotal + shorts * short + long > budget, short > breakFloorMinutes {
      short -= 1
    }

    // Pom length: as long as the settings allow, never longer, never below the floor.
    let room = (budget - shorts * short - long) / poms
    let work = max(min(settings.workMinutes, room), pomFloorMinutes)

    return Draft(
      poms: poms, work: work, short: short, long: long, endsWithLongBreak: endsWithLongBreak)
  }
}

// MARK: - The draft

/// A shape part-way through being built.
///
/// **A type rather than six local variables**, because the absorption step has to hand them all
/// around together — and a six-parameter function is a five-parameter function that grew one more.
private struct Draft {
  let poms: Int
  var work: Int
  var oddMinutes: Int = 0
  var short: Int
  var long: Int
  let endsWithLongBreak: Bool

  var shorts: Int { max(poms - 1, 0) }

  var totalMinutes: Int {
    poms * work + oddMinutes + shorts * short + (endsWithLongBreak ? long : 0)
  }

  /// Hands the leftover minutes out in the preset's order, filling the budget exactly.
  ///
  /// **Focus is the backstop.** Every break has a ceiling, so a large remainder can exhaust both;
  /// work has none, and the budget must come out exact. Anything the presets cannot place lands on
  /// the poms.
  mutating func absorb(_ remainder: Int, preset: AbsorptionPreset) {
    var left = remainder
    for bucket in preset.order where left > 0 {
      switch bucket {
      case .longBreak: left -= takeLongBreak(left, cap: preset.longBreakCap)
      case .shortBreak: left -= takeShortBreaks(left, cap: preset.shortBreakCap)
      case .focus:
        giveToFocus(left)
        left = 0
      }
    }
    if left > 0 { giveToFocus(left) }
  }

  private mutating func takeLongBreak(_ available: Int, cap: Int) -> Int {
    guard endsWithLongBreak else { return 0 }
    let take = min(available, max(cap - long, 0))
    long += take
    return take
  }

  private mutating func takeShortBreaks(_ available: Int, cap: Int) -> Int {
    guard shorts > 0 else { return 0 }
    let each = min(available, max(cap - short, 0) * shorts) / shorts
    short += each
    return each * shorts
  }

  /// Odd minutes go one at a time to the earliest poms, so the result is a single exact shape a test
  /// can assert rather than a range it must tolerate.
  private mutating func giveToFocus(_ amount: Int) {
    work += amount / poms
    oddMinutes += amount % poms
  }

  /// The blocks in the order they run.
  ///
  /// **The break after the final pom is the long one or nothing at all** — never a short break. A
  /// short break exists to get you to the next pom, and after the last one there is no next pom.
  var blocks: [ShapedBlock] {
    var blocks: [ShapedBlock] = []
    for index in 0..<poms {
      blocks.append(ShapedBlock(kind: .work, minutes: work + (index < oddMinutes ? 1 : 0)))
      if index < poms - 1 {
        blocks.append(ShapedBlock(kind: .shortBreak, minutes: short))
      }
    }
    if endsWithLongBreak {
      blocks.append(ShapedBlock(kind: .longBreak, minutes: long))
    }
    return blocks
  }
}
