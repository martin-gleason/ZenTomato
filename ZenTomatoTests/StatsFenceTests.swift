import Foundation
import Testing

@testable import ZenTomato

/// The fence around F6, executed rather than promised.
///
/// WHY THIS FILE EXISTS
/// A stats screen is where scope pressure appears first, and `F6.md` calls it
/// *"the worst of the project"*. None of it arrives as a bad decision. It
/// arrives as a trend line on one afternoon, a best day on another, a progress
/// ring because the sprint dots already look like one, a streak because the days
/// table is right there. Each is one small commit that looks like statistics.
/// `SPEC.md` puts gamification out of scope by name, and prose did not hold that
/// line in F3 or F5.
///
/// So the rules that can be mechanical are mechanical: this file reads the
/// source tree and fails the build when a word or a call appears where it may
/// not. **A fence nobody runs is a fence that does not exist.**
///
/// HOW IT READS THE TREE
/// Through `#filePath` — this file's own path as compiled — so the repository is
/// one directory up. `LaunchBackgroundTests` already does this and passes in CI,
/// so no build setting and no bundled resource is involved.
///
/// **COMMENTS ARE STRIPPED BEFORE ANYTHING IS SEARCHED, AND THAT IS THE ONE
/// SUBTLE DECISION IN THIS FILE.** The doc comment on `StatsScreen` lists what
/// must never be added — *"no streak, no badge, no best day, no progress ring"*
/// — and a blunt search would fail on the very sentence that states the rule.
/// A fence that cannot tell a refusal from a violation is a fence somebody
/// switches off within a month. So the search is over *code*: what the app does,
/// not what it says about itself.
@Suite("StatsFence")
struct StatsFenceTests {
  // MARK: Gamification

  /// Zero hits, case-insensitively, across every file this feature adds or
  /// edits.
  ///
  /// `best` and `average` are on the list on purpose: *your best day* and *your
  /// daily average* arrive looking like statistics rather than like
  /// gamification, and are the two most likely to be added by somebody who has
  /// read the out-of-scope list and does not think it applies to them.
  ///
  /// Whole words only: `String` ends in *ring* and `export` contains *xp*.
  @Test("noGamificationAnywhereInThisFeature")
  func noGamificationAnywhereInThisFeature() throws {
    let forbidden = [
      "streak", "badge", "trophy", "medal", "award", "milestone", "achievement", "xp",
      "best", "longest", "average", "trend", "comparison", "improvement", "goal", "target",
      "quota", "ring", "scoreboard", "leaderboard"
    ]

    for file in try Self.featureFiles {
      let code = try Self.code(of: file)
      for word in forbidden {
        #expect(
          try Self.matches("\\b\(word)\\b", in: code, caseInsensitive: true) == 0,
          "\(file.lastPathComponent) uses the word “\(word)”.")
      }
    }
  }

  /// Nothing in this feature draws a chart, a gauge, a ring or a progress arc.
  ///
  /// **A progress ring is a scope violation however it is drawn** — through
  /// `Gauge`, through `ProgressView`, or by trimming a circle by hand — so all
  /// three are named. `SprintProgressView`, which F2 built and this feature does
  /// not touch, is not caught: the pattern needs a word boundary before it.
  @Test("nothingDrawsAChartOrARing")
  func nothingDrawsAChartOrARing() throws {
    let forbidden = [
      "import Charts", "\\bChart\\(", "BarMark", "LineMark", "AreaMark", "SectorMark",
      "RuleMark", "PointMark", "\\bGauge\\(", "\\bProgressView\\(", "\\.progressViewStyle",
      "\\bCanvas\\(", "\\.trim\\(from:"
    ]

    for file in try Self.featureFiles {
      let code = try Self.code(of: file)
      for pattern in forbidden {
        #expect(
          try Self.matches(pattern, in: code) == 0,
          "\(file.lastPathComponent) draws \(pattern).")
      }
    }
  }

  // MARK: One counting path

  /// **Exactly one file in this feature opens the database, and it is
  /// `StatsQuery`.**
  ///
  /// That is the mechanism behind "there is only one counting rule". A screen
  /// that wanted to count something itself would have to import SwiftData, and
  /// this is what would stop it. The export and the sprint set never touch a
  /// store at all.
  @Test("oneFileInTheFeatureOpensTheDatabase")
  func oneFileInTheFeatureOpensTheDatabase() throws {
    let counting = try Self.swiftFiles(under: "ZenTomato/Stats")
      .filter { try Self.code(of: $0).contains("import SwiftData") }

    #expect(counting.map(\.lastPathComponent) == ["StatsQuery.swift"])

    for directory in ["ZenTomato/Export", "ZenTomato/Sprint"] {
      for file in try Self.swiftFiles(under: directory) {
        #expect(
          try Self.code(of: file).contains("import SwiftData") == false,
          "\(file.lastPathComponent) opens the database.")
      }
    }
  }

  /// Neither the exported page nor the screen ever sees a stored row.
  ///
  /// They are handed finished values. If a fetch or a model type appeared here,
  /// a second total could be built from it — and two totals that can disagree is
  /// how the one number this app exists to produce stops being trusted.
  @Test("neitherThePageNorTheScreenSeesAStoredRow")
  func neitherThePageNorTheScreenSeesAStoredRow() throws {
    let readers = try Self.swiftFiles(under: "ZenTomato/Export") + Self.statsViewFiles()

    for file in readers {
      let code = try Self.code(of: file)
      for pattern in ["FetchDescriptor", "#Predicate", "PomodoroSession", "CompletedTaskRecord", "Distraction\\b"] {
        #expect(
          try Self.matches(pattern, in: code) == 0,
          "\(file.lastPathComponent) reaches for \(pattern).")
      }
    }
  }

  /// **A day is the local calendar day of the block's START.**
  ///
  /// Two halves. `wasAbandoned` — the rule that a stopped block counts for
  /// nothing — appears in exactly four files tree-wide, listed exhaustively so a
  /// fifth reader must be argued for rather than appear. And `.endedAt`
  /// never appears in the same expression as `StatsDay`, because deciding a day
  /// from a block's *end* is the one silent way to get the counting rule wrong:
  /// it moves every midnight block onto the wrong day and nothing looks broken.
  @Test("theDayRuleIsTheBlocksStart")
  func theDayRuleIsTheBlocksStart() throws {
    let holders = try Self.swiftFiles(under: "ZenTomato")
      .filter { try Self.code(of: $0).contains("wasAbandoned") }
      .map(\.lastPathComponent)
      .sorted()

    #expect(holders == ["PeriodAssembly.swift", "PomodoroSession.swift", "StatsQuery.swift", "TimerEngine.swift"])

    for file in try Self.swiftFiles(under: "ZenTomato") {
      for line in try Self.code(of: file).components(separatedBy: "\n") {
        #expect(
          (line.contains(".endedAt") && line.contains("StatsDay")) == false,
          "\(file.lastPathComponent) decides a day from a block's end: \(line)")
      }
    }
  }

  // MARK: The export is pure

  /// **`ZenTomato/Export/` contains no clock, no calendar, no locale and no
  /// disk.**
  ///
  /// This is what makes the committed golden file stable on every machine rather
  /// than on the one that generated it. A system date formatter asked for
  /// `HH:mm` returns `2:32 PM` on a phone set to a twelve-hour clock; a
  /// locale-aware comparison orders two titles differently on a laptop and on a
  /// build server. Neither is reachable from this directory.
  ///
  /// The feature's one piece of I/O — writing the file the share sheet hands
  /// over — lives in `Views/StatsExportFile.swift`, on purpose, so that this
  /// fence stays absolute.
  @Test("theExportIsPureByConstruction")
  func theExportIsPureByConstruction() throws {
    let forbidden = [
      "\\bDate\\(", "\\bCalendar\\b", "\\bTimeZone\\b", "\\bLocale\\b", "DateFormatter",
      "ISO8601", "\\.formatted\\(", "FileManager", "ModelContext", "URLSession",
      "localizedStandardCompare", "localizedCaseInsensitiveCompare", "@MainActor", "\\.now\\b"
    ]

    for file in try Self.swiftFiles(under: "ZenTomato/Export") {
      let code = try Self.code(of: file)
      for pattern in forbidden {
        #expect(
          try Self.matches(pattern, in: code) == 0,
          "\(file.lastPathComponent) is no longer pure: \(pattern).")
      }
    }
  }

  /// The two golden files are committed, present and not empty.
  ///
  /// A deleted golden that let its test pass would leave the suite green while
  /// the page it defends drifted, which is worse than having no test at all.
  @Test("theGoldensAreOnDiskAndNotEmpty")
  func theGoldensAreOnDiskAndNotEmpty() throws {
    for name in ["fortnight.md", "empty.md"] {
      let url = Self.repositoryRoot.appending(path: "ZenTomatoTests/Goldens").appending(path: name)
      let contents = try #require(try? String(contentsOf: url, encoding: .utf8), "\(name) is missing.")
      #expect(contents.isEmpty == false)
    }
  }

  // MARK: No capture surface, no new writes, nothing out of v0.1

  /// No text field, anywhere in this feature.
  ///
  /// `CLAUDE.md`: the app never accepts a new task from the user, and there is
  /// no capture surface of any kind. A history screen is a plausible place for a
  /// search box over the log or an "add a note" field, and neither exists.
  @Test("noCaptureSurfaceInThisFeature")
  func noCaptureSurfaceInThisFeature() throws {
    let files = try Self.swiftFiles(under: "ZenTomato/Stats")
      + Self.swiftFiles(under: "ZenTomato/Export")
      + Self.swiftFiles(under: "ZenTomato/Sprint")
      + Self.statsViewFiles()

    for file in files {
      let code = try Self.code(of: file)
      for pattern in ["TextField", "SecureField", "TextEditor", "\\.searchable", "UITextField"] {
        #expect(try Self.matches(pattern, in: code) == 0, "\(file.lastPathComponent) accepts typing.")
      }
    }
  }

  /// The one write this app can make is unchanged, and this feature adds no
  /// second one.
  ///
  /// The endpoint table itself is asserted by `TodoistEndpointTests`; this checks
  /// what F6 could plausibly have done — reached for a write while wiring D21.
  @Test("thisFeatureAddsNoWriteToTodoist")
  func thisFeatureAddsNoWriteToTodoist() throws {
    for file in try Self.featureFiles {
      let code = try Self.code(of: file)
      for word in ["\\bcreate\\b", "\\bmove\\b", "\\breopen\\b", "POST /tasks"] {
        #expect(try Self.matches(word, in: code, caseInsensitive: true) == 0, "\(file.lastPathComponent): \(word)")
      }
    }
  }

  /// Nothing from Phase 2 crept in, and no Swift hygiene rule was traded away
  /// for a shortcut. D2 moved the watch terms out; `WatchLinkTests` has the rest.
  @Test("nothingOutOfScopeAndNoForcedShortcuts")
  func nothingOutOfScopeAndNoForcedShortcuts() throws {
    let forbidden = [
      "CloudKit", "NSUbiquitous", "NSPersistentCloudKit", "\\bmacOS\\b", "AppIntent", "WidgetKit",
      "\\bTheme\\b", "try!", "\\bas!", "fatalError", "nonisolated\\(unsafe\\)", "@unchecked Sendable"
    ]

    for file in try Self.featureFiles {
      let code = try Self.code(of: file)
      for pattern in forbidden {
        #expect(try Self.matches(pattern, in: code) == 0, "\(file.lastPathComponent): \(pattern).")
      }
    }
  }

  // MARK: The way in

  /// **The history control exists, and it is present in every state.**
  ///
  /// D19: when a rule about movement meets an affordance somebody needs, reserve
  /// the space. A control that appeared only once there was history to look at
  /// would be missing on exactly the day somebody wanted to check whether
  /// anything had been recorded — and F3 lost a whole feature to an affordance
  /// suppressed to protect something else.
  ///
  /// It is drawn as an overlay in a corner that is empty in every state, so the
  /// 96-point countdown numeral moves by zero points.
  @Test("theWayIntoTheHistoryIsAlwaysThere")
  func theWayIntoTheHistoryIsAlwaysThere() throws {
    let screen = try Self.code(of: Self.repositoryRoot.appending(path: "ZenTomato/Views/TimerScreen.swift"))

    #expect(screen.contains(".overlay(alignment: .topLeading) { historyButton }"))
    // Not wrapped in a condition: the overlay is attached unconditionally, and
    // the declaration is a plain computed property rather than a branch.
    #expect(try Self.matches("if [^\n]*historyButton", in: screen) == 0)

    // And the control itself is never switched off. Read from its declaration to
    // the start of the next member, so this asks about the button and not about
    // some other control further down the file.
    let declaration = try #require(screen.range(of: "private var historyButton"))
    let next = try #require(
      screen.range(of: "private func failureRow", range: declaration.upperBound..<screen.endIndex))
    #expect(screen[declaration.lowerBound..<next.lowerBound].contains(".disabled(") == false)
  }

  // MARK: Private

  /// The repository, found from this file's own compiled path.
  private static let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()    // ZenTomatoTests
    .deletingLastPathComponent()    // repository root

  /// Every file this feature adds or edits.
  private static var featureFiles: [URL] {
    get throws {
      let edited = [
        "ZenTomato/Views/TimerScreen.swift",
        "ZenTomato/Views/TimerView.swift",
        "ZenTomato/Views/PlanBuilderView.swift",
        "ZenTomato/App/ZenTomatoApp.swift"
      ].map { repositoryRoot.appending(path: $0) }

      return try swiftFiles(under: "ZenTomato/Stats")
        + swiftFiles(under: "ZenTomato/Export")
        + swiftFiles(under: "ZenTomato/Sprint")
        + statsViewFiles()
        + edited
    }
  }

  /// Every `ZenTomato/Views/Stats*.swift`.
  private static func statsViewFiles() throws -> [URL] {
    try swiftFiles(under: "ZenTomato/Views").filter { $0.lastPathComponent.hasPrefix("Stats") }
  }

  private static func swiftFiles(under path: String) throws -> [URL] {
    let directory = repositoryRoot.appending(path: path)
    let found = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)?
      .compactMap { $0 as? URL }
      .filter { $0.pathExtension == "swift" }
      .sorted { $0.path < $1.path }

    let files = try #require(found, "No Swift files under \(path). The fence is searching the wrong tree.")
    #expect(files.isEmpty == false, "No Swift files under \(path).")
    return files
  }

  private static func matches(_ pattern: String, in text: String, caseInsensitive: Bool = false) throws -> Int {
    let expression = try NSRegularExpression(
      pattern: pattern,
      options: caseInsensitive ? [.caseInsensitive] : [])
    return expression.numberOfMatches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
  }

  /// A file's code, with every comment removed.
  ///
  /// See the note at the top of this file: the sentence that *states* a rule
  /// must not be what breaks it. String literals are left alone, so a `//`
  /// inside a quoted string is not mistaken for the start of a comment.
  private static func code(of file: URL) throws -> String {
    StatsFenceTests.stripComments(from: try String(contentsOf: file, encoding: .utf8))
  }

  private static func stripComments(from source: String) -> String {
    var output = ""
    var characters = Array(source)
    var index = 0
    var inString = false
    var inBlockComment = false

    while index < characters.count {
      let character = characters[index]

      if inBlockComment {
        if character == "*", index + 1 < characters.count, characters[index + 1] == "/" {
          inBlockComment = false
          index += 2
          continue
        }
        output.append(character == "\n" ? "\n" : " ")
        index += 1
        continue
      }

      if inString {
        output.append(character)
        if character == "\\", index + 1 < characters.count {
          output.append(characters[index + 1])
          index += 2
          continue
        }
        if character == "\"" { inString = false }
        index += 1
        continue
      }

      if character == "/", index + 1 < characters.count, characters[index + 1] == "/" {
        while index < characters.count, characters[index] != "\n" {
          output.append(" ")
          index += 1
        }
        continue
      }

      if character == "/", index + 1 < characters.count, characters[index + 1] == "*" {
        inBlockComment = true
        index += 2
        continue
      }

      if character == "\"" { inString = true }
      output.append(character)
      index += 1
    }

    return output
  }
}
