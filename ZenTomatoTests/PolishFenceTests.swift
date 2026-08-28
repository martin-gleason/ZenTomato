import Foundation
import SwiftData
import Testing

@testable import ZenTomato

/// What F6b may not do, enforced rather than promised.
///
/// **WHY A REPAIR PASS NEEDS A FENCE OF ITS OWN.** `CLAUDE.md` forbids building, stubbing or
/// preparing for anything outside the spec. That is easy to honour while writing a feature,
/// because a feature declares what it is. It is much harder while *optimising*, because
/// **performance work's natural moves look exactly like architecture work**: a cache, an
/// actor, a queue, a layer of indirection. Every one of those is also what a bi-directional
/// sync engine wants first, and "make it faster" is the most respectable cover story
/// available for laying v1.1's foundations.
///
/// `D16` states the test — *would I write this the same way if bi-directional sync were never
/// coming?* — and that is a judgement. These are the parts of it a machine can hold.
///
/// **The legitimate performance moves add nothing.** Off the main actor; lazily rather than
/// eagerly; once rather than repeatedly. They rearrange work that already exists and need no
/// new type. The dangerous move is caching, which is new machinery *and* is what a sync layer
/// reaches for first — so the counts below are what stop one arriving quietly.
///
/// Each number is a **baseline taken before the pass began**, not a limit invented here. A
/// count that must change is a conversation, and changing it is one line in a diff somebody
/// reads.
@Suite("PolishFence")
struct PolishFenceTests {
  // MARK: The token layer, where a theme system would start

  /// `theTokenLayerDoesNotGrow` — polish uses the roles that exist and adds none.
  ///
  /// `SPEC.md` puts **themes** out of scope, and the two-layer token system is precisely
  /// where a theme system begins. It would not arrive announced; it would arrive as one
  /// reasonable-looking `ColorRole` case at a time, each defensible on its own, during exactly
  /// the kind of pass that is licensed to make things look better.
  ///
  /// So the count is fixed for the duration. A polish task that genuinely needs a new role has
  /// found something the design system does not cover, which is worth saying out loud rather
  /// than absorbing.
  @Test("theTokenLayerDoesNotGrow")
  func theTokenLayerDoesNotGrow() throws {
    #expect(try Self.count("^  case [a-z]", in: "ZenTomato/DesignSystem/Semantic/ColorRole.swift") == 20)
    #expect(try Self.count("^  static (let|func) ", in: "ZenTomato/DesignSystem/Semantic/Typography.swift") == 13)
    #expect(try Self.count("^  static let ", in: "ZenTomato/DesignSystem/Semantic/Spacing.swift") == 15)
    #expect(try Self.count("^  static let ", in: "ZenTomato/DesignSystem/Semantic/Radius.swift") == 6)
  }

  // MARK: New machinery, of any kind

  /// `noNewStoredShape` — the database does not gain a type during a repair pass.
  ///
  /// Twelve `@Model` types is what v0.1 finished with. A thirteenth is a feature, whatever it
  /// is called — and the local task model the owner wants is explicitly v1.5.
  @Test("noNewStoredShape")
  func noNewStoredShape() throws {
    #expect(try Self.countAcrossApp("^@Model") == 12)
    // Six fields, unchanged since F1. SPEC.md: "Nothing else."
    // **SEVEN SINCE `D24`, AND THE MOVE IS THE POINT OF THE FENCE.**
    //
    // This was six, and the bound was mutation-tested with *an alarm-sound
    // picker specifically* as the hypothetical seventh — so this is the exact
    // change it was watching for, arriving as a ratified amendment to
    // `SPEC.md` line 30 rather than as a quiet extra field.
    //
    // **ASKS THE SCHEMA, NOT THE FILE.** This used to grep `^  var [a-z]` in
    // AppSettings.swift, and F2c showed what that measures: the seventh field's
    // computed accessor was put in a second file, and the regex went on reading
    // seven because the property had moved out of its reach. Swift forbids
    // stored properties in extensions, so the schema claim survived by accident —
    // but a fence that can be satisfied by moving code is measuring file shape
    // rather than the database.
    //
    // `Schema` reports the persisted columns wherever the source lives.
    #expect(try #require(Schema([AppSettings.self]).entities.first).properties.count == 7)
    // TimerState is the other stored shape F2c touched: it carries the block's
    // chosen sound, so a block runs under the setting it started with. Fenced
    // here for the same reason AppSettings is — a schema change is a migration
    // over somebody's real history, and it should be seen rather than counted
    // after the fact.
    let timerStateColumns = try #require(Schema([TimerState.self]).entities.first).properties.count
    #expect(timerStateColumns == timerStateColumnCount)
  }

  /// `TimerState`'s persisted column count, as `Schema` reports it.
  ///
  /// Pinned rather than grepped, for the reason the `AppSettings` line above
  /// gives: a regex over a source file measures where code lives, and code
  /// moves. Sixteen before `F2c`; the seventeenth is `alertSoundRawValue`.
  private let timerStateColumnCount = 17

  /// `noNewProtocol` — because a protocol is the shape of "swappable later".
  ///
  /// The ten that exist are all seams for testing: a clock, a transport, a player, a token
  /// store. Each was written because a test had to hand the app a stand-in. **An eleventh
  /// arriving during a polish pass would almost certainly be "extracted for testability" and
  /// mean "made swappable for the sync engine"** — which is the drift this fence exists to
  /// catch, in its most plausible disguise.
  @Test("noNewProtocol")
  func noNewProtocol() throws {
    #expect(try Self.countAcrossApp("^(public |internal )?protocol ") == 10)
  }

  /// `noNewPersistentSurface` — no cache arrives quietly.
  ///
  /// **The app uses `UserDefaults` nowhere at all** — the single mention in the tree is a
  /// sentence in a doc comment explaining that `AppSettings` is a database row instead. Every
  /// piece of state that outlives a launch is in SwiftData, in one container, made once in the
  /// composition root.
  ///
  /// That is a stronger fact than "one use", and worth pinning as such: new persistent state
  /// is the first thing a sync layer needs and the last thing a repair pass should produce.
  ///
  /// If a measurement genuinely demands a cache, this test failing is the correct outcome: it
  /// stops the pass and moves the argument to a delta, where it belongs.
  @Test("noNewPersistentSurface")
  func noNewPersistentSurface() throws {
    #expect(
      try Self.countAcrossApp("UserDefaults") == 0,
      "A repair pass has reached for a second kind of persistence.")
    // One container, made once, in the composition root.
    #expect(try Self.countAcrossApp("ModelContainer\\(") <= 1)
  }

  // MARK: v1.1 and v1.5, by name

  /// `nothingFromTheParkedList` — the work the owner wants next, kept out of this pass.
  ///
  /// Every term below names something real and agreed for later: bi-directional Todoist sync,
  /// a local task model, Fantastical through EventKit, gamification, modular themes. None is
  /// forbidden for ever. All are forbidden *here*, because the moment one lands under the
  /// heading of polish there is no longer a line between v0.1 and v1.1.
  @Test("nothingFromTheParkedList")
  func nothingFromTheParkedList() throws {
    for term in [
      "import EventKit", "EKEvent", "\\bpushTo", "\\bpullFrom", "conflictResolution",
      "\\bThemeProvider", "\\bstreak", "\\bbadge", "SyncEngine", "\\bmergePolicy"
    ] {
      #expect(
        try Self.countAcrossApp(term) == 0,
        Comment(rawValue: "\(term) belongs to v1.1 or v1.5, not to a repair pass."))
    }
  }

  // MARK: Private

  private static let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()

  private static func count(_ pattern: String, in path: String) throws -> Int {
    let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
    return matches(pattern, in: text)
  }

  /// Across every line of shipped Swift — the app, the watch, and the widget.
  private static func countAcrossApp(_ pattern: String) throws -> Int {
    var total = 0
    for directory in ["ZenTomato", "ZenTomatoWatch", "ZenTomatoActivity"] {
      guard let walk = FileManager.default.enumerator(
        at: root.appending(path: directory), includingPropertiesForKeys: nil) else { continue }
      for case let url as URL in walk where url.pathExtension == "swift" {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
        total += matches(pattern, in: stripped(text))
      }
    }
    return total
  }

  /// Comments removed before searching, for the reason `StatsFenceTests` gives: a fence that
  /// cannot tell a refusal from a violation fires on the sentence that states the rule, and is
  /// switched off within a month.
  private static func stripped(_ text: String) -> String {
    text
      .components(separatedBy: "\n")
      .filter { line in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("//") == false && trimmed.hasPrefix("///") == false
      }
      .joined(separator: "\n")
  }

  private static func matches(_ pattern: String, in text: String) -> Int {
    guard let expression = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    else { return -1 }
    return expression.numberOfMatches(
      in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
  }
}
