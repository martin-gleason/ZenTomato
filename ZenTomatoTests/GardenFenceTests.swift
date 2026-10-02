import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// **The garden only ever accumulates** — `D48`, built in `F16-T2`.
///
/// The v1.5 spec's hook intention: *a test that fails if any user-facing surface counts consecutive
/// days or renders an unbroken chain.* It has three parts on purpose, because any one of them alone is
/// defeated by a five-minute edit (`docs/plans/F16.md`, *The hook this feature owes*):
///
/// 1. **The vocabulary** catches the honest version — somebody who writes `streak`.
/// 2. **The shape** catches the renamed version — the garden is handed one whole number and can see
///    no day, date or calendar, so it cannot count consecutive days whatever the variable is called.
/// 3. **The behaviour** is the actual promise — driven through the real store and the real counting
///    path, not by calling the calculator twice with the same literal.
///
/// Comments are stripped before anything is searched, with `StatsFenceTests`' own stripper: the
/// garden's doc comments state the ruling in the forbidden words and must not fail because of it.
///
/// `@MainActor`: the behaviour tests touch SwiftData.
@Suite("GardenFence")
@MainActor
struct GardenFenceTests {
  // MARK: Part one — the vocabulary

  /// No garden file counts days in a row, under any of the names that thing usually arrives as.
  ///
  /// The second list is `StatsFenceTests.noGamificationAnywhereInThisFeature`'s, carried over: the
  /// garden is the one licensed exception to that rule, and the licence does not extend to its words.
  @Test("noSurfaceCountsConsecutiveDays")
  func noSurfaceCountsConsecutiveDays() throws {
    let forbidden = [
      "streak", "consecutive", "inARow", "chain", "unbroken", "sinceLast", "currentRun", "dailyGoal",
      "daysActive", "perfectWeek",
      "badge", "trophy", "medal", "award", "milestone", "achievement", "xp", "best", "longest",
      "average", "trend", "comparison", "improvement", "goal", "target", "quota", "scoreboard",
      "leaderboard"
    ]
    for file in try Self.gardenFiles() {
      let words = try Self.words(in: Self.code(of: file))
      for phrase in forbidden {
        let wanted = Self.words(in: phrase)
        let found = words.indices.contains { start in
          words[start...].starts(with: wanted)
        }
        #expect(!found, "\(file.lastPathComponent) uses the word “\(phrase)”.")
      }
    }
  }

  // MARK: Part two — the shape

  /// **A thing that cannot see days cannot count consecutive ones.** No calendar, no date, no day
  /// row, and no database anywhere in the garden's files.
  @Test("theGardenSeesNoDays")
  func theGardenSeesNoDays() throws {
    let forbidden = [
      "\\bCalendar\\b", "\\bDate\\b", "\\bStatsDay\\b", "\\bStatsDayRow\\b", "\\.days\\b",
      "\\bStatsPeriod\\b", "\\bTimeInterval\\b", "import SwiftData"
    ]
    for file in try Self.gardenFiles() {
      let code = try Self.code(of: file)
      for pattern in forbidden {
        #expect(
          try Self.matches(pattern, in: code) == 0,
          "\(file.lastPathComponent) can see time: “\(pattern)”.")
      }
    }
  }

  /// **The garden is handed one number, and keeps none.** No stored type, no settings row, no saved
  /// value anywhere in its files; and the calculator has exactly one way in, which takes a whole number.
  @Test("theGardenReadsOnlyTheCountingPath")
  func theGardenReadsOnlyTheCountingPath() throws {
    let forbidden = [
      "@Model", "\\bAppSettings\\b", "\\bModelContext\\b", "\\bFetchDescriptor\\b", "@AppStorage",
      "\\bUserDefaults\\b", "@Query\\b"
    ]
    for file in try Self.gardenFiles() {
      let code = try Self.code(of: file)
      for pattern in forbidden {
        #expect(
          try Self.matches(pattern, in: code) == 0,
          "\(file.lastPathComponent) reaches for stored state: “\(pattern)”.")
      }
    }

    let garden = try Self.code(of: Self.repositoryRoot.appending(path: "ZenTomato/Garden/Garden.swift"))
    #expect(try Self.matches("\\binit\\s*\\(", in: garden) == 1, "The garden has more than one way in.")
    #expect(
      try Self.matches("\\binit\\(finishedPoms: Int\\)", in: garden) == 1,
      "The garden's one way in is not a single whole number.")
  }

  // MARK: Part three — the behaviour

  /// **Forty poms in two days and forty poms over eight months are the same garden.**
  ///
  /// Both stores go through the real path — rows written to SwiftData, counted by `StatsQuery`, handed
  /// to the garden — so any adjacency rule anywhere on that path makes the two differ, whatever it is
  /// called. The count is asserted too, so two empty gardens cannot pass this by agreeing on nothing.
  @Test("theGardenIsAFunctionOfCountAlone")
  func theGardenIsAFunctionOfCountAlone() throws {
    let crammed = try Self.gardenFromStore { index in
      // Twenty a day, half an hour apart, on two days.
      StatsStoreFixture.at(2026, 3, 2 + index / 20, 6, 0).addingTimeInterval(Double(index % 20) * 1_800)
    }
    let scattered = try Self.gardenFromStore { index in
      // One every six days or so, with a three-week gap after every eighth — about ten months.
      let gaps = index / 8
      return StatsStoreFixture.at(2025, 9, 1, 9, 0).addingTimeInterval(Double(index * 6 + gaps * 21) * 86_400)
    }

    #expect(crammed.count == Self.poms)
    #expect(scattered.count == Self.poms)
    #expect(crammed.garden == scattered.garden)
    #expect(crammed.garden == Garden(finishedPoms: Self.poms))
  }

  /// **No finished pom ever makes the garden smaller**, on any number it exposes.
  ///
  /// The weakest of the three parts, said plainly in the plan: a shrink written anywhere *other* than
  /// in the calculator passes this. `theGardenSeesNoDays` is what stops the realistic one, which needs
  /// a date.
  @Test("theGardenNeverShrinks")
  func theGardenNeverShrinks() {
    var previous = Garden(finishedPoms: 0)
    for poms in 1...5_000 {
      let next = Garden(finishedPoms: poms)
      #expect(next.rows.count == previous.rows.count, "The garden lost a row at \(poms).")
      for (row, (before, after)) in zip(previous.rows, next.rows).enumerated() where after < before {
        Issue.record("Row \(row) went from \(before) to \(after) at \(poms) poms.")
      }
      #expect(next.itemCount >= previous.itemCount, "The garden drew less at \(poms) poms.")
      previous = next
    }
  }

  // MARK: The door and the voice

  /// **The door is beside the history, and it is shut while a focus block counts** (`Q1`; `F16`'s
  /// scope fence: no reward in the eyeline during work). Read from the timer screen's source, the way
  /// `StatsFenceTests.theWayIntoTheHistoryIsAlwaysThere` reads the history door.
  @Test("theGardenDoorIsBesideTheHistoryAndShutDuringFocus")
  func theGardenDoorIsBesideTheHistoryAndShutDuringFocus() throws {
    let screen = try Self.code(of: Self.repositoryRoot.appending(path: "ZenTomato/Views/TimerScreen.swift"))
    #expect(screen.contains(".overlay(alignment: .topLeading) { gardenButton }"))
    #expect(try Self.matches("if [^\n]*gardenButton", in: screen) == 0, "The door is drawn conditionally.")
    let declaration = try #require(screen.range(of: "private var gardenButton"))
    let rest = screen[declaration.upperBound...]
    let end = rest.range(of: "\n  }\n", options: .regularExpression)?.lowerBound ?? rest.endIndex
    #expect(rest[..<end].contains(".disabled(model.capture != nil)"), "The door opens during a focus block.")
  }

  /// **VoiceOver hears the real count**, not the number of tomatoes drawn — at a year of work they
  /// differ by nearly a thousand.
  ///
  /// **Two halves, and why the second reads source.** The words come from `GardenView.spoken`, checked
  /// directly. *Which number* reaches it is decided where the screen calls it, and the first version of
  /// this test only checked the words — `F16-M9` handed VoiceOver the tomato count and it stayed green.
  /// Reading the rendered accessibility tree would be better and is not possible here: SwiftUI builds
  /// that tree only when an assistive technology asks, and this project has no UI test target (`A31`).
  /// So the call site is read as text, the way the door is.
  @Test("theGardenSaysTheCountNotTheTomatoes")
  func theGardenSaysTheCountNotTheTomatoes() throws {
    #expect(GardenView.spoken(1) == "1 finished pomodoro")
    #expect(GardenView.spoken(1_044) == "1044 finished pomodoros")
    #expect(Garden(finishedPoms: 1_044).itemCount != 1_044, "The fixture cannot tell count from tomatoes.")

    let view = try Self.code(of: Self.repositoryRoot.appending(path: "ZenTomato/Views/GardenView.swift"))
    #expect(try Self.matches("\\.accessibilityValue\\(", in: view) == 1)
    #expect(view.contains(".accessibilityValue(Text(Self.spoken(finishedPoms)))"), "VoiceOver is not given the count.")
  }

  // MARK: The stated shape

  /// The shapes the plan's checkpoint asks for, stated rather than described: 0, 1, 40 and a year.
  @Test("theGardenHasAStatedShape", arguments: [
    (0, [0, 0, 0, 0, 0]),
    (1, [1, 0, 0, 0, 0]),
    (40, [24, 4, 0, 0, 0]),
    (1_044, [24, 24, 24, 8, 0])
  ])
  func theGardenHasAStatedShape(poms: Int, rows: [Int]) {
    #expect(Garden(finishedPoms: poms).rows == rows)
  }

  /// Nothing is lost past the last full row: the poms a garden accounts for never exceed the count,
  /// and fall short of it only by less than one item of the smallest row still filling.
  @Test("everyPomIsAccountedFor")
  func everyPomIsAccountedFor() throws {
    let largest = try #require(Garden.pomsPerItem.last)
    for poms in [0, 1, 23, 24, 25, 119, 120, 121, 1_044, 8_183, 8_184, 50_000] {
      let garden = Garden(finishedPoms: poms)
      let accounted = zip(garden.rows, Garden.pomsPerItem).reduce(0) { $0 + $1.0 * $1.1 }
      #expect(accounted <= poms)
      #expect(poms - accounted < largest, "\(poms) poms: \(poms - accounted) unaccounted.")
    }
  }

  // MARK: Private

  /// Forty: enough to fill the first row and start the second, so a rule that only looked at the
  /// first row would still be seen.
  private static let poms = 40

  /// The repository, found from this file's own compiled path.
  private static let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()    // ZenTomatoTests
    .deletingLastPathComponent()    // repository root

  /// Every file under `ZenTomato/Garden/`, and the garden's screen once `F16-T3` builds it.
  private static func gardenFiles() throws -> [URL] {
    let directory = repositoryRoot.appending(path: "ZenTomato/Garden")
    let found = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)?
      .compactMap { $0 as? URL }
      .filter { $0.pathExtension == "swift" }
      .sorted { $0.path < $1.path }
    let files = try #require(found, "No ZenTomato/Garden directory. The fence is searching the wrong tree.")
    #expect(files.isEmpty == false, "No Swift files under ZenTomato/Garden.")

    let screen = repositoryRoot.appending(path: "ZenTomato/Views/GardenView.swift")
    return FileManager.default.fileExists(atPath: screen.path) ? files + [screen] : files
  }

  /// Every word in some code, lowercased, **with identifiers split where their words join.**
  ///
  /// `consecutiveDays` is two words, and a whole-word search for `consecutive` cannot see it — the
  /// first draft of this fence searched that way, and `F16-M1` walked straight past it (recorded in
  /// `docs/plans/F16.md`). Splitting at each lower-to-upper change and at underscores and digits makes
  /// the camel-cased name and the prose word the same thing to the fence.
  private static func words(in text: String) -> [String] {
    var words: [String] = []
    var current = ""
    var previous: Character?
    for character in text {
      if character.isLetter {
        if character.isUppercase, let last = previous, last.isLowercase, !current.isEmpty {
          words.append(current)
          current = ""
        }
        current.append(Character(character.lowercased()))
      } else if !current.isEmpty {
        words.append(current)
        current = ""
      }
      previous = character
    }
    if !current.isEmpty { words.append(current) }
    return words
  }

  private static func code(of file: URL) throws -> String {
    StatsFenceTests.stripComments(from: try String(contentsOf: file, encoding: .utf8))
  }

  private static func matches(_ pattern: String, in text: String) throws -> Int {
    let expression = try NSRegularExpression(pattern: pattern)
    return expression.numberOfMatches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
  }

  /// Writes `poms` finished blocks at the given instants, then counts them the way the garden will.
  private static func gardenFromStore(at start: (Int) -> Date) throws -> (count: Int, garden: Garden) {
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext
    for index in 0..<poms {
      context.insert(StatsStoreFixture.work(200_000 + index, from: start(index)))
    }
    try context.save()
    let count = StatsQuery(context: context, calendar: StatsStoreFixture.calendar).lifetimePomodoroCount()
    return (count, Garden(finishedPoms: count))
  }
}
