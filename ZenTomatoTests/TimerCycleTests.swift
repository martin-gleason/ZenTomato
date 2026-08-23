import Foundation
import Testing

@testable import ZenTomato

/// Tests for the rule that decides what follows what.
///
/// No clock, no database, no alarm — the whole point of keeping the cycle as a
/// plain function is that its rules can be proved by walking them.
@Suite("TimerCycle")
struct TimerCycleTests {
  /// The spec's defaults: four focus blocks to a sprint.
  private let defaults = TimerSettingsSnapshot(
    workMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    pomodorosPerSprint: 4,
    soundEnabled: true,
    autoStartNextBlock: false)

  /// A sprint of one, the off-by-one edge: every focus block earns the long
  /// break directly and a short break never happens.
  private let sprintOfOne = TimerSettingsSnapshot(
    workMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    pomodorosPerSprint: 1,
    soundEnabled: true,
    autoStartNextBlock: false)

  /// Walks a whole sprint, completing every block, and records what was run.
  private func walk(_ settings: TimerSettingsSnapshot, steps: Int)
    -> (blocks: [BlockKind], last: TimerCycle.Transition) {
    var kind = BlockKind.work
    var completed = 0
    var blocks: [BlockKind] = [kind]
    var last = TimerCycle.Transition(kind: kind, completedInSprint: completed, endsSprint: false)
    for _ in 0..<steps {
      last = TimerCycle.next(after: kind, completedInSprint: completed, completed: true, settings: settings)
      kind = last.kind
      completed = last.completedInSprint
      blocks.append(kind)
    }
    return (blocks, last)
  }

  /// The sprint the spec describes, in order. The fourth focus block is
  /// followed by the LONG break, not a short one — the long break ends the
  /// sprint rather than interrupting it.
  @Test("cycleWithDefaults")
  func cycleWithDefaults() {
    let run = walk(defaults, steps: 7)

    #expect(run.blocks == [.work, .shortBreak, .work, .shortBreak, .work, .shortBreak, .work, .longBreak])
    #expect(run.last.completedInSprint == 4)
    // The long break has been reached but not yet taken, so the sprint is not
    // over — that happens when the long break itself ends.
    #expect(run.last.endsSprint == false)
  }

  /// With a sprint of one, every *completed* focus block goes straight to the
  /// long break. This looks wrong at a glance and is correct: the tally reaches
  /// the sprint size on the very first block.
  @Test("cycleWithSprintOfOne")
  func cycleWithSprintOfOne() {
    let run = walk(sprintOfOne, steps: 6)

    #expect(run.blocks == [.work, .longBreak, .work, .longBreak, .work, .longBreak, .work])
    #expect(run.blocks.contains(.shortBreak) == false)
  }

  /// The other half of a sprint of one, which the walk above cannot see because
  /// it finishes every block.
  ///
  /// A sprint of one is the configuration the project itself nominates for
  /// hand-testing the cycle, so it is the one a person is most likely to be
  /// sitting in front of when they press Skip — and the answer they get is a
  /// short break, in a sprint that "never has short breaks". That is deliberate
  /// and it follows from the rule that matters more: a skipped block earns
  /// nothing, and the long break is earned. Stated as a test so the sentence in
  /// the documentation and the behaviour cannot drift apart again.
  @Test("skippedWorkInASprintOfOneStillTakesAShortBreak")
  func skippedWorkInASprintOfOneStillTakesAShortBreak() {
    let skipped = TimerCycle.next(after: .work, completedInSprint: 0, completed: false, settings: sprintOfOne)

    #expect(skipped.kind == .shortBreak)
    #expect(skipped.completedInSprint == 0)
    #expect(skipped.endsSprint == false)

    // Finishing the same block instead earns the long break immediately.
    let completed = TimerCycle.next(after: .work, completedInSprint: 0, completed: true, settings: sprintOfOne)
    #expect(completed.kind == .longBreak)
    #expect(completed.completedInSprint == 1)
  }

  /// The end of a long break returns the tally to zero and says so, which is
  /// what tells the engine to stop rather than start a fifth block.
  @Test("longBreakResetsCount")
  func longBreakResetsCount() {
    let ended = TimerCycle.next(after: .longBreak, completedInSprint: 4, completed: true, settings: defaults)

    #expect(ended.kind == .work)
    #expect(ended.completedInSprint == 0)
    #expect(ended.endsSprint)

    // A long break that was skipped still ends the sprint. Skipping the rest is
    // not the same as earning a fifth pomodoro.
    let skipped = TimerCycle.next(after: .longBreak, completedInSprint: 4, completed: false, settings: defaults)
    #expect(skipped.completedInSprint == 0)
    #expect(skipped.endsSprint)
  }

  /// A skipped focus block advances the cycle but earns nothing, so skipping
  /// the fourth block of four leads to a short break and then a fourth focus
  /// block again — never to the long break.
  @Test("skippedWorkDoesNotEarnTheLongBreak")
  func skippedWorkDoesNotEarnTheLongBreak() {
    let skipped = TimerCycle.next(after: .work, completedInSprint: 3, completed: false, settings: defaults)

    #expect(skipped.kind == .shortBreak)
    #expect(skipped.completedInSprint == 3)

    let completed = TimerCycle.next(after: .work, completedInSprint: 3, completed: true, settings: defaults)
    #expect(completed.kind == .longBreak)
    #expect(completed.completedInSprint == 4)
  }

  /// Breaks are not pomodoros: neither taking one nor skipping one moves the
  /// tally.
  @Test("breaksDoNotChangeTheTally")
  func breaksDoNotChangeTheTally() {
    for completed in [true, false] {
      let after = TimerCycle.next(after: .shortBreak, completedInSprint: 2, completed: completed, settings: defaults)
      #expect(after.kind == .work)
      #expect(after.completedInSprint == 2)
      #expect(after.endsSprint == false)
    }
  }
}
