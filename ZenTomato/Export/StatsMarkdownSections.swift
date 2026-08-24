import Foundation

/// The six sections of the exported page, one function each.
///
/// WHY THIS IS A SEPARATE FILE
/// `StatsMarkdown` is the shape of the document — its title, its summary line,
/// and the order the sections appear in. This file is the sections themselves.
/// Kept together they would be one type well over the four-hundred-line limit,
/// and the honest answer to that is a seam rather than a `swiftlint:disable`:
/// the split falls exactly where the document's own outline falls, so a change
/// to how projects are listed touches one function in one file and nothing else.
///
/// EVERY FUNCTION HERE RETURNS AN OPTIONAL, AND THAT IS THE WHOLE EMPTY-SECTION
/// RULE
/// `nil` means "this section has nothing in it", and `StatsMarkdown` drops it.
/// A section with nothing in it is omitted entirely — never an empty table,
/// never a heading with nothing under it. There is one exception, handled a
/// level up: a range in which *nothing at all* happened becomes a three-line
/// document rather than a page of absent headings.
///
/// NOTHING HERE COUNTS ANYTHING
/// Every number on the page arrives already counted, on a `StatsPeriod`. These
/// functions choose words, choose an order, and pad a column. If a total were
/// ever computed here it would be a second counting rule, which is the one
/// failure this feature is built to prevent — see `StatsQuery`.
///
/// ORDERINGS ARE APPLIED HERE EVEN WHERE THE QUERY ALREADY APPLIED THEM
/// `StatsQuery` sorts what it returns, and this file sorts it again by the same
/// total order. That is deliberate, not redundant: applying the same total order
/// twice cannot change an answer, and it makes the document's order a property
/// of the document rather than something inherited from whoever built the value.
/// The golden file is then defended against a change to the query's sort as well
/// as against a change here.
///
/// Every comparison uses plain `<` on `String`. Code-point ordering is identical
/// on every machine; the locale-aware comparisons are not, and the golden file
/// would churn between a laptop and a build machine.
enum StatsMarkdownSections {
  // MARK: Days

  /// `## Days` — the one table in the document.
  ///
  /// A table earns its place here and nowhere else, because this is the one
  /// place you read *down* a column, which is what a fortnightly review does.
  /// Ascending, oldest first: the page is read like a diary.
  ///
  /// A day appears only if something was recorded on it. Five blank rows in a
  /// fortnight are padding, and a gap in the dates says the same thing more
  /// honestly. A day with taps but no finished block shows `0`.
  ///
  /// `0` rather than a dash in the count columns, because the column's job is
  /// arithmetic and a dash is not a number you can add up.
  static func days(_ rows: [StatsDayRow]) -> String? {
    guard rows.isEmpty == false else { return nil }

    let header = ["Date", "Pomodoros", "I", "E"]
    let body = rows
      .sorted { $0.day < $1.day }
      .map { row in
        [
          StatsWords.date(row.day),
          "\(row.pomodoroCount)",
          "\(row.internalCount)",
          "\(row.externalCount)"
        ]
      }

    let widths = columnWidths(header: header, body: body)
    let lines = [tableRow(header, widths), separatorRow(widths)] + body.map { tableRow($0, widths) }

    return heading("Days") + lines.joined(separator: "\n")
  }

  // MARK: Projects

  /// `## Projects` — where the time went.
  ///
  /// Bold project, em dash, count, and the I/E figures. Tasks nest one level
  /// with a bare count: their own I/E live in `## Distractions`, and repeating
  /// them here would give the same number two homes and two chances to disagree.
  ///
  /// **Two different absences, two different words, and the difference matters.**
  /// A block worked under a project with no task chosen produces a sub-row
  /// called `No task`, so the lines under a heading always add up to the
  /// heading — a heading that disagrees with its own sub-rows is how a page
  /// stops being believed. A block that recorded no *project* groups under a
  /// heading called `No project`, which today is the common case: the session
  /// plan hands the timer a task's title alone, so most task-attached blocks
  /// have no project name on them. Calling that heading `No task` while named
  /// tasks sit underneath it would be simply wrong.
  ///
  /// Ordering is `StatsPeriod`'s own, applied to the rows it already ordered —
  /// the same total order twice, never a second opinion about it.
  static func projects(_ rows: [StatsProjectRow]) -> String? {
    guard rows.isEmpty == false else { return nil }

    let lines = rows.sorted(by: StatsPeriod.projectIsBefore).flatMap { project -> [String] in
      let name = project.title.map(StatsWords.clean) ?? StatsWords.noProject
      let tally = StatsWords.projectTally(
        internalCount: project.internalCount,
        externalCount: project.externalCount)
      let blocks = StatsWords.count(project.pomodoroCount, "pomodoro", "pomodoros")
      let head = "- **\(name)** — \(blocks) \(tally)"

      let tasks = project.tasks
        .sorted(by: StatsPeriod.taskRowIsBefore)
        .map { "  - \($0.title.map(StatsWords.clean) ?? StatsWords.noTask) — \($0.pomodoroCount)" }

      return [head] + tasks
    }

    return heading("Projects") + lines.joined(separator: "\n")
  }

  // MARK: Completed and Repeating

  /// `## Completed` — what came out of the fortnight (D11).
  ///
  /// Date, em dash, and the title **snapshot**: what the task was called at the
  /// moment it was ticked off, never a live lookup. A two-week-old review shows
  /// what was true then, and a task since deleted in Todoist still appears here,
  /// which is correct.
  ///
  /// Recurring completions are excluded — they are the next section, and the
  /// argument for splitting them is on `repeating(_:)`.
  static func completed(_ oneOffs: [StatsCompletion]) -> String? {
    guard oneOffs.isEmpty == false else { return nil }

    let lines = oneOffs
      .sorted(by: byDayThenTitle)
      .map { "- \(StatsWords.date($0.day)) — \(StatsWords.clean($0.title))" }

    return heading("Completed") + lines.joined(separator: "\n")
  }

  /// `## Repeating` — the habits (D21).
  ///
  /// One line per distinct task, with the weekdays it was closed on.
  ///
  /// WHY THIS SECTION EXISTS AT ALL
  /// Closing a recurring task in Todoist does not finish it — it advances it to
  /// its next occurrence. Without this split the same title lands on eight days
  /// of fourteen in `## Completed` with nothing to explain why. Finishing a
  /// chapter and ticking off a daily habit are not the same achievement, and a
  /// page that files them together makes the first one disappear.
  ///
  /// The boolean is the one captured at the moment of completion, from Todoist's
  /// own answer. It is never inferred from a title appearing more than once.
  ///
  /// **Known limitation, stated rather than discovered.** The weekdays are
  /// deduplicated, so over a fortnight two Mondays collapse into one `Mon`. That
  /// is exactly `F6.md`'s ratified sample and it ships as specified. `F6.md`
  /// predicts one or two format revisions once real data is read on paper, and
  /// this is the likeliest of them; the golden file is what makes that revision
  /// cheap and visible.
  static func repeating(_ repeats: [StatsCompletion]) -> String? {
    guard repeats.isEmpty == false else { return nil }

    let grouped: [String: [StatsCompletion]] = Dictionary(grouping: repeats) {
      StatsWords.clean($0.title)
    }

    var groups: [RepeatingGroup] = []
    for (title, entries) in grouped {
      groups.append(RepeatingGroup(title: title, days: Set(entries.map(\.day))))
    }
    groups.sort(by: byDistinctDaysThenTitle)

    let lines = groups.map { "- \($0.title) — \(weekdayList(of: $0.days))" }

    return heading("Repeating") + lines.joined(separator: "\n")
  }

  // MARK: Distractions

  /// `## Distractions` — grouped by task, which is the one real editorial
  /// decision in this feature.
  ///
  /// Chronological order tells you *when* you got distracted; the `## Days`
  /// table already carries that. Grouping by task tells you *what* keeps
  /// distracting you, which is the self-knowledge `SPEC.md` says the log exists
  /// for.
  ///
  /// Groups are ordered by how many taps they hold, descending — the thing that
  /// interrupted you most is the thing you came to the page to find — with ties
  /// broken by name so the order is deterministic, and `No task` always last.
  /// Within a group, ascending by time: you are re-walking the afternoon.
  ///
  /// **A group is a task *and* a project, not one name.** A task called `Thesis`
  /// and a block attached to the `Thesis` project with no task chosen are two
  /// different things; collapsing them into one heading would silently merge two
  /// afternoons. The second reads `Thesis (no task)`, which says what it is.
  ///
  /// **A skipped note renders `*(no note)*`, never a blank.** Three reasons, all
  /// real. A tap with no sentence *is* data — somebody noticed the interruption
  /// and only declined to describe it, and a blank line says nothing happened.
  /// The lines here are counted against the `## Days` table's I and E columns,
  /// so a line that renders as trailing whitespace makes two sections of the
  /// same page silently disagree. And in Markdown a line ending in an em dash
  /// renders as a dangling dash, which reads as a rendering bug — which is
  /// exactly what the reader would conclude.
  static func distractions(_ groups: [StatsDistractionGroup]) -> String? {
    guard groups.isEmpty == false else { return nil }

    let blocks = groups.sorted(by: StatsPeriod.groupIsBefore).map { group -> String in
      let lines = group.entries.sorted(by: byDayThenTime).map { entry in
        let marker = entry.kind == .internalInterruption ? "**I**" : "**E**"
        let written = StatsWords.clean(entry.note ?? "")
        let note = written.isEmpty ? "*(no note)*" : written
        return "- \(StatsWords.date(entry.day)), \(StatsWords.time(entry.time)) — \(marker) — \(note)"
      }
      // No blank line between a `###` heading and its first bullet: they are one
      // block. One blank line between groups, which the join below supplies.
      return "### \(name(of: group))\n" + lines.joined(separator: "\n")
    }

    return heading("Distractions") + blocks.joined(separator: "\n\n")
  }

  // MARK: Stopped early

  /// `## Stopped early` — where you bailed, and why (D13, D15).
  ///
  /// Its own section, and last. A distraction is a moment; a stop is a decision.
  /// Among a list of taps a stop would vanish, and a written sentence was
  /// charged for each one precisely so it would be worth reading later.
  ///
  /// **These blocks appear here and nowhere else, and in no count.** `42
  /// pomodoros` at the top of the page means blocks you finished. The abandoned
  /// *rate* is deliberately absent from this document: D15 rejected it by name,
  /// because it would make the first thing you read every fortnight a measure of
  /// how often you gave up.
  ///
  /// Every abandoned block appears, whatever its kind. A stop taken during a
  /// break cost a written sentence too, and a section called "where I bailed"
  /// that omits it is not answering its own question. A break is named by its
  /// kind — `short break` — rather than by an attachment it never had.
  ///
  /// The reason is in straight double quotes because it is the person's own
  /// words, reproduced. A missing one — possible for rows written before D13, or
  /// through the alarm's own Stop button — renders `*(no reason recorded)*`
  /// rather than an empty pair of quotes.
  static func stoppedEarly(_ stops: [StatsStop]) -> String? {
    guard stops.isEmpty == false else { return nil }

    let lines = stops.sorted(by: byDayThenTime).map { stop -> String in
      let written = StatsWords.clean(stop.reason ?? "")
      let reason = written.isEmpty ? "*(no reason recorded)*" : "\"\(written)\""
      let middle = label(for: stop)
      let opening = "- \(StatsWords.date(stop.day)), \(StatsWords.time(stop.time))"

      guard let middle else { return "\(opening) — \(reason)" }
      return "\(opening) — \(middle) — \(reason)"
    }

    return heading("Stopped early") + lines.joined(separator: "\n")
  }
}

// MARK: - Grouping values

/// One habit in `## Repeating`, and the distinct days it was closed on.
private struct RepeatingGroup {
  let title: String
  let days: Set<StatsDay>
}

// MARK: - Shared shapes

extension StatsMarkdownSections {
  /// A `## Heading` and the blank line under it.
  ///
  /// One place, so that a section can never accidentally ship with two blank
  /// lines under its heading — which is invisible in a rendered page and a
  /// failed golden-file comparison in a test log.
  fileprivate static func heading(_ title: String) -> String {
    "## \(title)\n\n"
  }

  /// The middle segment of a stopped-early line, or `nil` when there is none.
  ///
  /// A break is named by its kind, lower-cased so it reads as part of the
  /// sentence rather than as a title. A focus block with nothing attached gets
  /// no segment at all: `— No task —` would be noise on the rarest lines in the
  /// document, and the line reads perfectly as a time and a reason.
  fileprivate static func label(for stop: StatsStop) -> String? {
    guard stop.kind == .work else {
      return stop.kind.displayName.lowercased()
    }
    let name = StatsWords.clean(stop.title ?? "")
    return name.isEmpty ? nil : name
  }

  fileprivate static func byDayThenTitle(_ left: StatsCompletion, _ right: StatsCompletion) -> Bool {
    left.day == right.day ? StatsWords.clean(left.title) < StatsWords.clean(right.title) : left.day < right.day
  }

  fileprivate static func byDayThenTime(_ left: StatsDistractionEntry, _ right: StatsDistractionEntry) -> Bool {
    left.day == right.day ? left.time < right.time : left.day < right.day
  }

  fileprivate static func byDayThenTime(_ left: StatsStop, _ right: StatsStop) -> Bool {
    left.day == right.day ? left.time < right.time : left.day < right.day
  }

  /// Distinct-day count descending, then title ascending.
  fileprivate static func byDistinctDaysThenTitle(_ left: RepeatingGroup, _ right: RepeatingGroup) -> Bool {
    if left.days.count != right.days.count { return left.days.count > right.days.count }
    return left.title < right.title
  }

  /// The weekdays a habit was closed on: `Mon, Tue, Wed, Fri, Sat`.
  ///
  /// Deduplicated while keeping the Monday-first order, which a `Set` would
  /// lose — the order is the whole point of the line.
  fileprivate static func weekdayList(of days: Set<StatsDay>) -> String {
    let ordered = days.sorted { StatsWords.weekOrder($0) < StatsWords.weekOrder($1) }
    var seen: [String] = []
    for day in ordered {
      let word = StatsWords.weekdayAbbreviation(day)
      if seen.contains(word) == false { seen.append(word) }
    }
    return seen.joined(separator: ", ")
  }

  /// What a `###` heading says.
  ///
  /// The task, else the project with `(no task)` after it, else `No task`. The
  /// middle case is the one worth spelling out: `Thesis (no task)` tells you
  /// these taps happened while you were working on the project without having
  /// picked anything in it, which is a different afternoon from one spent on a
  /// task that happens to be called Thesis.
  fileprivate static func name(of group: StatsDistractionGroup) -> String {
    if let task = group.taskTitle {
      return StatsWords.clean(task)
    }
    if let project = group.projectTitle {
      return "\(StatsWords.clean(project)) (no task)"
    }
    return StatsWords.noTask
  }

  // MARK: The table

  fileprivate static func columnWidths(header: [String], body: [[String]]) -> [Int] {
    header.indices.map { column in
      let cells = [header[column]] + body.map { $0[column] }
      return cells.map { $0.count }.max() ?? 0
    }
  }

  /// One row of the pipe table, padded so the raw file is readable in a plain
  /// text editor as well as rendered.
  ///
  /// Widths are counted in `Character`s rather than in UTF-16 units, so a title
  /// carrying an accent or an emoji does not silently misalign the column.
  fileprivate static func tableRow(_ cells: [String], _ widths: [Int]) -> String {
    let padded = zip(cells, widths).map { cell, width in
      " \(cell)\(String(repeating: " ", count: max(0, width - cell.count))) "
    }
    return "|\(padded.joined(separator: "|"))|"
  }

  fileprivate static func separatorRow(_ widths: [Int]) -> String {
    "|\(widths.map { String(repeating: "-", count: $0 + 2) }.joined(separator: "|"))|"
  }
}
