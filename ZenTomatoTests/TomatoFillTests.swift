import Testing

@testable import ZenTomato

/// `F2f-T3` — **how full the tomato is**, and the only part of this feature a test can reach.
///
/// **WHAT IS AND IS NOT TESTED HERE, SAID PLAINLY.** The drawing is not: `TomatoGlyph` is a SwiftUI
/// `View`, this project has no UI test target, and a widget's rendering is beyond every instrument the
/// repository owns — which is precisely the failure the post-v1.5 retrospective is being kept for. What
/// *is* testable is the fraction, because `F2f-T3` deliberately put it on `BlockReadout` rather than
/// inside the view: a rule expressed only in a `View` body is a rule nothing checks.
///
/// So this suite asserts the number, `F2f-T5` reads the picture on hardware, and neither pretends to be
/// the other.
///
/// **The mirror of this arithmetic already exists and is already right.** `SprintCount` draws
/// `"\(completed) of \(total)"` from the same two fields, and `F8-T4` proved a shaped sprint of three
/// reaches the activity as three rather than four. The tomato divides what that prints.
@Suite("TomatoFill")
struct TomatoFillTests {
  /// A named case rather than a three-member tuple, which `swiftlint`'s `large_tuple` rule refuses —
  /// and is right to: `(0, 4, 0.0)` at a call site says nothing about which number is which.
  struct Case: Sendable, CustomStringConvertible {
    let completed: Int
    let total: Int
    let fill: Double

    var description: String { "\(completed) of \(total)" }
  }

  /// The fill is `completed / total`, and the fixtures are chosen so a wrong divisor shows.
  ///
  /// **Four of eight, not two of four**, for the first case: the two agree at one half, and a fixture
  /// where the right answer and a plausible wrong one coincide distinguishes nothing. Three of four and
  /// one of three are here because thirds are what a **shaped** sprint produces — `F8`'s whole point is
  /// that a sprint is not always four poms, and a tomato that filled in quarters regardless would
  /// disagree with the sprint dots drawn beside it.
  @Test(
    "theFillIsFinishedOverTotal",
    arguments: [
      Case(completed: 0, total: 4, fill: 0),
      Case(completed: 4, total: 8, fill: 0.5),
      Case(completed: 3, total: 4, fill: 0.75),
      Case(completed: 1, total: 3, fill: 1.0 / 3.0),
      Case(completed: 3, total: 3, fill: 1)
    ])
  func theFillIsFinishedOverTotal(testCase: Case) {
    let metadata = FocusAlarmMetadata(
      kind: .work, completedInSprint: testCase.completed, pomodorosPerSprint: testCase.total)

    #expect(metadata.sprintFill == testCase.fill)
  }

  /// **A sprint of no pomodoros has no fraction**, and the tomato must not invent one.
  ///
  /// `BlockReadout.metadata`'s own comment says the views draw *"a focus block with no sprint count in
  /// that case rather than inventing a number"*, and `SprintCount` is simply absent when there is no
  /// metadata. The fill follows the same rule: `nil`, not zero. **Zero would be a lie that looks like
  /// data** — an empty tomato says *no pomodoros finished yet*, which is a claim, and this is the case
  /// where the activity cannot make one.
  ///
  /// It is also the divide-by-zero, which is the reason a guard exists at all.
  @Test("aSprintOfNoPomodorosHasNoFill")
  func aSprintOfNoPomodorosHasNoFill() {
    let metadata = FocusAlarmMetadata(kind: .work, completedInSprint: 0, pomodorosPerSprint: 0)

    #expect(metadata.sprintFill == nil)
  }

  /// **More finished than the sprint holds clamps to full rather than drawing past the rim.**
  ///
  /// It should be unreachable — the cycle resets the tally when a sprint ends — but the tomato is drawn
  /// from a number that crossed a process boundary, and `StoredShape`'s own header makes the same
  /// argument about the same class of value: what arrives from elsewhere is checked rather than trusted.
  @Test("moreFinishedThanTheSprintHoldsClampsToFull")
  func moreFinishedThanTheSprintHoldsClampsToFull() {
    let metadata = FocusAlarmMetadata(kind: .work, completedInSprint: 9, pomodorosPerSprint: 4)

    #expect(metadata.sprintFill == 1)
  }
}
