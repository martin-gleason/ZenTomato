# F6 — Build contract

**Feature:** F6 Stats and export · **Branch:** `F6/stats-export` · **Written:** 2026-08-23
**Binds:** `docs/specs/SPEC.md` F6 · `CLAUDE.md` · `docs/plans/F6.md` · `docs/plans/00-deltas.md`
D11, D13, D15, D21, D21b.

This is the document two engineers implement literally. Where it and `F6.md` disagree, `F6.md`
wins and this file is wrong. Where `F6.md` is silent, this file decides and says so out loud, so
the owner can overrule at review rather than discover at export time.

**The bar is not "valid Markdown".** It is *"the export of one real study day is readable in the
Rhodia without translation."* Every decision below is answerable to that sentence.

---

## 0. Verification result — what Todoist API v1 returns for recurrence (D21)

D21 says explicitly: *"a boolean read from the wrong key is silently always false."* So this was
established before any code was designed, not assumed.

**Answer: `is_recurring` is a boolean on the task's `due` object. It is not on the task itself.
`due` is nullable.**

```json
{
  "id": "6XGgmFVcrG5RRjVr",
  "content": "Budget with YNAB by 7:30 AM",
  "project_id": "6X7rM8997g3RQmvh",
  "section_id": null,
  "child_order": 1,
  "due": {
    "date": "2016-08-05T07:00:00.000000Z",
    "timezone": null,
    "is_recurring": false,
    "string": "tomorrow at 10:00",
    "lang": "en"
  }
}
```

**Sources, in order of authority:**

1. **Doist's own API v1 client library**, `todoist-api-python`,
   `https://raw.githubusercontent.com/Doist/todoist-api-python/main/todoist_api_python/models.py` —
   the strongest evidence available, because it is the vendor's own decoder for the exact endpoint
   this app calls:

   ```python
   @dataclass
   class Due(JSONPyWizard):
       date: ApiDue
       string: str
       lang: str = "en"
       is_recurring: bool = False
       timezone: str | None = None
   ```

   and on the task: `due: Due | None`.
2. **`https://developer.todoist.com/api/v1/`** — the live documentation root. It documents due
   dates in three shapes (full-day, floating with time, fixed-timezone) and confirms the close
   command's behaviour that D21 exists because of: *"Tasks with recurring due dates will be
   scheduled to their next occurrence."* The rendered reference page is a single-page app and did
   not yield the task schema through a plain fetch; that is why the vendor SDK is quoted above
   rather than a paragraph of prose.

**The three facts an implementer must not get wrong:**

| Fact | Consequence if got wrong |
|---|---|
| The key is `is_recurring`, snake case, **inside `due`** | Read from the task root ⇒ always `nil` ⇒ always `false`. Every habit lands in `## Completed` and `## Repeating` is permanently empty. Silent. |
| `due` is **null** for a task with no due date | Decoding `due` as non-optional makes *every task on the account fail to decode*, which empties the picker. Not silent, but catastrophic and only on a real account. |
| `is_recurring` may be **absent** inside a present `due` | Decoding it as required makes those tasks fail to decode. Must default to `false`, never throw. |

`due` itself is on F3's deliberately-not-mirrored list (`F3-contract.md` §3.2). §4.1 below is the
visible argument with that list which that document demands. **We do not mirror `due`.** We mirror
one boolean derived from it.

---

## 1. File layout

Four directories, and the directory boundary **is** the ownership boundary and the fence boundary.
Every fence in §6 is expressible as "grep this directory for that word".

```
ZenTomato/Stats/     THE COUNTING RULE.  Owns SwiftData. Contains no string a person reads.
ZenTomato/Export/    THE PURE FUNCTION.  No SwiftData, no clock, no calendar, no locale, no I/O.
ZenTomato/Sprint/    D21b.               An in-memory set and the thing that empties it.
ZenTomato/Views/     THE SCREEN.         Reads a StatsPeriod. Never counts anything.
```

### 1.1 New files

```
ZenTomato/Stats/StatsDay.swift                 A local calendar day as four integers. THE day rule.
ZenTomato/Stats/StatsRange.swift               first…last StatsDay. Trailing-14-days. Fetch bounds.
ZenTomato/Stats/StatsPeriod.swift              The one answer. Both readers consume this and nothing else.
ZenTomato/Stats/StatsDayRow.swift              One day: counts, and that day's taps.
ZenTomato/Stats/StatsProjectRow.swift          One project: counts, and its task rows.
ZenTomato/Stats/StatsTaskRow.swift             One task: counts.
ZenTomato/Stats/StatsCompletion.swift          One completion. Carries D21's boolean.
ZenTomato/Stats/StatsDistractionEntry.swift    One tap, placed on a day and against a name.
ZenTomato/Stats/StatsStop.swift                One abandoned block, with its written reason.
ZenTomato/Stats/StatsQuery.swift               THE ONLY FILE IN THE FEATURE THAT IMPORTS SwiftData.

ZenTomato/Export/StatsWords.swift              Weekday/month tables, plurals, durations, note cleaning.
ZenTomato/Export/StatsMarkdown.swift           document(for:) -> String, and filename(for:).
ZenTomato/Export/StatsMarkdownSections.swift   One private function per section. Seam, not a limit raise.

ZenTomato/Sprint/SprintCompletions.swift       D21b. Task ids completed during this sprint.
ZenTomato/Sprint/SprintBoundaryObserver.swift  Empties it. Reads the engine; never writes to it.

ZenTomato/Views/StatsScreen.swift              Today's number first, then the three lists.
ZenTomato/Views/StatsScreenModel.swift         Holds the query, the range, and the two periods.
ZenTomato/Views/StatsDaySheet.swift            Tapping a day: that day's sentences.
ZenTomato/Views/StatsRangeControl.swift        Two date pickers and a reset. Nothing else.
ZenTomato/Views/StatsExportFile.swift          Writes the .md to a temp file; hands ShareLink a URL.
```

### 1.2 Edited files, and the whole of what changes in each

```
ZenTomato/Models/CompletedTaskRecord.swift   + wasRecurring: Bool  (D21). Init gains a REQUIRED param.
ZenTomato/Models/CachedTask.swift            + isRecurring: Bool   (D21). Mirrored, not invented. §4.1.
ZenTomato/Todoist/TodoistDTO.swift           + TodoistTaskDTO.due: Due?  with Due.isRecurring. §4.2.
ZenTomato/Todoist/TodoistCacheStore.swift    one argument at the CachedTask insert.
ZenTomato/Todoist/TaskCompletion.swift       read recurrence BEFORE deleting the cached row. §4.3.
ZenTomato/Plan/SessionPlanStore.swift        D21b: skip completed items; filter selections. §5.3.
ZenTomato/Views/TimerScreen.swift            ONE toolbar-adjacent button. §7.2.
ZenTomato/Views/TimerView.swift              present the stats screen; call SprintCompletions.record.
ZenTomato/App/ZenTomatoApp.swift             build SprintCompletions + SprintBoundaryObserver; wire.
ZenTomato/Views/PlanBuilderView.swift        one .filter on the task list. §5.4.
```

### 1.3 Files with ZERO changed lines. This is checked, not promised.

`ZenTomato/Models/AppSettings.swift` (six fields, `SPEC.md` says "Nothing else") ·
`ZenTomato/Distraction/DistractionTally.swift` (owner-written) ·
`ZenTomato/Timer/TimerEngine.swift` · `ZenTomato/Timer/TimerCycle.swift` ·
`ZenTomato/Models/PomodoroSession.swift` · `ZenTomato/Distraction/Distraction.swift` ·
`ZenTomato/Models/SessionPlan.swift` · `ZenTomato/Models/SessionPlanItem.swift` ·
`ZenTomato/Plan/SessionAttachment.swift` · `ZenTomato/Plan/SessionAttaching.swift` ·
`ZenTomato/Todoist/TodoistAPI.swift` · `scripts/todoist-allowed-endpoints.txt` ·
all of `ZenTomato/Music/`, `ZenTomato/Alarm/`, `ZenTomato/DesignSystem/`, `ZenTomatoActivity/`,
`scripts/`, `.githooks/`, `.github/`, `Config/`, `Makefile`, `.swiftlint.yml` limits,
`project.yml`, `docs/specs/`.

**`TimerEngine.swift` is untouched and that is a design requirement, not luck.** F4 proved the
pattern: the engine is `@Observable`, so anything that needs to know a sprint ended subscribes to
what is already published. §5.2 gives the proof that the existing surface is sufficient.

**`project.yml` is untouched, which constrains the golden file.** The golden `.md` is read from the
source tree through `#filePath`, not from the test bundle — see §3.6. `LaunchBackgroundTests.swift:70`
already does exactly this and passes in CI, so the technique is proven in this repository.

### 1.4 Test files

```
NEW  ZenTomatoTests/StatsCountingTests.swift          the rule, over hand-built values
NEW  ZenTomatoTests/StatsRangeTests.swift             trailing 14 days, half-open bounds, single day
NEW  ZenTomatoTests/StatsQueryStoreTests.swift        the rule, over a real store
NEW  ZenTomatoTests/RecurrenceCaptureTests.swift      D21 end to end
NEW  ZenTomatoTests/SprintCompletionsTests.swift      D21b
NEW  ZenTomatoTests/StatsMarkdownGoldenTests.swift    the golden files
NEW  ZenTomatoTests/StatsMarkdownSectionTests.swift   the per-section rules
NEW  ZenTomatoTests/StatsScreenModelTests.swift       the screen reads the same period
NEW  ZenTomatoTests/StatsFenceTests.swift             §6, executed
NEW  ZenTomatoTests/Support/StatsStoreFixture.swift   rows in a store          (Engineer A)
NEW  ZenTomatoTests/Support/StatsPeriodFixture.swift  the same fortnight, by hand (Engineer B)
NEW  ZenTomatoTests/Goldens/fortnight.md              committed. Reviewed by eye, once.
NEW  ZenTomatoTests/Goldens/empty.md                  committed.
EDIT ZenTomatoTests/SessionPlanFenceTests.swift       two column lists change. §4.4.
EDIT ZenTomatoTests/TodoistCacheTests.swift           decode tests for due. §4.2.
EDIT ZenTomatoTests/TaskCompletionTests.swift         the ordering claim. §4.3.
```

---

## 2. `StatsQuery` — the one counting rule

> *"Two counters that can disagree is how a number stops being trusted — and this is the number the
> whole app exists to produce."* (D15)

### 2.1 The shape, and why it makes a second counter awkward rather than merely discouraged

The mechanism is **not** a comment saying "use StatsQuery". It is that **no consumer is ever handed
anything countable.**

```swift
@MainActor
struct StatsQuery {
  init(context: ModelContext, calendar: Calendar = .current)

  /// The only method. There is no second one, and there is no accessor for rows.
  func period(_ range: StatsRange) -> StatsPeriod
}
```

Four properties do the work:

1. **`StatsQuery` has exactly one method and it returns a finished answer.** There is no
   `sessions(in:)`, no `distractions(for:)`, no `context` accessor. A screen that wanted to count
   something itself would have to open SwiftData, and §6 fails the build if it does.
2. **`StatsPeriod` stores answers, not material.** `pomodoroCount` is an `Int`. Nothing on it is a
   `PomodoroSession`, a `Distraction`, or a `CompletedTaskRecord`. There is nothing left to count.
3. **The rule itself is one failable initialiser on one `fileprivate` type inside
   `StatsQuery.swift`:**

   ```swift
   /// One block that counts. `nil` for everything that does not — and that
   /// `nil` is the entire counting rule, in one place, with no second copy.
   fileprivate struct CountedBlock {
     init?(_ session: PomodoroSession, calendar: Calendar)
   }
   ```

   `fileprivate` means no other file can hold one, so no other file can build a total from one.
4. **Today's number is the same function.** The stats screen's opening line is
   `query.period(.day(today)).pomodoroCount`. It is not a separate "count today" method, because a
   separate method is exactly the second counter this section exists to prevent.

### 2.2 The rules, encoded exactly as `F6.md` states them

Inside `CountedBlock.init?`, in this order, each an early return:

| Rule (`F6.md`) | Code |
|---|---|
| Breaks are not pomodoros | `guard session.kind == .work else { return nil }` |
| Abandoned blocks count for nothing | `guard session.wasAbandoned == false else { return nil }` |
| A day is the local calendar day of the block's **start** | `let day = StatsDay.containing(session.startedAt, in: calendar)` — `endedAt` is **never** passed to `StatsDay` anywhere in the tree |
| Names come from the snapshot | `session.taskTitle`, `session.projectTitle`. `CachedTask` / `CachedProject` are not fetched by `StatsQuery` at all |
| No-task rows group under the project, else under nothing | `taskTitle` stays `nil`; `projectTitle` stays `nil`; the *reader* supplies the words |

Two further facts, held outside `CountedBlock` because they are about rows the rule excludes:

- **Every fetched session, abandoned and break alike, contributes to an attribution table**
  `[UUID: (taskTitle: String?, projectTitle: String?, day: StatsDay)]`, keyed by `PomodoroSession.id`.
  Distractions and stops are placed through it. This is why an abandoned block's taps keep their
  task and their day even though the block itself counts for nothing.
- **A completion belongs to the day it was recorded** (D11), from `completedAt`, independently of
  any block.

### 2.3 The fetches — three, all bounded, no N+1

`F6.md` requires *"`#Predicate`-based SwiftData fetches with the date range pushed into the
predicate rather than filtering in memory."*

```
lower = start of range.first,           in `calendar`
upper = start of the day AFTER range.last, in `calendar`      HALF-OPEN. Exclusive upper.
```

An inclusive upper bound is the classic off-by-one here: it either drops or duplicates a block
that begins at midnight. Write it half-open and test it.

| # | Type | Predicate | Sort |
|---|---|---|---|
| 1 | `PomodoroSession` | `startedAt >= lower && startedAt < upper` | `startedAt` ascending |
| 2 | `Distraction` | `timestamp >= tapLower && timestamp < tapUpper` (§2.4) | `timestamp` ascending |
| 3 | `CompletedTaskRecord` | `completedAt >= lower && completedAt < upper` | `completedAt` ascending |

**Do not put `kind` or `wasAbandoned` into a predicate.** `BlockKind` is a `Codable` enum with no
raw value, which SwiftData splits into marker columns — F5's review was blocked once by exactly
this, on `DistractionKind`. The date bound is what makes the fetch cheap; kind and abandonment are
decided in Swift, in `CountedBlock.init?`, which is where the rule belongs anyway.

The sorts are not cosmetic. They are what makes the golden file stable.

### 2.4 Where a tap's day comes from — the one place the rule is subtle

A tap at 00:05 inside a block that began at 23:50 belongs to the day the **block** started. So a
tap's day is taken from its block's attribution row, never from its own timestamp. Consequences:

- The distraction fetch window must cover taps that fall outside the calendar range because their
  block began inside it. Compute it from fetch #1, which has already run:
  `tapLower = min(lower, earliest fetched startedAt)`, `tapUpper = max(upper, latest fetched endedAt)`.
  Still one bounded fetch; still no scan of a table designed to grow for the app's whole life.
- A tap whose `sessionID` matches no fetched session is **not dropped.** It is placed on the day of
  its own timestamp, with no task and no project name. `Distraction.swift` promises this in its own
  documentation — *"the feature that eventually displays these must show an unmatched row as 'no
  block' rather than treating it as an error"* — and a log that silently omits taps is the flattering
  record `PomodoroSession.swift` argues against. The engine has no path that produces one; the branch
  exists so that if one ever appears, it is visible rather than deleted. Test:
  `aTapWhoseBlockIsMissingStillAppears`.

### 2.5 A silence in `F6.md`, resolved here — taps inside a block that was stopped

`F6.md` and D15 exclude abandoned blocks from **counts of pomodoros**. Neither says what happens to
the taps recorded inside one. **Decision: a tap counts wherever it was tapped, including in a block
that was later stopped.**

Because: the tap is itself a finished, durable fact — it happened, and F5's whole design is that
the tap *is* the record; the point of the log is what interrupts you, and the block you bailed out
of is the most interesting one there is; D15's sentence is about the pomodoro count specifically
(*"42 pomodoros keeps meaning blocks you finished"*), not about the tally; and excluding them would
silently delete the taps that most likely explain the stop sitting three sections below.

**This must be named in the PR description** so the owner can rule otherwise. It is a one-line
change if they do.

### 2.6 `StatsPeriod` — the whole surface

Stored (four arrays and a range; nothing else):

```swift
struct StatsPeriod: Sendable, Equatable {
  let range: StatsRange
  let days: [StatsDayRow]          // ascending by day
  let projects: [StatsProjectRow]  // §3.4 ordering
  let completions: [StatsCompletion]
  let stops: [StatsStop]           // ascending by instant
}
```

Computed, so that no total can disagree with the rows it came from:

```
pomodoroCount        sum over days
focusedSeconds       sum over days
internalCount        sum over days
externalCount        sum over days
taskRows             projects flattened, re-sorted globally     (the screen's Tasks section)
distractionsByTask   days' taps regrouped by name               (the export's Distractions section)
oneOffCompletions    completions where wasRecurring == false
repeatingCompletions completions where wasRecurring == true
isEmpty              days, projects, completions and stops all empty
```

`StatsDayRow` carries `distractions: [StatsDistractionEntry]`, so the day sheet and the export's
by-task grouping are two views of one array rather than two arrays.

`StatsQuery` builds `days` and `projects` from the **same** `[CountedBlock]`, so agreement is
structural. It is still asserted:
`totalsAgreeBetweenDaysAndProjects` checks `period.pomodoroCount == projects.reduce(0, +)` and the
same for I and E.

### 2.7 `StatsDay` and `StatsRange`

```swift
struct StatsDay: Sendable, Hashable, Comparable {
  let year: Int; let month: Int; let day: Int
  let weekday: Int                      // Calendar's numbering: 1 = Sunday

  static func containing(_ instant: Date, in calendar: Calendar) -> StatsDay
  init(year: Int, month: Int, day: Int, weekday: Int)   // fixtures and tests only
}
```

`StatsDay` holds `weekday` **as a stored integer computed once, at query time**. This is the single
decision that makes the golden file stable on any machine: after this point there is no `Calendar`
and no `DateFormatter` anywhere in the export path, so there is nothing left for a region setting,
a first-day-of-week preference or a 12-hour clock to change. See §3.2.

`StatsClockTime` is the same idea for a tap's time and is nested inside
`StatsDistractionEntry` / `StatsStop` as two `Int`s (`hour`, `minute`), computed at query time.

```swift
struct StatsRange: Sendable, Hashable {
  let first: StatsDay
  let last: StatsDay                    // inclusive

  static func trailing14Days(endingOn: StatsDay, in: Calendar) -> StatsRange
  static func day(_ day: StatsDay) -> StatsRange
  var isSingleDay: Bool { first == last }
}
```

*Trailing 14 days* means **today and the thirteen days before it**, inclusive: fourteen calendar
days. Test `defaultRangeIsTrailing14Days` asserts `first` is exactly 13 days before `last` and that
`last` is today.

`StatsQuery` turns `first`/`last` into `Date` bounds with its injected `Calendar`. That conversion
can fail (`Calendar.date(from:)` is optional and force-unwrapping is banned here). On failure the
query returns `StatsPeriod.empty(for: range)`. One branch, one test, no `!`.

---

## 3. The export as a pure function

### 3.1 Signature

```swift
enum StatsMarkdown {
  static func document(for period: StatsPeriod) -> String
  static func filename(for range: StatsRange) -> String
}
```

`F6.md` writes it `makeMarkdown(from:range:)`. The range travels **inside** the period instead of
beside it, because two parameters that must agree are two parameters that can disagree — and the
one they would disagree about is the title of the document.

`document(for:)` takes a value, returns a string, and touches nothing else. That is what makes the
golden file possible, and the golden file is the strongest evidence available for a feature whose
acceptance criterion is a human reading a page.

### 3.2 Purity is structural, not promised

**`ZenTomato/Export/` contains no `Date`, no `Calendar`, no `TimeZone`, no `Locale`, no
`DateFormatter`, no `.formatted(`, no `ModelContext`, no `FileManager`.** All of it is checked by
§6. The export renders integers.

Dates and times are therefore rendered from tables in `StatsWords.swift`:

```swift
weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]   // indexed by StatsDay.weekday - 1
monthNames   = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
```

- **A date reads `Wed 19 Aug`.** `"\(weekday) \(day) \(month)"`. No zero padding on the day:
  `Wed 3 Sep`, not `Wed 03 Sep`.
- **A time reads `14:32`.** `String(format: "%02d:%02d", hour, minute)`. 24-hour, always, on every
  device. This is exactly the bug a `DateFormatter` with `"HH:mm"` produces on a phone set to
  12-hour time unless the locale is forced to `en_US_POSIX`; there is no formatter here, so there
  is no bug here.
- **The document is English.** The weekday and month tables are English literals and are not
  localised. `SPEC.md` names one reader and one paper notebook; a localised export cannot have a
  byte-identical golden file, and losing the golden costs more than translating a page nobody has
  asked to translate. Recorded so it is a decision rather than an oversight.
- **String ordering uses plain `<`**, never `localizedStandardCompare` or
  `localizedCaseInsensitiveCompare`. Code-point ordering is the same on every machine; a localised
  comparison is not, and the golden would churn between a developer's laptop and CI.

### 3.3 The document, exactly

Whitespace rules, because these are what make a golden churn:

- Line separator is `\n`. Never `\r\n`.
- Exactly one blank line between blocks. Never two.
- No trailing spaces on any line.
- The document ends with exactly one `\n`.

**Title.** `# ZenTomato — 2026-08-08 to 2026-08-21` (em dash, U+2014, spaced). Single-day range:
`# ZenTomato — 2026-08-23`. Dates here are zero-padded and sortable — a deliberate exception to
"no ISO", matching `F6.md`'s own example, for the same reason as the filename: *a file sitting in
Files a month later still says what it is.* **Every date inside the document reads `Wed 19 Aug`.**
Name this exception in the PR; a reviewer will otherwise flag it as a contradiction.

**Filename.** `ZenTomato-2026-08-08-to-2026-08-21.md`; single day `ZenTomato-2026-08-23.md`.

**Summary line.**

```
42 pomodoros · 17 hours 30 minutes · 23 distractions (14 internal / 9 external)
```

- Separator is `" · "` — U+00B7 with a space either side, matching `DistractionTally`.
- `1 pomodoro` / `N pomodoros`. `1 distraction` / `N distractions`.
- Duration: sum of `max(0, endedAt - startedAt)` over counted blocks, **truncated to whole
  seconds, then to whole minutes** — seconds are discarded, not rounded. `h = total / 3600`,
  `m = (total % 3600) / 60`. Rendered `"17 hours 30 minutes"`; `"1 hour 1 minute"`;
  `"30 minutes"` when `h == 0`; `"17 hours"` when `m == 0` and `h > 0`; `"0 minutes"` when both are
  zero. The clamp at zero exists because F5 found and fixed a backward clock jump that could write
  `startedAt` after `endedAt`; a negative duration in the header would be the loudest possible
  symptom of the next one.
- Distractions: `0` renders `no distractions` with **no** parenthetical. Only internal renders
  `(14 internal)`. Only external renders `(9 external)`. Both renders `(14 internal / 9 external)`.
- **The abandoned rate is not here.** D15 rejected it by name: *"it makes the first thing you see
  every time a measure of how often you gave up, which is a different document from the one this is
  meant to be."*

**Section order — an order of questions, not five buckets (D15).**

```
## Days            when
## Projects        where the time went
## Completed       what came out of it            (D11, one-offs)
## Repeating       the habits                     (D21)
## Distractions    what interrupted me, by task
## Stopped early   where I bailed, and why        (D13)
```

**A section with nothing in it is omitted entirely.** Never an empty table, never a heading with
nothing under it.

**`## Days`** — a Markdown pipe table, ascending. A day appears if anything happened on it: a
counted pomodoro, a tap, or a stop. A day with taps but no finished pomodoro shows `0`.

```
| Date       | Pomodoros | I | E |
|------------|-----------|---|---|
| Wed 19 Aug | 6         | 3 | 1 |
| Thu 20 Aug | 4         | 2 | 2 |
```

Column width = the longest cell in that column including the header, counted in `Character`s. One
space of padding either side. Cells left-aligned, padded on the right. The separator row is
`|` + `-` repeated `width + 2` + `|`. `F6.md`'s sample is hand-typed with wider padding; the golden
will differ from it cosmetically and that is expected.

**`## Projects`**

```
- **Thesis** — 14 pomodoros (I 7 / E 2)
  - Ch.3 draft — 9
  - Reading — 5
- **Admin** — 3 pomodoros (I 1 / E 0)
```

`(I n / E m)` is always rendered, including zeros — that is `F6.md`'s own sample. Task sub-rows show
the count only, indented two spaces. Blocks attached to a project but not to a task contribute to
the project's total and produce **no** sub-row. Blocks attached to neither appear as a final group
headed `**No task**` with no sub-rows, which is `F6.md`'s word for that case; it reads slightly oddly
as a project heading and is followed literally rather than improved on. Ordering: pomodoro count
descending, then title ascending (plain `<`). The `No task` group is always last.

**`## Completed`** — one-offs only, ascending by `completedAt`, ties broken by title.

```
- Wed 19 Aug — Ch.3 draft
```

**`## Repeating`** (D21) — grouped by title snapshot; the weekdays it was closed on, deduplicated,
in the order `Mon, Tue, Wed, Thu, Fri, Sat, Sun`, joined `", "`.

```
- Budget with YNAB by 7:30 AM — Mon, Tue, Wed, Fri, Sat
```

Group ordering: distinct-day count descending, then title ascending. **Known limitation, stated
because it is the most likely first format revision:** over a fortnight, two Mondays collapse to one
`Mon`. That is exactly `F6.md`'s ratified sample, so it ships as specified; `F6.md` predicts *"one or
two format revisions after you see real data"* and the golden makes that revision cheap.

**`## Distractions`** — grouped by name, which is `taskTitle ?? projectTitle`, and `No task` when
neither. No blank line between a `###` heading and its first bullet; one blank line between groups.
Within a group, ascending by instant. Group order: tap count descending, then name ascending; `No
task` last.

```
### Ch.3 draft
- Wed 19 Aug, 14:32 — **I** — kept re-reading the same paragraph
- Wed 19 Aug, 14:41 — **E** — roommate came in
- Thu 20 Aug, 09:12 — **I** — *(no note)*
```

A `nil` note renders `*(no note)*`. *"A tap with no sentence is data; an empty line looks like a
bug."*

**`## Stopped early`** (D13, D15) — its own section, never a line among the taps. Ascending.

```
- Wed 19 Aug, 15:10 — Ch.3 draft — "meeting moved up an hour"
- Fri 21 Aug, 11:02 — Reading list — "too tired to take any of it in"
```

- Every abandoned block appears, whatever its kind. A stop taken during a break cost a written
  sentence too, and a section called "where I bailed" that omits it is not answering its question.
  A non-work block is named by its kind rather than by an attachment it never had:
  `- Fri 21 Aug, 11:02 — short break — "…"`.
- `abandonReason == nil` — possible for rows written before D13, or through the alarm's Stop —
  renders `*(no reason recorded)*` in place of the quoted sentence.
- Straight double quotes `"…"`, not typographic ones: the reason is quoted user text and a curly
  quote inside it would then be ambiguous.

**Person-written text** — notes, stop reasons, task and project titles — has every run of
whitespace, including newlines, collapsed to one space, and is then trimmed. Nothing else is
escaped: these are the person's own words and a backslash in front of an asterisk is noise in a
paper notebook.

**The empty document.** When `period.isEmpty` — no counted pomodoro, no tap, no stop, no completion
in range — the whole document is:

```
# ZenTomato — 2026-08-08 to 2026-08-21

No pomodoros in this range.
```

Note the precise boundary: *empty* means nothing at all happened. A range with three stops and no
finished blocks is **not** empty — it renders a header saying `0 pomodoros` and a `## Stopped early`
section, and no other section. Test both.

### 3.4 No identifiers, anywhere

Not a Todoist id, not a `UUID`, not a session id. `noIdentifiersInOutput` runs the fixture document
through a UUID regex and asserts zero matches, and asserts that none of the fixture's Todoist ids
appears as a substring. The fixture's ids must be distinctive strings (`"td-task-0001"`, not `"1"`)
or the test proves nothing.

### 3.5 Delivery

`ZenTomato/Views/StatsExportFile.swift`:

1. Take `StatsMarkdown.document(for:)` and `StatsMarkdown.filename(for:)`.
2. Delete any file this app previously wrote into `FileManager.default.temporaryDirectory`, so the
   directory does not accumulate a fortnight per share.
3. Write the document UTF-8 to `temporaryDirectory/<filename>`.
4. Hand `ShareLink(item: url)` that URL.

A real file with a real name, so it arrives in Files as `ZenTomato-2026-08-08-to-2026-08-21.md`
rather than as `Untitled.txt`. This is the only I/O in the feature and it is deliberately outside
`ZenTomato/Export/`, which is what keeps the fence in §3.2 absolute. It runs from a `.task`, never
from `body`. A write failure disables the share control and shows one plain sentence; it never
crashes and never shares a stale file.

### 3.6 The golden files

Two committed documents, `ZenTomatoTests/Goldens/fortnight.md` and `.../empty.md`.

- The test builds a `StatsPeriod` **by hand** — `StatsPeriodFixture` — with no store, no clock and
  no calendar involved, calls `StatsMarkdown.document(for:)`, and compares byte for byte.
- The golden is read from the source tree at `#filePath`, as `LaunchBackgroundTests.swift:70`
  already does. It is not a bundle resource, so `project.yml` needs no change and there is no silent
  "the resource was not copied" failure mode.
- The test must fail loudly if the file is missing or empty — `#require` the contents and assert
  non-empty — so a deleted golden can never pass vacuously.
- On mismatch the failure message prints the first differing line number and both lines with three
  lines of context either side. A 2,000-character `#expect(a == b)` diff is unreadable in a CI log,
  and an unreadable failure is a failure somebody force-pushes past.
- The fortnight fixture must contain, deliberately: a block spanning midnight; an abandoned block
  with a reason and one without; a break; a tap with a note and one without; a task-attached block,
  a project-only block and a block attached to neither; one recurring completion closed on several
  days including twice on one day, and two one-off completions; a title with a `·` in it and one
  with an apostrophe.

**Nobody may regenerate a golden to make a test pass.** A golden changes only in a commit whose
message says which format decision changed and why. It is reviewed by eye once and defended by a
machine forever.

---

## 4. D21 — a completion records whether the task was recurring

### 4.1 The visible argument with `F3-contract.md` §3.2

That table lists `due` among the fields deliberately not mirrored, and says adding one must be
*"a visible argument with this table rather than a small reasonable commit."* This is it.

**We are not mirroring `due`.** We mirror one boolean derived from it. There is no date, no
`string`, no `lang`, no `timezone`, and nothing from which a schedule could be reconstructed —
which is precisely D21's own fence: *"It is not a recurrence rule, a schedule, a due date, or
anything that could reconstruct one."*

Apply D16's test — *would I write this the same way if bi-directional sync were never coming?* Yes.
It exists for the export, the export is this feature, and it would be equally right if v1.5 never
happened. It is also not the shape D16 forbids: it is meaningful on the day it lands, not `nil`
today and meaningful after sync.

`docs/plans/F3-contract.md` §3.2 gets one added sentence recording that `is_recurring` moved off
that list under D21. That is the only change to a shipped contract document.

### 4.2 The wire format

```swift
struct TodoistTaskDTO: Decodable, Sendable, Equatable {
  // … the five existing fields, unchanged …

  /// Todoist's due information, reduced to the one fact D21 needs. `nil` when
  /// the task has no due date at all — which is a normal task, not a failure.
  let due: Due?

  struct Due: Decodable, Sendable, Equatable {
    let isRecurring: Bool
  }
}
```

**Decoding must be tolerant in exactly two places, and a test proves each:**

- `due` is decoded with `decodeIfPresent`, so both a missing key and an explicit `null` produce
  `nil`.
- `Due` gets a hand-written `init(from:)` doing
  `isRecurring = try container.decodeIfPresent(Bool.self, forKey: .isRecurring) ?? false`.

A required field here would make *every task on the account fail to decode* the day Todoist ships a
shape we did not anticipate — emptying the picker, on a real phone, in nobody's test. The three
`TodoistCacheTests` additions: a task with no `due` key; a task with `"due": null`; a task with a
`due` object containing `date`/`string`/`lang` but no `is_recurring`. All three must decode, and
all three must be `isRecurring == false`.

A fourth test decodes the full documented shape quoted in §0 and asserts `isRecurring == true` for
`"is_recurring": true`. **That test is the one that catches the wrong key**, and it must use the
real snake-case JSON, not a hand-built Swift value.

The endpoint set does not change. `scripts/todoist-allowed-endpoints.txt` is untouched,
`TodoistAPI.allEndpoints` is still four, and the single `POST` in `TodoistAPI.swift` is still the
close command.

### 4.3 Capturing it — the ordering that decides whether it is ever true

`CachedTask` gains `var isRecurring: Bool = false`, set from `dto.due?.isRecurring ?? false` at the
one insert in `TodoistCacheStore.replaceEverything`.

`CompletedTaskRecord` gains `var wasRecurring: Bool = false`. **The initialiser parameter has no
default.** The stored property's default exists only so SwiftData can migrate existing rows; the
initialiser's absence of one is what forces the single call site to state the answer, and what would
force any future call site to as well.

`TaskCompletion.recordLocally` — **read before you delete:**

```
1. fetch the CachedTask row for taskID           ← recurrence is read HERE
2. insert CompletedTaskRecord(…, wasRecurring:)
3. delete the CachedTask row
4. save
```

Today's code deletes the cached row and saves in one step. Doing the delete first, or reading
recurrence from a row already deleted, yields `false` on every completion, forever, silently — the
exact failure D21 warns about, arriving through the door nobody was watching. `RecurrenceCaptureTests`
must contain `recurrenceIsReadBeforeTheCachedRowIsDropped`, **verified to fail when the two steps
are swapped**, and the PR must say it was verified that way.

The second-attempt path in `recordLocally` (record alone, after a rollback) must carry the same
boolean. A retry that quietly writes `false` is the same bug with a rarer trigger.

**When the task is not in the mirror** — signed out, cache cleared, or a plan item for a task the
last refresh did not return — `wasRecurring` is `false` and the completion lands in `## Completed`
rather than `## Repeating`. `Bool?` is not available: `discouraged_optional_boolean` is an enabled
lint rule in this repository and D21 says "one boolean". Document the consequence on the property in
plain words, and name it in the PR. It is a small, honest, visible loss; a third state would be a
larger, quieter one.

### 4.4 The two fence tests that must change

`ZenTomatoTests/SessionPlanFenceTests.swift`:

- `completionRecordIsThreeColumns` → **rename** to `completionRecordIsFourColumns`, expect
  `["taskID", "titleSnapshot", "completedAt", "wasRecurring"]`, and **rewrite its doc comment**. Its
  current text says a fourth column would make it a task list; the new text must say why this
  particular fourth column does not, citing D21. F5's review closed the same class of finding three
  times: a doc comment that still claims the old guarantee is the sentence that stops the next reader
  checking.
- `theLocalCopyHasNoInventedColumns` → the `CachedTask` set gains `"isRecurring"`, and the doc
  comment gains one sentence saying this column is a field Todoist sent, which is what that test
  actually asserts.

Neither test may be deleted or weakened. `everySavedTypeIsInTheSchema` gains the new argument at its
`CompletedTaskRecord` insert.

### 4.5 Migration

Two new non-optional `Bool` properties, each with a stored default of `false`. SwiftData's
lightweight migration adds them to existing rows without a migration plan. `CachedTask` rows are
replaced wholesale on every refresh, so they self-correct within one foreground.
`CompletedTaskRecord` is append-only, so rows written before this feature read `false` forever —
correct, since nothing recorded what was true then, and guessing would be worse. Say so in the PR.

---

## 5. D21b — a task completed during a sprint does not come back into it

Holds for **every** task, so it needs no recurrence knowledge and cannot be wrong about one it
guessed at. In memory, one sprint, gone at launch.

### 5.1 Where it lives

```swift
/// The tasks ticked off since this sprint began. In memory, one sprint, never saved.
@MainActor @Observable
final class SprintCompletions {
  private(set) var taskIDs: Set<String> = []

  func record(taskID: String)          // called after Todoist confirms a close
  func contains(_ taskID: String) -> Bool
  func clear()                         // called when a sprint ends
}
```

Nothing persists across launches. `CompletedTaskRecord` is the history, and *"a second store of the
same fact is a second thing that can disagree."* It is `@Observable` so the picker redraws the
instant a task leaves it, with no notification and no manual refresh.

`record` is called from the completion path on `.closed` **only**. `.alreadyGone` means the task was
finished or deleted somewhere else, which this app did not do — see §8, risk 9.

### 5.2 What clears it, with the proof that `TimerEngine` needs no changes

`SprintBoundaryObserver` follows the engine exactly as `BlockPhaseObserver` does — an `Observations`
loop over `@Observable` values, delivering only on change — and clears the set when:

```
engine.isRunning == false  &&  engine.completedInSprint == 0
```

That is the whole rule, and it is sufficient because `TimerCycle` and `TimerEngine` between them
guarantee that the condition is true **exactly** when no sprint is in progress:

| Way the engine comes to rest | `completedInSprint` | Cleared? | Right? |
|---|---|---|---|
| A long break ended (`endsSprint`) | `0` — `TimerCycle.next` resets it | yes | yes: the sprint ended |
| `stop(reason:)` | `0` — `goIdle(kind: .work, completedInSprint: 0)` | yes | yes: D21b says stopping clears it |
| A block ended, auto-start off, mid-sprint | `≥ 1` — a finished work block increments | no | yes: the sprint continues |
| Launch, never started | `0` | yes | harmless: the set is already empty in a fresh process |
| A block running | n/a, `isRunning` is true | no | yes |

There is no fourth way to come to rest: `goIdle` is the only path to `isRunning == false`, and it
takes its count from the transition. Skip was removed by D13, so there is no abandoned-but-
sprint-continuing case. **`TimerEngine.swift` therefore has zero changed lines**, and the engine
learns nothing about Todoist — which is the same guarantee `SessionAttaching` was built to give and
the same one F4 held.

`SprintBoundaryObserver` is created and `start()`ed in `ZenTomatoApp` beside the music observer, and
it must `cancel()` its task in an `isolated deinit`, exactly as `BlockPhaseObserver` does.

### 5.3 How it reaches the plan without the plan learning about the timer

`SessionPlanStore.init` gains `completedThisSprint: SprintCompletions`. The store asks a set whether
it holds a string. It gains no knowledge of blocks, sprints, breaks or the engine.

Two changes inside it:

- **`takeNextAttachment()`** — before taking the item at `currentIndex`, advance past any item where
  `kind == .task && completedThisSprint.contains(todoistID)`. That is the existing `stepOver`
  semantics: the cursor moves, the item is not removed, not marked and not reordered. The moved
  cursor is persisted as it already is. Projects are never skipped; D21b is about tasks.
- **`replacePlan(with:)`** — drop selections already in the set. The picker will not offer them, so
  this is belt and braces; it is worth one line because it makes the rule a property of the store
  rather than of a screen.

`SessionPlanItem` gains **no field.** `planItemHasFourStoredProperties` must still pass untouched —
this is exactly the fence D17 built, and D21b is precisely the sort of reasonable-looking pressure it
was built against.

### 5.4 How it reaches the picker without the picker learning about the timer

`PlanBuilderView.picker` gains one clause:

```swift
tasks: tasks
  .filter { completedThisSprint.contains($0.id) == false }
  .map { … }
```

`PickerScreenModel` is unchanged: it is a pure value built from whatever rows it is given, and it is
simply given fewer. It gains no reference to the set, no reference to the engine, and no new field.

### 5.5 Tests

| Test | Asserts |
|---|---|
| `aTaskCompletedThisSprintLeavesThePicker` | recorded id is absent from `PickerScreenModel.tasks`; every other task is still there |
| `theSetEmptiesWhenALongBreakEnds` | drive the engine through a sprint of one; the set is empty afterwards |
| `stoppingEmptiesTheSet` | `stop(reason:)` clears it |
| `aBoundaryMidSprintDoesNotEmptyTheSet` | block ends with auto-start off, one completed ⇒ kept |
| `thePlanStepsOverATaskCompletedThisSprint` | `takeNextAttachment()` returns the item after it, cursor persisted |
| `nothingAboutD21bIsSaved` | new store, new process ⇒ the set is empty; no new SwiftData entity exists |

---

## 6. Concurrency posture

**Swift 6, `SWIFT_STRICT_CONCURRENCY = complete`. `ModelContext` is not `Sendable`.**

- `StatsQuery` is `@MainActor`, holds a `ModelContext`, and is the only thing in the feature that
  does. Everything it returns — `StatsPeriod` and every type it contains — is a plain immutable
  `Sendable` value holding no model object and no reference. Nothing needs `@unchecked`, nothing
  needs `nonisolated(unsafe)`, and neither appears in the diff.
- `SprintCompletions` and `SprintBoundaryObserver` are `@MainActor`, matching the engine and the plan
  store, so every hand-off is a plain method call with no thread hop and nothing that can arrive out
  of order. F4's review is the argument: the ordering bugs it found all lived at suspension points
  that did not need to exist.
- **`StatsMarkdown` is `nonisolated`** — no actor, no state, no globals. A pure function of a
  `Sendable` value.

### 6.1 Where the queries run, so a fortnight does not block a redraw

Three rules, in order of how much they actually buy:

1. **`period(_:)` is never called from a `body`.** It is called from `.task` and from `.onChange` in
   `StatsScreenModel`, and the result is stored. A `body` reads stored values only. This is the rule
   that matters; a query inside `body` runs on every redraw and no amount of speed saves it.
2. **The screen paints today's number before it computes the range.** `StatsScreenModel.load()` runs
   `period(.day(today))` first and publishes it, then runs `period(range)`. The first call touches
   one day. That serves the ratified design — *"the number, first"* — and the performance posture
   with one ordering, not two mechanisms.
3. **The work is bounded by construction:** three fetches, all date-bounded in the predicate, all
   sorted in the descriptor, no fetch inside a loop, no second query per row, no live-cache lookup.
   A fortnight is on the order of a hundred blocks and a few hundred taps.

**This is measured, not asserted.** The PR must carry the wall-clock time of `period(_:)` over a
store seeded with a year of realistic data (`StatsStoreFixture.year()`), taken on the pinned
simulator. **Budget: 16 ms — one frame at 60 Hz.**

**If it exceeds the budget, the escalation is already decided and is not the engineer's to invent:**
move the fetches into a `@ModelActor` built from the app's `ModelContainer` (which *is* `Sendable`),
keep `StatsPeriod` as the only thing that crosses the boundary, and make `period(_:)` `async`. The
seam is unchanged by that move, which is the point of returning a value type in the first place. Do
**not** take that step pre-emptively: it adds a suspension point, and a suspension point is where
this project's last two features found their real bugs.

Whatever the number is, it goes in the PR. `CLAUDE.md`: *"Assertions are not evidence."*

---

## 7. Scope fence

### 7.1 Greppable, and executed by `ZenTomatoTests/StatsFenceTests.swift`

`StatsFenceTests` reads the source tree through `#filePath`, as `LaunchBackgroundTests` already does.
A fence nobody runs is a fence that does not exist.

**Gamification — `SPEC.md`'s out-of-scope list, and D15's note that a stats screen is exactly where
this pressure appears first.** Zero hits, case-insensitively, across every file this feature adds or
edits:

```
import Charts   Chart(   BarMark   LineMark   AreaMark   SectorMark   RuleMark   PointMark
Gauge(   ProgressView(   .progressViewStyle   Canvas(   .trim(from:
streak   badge   trophy   medal   award   milestone   achievement   level up   xp
best   personal record   record day   bestDay   longest   average   trend   comparison
vs last   change from   improvement   goal   target   quota   ring
```

`best` and `average` are on the list on purpose: "your best day" and "your daily average" are the two
that arrive looking like statistics rather than like gamification.

**No capture surface.** `TextField|SecureField|TextEditor|.searchable|UITextField` = **0** across
`ZenTomato/Stats/`, `ZenTomato/Export/`, `ZenTomato/Sprint/` and `ZenTomato/Views/Stats*`. Extend
`NoCaptureSurfaceTests` to cover the new files rather than writing a second one.

**One counting path.**

- `import SwiftData` under `ZenTomato/Stats/` = exactly one file, `StatsQuery.swift`.
- `import SwiftData` under `ZenTomato/Export/` and `ZenTomato/Sprint/` = **0**.
- `FetchDescriptor|#Predicate|PomodoroSession|CompletedTaskRecord|Distraction\b` under
  `ZenTomato/Export/` and `ZenTomato/Views/Stats*` = **0**.
- `wasAbandoned` across the whole tree appears only in `PomodoroSession.swift`, `TimerEngine.swift`
  and `Stats/StatsQuery.swift`.
- `.endedAt` never appears in the same expression as `StatsDay`, anywhere.

**The export is pure.** Under `ZenTomato/Export/`, all **0**:

```
Date(   Calendar   TimeZone   Locale   DateFormatter   ISO8601   .formatted(
FileManager   ModelContext   URLSession   localizedStandardCompare   localizedCaseInsensitiveCompare
```

**Todoist.** `scripts/todoist-allowed-endpoints.txt` unchanged. `TodoistAPI.allEndpoints.count == 4`.
Exactly one `Method.post`, and it is `closeTask`. `create|update|move|comment|reopen|POST /tasks"` = 0.
`make check-todoist` green.

**Out of v0.1 entirely.** `WCSession|watchOS|WatchConnectivity|CloudKit|NSUbiquitous|NSPersistentCloudKit|
macOS|AppIntent|WidgetKit|Theme|colorScheme override` = 0 in the diff.

**Swift hygiene.** `try!|as!|fatalError|nonisolated(unsafe)|@unchecked Sendable|!` force-unwrap = 0.
`swiftlint --strict` green with **no limit raised** — type bodies 250 lines, files 400 lines, and
`.swiftlint.yml` has zero changed lines except, optionally, one added `custom_rules` entry. Find a
seam; `StatsMarkdownSections.swift` exists because that is what a seam looks like.

**Zero-changed-line files.** `git diff main --stat` must be empty over every path in §1.3. Paste the
command and its output in the PR, as F4's and F5's reviews did.

### 7.2 The entry point, and the rule it must not break

The stats screen is reached from a control on the timer screen beside the existing gear
(`TimerScreen.swift:479`), added the same way: an overlay in space that is already empty, so the
countdown numeral moves by zero points.

**It is present and enabled in every state — running, idle, first launch, no data.** D19 states the
general rule: *"when a rule about movement conflicts with an affordance somebody needs, reserve the
space."* And F3 lost a whole feature to an affordance suppressed to protect something else. A stats
button that appears only when there is data is unreachable on exactly the day somebody wants to check
whether anything was recorded.

Accessibility label `"Statistics"`, `accessibilitySortPriority(0)` like the gear, muted grey ink, a
44-point hit area, `Typography.label` so the glyph grows with Dynamic Type. No new colour role, no
new spacing token, no literal size.

`TimerScreen.swift` carries known residue from D13 — `Button("Skip") { }` in preview scaffolding and
five doc comments describing Skip as shipping — recorded in F5's review as an `F2b` retrofit.
**Do not fix it here.** F5's review already ruled that touching that file for anything but its own
reason collides on rebase. Touch it for the button and nothing else.

---

## 8. Risks, most likely first

1. **A second counting path appears anyway**, most likely as "today's count" computed on the screen
   because it is one line. Then the screen and the export disagree and the number stops being
   trusted, which is D15's stated fear about the one number the app exists to produce. Mitigated by
   `period(.day(today))` being the *only* way to get it, by `StatsPeriod` holding no material to
   count, and by §7.1 executed as a test.
2. **`wasRecurring` is silently always `false`.** Three doors: the wrong JSON key (§0), the cached
   row deleted before it is read (§4.3), or the initialiser given a default nobody notices. It fails
   silently in all three — `## Repeating` is simply empty and looks like a quiet fortnight. Mitigated
   by real snake-case JSON in the decode test, by an ordering test verified to fail when the two steps
   are swapped, and by a required initialiser parameter.
3. **Adding `due` to the task DTO breaks decoding for every task on a real account.** Not silent, but
   it presents as an empty picker on the owner's phone and nowhere else. Mitigated by
   `decodeIfPresent` on both levels and three tolerance tests.
4. **Scope pressure — "the worst of the project" (`F6.md`).** A trend line, a best day, a progress
   ring, a streak. Each arrives as one small commit that looks like statistics. Mitigated by §7.1
   being greppable and executed, and by pointing the adversarial review at it specifically.
5. **The golden churns for reasons that are not about readability** — a locale, a time zone, a
   region setting, a `localizedStandardCompare`. Mitigated structurally: after `StatsQuery` there is
   no `Calendar`, no `Locale` and no `DateFormatter` in the export path at all, so there is nothing
   left to vary.
6. **The format is wrong and only real data will say so.** `F6.md` predicts one or two revisions.
   The `## Repeating` weekday collapse (§3.3) is the most likely. This is not a defect to prevent —
   it is why the device check is "export a real day and read it next to the Rhodia", and why the
   golden exists to make the revision cheap and visible.
7. **The screen blocks a redraw on a long range.** All-time after months is `F6.md`'s named risk.
   Mitigated by the 14-day default, by today-first painting, by never querying from `body`, and by a
   measured 16 ms budget with a pre-decided escalation (§6.1).
8. **D21b clears at the wrong moment.** Over-clearing is harmless; under-clearing offers back work
   already done, which is the bug D21b exists to fix. The `isRunning && completedInSprint` rule is
   argued from `TimerCycle` in §5.2 and each of the four resting states has its own test.
9. **`.alreadyGone` does not enter the D21b set, and its cached row is not deleted either** — so a
   task finished in Todoist on another device can still be offered until the next refresh. This is
   pre-existing F3 behaviour, not introduced here, and widening D21b's trigger would change its
   meaning from "completed" to "believed gone". Recorded, not built. Name it in the PR.
10. **Taps inside stopped blocks (§2.5)** is a counting decision `F6.md` does not make. If the owner
    reads D15's *"excluded from every count"* as covering taps, the header numbers change and the
    golden changes with them. Named in the PR before the review, not after.
11. **`TimerScreen.swift` collides on rebase** with the outstanding `F2b` Skip-residue retrofit.
    Mitigated by touching it for one button and nothing else.
12. **Two new non-optional `Bool` columns migrate an existing on-device store.** Lightweight
    migration handles it, but the owner's phone holds real data from F2–F5 and this is the first
    schema change since. Verify against a store carried forward — reinstall over, do not delete —
    and say so in the PR.

---

## 9. The A/B seam

Strictly disjoint by file. Neither engineer opens a file the other owns.

### 9.1 The handoff, and it is the only sequencing constraint

**A's first commit is the `ZenTomato/Stats/` value types — everything except `StatsQuery.swift` — and
the `SprintCompletions` public surface.** B starts from that commit. Everything after it runs in
parallel.

The interfaces B builds against, frozen by that commit:

```swift
StatsMarkdown.document(for: StatsPeriod) -> String
StatsMarkdown.filename(for: StatsRange) -> String
SprintCompletions.record(taskID:) / .contains(_:) / .clear()
```

`StatsPeriod: Equatable` is load-bearing for the cross-check below and must be in that first commit.

### 9.2 The one test that proves the seam holds

`theFixtureStoreProducesTheFixturePeriod` — **owned by A** — builds A's `StatsStoreFixture` in a real
store, runs `StatsQuery` over it with a fixed calendar and time zone, and asserts the result equals
B's hand-built `StatsPeriodFixture.fortnight`.

It is the most valuable test in the feature. It is what makes the golden file evidence about the
*app* rather than evidence about a string function: it ties the document a human reads to rows a
timer actually wrote. It needs both engineers' fixtures, so it lands last, and it is the merge gate.

### 9.3 Engineer A — the rule and the record

**Owns, in full:**

- All of `ZenTomato/Stats/` (ten new files)
- All of `ZenTomato/Sprint/` (two new files)
- `ZenTomato/Plan/SessionPlanStore.swift` (edit)
- `ZenTomato/Models/CompletedTaskRecord.swift`, `ZenTomato/Models/CachedTask.swift` (edits)
- `ZenTomato/Todoist/TodoistDTO.swift`, `TodoistCacheStore.swift`, `TaskCompletion.swift` (edits)
- `docs/plans/F3-contract.md` §3.2 (one sentence)
- Tests: `StatsCountingTests`, `StatsRangeTests`, `StatsQueryStoreTests`, `RecurrenceCaptureTests`,
  `SprintCompletionsTests`, `Support/StatsStoreFixture.swift`
- Test edits: `SessionPlanFenceTests`, `TodoistCacheTests`, `TaskCompletionTests`

**Never opens:** anything under `ZenTomato/Views/`, `ZenTomato/App/`, `ZenTomato/Export/`, or
`ZenTomatoTests/Goldens/`.

**Owns these `F6.md` tests:** `dayBoundaryUsesStart`, `abandonedExcluded`, `breaksNotCounted`,
`snapshotNamesUsed`, `noTaskRowsGroupUnderProject`, `defaultRangeIsTrailing14Days`, and
`theFixtureStoreProducesTheFixturePeriod`.

### 9.4 Engineer B — the two readers

**Owns, in full:**

- All of `ZenTomato/Export/` (three new files)
- All of `ZenTomato/Views/Stats*.swift` (five new files)
- `ZenTomato/Views/TimerScreen.swift`, `TimerView.swift`, `PlanBuilderView.swift` (edits)
- `ZenTomato/App/ZenTomatoApp.swift` (edit)
- `ZenTomatoTests/Goldens/fortnight.md`, `ZenTomatoTests/Goldens/empty.md`
- Tests: `StatsMarkdownGoldenTests`, `StatsMarkdownSectionTests`, `StatsScreenModelTests`,
  `StatsFenceTests`, `Support/StatsPeriodFixture.swift`
- Test edit: `NoCaptureSurfaceTests` (extend to the new directories)

**Never opens:** anything under `ZenTomato/Stats/`, `ZenTomato/Sprint/`, `ZenTomato/Todoist/`,
`ZenTomato/Models/`, `ZenTomato/Plan/`.

**Owns these `F6.md` tests:** `goldenExport`, `skippedNoteRendersMarker`, `emptyRangeIsReadable`,
`noIdentifiersInOutput`, `statsScreenMatchesExport`.

### 9.5 Evidence the PR must carry

`CLAUDE.md`: *"A feature is done when a command returns pass and the output is in the PR."*

1. `make ci` — full output, as F5's review pasted it.
2. `git diff main --stat` over every path in §1.3, showing empty.
3. The `StatsFenceTests` greps and their zero counts.
4. The `period(_:)` timing over a year of fixture data, against the 16 ms budget.
5. The golden file diff.
6. **One real study day's exported Markdown, pasted verbatim.** `F6.md`: *"it is the evidence."*
   Not gated on a device — this one needs data, not hardware.
7. Named explicitly for the owner to rule on: §2.5 (taps in stopped blocks), §3.3 (the ISO title
   exception, the `## Repeating` weekday collapse, breaks in `## Stopped early`), §4.3 (a completion
   with no cached row reads as not-recurring), risk 9.

---

*Written by the solutions architect, 2026-08-23. No app code in this document is authoritative over
`docs/specs/SPEC.md`. Where this file and `docs/plans/F6.md` disagree, `F6.md` wins.*
