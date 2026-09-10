import Foundation

/// The two budgets a screen has to be able to quote, asked of the calculator rather than restated.
///
/// **WHY THIS IS NOT A PAIR OF FORMULAS.** `SprintShaper.suggestedMinimumMinutes(for:)` computes
/// `poms × 10 + (poms − 1) × 5 + 5` — and that trailing `+ 5` is a long break, unconditionally. It
/// is the right number for the shape the app makes by default and it is **wrong whenever the
/// trailing long break is switched off**: with the toggle off a four-pomodoro sprint fits in
/// fifty-five minutes, while the function still reports sixty. A screen that quoted sixty beside a
/// shape holding four pomodoros would be contradicted by the numbers directly above it.
///
/// The same trap sits under "nothing fits". The shortest budget that produces any shape at all is
/// fifteen minutes with the toggle on (a pomodoro at its floor plus a long break at its floor) and
/// **ten** with it off. A hardcoded fifteen tells somebody with twelve minutes and the toggle off
/// that nothing fits, when the calculator would have shaped it.
///
/// **So both numbers are found by asking `SprintShaper` rather than by re-deriving its arithmetic.**
/// An assertion — or a sentence — that recomputes its expected value cannot see the path that
/// produces the real one, which is this project's own named failure. These search upward from one
/// minute and return the first budget the shaper actually answers, so the screen and the shape can
/// never disagree.
///
/// The search is bounded by construction: `upperBound` is a full sprint at the person's own settings
/// with nothing squeezed, which the shaper can always fit. That is a few hundred iterations of pure
/// integer arithmetic, run when a control moves and never in a loop.
enum ShapeBudgets {
  /// The smallest budget these controls can make **any** shape out of, or `nil` if none can.
  ///
  /// The number the "nothing fits" sentence quotes.
  static func smallestBudgetMinutes(settings: TimerSettingsSnapshot, endsWithLongBreak: Bool) -> Int? {
    firstBudget(settings: settings, endsWithLongBreak: endsWithLongBreak) { _ in true }
  }

  /// The smallest budget that holds a **full** sprint — `pomodorosPerSprint` pomodoros — under these
  /// controls, or `nil` if none does.
  ///
  /// The number the under-the-suggested-minimum sentence quotes.
  static func fullSprintBudgetMinutes(settings: TimerSettingsSnapshot, endsWithLongBreak: Bool) -> Int? {
    firstBudget(settings: settings, endsWithLongBreak: endsWithLongBreak) {
      $0.isUnderSuggestedMinimum == false
    }
  }

  // MARK: Private

  /// The first budget, counting up from one, whose shape satisfies `condition`.
  ///
  /// The preset is not a parameter and that is deliberate: absorption decides *where* leftover
  /// minutes land, never whether a shape exists or how many pomodoros it holds. A preset parameter
  /// here would be a knob that changes no answer, which is the kind of thing a later reader trusts.
  private static func firstBudget(
    settings: TimerSettingsSnapshot,
    endsWithLongBreak: Bool,
    where condition: (SprintShape) -> Bool
  ) -> Int? {
    let poms = settings.pomodorosPerSprint
    let upperBound =
      poms * settings.workMinutes
      + max(poms - 1, 0) * settings.shortBreakMinutes
      + (endsWithLongBreak ? settings.longBreakMinutes : 0)

    for budget in 1...max(upperBound, 1) {
      guard
        let shape = SprintShaper.shape(
          budgetMinutes: budget, settings: settings, endsWithLongBreak: endsWithLongBreak),
        condition(shape)
      else { continue }
      return budget
    }
    return nil
  }
}
