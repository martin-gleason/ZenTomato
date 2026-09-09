import Foundation
import Testing

@testable import ZenTomato

/// `F8-T1` — the shape calculator, against the worked table in `docs/plans/F8.md`.
///
/// **Every budget in that table is a row here.** The table was not illustration; it was the
/// specification, computed and argued at the gate before any code existed.
@Suite("SprintShape")
struct SprintShapeTests {
  /// Today's shipped defaults: 25 / 5 / 15, four poms to a sprint.
  static let settings = TimerSettingsSnapshot(
    workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15,
    pomodorosPerSprint: 4, soundEnabled: true, alertSound: .systemDefault, autoStartNextBlock: false)

  private static func shape(
    _ budget: Int, _ preset: AbsorptionPreset = .balanced, longBreak: Bool = true
  ) -> SprintShape? {
    SprintShaper.shape(
      budgetMinutes: budget, settings: settings, preset: preset, endsWithLongBreak: longBreak)
  }

  // MARK: The owner's own example

  /// Two hours, the case the whole feature was raised for.
  @Test("theOwnersTwoHourExample")
  func theOwnersTwoHourExample() throws {
    let shape = try #require(Self.shape(120))
    #expect(shape.pomCount == 4)
    #expect(shape.focusMinutes == 88)
    #expect(shape.totalMinutes == 120)
    #expect(shape.isUnderSuggestedMinimum == false)
    #expect(shape.blocks.filter { $0.kind == .work }.allSatisfy { $0.minutes == 22 })
    #expect(shape.blocks.filter { $0.kind == .shortBreak }.allSatisfy { $0.minutes == 5 })
    #expect(shape.blocks.last == ShapedBlock(kind: .longBreak, minutes: 17))
  }

  // MARK: The minimum, and below it

  /// Sixty minutes is the smallest budget holding a full sprint at the floors, and the owner stated
  /// that number independently. Both derivations must agree.
  @Test("sixtyMinutesIsTheMinimumAndItIsDerived")
  func sixtyMinutesIsTheMinimumAndItIsDerived() throws {
    #expect(SprintShaper.suggestedMinimumMinutes(for: Self.settings) == 60)

    let shape = try #require(Self.shape(60))
    #expect(shape.pomCount == 4)
    #expect(shape.isUnderSuggestedMinimum == false)
    #expect(shape.totalMinutes == 60)
    #expect(shape.blocks.filter { $0.kind == .work }.allSatisfy { $0.minutes == 10 })
    #expect(shape.blocks.last == ShapedBlock(kind: .longBreak, minutes: 5))
  }

  /// Under the minimum the shape still exists and still runs — it simply says so.
  @Test("underTheMinimumStillProducesAShape")
  func underTheMinimumStillProducesAShape() throws {
    for (budget, poms) in [(45, 3), (30, 2), (20, 1)] {
      let shape = try #require(Self.shape(budget), "\(budget) should still produce a shape")
      #expect(shape.pomCount == poms)
      #expect(shape.isUnderSuggestedMinimum, "\(budget) is under the minimum and must say so")
      #expect(shape.totalMinutes == budget)
    }
  }

  /// The owner's twenty-minute case: one pom, squeezed to its floor, and the long break it earns.
  @Test("twentyMinutes")
  func twentyMinutes() throws {
    let shape = try #require(Self.shape(20))
    #expect(shape.blocks == [
      ShapedBlock(kind: .work, minutes: 10),
      ShapedBlock(kind: .longBreak, minutes: 10)
    ])
  }

  /// **`nil` is a real answer.** Fourteen minutes cannot hold a pom at its floor plus any break, and
  /// the calculator must say so rather than return something empty that a screen would render as a
  /// shape with nothing in it.
  @Test("aBudgetTooShortForOnePomReturnsNothing")
  func aBudgetTooShortForOnePomReturnsNothing() {
    #expect(Self.shape(14) == nil)
    #expect(Self.shape(0) == nil)
    #expect(Self.shape(-30) == nil)
  }

  // MARK: The promises

  /// *"I will fill your two hours"* and *"I will not overrun your two hours"*, both kept, for every
  /// budget that produces a shape at all.
  @Test("everyShapeFillsItsBudgetExactly")
  func everyShapeFillsItsBudgetExactly() {
    for budget in 15...300 {
      guard let shape = Self.shape(budget) else { continue }
      #expect(shape.totalMinutes == budget, "budget \(budget) did not come out exact")
    }
  }

  /// The floors hold whatever the budget does.
  @Test("noBlockIsEverBelowItsFloor")
  func noBlockIsEverBelowItsFloor() {
    for budget in 15...300 {
      for preset in AbsorptionPreset.allCases {
        guard let shape = Self.shape(budget, preset) else { continue }
        for block in shape.blocks {
          let floor =
            block.kind == .work ? SprintShaper.pomFloorMinutes : SprintShaper.breakFloorMinutes
          #expect(block.minutes >= floor, "\(block.kind) of \(block.minutes)m at budget \(budget)")
        }
      }
    }
  }

  /// A short break exists to get you to the next pom. After the last one there is no next pom.
  @Test("noShortBreakEverTrailsTheFinalPom")
  func noShortBreakEverTrailsTheFinalPom() {
    for budget in 15...300 {
      guard let shape = Self.shape(budget) else { continue }
      #expect(shape.blocks.last?.kind != .shortBreak, "budget \(budget) ended on a short break")
    }
  }

  // MARK: The rejected objective functions

  /// **"Maximise focus minutes" would return one 120-minute pom.** Kept as a test so the rule is not
  /// re-derived later by someone who finds it reasonable — it is the most focus minutes available,
  /// and it deletes every break and abandons the technique.
  @Test("maximiseFocusIsNotTheRule")
  func maximiseFocusIsNotTheRule() throws {
    let shape = try #require(Self.shape(120))
    #expect(shape.pomCount > 1, "one giant pom is the rejected 'maximise focus' answer")
    #expect(shape.blocks.contains { $0.kind != .work }, "a shape with no breaks is not a sprint")
  }

  /// **"Maximise the number of poms" would return eight 10-minute poms** for the same budget. The
  /// opposite failure, and equally far from the technique.
  @Test("maximisePomsIsNotTheRule")
  func maximisePomsIsNotTheRule() throws {
    let shape = try #require(Self.shape(120))
    #expect(shape.pomCount <= Self.settings.pomodorosPerSprint, "a shape is one sprint, not more")
    #expect(shape.pomCount == 4)
  }

  // MARK: The trailing long break

  /// What the trailing long break costs, asserted rather than remembered: fourteen minutes of focus
  /// at two hours. `docs/plans/F8.md` records this as the argument a future delta must answer.
  @Test("droppingTheTrailingLongBreakBuysFocus")
  func droppingTheTrailingLongBreakBuysFocus() throws {
    let with = try #require(Self.shape(120, longBreak: true))
    let without = try #require(Self.shape(120, longBreak: false))

    #expect(with.focusMinutes == 88)
    #expect(without.focusMinutes == 102)
    #expect(without.endsWithLongBreak == false)
    #expect(without.totalMinutes == 120)
    #expect(without.blocks.last?.kind == .work, "with no long break, a shape ends on work")
  }

  // MARK: The presets

  /// The presets diverge only when there is a remainder large enough for the caps to bind.
  @Test("presetsDivergeAtThreeHours")
  func presetsDivergeAtThreeHours() throws {
    #expect(try #require(Self.shape(180, .balanced)).focusMinutes == 120)
    #expect(try #require(Self.shape(180, .moreFocus)).focusMinutes == 150)
    #expect(try #require(Self.shape(180, .moreRest)).focusMinutes == 102)
  }

  /// **The trap this suite exists to avoid.** At sixty minutes every preset returns an identical
  /// shape, because the shape sits at its floors and there is no remainder to distribute. An
  /// assertion about presets placed here would pass no matter what the code did.
  ///
  /// It is asserted deliberately, so the fact is recorded rather than discovered by someone writing
  /// a preset test at the wrong budget.
  @Test("presetsAreIdenticalAtTheMinimumAndProveNothingThere")
  func presetsAreIdenticalAtTheMinimumAndProveNothingThere() throws {
    let balanced = try #require(Self.shape(60, .balanced))
    #expect(try #require(Self.shape(60, .moreFocus)).blocks == balanced.blocks)
    #expect(try #require(Self.shape(60, .moreRest)).blocks == balanced.blocks)
  }

  // MARK: Odd minutes

  /// Minutes that will not divide evenly go one each to the earliest poms, so a test can assert one
  /// exact shape rather than tolerate a range.
  @Test("oddMinutesGoToTheEarliestPoms")
  func oddMinutesGoToTheEarliestPoms() throws {
    let shape = try #require(Self.shape(120, longBreak: false))
    let poms = shape.blocks.filter { $0.kind == .work }.map(\.minutes)
    #expect(poms == [26, 26, 25, 25])
  }
}
