# F7b — review log

**Unit:** `F7b` — a refused read is not an empty one. Retrofit on `F7`.
**Branch:** `F7b/a-resend-cannot-become-a-second`
**Plan:** `docs/plans/F7b.md`
**Register:** `O47` (open, `@Review`) — in `docs/plans/00-register.md` **and** in `docs/reviews/OPEN.md`.
**Review passes:** two. The second returned two blocking findings; both were real and both are fixed.

## What was reviewed

One defect, one file of production code, one file of tests. The finding that opened the unit:
`WatchTapInbox.receive(_:)` used `try? context.fetch(...)`, which maps a **refused read** and an
**empty read** onto the same branch — and that branch falls through to the insert. A redelivered
wrist tap whose duplicate check was refused became a second row for one press.

## The six dimensions

| Dimension | Finding |
|---|---|
| **Correctness** | The defect itself. A thrown fetch became "nothing found" and fell through to the insert. Fixed: the throw now reaches `receive(_:)` and returns `Outcome.unreadable` without inserting. Proved by `F7b-M1` and `F7b-M4` — the defect and the reviewer's own literal trigger, each re-applied to the fixed tree, each caught by both refused-read tests, each printing `outcome → .failed`, which is the insert happening. |
| **Security** | The project's own data invariant — *the distraction log must not inflate* — was the thing being violated. No secrets, no network, no PII surface touched. `Distraction.id` is unchanged; no schema change was made, so the owner's real store is untouched. |
| **Performance** | Unchanged, and now one call shallower: the private `fetchDistractions(_:)` went with the seam, so `receive(_:)` fetches directly. The same single fetch with the same `fetchLimit = 1`. No new allocation, no new I/O, nothing unbounded. |
| **Code quality** | The new `Outcome.unreadable` reuses a word the codebase already owns: `StatsQuery.period(_:)` returns `.unreadable(for:)` for the same event, and `StatsScreenCopy.unreadableHeading` is *"Couldn't read your history"*. Two files in the same app disagreed about whether a SwiftData read can be refused; they now agree and use the same noun. **`WatchTapInbox` gained no new surface at all.** The first build added an injectable `refusableFetch` closure; the second review deleted it, and the type is back to one stored property. |
| **Contract compliance** | No spec delta is owed. `SPEC.md` and the function's own doc comment already state the guarantee — *"two rows where there was one tap inflates the counts the fortnightly review reads — quietly, plausibly, and always upward"* — and the commit that introduced the file is titled *"the phone writes the row, and a resend cannot become a second"*. Nothing user-visible changed: the sole caller's `guard ... == .recorded` already drops a non-`.recorded` outcome. No Todoist write, no new dependency, no capture surface. |
| **Process compliance** | `docs/plans/F7b.md` was written and saved **before** any Swift file was touched — the `F4c` failure was a plan committed one second after the code it gates. The red run was performed and its real output recorded before the fix — and it is now marked in the plan as belonging to the superseded build, because the tests it ran were the ones the second review found to be testing the wrong line. Six mutations were applied to the shipped tree, run, and reverted; none is recorded as *prevented by construction*. Every mutation was re-applied and re-run against the rebuilt tree after the review rather than carried forward, which is `C32`'s precedent. `F7b-M1`–`F7b-M6` are named in the plan, not in the register: `## Mutations (M)` does not open until `C33`, and Axis 2 forbids a register id in a commit message. |

## The second review's two blocking findings, and what they cost

### 1. The tests were testing a line the app does not run

The first build reached the refused-read branch through an injectable closure on the production type,
`refusableFetch`, justified in the plan on the claim that **"there is no supported way to make a real
`ModelContext` throw from `fetch` on demand."**

**The claim was wrong, and the suite paid for it.** Every refused-read test drove the closure, so
`return try context.fetch(descriptor)` — the only line the shipped app ever executes — was never
driven as a throwing call. The reviewer reinstated the original defect one level deeper:

```swift
return (try? context.fetch(descriptor)) ?? []
```

and `make test` printed `✔ Test run with 639 tests in 94 suites passed` / `** TEST SUCCEEDED **`.
Two tests written for exactly this defect could not see it. The unit's own headline — *a test that
has never been shown to fail is not evidence* — applied to the unit.

**Nothing was refuted. The seam is deleted.** Three routes to a genuine throw were tried by running
them, not by reasoning about them:

| Route | Result |
|---|---|
| A container whose `Schema` omits `Distraction` | **No throw** — `fetch` returns `[]`. |
| Releasing the container under a live context | Not run. `TestStore`'s doc records that this kills the process inside SwiftData. |
| **Overwriting the open on-disk store's bytes** | **Throws, cleanly, no crash** — `NSCocoaErrorDomain` 259, `NSSQLiteErrorDomain` 26. |

`refusableFetch` and the private `fetchDistractions(_:)` that read it are gone; `receive(_:)` calls
`try context.fetch(existing)` directly. Both tests now point a real `ModelContext` at a real store
file whose bytes have been overwritten, restore the bytes afterwards, and reopen through a fresh
container. This also closes the non-blocking finding that the seam was `internal` and mutable on a
production type and had leaked into the memberwise initialiser: there is no such property any more.

### The correction found a second defect in the evidence, and it is in this unit's own assertions

**A store too corrupt to read is also too corrupt to write.** So under every mutation that reinstates
the fall-through, the insert happens and the `save()` is refused too — and the row count after the
bytes are restored is `1` whether the code is right or wrong. **The row-count assertions do not
discriminate in this fixture.** They were the assertions the first review called load-bearing.

They are kept, because they record truthfully what is on the disk, and they are now labelled in the
test source as recorded rather than relied on. What discriminates is `Outcome`, and the reason is
structural rather than stylistic: **`.failed` is reachable only after `context.insert(row)`.** So
`.unreadable` rather than `.failed` *is* the proof that no insert was attempted. Every mutation that
reinstates the fall-through prints `outcome → .failed`, which is the run printing the defect.

### 2. `O47` was not in `OPEN.md`

`conventions-local.md` defines `docs/reviews/OPEN.md` as *"every outstanding item from every review,
in one table"*, and the file's own header says *"Maintained at each review."* The row was written only
into `docs/plans/00-register.md`, and the five bullets under *Still open after this unit* below are
exactly the per-review section `OPEN.md` exists to replace.

**The justification given was wrong on its own terms.** It cited `O44`, which forbids *generating*
`OPEN.md` from the register — not adding a row to it. `C32`, the unit this branch is cut from, wrote
`O45` and `O46` into both files. `O47` is now in `OPEN.md` under *Needs the owner*.

## One non-blocking finding was refuted rather than taken

**"Keeping the error in a log line costs nothing."** It costs the project's first logging facility. A
grep of the app target for `OSLog`, `Logger(`, `os_log` and `print(` returns **zero hits** — there is
no logger to add a line to, and introducing one inside a defect fix is new infrastructure in a file
whose virtue is that it does one thing. The observation underneath it is correct and is not dismissed:
a tap lost this way is silent and undiagnosable, and `O15` cannot tell it from a WatchConnectivity
loss. That is recorded in `O47` and in `OPEN.md`, where a decision can be taken about it.

The other three non-blocking findings were taken: the seam is gone (2), `.failed`'s doc comment no
longer claims *"it is reported rather than swallowed"* when its only caller swallows it (3), and no
`M<n>` id is allocated — that is `C33` (5).

## Challenges a reviewer should press on, and the answers

**"A corrupted SQLite file is not a realistic failure."** It does not have to be the realistic one.
It is *a* refused read, which is the only property the branch depends on, and it is the only refused
read that can be produced on demand without killing the process. The realistic cause on a phone — a
locked store, a full disk, a migration mid-flight — would arrive at the same `catch`.

**"Dropping a tap contradicts `aTapForAnUnknownBlockIsStillRecorded`, which says *never drop a
tap*."** That rule is about refusing a tap because it *looks* odd — an unrecognised session id — and
it stands untouched and still passes. This is the different case where the phone cannot establish
whether writing would create a second row for one press.

**"Why not `.failed`?"** Because `.failed` means a write was attempted and refused, and it is the
only outcome reachable after `context.insert(row)`. Keeping the two words apart is what makes the
mutation runs readable — and it is the assertion doing the work.

**"Why no uniqueness constraint?"** Declined with reasons, recorded in the plan and in `O47`.
Briefly: `.unique` upserts rather than rejects, so a redelivered tap would overwrite a typed `note`
with `nil`; it is an irreversible schema change to the one store that cannot be regenerated, with no
`VersionedSchema` in the tree; and it buys little once the swallowed error is gone. **The upsert
claim is recorded as a claim, not as fact — nothing here has run it.** The asymmetry is decisive:
declining needs no verification, adding needs three.

## Evidence

Every gate re-run after the seam was deleted. No result is carried forward from the first pass.

| Gate | Result |
|---|---|
| `make lint` | pass — `swiftlint 0.65.1 --strict`, no violations |
| `make check-status` | pass — `00-status.md is up to date` |
| `bash scripts/check-open-register.sh` | pass — `the register renders as tables` |
| `bash scripts/tests/run-script-tests.sh` | pass — `19 passed, 0 failed` |
| `make test` | pass — `✔ Test run with 639 tests in 94 suites passed` / `** TEST SUCCEEDED **` |

| Mutation | Issues | What it proves |
|---|---|---|
| `F7b-M1` — the defect re-applied | 4 | `outcome → .failed`, which is reachable only after the insert |
| `F7b-M2` — row written, still reported as dropped | 4 | caught, but **its designed distinction collapsed** — see the plan |
| `F7b-M3` — the `catch` returns `.recorded` | 2 | three outcomes distinguished, not merely "it changed" |
| `F7b-M4` — **the reviewer's own trigger, verbatim** | 4 | **green before this fix, red after.** The finding, closed |
| `F7b-M5` — the happy-path dedup inverted | 16 | the `F7` behaviours are still under test |
| `F7b-M6` — the fixture overwrites only the main store file | 2 | the `-wal`/`-shm` overwrites are load-bearing: without them the read succeeds from the log and prints `.duplicate` |

**The row-count assertions are not in that list, and that is the point.** They cannot discriminate in
this fixture and are labelled as such in the test source. What the mutations are caught on is
`Outcome`.

## Still open after this unit

**Everything below is in `O47` and in `docs/reviews/OPEN.md`.** It is repeated here as a reading
convenience, not as a second place to look: the first review kept these bullets *instead* of an
`OPEN.md` row, which was the second blocking finding.

- Whether DROP is the right ruling. One line to flip, and the owner's call.
- Whether the uniqueness constraint is ever taken. Needs a `D<n>`.
- The asymmetry between a refused tap on the phone (an amber line: *"That tap wasn't saved. Tap
  again."*) and a lost wrist tap (nothing at all — no surface, and now confirmed, no log line
  either, because the app has no logger). Real, never decided, out of scope here.
- A sweep for the same `try?`-swallows-a-read pattern elsewhere. `StatsQuery`'s three period reads
  funnel `nil` into `.unreadable(for:)` and swallow nothing; its fourth, the `CachedProject` mirror
  at line 174, degrades to the name already on the row per `D22` and reaches no `.unreadable`. That
  is a different class from this defect — it cannot make a count wrong and it writes nothing — but
  it is not described by "deliberate and correct" either, which is why the plan now names it. A
  sweep may still be worth a chore.
- `O15` — three wrist taps with the phone in another room — remains the only end-to-end check of
  this path, and it cannot distinguish a tap lost to a refused read from one lost to
  WatchConnectivity. If refused reads prove common on the device, revisit with a retry rather than
  by flipping to insert-anyway.
- **The row-count assertions in both refused-read tests do not discriminate**, because a store too
  corrupt to read is also too corrupt to write. They are labelled as such in the test source. A
  fixture that refuses a read while permitting a write does not exist in SwiftData as far as this
  unit could establish by running things; if one is found, the count assertions become evidence and
  should be re-mutated.
