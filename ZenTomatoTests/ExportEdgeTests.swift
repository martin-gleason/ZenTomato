import Foundation
import Testing

@testable import ZenTomato

/// The three sharp edges on the export, and the one that was ruled rather than fixed.
@Suite("ExportEdges")
struct ExportEdgeTests {
  // MARK: A7 — a title is prose, not markup

  /// `aTitleWithMarkupIsPrintedAsItself` — asterisks survive, and the table does not break.
  ///
  /// **A task called `**Thesis**` used to render as bold *Thesis*, silently losing its
  /// asterisks**, and one containing a pipe broke the Days table it landed in. Neither is a
  /// crash, and neither appears in any fixture, because fixture titles are all well-behaved.
  /// But the bar for this feature is that the page reads without translation, and a title that
  /// changes shape on the way to the paper fails it.
  @Test("aTitleWithMarkupIsPrintedAsItself")
  func aTitleWithMarkupIsPrintedAsItself() {
    #expect(StatsWords.clean("**Thesis**") == "\\*\\*Thesis\\*\\*")
    #expect(StatsWords.clean("Ch.3 [draft]") == "Ch.3 \\[draft\\]")
    #expect(StatsWords.clean("read | write") == "read \\| write")
    #expect(StatsWords.clean("`git rebase`") == "\\`git rebase\\`")
    #expect(StatsWords.clean("#1 priority") == "\\#1 priority")
  }

  /// And ordinary punctuation is left completely alone.
  ///
  /// **This half matters as much as the other.** Escaping every Markdown metacharacter would
  /// put backslashes in front of full stops and apostrophes, which are far commoner in a task
  /// title than an asterisk — and `Ch\.3 draft` on the page would be a worse failure of the
  /// same bar than the one being fixed.
  @Test("ordinaryPunctuationIsUntouched")
  func ordinaryPunctuationIsUntouched() {
    for title in [
      "Ch.3 draft", "Marta's feedback", "Reading · notes",
      "Budget with YNAB by 7:30 AM", "Pick 1–3 MITs", "Email (again)"
    ] {
      #expect(StatsWords.clean(title) == title, "\(title) was altered on the way to the page.")
    }
  }

  /// Whitespace collapsing still happens, and happens before escaping.
  @Test("whitespaceIsStillCollapsed")
  func whitespaceIsStillCollapsed() {
    #expect(StatsWords.clean("  two   spaces  ") == "two spaces")
    #expect(StatsWords.clean("a\nnewline") == "a newline")
  }

  // MARK: A4 — the sweep does not reach a page somebody is reading

  /// `writingTwiceKeepsOnlyTheCurrentPage` — and only inside this launch's own directory.
  ///
  /// The sweep exists so temporary pages do not accumulate. It used to run over the entire
  /// temporary directory, so exporting twice while a share sheet was still open could delete
  /// the file that sheet was reading. Now it is bounded to a per-launch subdirectory.
  @Test("writingTwiceKeepsOnlyTheCurrentPage")
  func writingTwiceKeepsOnlyTheCurrentPage() throws {
    let first = try StatsExportFile.write(document: "# one\n", filename: "ZenTomato-one.md")
    let second = try StatsExportFile.write(document: "# two\n", filename: "ZenTomato-two.md")

    #expect(FileManager.default.fileExists(atPath: second.path))
    #expect(try String(contentsOf: second, encoding: .utf8) == "# two\n")
    // The first is gone, which is the sweep working.
    #expect(FileManager.default.fileExists(atPath: first.path) == false)

    // AND IT NEVER LEFT ITS OWN DIRECTORY. A file with the same shape of name, sitting in the
    // temporary directory itself, is untouched — that is the share extension's copy, and the
    // whole point of the change.
    let bystander = FileManager.default.temporaryDirectory.appending(path: "ZenTomato-elsewhere.md")
    try Data("# not mine\n".utf8).write(to: bystander)
    defer { try? FileManager.default.removeItem(at: bystander) }

    _ = try StatsExportFile.write(document: "# three\n", filename: "ZenTomato-three.md")
    #expect(
      FileManager.default.fileExists(atPath: bystander.path),
      "The sweep reached outside its own directory.")
  }

  // MARK: A8 — ruled, and pinned so it cannot drift silently

  /// `theDayIsResolvedInTheReadersCurrentZone` — today's behaviour, written down.
  ///
  /// **A8 was researched and deliberately not changed.** Two camps exist: Clockify and Google
  /// Analytics store an instant and recompute the day in the reader's *current* zone, so
  /// history moves when you do; Strava stores the local date at recording and an activity
  /// *"will be counted for the day it was started"*.
  ///
  /// Strava's model is the right one for a Rhodia review, and **half of it is already built** —
  /// the day rule is the local calendar day of the block's start. What is missing is that the
  /// zone comes from the reader, not from the block. Closing that needs a stored time-zone
  /// identifier on `PomodoroSession`, which is a schema change, which is a delta — twenty days
  /// from a hard stop, for a fault that needs a zone crossing *and* a fortnight spanning it.
  ///
  /// So this test does not assert the desirable behaviour. **It pins the actual one**, so that
  /// if it ever changes, it changes because somebody meant it to.
  @Test("theDayIsResolvedInTheReadersCurrentZone")
  func theDayIsResolvedInTheReadersCurrentZone() {
    // 23:30 on 23 August in London; 07:30 the next morning in Tokyo.
    let instant = Date(timeIntervalSince1970: 1_787_524_200)

    var london = Calendar(identifier: .gregorian)
    london.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
    var tokyo = Calendar(identifier: .gregorian)
    tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt

    let asLondon = StatsDay.containing(instant, in: london)
    let asTokyo = StatsDay.containing(instant, in: tokyo)

    // One instant, two days. That is exactly the limitation, stated as a fact rather than
    // left to be discovered by somebody reading a fortnight after a flight.
    #expect(asLondon.day == 23)
    #expect(asTokyo.day == 24)
    #expect(asLondon != asTokyo)
  }
}
