# F7b — a refused read is not an empty one

**Status:** built, gates green, awaiting review. Defect fix on a shipped feature; no gate was
required and none was waited for.
**Branch:** `F7b/a-resend-cannot-become-a-second`
**Kind:** retrofit on `F7` (`conventions.md`: `F<N>b` is a second pass on an already-shipped
feature). Merged in PR for `F7`; the file this repairs was introduced by
`feat(F7-T4): the phone writes the row, and a resend cannot become a second`.
**Done when:** a redelivered wrist tap whose duplicate check is refused by the database cannot
become a second row, and a test that fails against the shipped code proves it.

## Why this needed no gate

`docs/conventions.md`: *"Defect fixes proceed without a gate, and that is not a loophole: the
distinction is whether the app is failing to do what the contract already says."* The contract
already says it. `WatchTapInbox.receive(_:)`'s own doc comment says *"two rows where there was one
tap inflates the counts the fortnightly review reads — quietly, plausibly, and always upward"*, and
the commit that introduced the file promises in its title that a resend cannot become a second row.
The code does not do that. Nothing new is being proposed; a stated guarantee is being made true.

It is still a **retrofit**, so it gets this plan, a register row and `docs/reviews/F7b.md` like any
other unit.

## The defect, in one line

`ZenTomato/WatchLink/Phone/WatchTapInbox.swift`, `receive(_:)`, as shipped:

```swift
if let found = try? context.fetch(existing), found.isEmpty == false {
  return .duplicate
}
```

`try?` maps a thrown error to `nil`; the `if let` then fails; control falls through to
`context.insert(row)` and `try context.save()`. **"Could not look" and "nothing there" are the same
branch, and the branch they share is the one that writes.** A redelivered tap whose dedup read was
refused is written as a second row for one press.

There is no database backstop. `ZenTomato/Distraction/Distraction.swift:45` is a bare `var id: UUID`,
and `grep -rn "Attribute(" --include="*.swift" ZenTomato ZenTomatoWatch` returns nothing.

**Reachable, not exotic.** WatchConnectivity guarantees *at least once* delivery, so redelivery is
ordinary traffic. And this app already treats a refused SwiftData read as a real event: `StatsQuery`
carries an entire `.unreadable` state, with its own screen copy and its own suite, for exactly this
case. Two files in the same app disagreed about whether a read can be refused. After this unit they
agree, and they use the same noun.

## The ruling: the tap is dropped, nothing is inserted

A new `Outcome` case, `unreadable` — **not** a reuse of `.failed`, whose own doc comment says *"The
row could not be saved"*, a fact about a write that was attempted and refused. A refused dedup read
attempted no write at all.

Both errors are silent, so the tie is broken by which one is reversible and which one lies. A
dropped tap makes the log say *"no tap here"*: an under-report is **absent rather than wrong**, and
the fortnightly number is then a floor. A duplicated row makes the log say *"two taps here"* when
there was one, **permanently** — this app has no capture surface by standing rule, so there is no
screen, and no intention to build a screen, that can delete it. `docs/reviews/OPEN.md` already
records the precedent: a laggy button inflated the distraction tally, and `O44` notes those rows are
still in the database with nothing able to remove them. Inflation in this app is not a bug you fix,
it is a number you live with — and an over-count always flatters, so it is the error nobody
double-checks.

The repository rules this way twice already. `StatsQuery.readEverything(in:)` refuses to return a
partial period because *"a period missing any one of them would look exactly like a real period that
happened not to contain them. That is the shape of a lie."* `TimerEngine.recordDistraction(_:)`
deletes its row on a save failure rather than leave it for a later silent commit. **Do not write
what you cannot vouch for.**

**The objection, named.** `WatchTapInboxTests.aTapForAnUnknownBlockIsStillRecorded` says in bold
*"Never drop a tap."* That rule is about refusing a tap because it *looks* odd — an unrecognised
session id — and it stands untouched. This is not that: here the phone cannot establish whether
writing would create a second row for one press.

**The practical point.** A `ModelContext` whose `fetch` throws is very unlikely to have a `save`
that succeeds, so most taps this ruling "loses" would have returned `.failed` a few lines later
anyway. What it actually changes is the one case where the read is refused and the write would have
succeeded — precisely the case that manufactures the duplicate.

**If the owner overrules,** it is one line: return past the `catch` into the insert, and flip the two
new tests. `O47` holds that question open.

## Nothing user-visible changes

The only production caller is `ZenTomato/WatchLink/Phone/PhoneWatchLink.swift:105`:

```swift
guard self.inbox.receive(tap) == .recorded else { return }
```

`.unreadable` is not `.recorded`, so the existing guard already does the right thing: `receivedTaps`
is not incremented (nothing was received into the store) and `engine.adoptWristTap(...)` is not
called (there is no row for the end-of-block sheet to ask about). `PhoneWatchLink.swift` is not
edited, and no banner, counter, alert or log line is added — `.failed` is dropped just as silently
today, and inventing a surface for `.unreadable` alone would be new user-facing behaviour owing a
delta.

## The uniqueness constraint was declined, not forgotten

`@Attribute(.unique)` is **not** added to `Distraction.id` or to anything. Three reasons:

1. **`.unique` is an upsert, not a rejection.** A colliding insert is understood to update the
   stored row from the new one. `receive(_:)` builds `Distraction(id:kind:timestamp:sessionID:)`
   with `note` defaulting to `nil`, so a redelivered tap would overwrite a sentence the person typed
   in the end-of-block sheet with nothing. That converts a duplicate-row defect into a silent
   deletion of log *content*, which is strictly worse under `zenpom-v1.5.md`'s *"if a scope decision
   threatens the log, the log wins"*. **Stated as a claim, not as established fact** — nothing in
   this repository has run it, and `conventions.md` is explicit that a decision about what another
   system can do is not ratifiable until something has. The asymmetry is itself decisive: declining
   needs no verification, adding needs three.
2. **It is an irreversible schema change to the one store that cannot be regenerated.**
   `AppModelContainer.make(_:)` builds one flat `Schema` and hands it straight to `ModelContainer`;
   there is no `VersionedSchema` and no `SchemaMigrationPlan` anywhere in the tree. Lightweight
   migration is the whole migration story, and a newly-added uniqueness constraint is the case it
   handles least predictably. `O2`'s lesson is that install-over-a-real-store is the check a unit
   test cannot perform, and `docs/chores/C26.md` records the stake: that store holds the distraction
   log, and `O1` — one real day's export, read beside the Rhodia — has never been run.
3. **It buys little once the swallowed error is gone.** Every remaining path to a duplicate `id`
   runs through the `.duplicate` return. The inflation `OPEN.md` records came from repeated *real*
   presses, each with its own fresh `UUID` — distinct ids, which no constraint would have stopped.

Taking it needs a `D<n>`, a versioned schema with an explicit de-dup migration, a test asserting what
happens to a non-nil `note` on collision, and a new `O` row in `O2`'s shape. It is not a commit.

## There is no seam. The tests drive the line the app runs

**This section replaced an earlier one, and the reason is the whole point of the unit.** The first
build of `F7b` reached the refused-read branch through a replaceable closure on the production type:

```swift
var refusableFetch: ((FetchDescriptor<Distraction>) throws -> [Distraction])?
```

It was justified on the claim that *"there is no supported way to make a real `ModelContext` throw
from `fetch` on demand"*. **That claim was wrong, and the adversarial review found what it cost.**
With the seam in place, every refused-read test drove the injected closure, and
`return try context.fetch(descriptor)` — the only line the shipped app ever executes — was never
driven as a throwing call. The reviewer reinstated the original defect one level deeper:

```swift
return (try? context.fetch(descriptor)) ?? []
```

and `make test` printed `✔ Test run with 639 tests in 94 suites passed` / `** TEST SUCCEEDED **`.
The suite could not see the defect it exists to catch. A seam that is one level above the defect is
a seam the defect can hide under.

**A real `ModelContext` can be made to throw.** Three routes were tried, by running each rather than
by reasoning about it:

| Route | Result |
|---|---|
| A container whose `Schema` omits `Distraction` | **No throw.** `fetch` returns `[]`. Probed: *"PROBE: fetch did NOT throw, returned 0"*. |
| Releasing the container under a live context | Rejected unrun. `TestStore`'s own doc records that this kills the process inside SwiftData — a crash scored as a kill. |
| **Overwriting the store file's bytes under an open on-disk store** | **Throws, cleanly, no crash.** `NSCocoaErrorDomain` 259, *"The file "ZenTomato.store" couldn't be opened because it isn't in the correct format"*, `NSSQLiteErrorDomain=26`. |

So the seam was **deleted**, along with the private `fetchDistractions(_:)` that read it, and
`receive(_:)` now calls `try context.fetch(existing)` directly. `WatchTapInbox` has one stored
property again — `let context` — and no mutable production surface a test injects into.

`CorruptibleStore`, private to `WatchTapInboxTests`, owns the mechanism: an on-disk store from
`TestStore.temporaryFileStore()`, whose database file and both side files (`-wal`, `-shm`) are
overwritten with `0x41` and whose original bytes are kept. All three files are overwritten
deliberately: leaving the write-ahead log intact lets SQLite answer from it and the read succeeds.

**Keeping the bytes is what makes the row count assertable.** After the refused read the original
bytes are written back and the store is reopened through a *fresh* container, so
`try corruptible.rowsOnDisk().count == 1` reads what is on the disk rather than what some context
still remembers — and rather than recomputing what the test expects to be there, which is the
failure mode `conventions.md` names.

## Tasks

| Task | Owner | What |
|---|---|---|
| `F7b-T0` | agent | This plan, written before any Swift changed. |
| `F7b-T1` | agent | RED. The enum case, the helper and the two tests — **without** the fix. Run, watch fail, record verbatim. |
| `F7b-T2` | agent | GREEN. The `do`/`catch` in `receive(_:)`. Run, watch pass. |
| `F7b-T3` | agent | Mutations, each applied to the shipped tree, each run, each reverted. |
| `F7b-T4` | agent | `docs/reviews/F7b.md`, the `O47` register row and its `OPEN.md` row, regenerated `00-status.md`. |
| `F7b-T5` | agent | **Added by the adversarial review.** Delete the seam; drive the production `fetch` to throw for real; re-run every gate and every mutation against the rebuilt tree. |

A test asserting `.unreadable` cannot compile against the old enum, so "write the failing test
first" has to mean the case lands *with* the test and *without* the fix. That is the split, and
commit 1 was seen to fail.

## F7b-T1 — the red run, verbatim

**READ THE NOTE BELOW BEFORE THIS OUTPUT.** The run recorded here was made against the *seam* build
of the tests, which `F7b-T5` deleted. It is kept because it happened and because the way it failed is
what the review went on to find. **It is not the red evidence for the tests as they now stand** —
that is `F7b-M1` and `F7b-M4`, which apply the original defect to the shipped tree and are caught by
the rewritten tests.

Command: `make test`, with the enum case, the seam, the helper and the two tests in place and
`EDIT 1.3` deliberately withheld — `receive(_:)` still calling `try? context.fetch`.

```
◇ Test "aRefusedDedupReadCannotDuplicateAnExistingRow" started.
✘ Test "aRefusedDedupReadCannotDuplicateAnExistingRow" recorded an issue at WatchTapInboxTests.swift:232:5: Expectation failed: refusingInbox().receive(tap) == .unreadable
↳ refusingInbox().receive(tap) == .unreadable → false
↳   refusingInbox().receive(tap) → .duplicate
✘ Test "aRefusedDedupReadCannotDuplicateAnExistingRow" failed after 0.010 seconds with 1 issue.
◇ Test "aRefusedDedupReadDropsTheTapAndSaysSo" started.
✘ Test "aRefusedDedupReadDropsTheTapAndSaysSo" recorded an issue at WatchTapInboxTests.swift:249:5: Expectation failed: outcome == .unreadable
↳ outcome == .unreadable → false
↳   outcome → .recorded
✘ Test "aRefusedDedupReadDropsTheTapAndSaysSo" recorded an issue at WatchTapInboxTests.swift:251:5: Expectation failed: try taps().isEmpty
↳ A tap the phone could not check must not be written.
✘ Test "aRefusedDedupReadDropsTheTapAndSaysSo" failed after 0.005 seconds with 2 issues.
✘ Suite "WatchTapInbox" failed after 0.051 seconds with 3 issues.
✘ Test run with 639 tests in 94 suites failed after 5.310 seconds with 3 issues.
```

**637 tests at HEAD of this branch, 639 after.** Both new tests fail against the shipped behaviour,
which is what the red run is for.

### The red run did not show two rows, and that is worth recording

The work order predicted `(try taps().count → 2) == 1`. It did not happen, for a reason that
sharpens the evidence rather than weakening it. **In the red state the seam exists but nothing
consults it:** `receive(_:)` still calls `try? context.fetch` directly, so the refusing closure is
never reached. The refusing inbox therefore reads the real in-memory store, finds the row the first
`receive` wrote, and returns `.duplicate` — hence `refusingInbox().receive(tap) → .duplicate` above,
and a row count that is legitimately 1.

So the two halves of the evidence live in two places, and both are here:

- **The red run** proves the two new tests fail against the shipped code.
- **`F7b-M1`** — the defect re-applied to the *fixed* tree, where the seam **is** wired — proves the
  tests catch the defect as it actually behaves: `.recorded` where `.unreadable` was expected, and
  the second row written.

## F7b-T2 — green

```
✔ Test run with 639 tests in 94 suites passed after 5.630 seconds.
** TEST SUCCEEDED **
```

## F7b-T3 — six mutations, each run against the rebuilt tree

**Every mutation below was re-applied and re-run after the seam was deleted.** None is carried
forward from the first build; `C32`'s precedent is that a review's fixes invalidate the runs made
before them. Each was applied to the shipped tree, run with `make test`, and reverted before the
next. `prevented by construction` is not a result; every row is an observed failure.

**A NOTE ON THE ISSUE COUNTS, BECAUSE FOUR READS AS MORE THAN IT IS.** Each refused-read test carries
two assertions: `outcome == .unreadable` and a companion `outcome != .failed`. In the green direction
the companion cannot fail — once the outcome *is* `.unreadable` it is necessarily not `.failed` — so a
count of `4` is **two tests with a companion each, not four independent catches.** The companion still
earns its place in the red direction: under `F7b-M1` the outcome is actually `.failed`, so it fires and
distinguishes *"the insert was attempted"* from *"some other non-unreadable outcome"*. Recorded because
this project's own conventions name inflated evidence as a recurring defect, and a count nobody
qualified is how it inflates. **The discriminating count is two per refused-read mutation.**

| Mutation | Edit | Issues | Caught by |
|---|---|---|---|
| `F7b-M1` | The defect itself: the `do`/`catch` becomes `if let found = try? context.fetch(existing), found.isEmpty == false` | 4 | both refused-read tests, on `Outcome` |
| `F7b-M2` | The row is written but still reported as dropped | 4 | both, on `Outcome` — **and the designed distinction collapsed; see below** |
| `F7b-M3` | The `catch` returns `.recorded` instead of `.unreadable` | 2 | both, on `Outcome` |
| `F7b-M4` | **The reviewer's own literal trigger**: `found = (try? context.fetch(existing)) ?? []` | 4 | both, on `Outcome` |
| `F7b-M5` | Regression: `if found.isEmpty == false` becomes `if found.isEmpty` | 16 | eight of the suite's nine tests — the `F7` behaviours |
| `F7b-M6` | **Fixture mutation**: `CorruptibleStore` overwrites the store file only, not `-wal` and `-shm` | 2 | `aRefusedDedupReadCannotDuplicateAnExistingRow` |

### `F7b-M1` — the defect itself, re-applied

**Edit:** replace the `do`/`catch` in `receive(_:)` with
`if let found = try? context.fetch(existing), found.isEmpty == false { return .duplicate }`.

```
✘ Test "aRefusedDedupReadCannotDuplicateAnExistingRow" recorded an issue at WatchTapInboxTests.swift:315:5: Expectation failed: outcome == .unreadable
↳ outcome == .unreadable → false
↳   outcome → .failed
✘ Test "aRefusedDedupReadCannotDuplicateAnExistingRow" recorded an issue at WatchTapInboxTests.swift:316:5: Expectation failed: outcome != .failed
↳ outcome != .failed → false
↳   outcome → .failed
✘ Test "aRefusedDedupReadCannotDuplicateAnExistingRow" failed after 0.070 seconds with 2 issues.
✘ Test "aRefusedDedupReadDropsTheTapAndSaysSo" recorded an issue at WatchTapInboxTests.swift:341:5: Expectation failed: outcome == .unreadable
↳ outcome == .unreadable → false
↳   outcome → .failed
✘ Test "aRefusedDedupReadDropsTheTapAndSaysSo" recorded an issue at WatchTapInboxTests.swift:342:5: Expectation failed: outcome != .failed
↳ Nothing was refused a write; the phone could not look.
↳ outcome != .failed → false
↳   outcome → .failed
✘ Test "aRefusedDedupReadDropsTheTapAndSaysSo" failed after 0.063 seconds with 2 issues.
✘ Suite "WatchTapInbox" failed after 0.172 seconds with 4 issues.
✘ Test run with 639 tests in 94 suites failed after 5.706 seconds with 4 issues.
** TEST FAILED **
```

**`outcome → .failed` is the defect, printed.** `.failed` is returned only from the `catch` on
`context.save()`, which is reachable only after `context.insert(row)` — so a run that prints it has
gone through the insert this unit exists to keep out. That, not the row count, is the tell.

### What this fixture cannot show, and the first review claimed it could

**A store too corrupt to read is also too corrupt to write.** Every mutation that falls through to
the insert therefore has its `save()` refused as well, the row is deleted from the context, and
`rowsOnDisk().count` after the bytes are restored is `1` whether the code is right or wrong.

**So the row-count assertions do not discriminate in this fixture.** They were the assertions the
first build's evidence rested on — *"`refusingInbox().receive(tap) → .recorded` with the count
assertion red beside it **is the second row**, printed"* — and under the corrected fixture they stay
green under the defect. They are kept, labelled in the test source as recorded rather than relied on,
because they are the honest record of what is on the disk.

`F7b-M2` is the direct casualty. It was designed to be caught *only* by the row counts, as the mirror
of `F7b-M3`, and it now fails identically to `F7b-M1` — 4 issues, all on `Outcome`. **The M2/M3 pair
no longer proves what it was built to prove.** That is recorded rather than quietly renumbered.

### `F7b-M2` — the row is written but still reported as dropped

**Edit:** the `catch` sets `found = []` and a `refused` flag instead of returning; the save path
returns `refused ? .unreadable : .recorded`.

```
✘ Test "aRefusedDedupReadCannotDuplicateAnExistingRow" recorded an issue at WatchTapInboxTests.swift:315:5: Expectation failed: outcome == .unreadable
↳ outcome == .unreadable → false
↳   outcome → .failed
✘ Test "aRefusedDedupReadCannotDuplicateAnExistingRow" recorded an issue at WatchTapInboxTests.swift:316:5: Expectation failed: outcome != .failed
✘ Test "aRefusedDedupReadDropsTheTapAndSaysSo" recorded an issue at WatchTapInboxTests.swift:341:5: Expectation failed: outcome == .unreadable
↳   outcome → .failed
✘ Suite "WatchTapInbox" failed after 0.153 seconds with 4 issues.
✘ Test run with 639 tests in 94 suites failed after 5.265 seconds with 4 issues.
```

Caught — but for the reason `F7b-M1` is caught, not the reason it was written for: the save it tries
to make is refused by the same corrupt file.

### `F7b-M3` — the mirror: nothing written, caller told one was

**Edit:** in the `catch`, `return .unreadable` becomes `return .recorded`.

```
✘ Test "aRefusedDedupReadCannotDuplicateAnExistingRow" recorded an issue at WatchTapInboxTests.swift:315:5: Expectation failed: outcome == .unreadable
↳ outcome == .unreadable → false
↳   outcome → .recorded
✘ Test "aRefusedDedupReadCannotDuplicateAnExistingRow" failed after 0.049 seconds with 1 issue.
✘ Test "aRefusedDedupReadDropsTheTapAndSaysSo" recorded an issue at WatchTapInboxTests.swift:341:5: Expectation failed: outcome == .unreadable
↳ outcome == .unreadable → false
↳   outcome → .recorded
✘ Test "aRefusedDedupReadDropsTheTapAndSaysSo" failed after 0.079 seconds with 1 issue.
✘ Test run with 639 tests in 94 suites failed after 6.175 seconds with 2 issues.
** TEST FAILED **
```

Note `.recorded` here against `.failed` in `M1`, `M2` and `M4`: the three outcomes are distinguished,
so the assertion is reading the value rather than merely noticing that it changed.

### `F7b-M4` — the adversarial reviewer's own trigger, verbatim

**Edit:** `found = try context.fetch(existing)` becomes `found = (try? context.fetch(existing)) ?? []`.

This is the exact edit the review made to the *first* build, where it passed 639 tests green. It is
kept as its own mutation for that reason, even though it is behaviourally the same program as
`F7b-M1`: **the thing that must be shown is that this specific edit now goes red.**

```
✘ Test "aRefusedDedupReadCannotDuplicateAnExistingRow" recorded an issue at WatchTapInboxTests.swift:315:5: Expectation failed: outcome == .unreadable
↳ outcome == .unreadable → false
↳   outcome → .failed
✘ Test "aRefusedDedupReadCannotDuplicateAnExistingRow" recorded an issue at WatchTapInboxTests.swift:316:5: Expectation failed: outcome != .failed
↳ `.failed` means the insert was attempted. Nothing should have been.
↳ outcome != .failed → false
↳   outcome → .failed
✘ Test "aRefusedDedupReadCannotDuplicateAnExistingRow" failed after 0.057 seconds with 2 issues.
✘ Test "aRefusedDedupReadDropsTheTapAndSaysSo" recorded an issue at WatchTapInboxTests.swift:341:5: Expectation failed: outcome == .unreadable
↳   outcome → .failed
✘ Test "aRefusedDedupReadDropsTheTapAndSaysSo" recorded an issue at WatchTapInboxTests.swift:342:5: Expectation failed: outcome != .failed
✘ Test "aRefusedDedupReadDropsTheTapAndSaysSo" failed after 0.064 seconds with 2 issues.
✘ Test run with 639 tests in 94 suites failed after 5.199 seconds with 4 issues.
** TEST FAILED **
```

**Green before the fix, 4 issues after.** That is the finding closed.

### `F7b-M5` — the regression mutation: the happy-path dedup is inverted

**Edit:** `if found.isEmpty == false { return .duplicate }` becomes `if found.isEmpty { return .duplicate }`.

```
✘ Test "duplicateTapIgnored" recorded an issue at WatchTapInboxTests.swift:47:5: Expectation failed: inbox.receive(tap) == .recorded
↳   inbox.receive(tap) → .duplicate
✘ Test "timestampIsTapTimeNotDeliveryTime" recorded an issue at WatchTapInboxTests.swift:65:5: Expectation failed: inbox.receive(tap) == .recorded
✘ Test "lateTapAttachesToItsSession" recorded an issue at WatchTapInboxTests.swift:106:5: Expectation failed: inbox.receive(tap) == .recorded
✘ Test "lateTapInheritsTaskSnapshot" recorded an issue at WatchTapInboxTests.swift:144:5: Expectation failed: period.externalCount == 1
✘ Test "aTapForAnUnknownBlockIsStillRecorded" recorded an issue at WatchTapInboxTests.swift:162:5: Expectation failed: inbox.receive(WatchTap(
✘ Test "twoRealTapsInOneBlockAreTwoRows" recorded an issue at WatchTapInboxTests.swift:185:5: Expectation failed: try taps().count == 2
✘ Test "aWristTapArrivesWithNoSentence" failed
✘ Test "aRefusedDedupReadCannotDuplicateAnExistingRow" failed
✘ Test run with 639 tests in 94 suites failed after 5.225 seconds with 16 issues.
** TEST FAILED **
```

Eight of the suite's nine tests fail — every path that writes a row is gone, because the first
`receive` now returns `.duplicate` against an empty store. `aRefusedDedupReadDropsTheTapAndSaysSo` is
the one that still passes, and correctly: it never writes a row to begin with.

### `F7b-M6` — the fixture itself, mutated

**Edit, in the test file:** `CorruptibleStore.files` overwrites `[""]` instead of `["", "-wal", "-shm"]`.

**This mutation exists because the three-file overwrite could have been superstition.** A fixture
whose setup does more than it needs to is a fixture nobody can reason about, and the only way to know
is to break it.

```
✘ Test "aRefusedDedupReadCannotDuplicateAnExistingRow" recorded an issue at WatchTapInboxTests.swift:315:5: Expectation failed: outcome == .unreadable
↳ outcome == .unreadable → false
↳   outcome → .duplicate
✘ Test "aRefusedDedupReadCannotDuplicateAnExistingRow" recorded an issue at WatchTapInboxTests.swift:319:5: Expectation failed: try corruptible.rowsOnDisk().count == 1
↳ try corruptible.rowsOnDisk().count == 1 → <not evaluated>
✘ Test "aRefusedDedupReadCannotDuplicateAnExistingRow" failed after 0.024 seconds with 2 issues.
✔ Test "aRefusedDedupReadDropsTheTapAndSaysSo" passed after 0.038 seconds.
✘ Test run with 639 tests in 94 suites failed after 5.021 seconds with 2 issues.
** TEST FAILED **
```

**`outcome → .duplicate` is the write-ahead log answering the read.** The main database file is
garbage and SQLite finds the row in the intact `-wal` anyway, so the fetch succeeds and the fixture
creates no refused read at all. The `-wal` and `-shm` overwrites are load-bearing, and this is the run
that says so.

**Two honest notes.** `aRefusedDedupReadDropsTheTapAndSaysSo` *passes* under `F7b-M6`, because it
writes nothing before corrupting, so there is no row in any log to answer from and the main-file
corruption is enough on its own. And `rowsOnDisk()` failing as `<not evaluated>` is the restore
throwing rather than an assertion disagreeing — under this mutation only one of the three files was
saved, so putting it back leaves an inconsistent store. Both are recorded rather than tidied: the
mutation is caught, and it is caught by one test rather than two.

## Gates

**Every one re-run after `F7b-T5`.** Nothing below is carried forward from the first build.

| Gate | Result |
|---|---|
| `make lint` | pass — `swiftlint 0.65.1 --strict`, `OK — no lint violations.` |
| `make check-status` | pass — `gen_status.py: OK — 00-status.md is up to date.` |
| `bash scripts/check-open-register.sh` | pass — `OK — the register renders as tables.` |
| `bash scripts/tests/run-script-tests.sh` | pass — `19 passed, 0 failed` |
| `make test` | pass — `✔ Test run with 639 tests in 94 suites passed after 4.765 seconds.` / `** TEST SUCCEEDED **`. **639 tests**, 637 at HEAD of this branch + 2 |

## What is out of scope, and stays out

1. `@Attribute(.unique)`, `VersionedSchema`, `SchemaMigrationPlan`. Declined with reasons above; it
   needs a `D<n>`.
2. Any user-visible surface for a lost wrist tap — banner, alert, badge, or a `refusedTaps` counter.
   New user-facing behaviour owes a delta, and `.failed` is dropped just as silently today. The
   asymmetry with the phone path (`TimerEngine` shows *"That tap wasn't saved. Tap again."*) is real,
   was never decided, and stays undecided.
3. Retrying or queueing a refused tap. New machinery — a hold with its own lifetime, ordering and
   failure modes — in a file whose whole virtue is that it does one thing.
4. Auditing the tree for the same `try?`-swallows-a-read pattern. **Checked rather than asserted,
   because the first draft of this line was too broad.** `StatsQuery` has four `try?` fetches, and
   they are not one group. Three — lines 156, 193 and 206 — return an optional that
   `readEverything(in:)` collapses to `nil` and `period(_:)` turns into `.unreadable(for:)`, the
   state this unit borrows the word from; they do not swallow anything. The fourth, line 174, is
   `(try? context.fetch(FetchDescriptor<CachedProject>())) ?? []` and **does not** reach
   `.unreadable`: it degrades to the project name already recorded on each row, which is what `D22`
   built that fallback for, and its own comment says so. It is not this defect's class — it cannot
   make a count wrong and it writes nothing — but it is not covered by the sentence above either,
   and saying so is cheaper than a reader discovering the gap. A sweep may be worth a chore; it is
   not this defect fix.
5. Anything in `docs/reviews/OPEN.md` beyond this unit. `O44` records that OPEN.md and the register
   are lossy in opposite directions and that the resolution is the owner's.
6. Opening the `## Mutations (M)` register — that is `C33`. No `M<n>` id is allocated or cited; the
   mutations above are named `F7b-M1`–`F7b-M6`, following `C28` and `C32`.
7. `O43`'s `F8-M7`/`F8-M8` collision and the `O23`/`O24`/`O25` collisions. Pre-existing and filed.
8. Anything on the watch side. `ZenTomatoWatch` mints the id and sends the payload; both are correct.

## What remains for the owner

`O47`. Two questions, both his: whether dropping is the right ruling (it is one line to flip), and
whether the uniqueness constraint is ever taken.
