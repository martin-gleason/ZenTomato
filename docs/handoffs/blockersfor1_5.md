# Blockers for v1.5

**Written:** 2026-09-16, from two parallel adversarial reviews and one condensing pass —
59 raw claims, deduplicated to 16 distinct sites, every survivor re-verified by running it.
**For:** the owner, to rule on; and for any session that picks this up afterwards.
**Status:** findings and recommendations. **Nothing here is ratified.** A recommendation is not a
decision, and this file does not become one by being read.

**Where this sits.** `docs/handoffs/turing-v2.md` records *how sessions fail*. This file records *what
is currently blocking v1.5 and what to do about it*. The overlap is deliberate and marked: §5 is
written for the coordinating role rather than for this project.

---

## The one-paragraph version

**`docs/plans/00-register.md` cannot become the canonical record today.** It is missing 18 agent rows,
36 of 37 decisions, six chores, and the `M`, `H` and `RR` registers entirely — and it has no validator,
while the file it would replace does. Separately, one live defect can corrupt the distraction log, four
ratified deltas are invisible to the amendment ratchet by a punctuation mismatch, and `D33` has been
ratified and unapplied for a week, so the project's own non-negotiables file states a superseded scope.

---

## 1 · Six decisions, with alternatives

Each is stated as a choice rather than a recommendation with a fig leaf. The recommendation is named,
and so is the case against it.

### DEC-1 · Where do agent findings live?

`docs/reviews/OPEN.md` holds a **"Needs the agent"** table: 18 `A` rows, **6 still open** (`A1`, `A8`,
`A14`, `A16`, `A17`, `A18`). `00-register.md` holds none, and `conventions.md` Axis 2 defines no `A`
register at all. `00-status.md` therefore reports "open register rows" while six agent-owned code
findings are invisible to it.

| Option | Cost | Case for | Case against |
|---|---|---|---|
| **A · Add `## Agent items (A)`, carry all 18** | one paste | lossless; preserves the audit trail of twelve closed findings | invents a register the conventions do not define — needs promoting upstream or the next project repeats this |
| B · Reclassify the 6 open as defects or chores, drop the closed 12 | twelve judgement calls | no new register | destroys twelve closed findings' reasoning, which is the part worth keeping |
| C · Fold `A` into `O` with an owner field | medium | uses an existing register | `O` means *"only the owner can close it"*; these are the opposite, and conflating them loses the distinction that made the table useful |

**Recommend A**, then promote the `A` register upstream to `conventions.md`. **The honest objection to
A:** this project has a standing habit of inventing structure, and a fourth register is more structure.
The counter is that the structure already exists in `OPEN.md` and is load-bearing — this only moves it
somewhere a generator can see.

**Blocks:** generation. Today, generating `OPEN.md` from the register deletes all eighteen rows.

### DEC-2 · Does the register carry the decisions, or point at them?

`00-deltas.md` defines **37** deltas. The register's `## Decisions (D)` table contains **one row**,
`D30`. `00-status.md` consequently prints `Decisions (D) | 1`.

| Option | Case for | Case against |
|---|---|---|
| A · Carry all 37 into the register | one file answers everything | 37 rows of duplication with no generator keeping them in step — it will drift inside a week, and drift is the disease being treated |
| **B · Retire the `D` section; `00-deltas.md` is canonical** | it is already complete, already guarded by `DeltaIntegrityTests`, and already what `conventions-local.md` says | "one canonical record" becomes "one canonical record per register", which is a weaker promise than the one just made |
| C · Status quo | free | two partially-authoritative sources is the second intake path the conventions forbid, and it is already producing a wrong number on a CI-enforced page |

**Recommend B**, with the `D` section replaced by one line naming `00-deltas.md` and the status
generator taught to count there.

**The uncomfortable part, stated plainly:** B is in tension with *"two files to maintain is exactly what
I think we need to avoid."* The distinction is that `00-deltas.md` is not a second copy of the register
— it is the decisions themselves, in ADR form, with a test enforcing them. Retiring the register's `D`
table removes a copy rather than creating one. If that reads as a lawyer's answer, take A instead and
accept the duplication cost; what must not survive is C.

### DEC-3 · When do `M`, `H` and `RR` open?

None of the three exists. In active use right now: **52 mutation IDs** across the plans, and **15 real
enforcement mechanisms**. `ZenTomatoTests/DeltaIntegrityTests.swift:195` reads
`/// everyRatifiedSpecAmendmentIsApplied — H2.` — **a shipped production test cites a register row that
exists in no register.** That is precisely the `D14` failure `DeltaIntegrityTests` was written to
prevent, reproduced one register over, unguarded because there is no `H` equivalent of that test.

| Option | Case for | Case against |
|---|---|---|
| **A · Open `M` and `H` now with backfill; `RR` with seed rows** | `F13` is blocked without `M` — it produces seven mutation results with nowhere to put them, and its own plan says so | the largest single piece of work in this list |
| B · Open `M` only, defer `H` and `RR` | unblocks `F13` at a third of the cost | leaves a shipped test citing a non-existent row, which is the finding that should be most embarrassing |
| C · Defer all three until after generation | fastest to generation | a generator that emits three empty sections certifies a lie in a CI-enforced file |

**Recommend A.** `H` is not optional: the hook register is the one artifact that traces *spec invariant
→ mechanism → owning task*, and this project has fifteen mechanisms and a status page that says
**"0 of 0 built."**

### DEC-4 · `F8-T4` — what is actually blocked?

**A reviewer escalated this to "the preset control is invalidated." That escalation was checked and
overruled, and the correction matters more than the finding.**

`SprintShapeTests.swift:166` asserts `moreRest @ 180 → focusMinutes == 102`. `F8.md`'s own **BLOCKING**
note computes **100**. Both are correct arithmetic over *different* distribution rules: the plan's 100
needs the three short breaks to absorb 20 minutes unevenly (*"5 → 7, 7, 6"*); the code's 102 divides
evenly — `20/3 = 6`, the shorts absorb 18, and the leftover 2 falls to focus as odd minutes.
`102 + 33 + 45 = 180`. It balances.

**The presets diverge either way** — `150 / 120 / 102` under the code, `150 / 120 / 100` under the plan.
So `O39` and the preset control stand. What is owed is a two-line correction, not a rebuild.

**What genuinely needs a ruling is one sentence.** Ruling C says *"long breaks are interior; the break
after the final pom is not scheduled"* and also *"a shape is one sprint."* Those cannot both hold: a
one-sprint shape's last pom **is** the final pom, so interior-only means **no shape ever gets a long
break** — while every row of the worked table ends with one, and Ruling D ships an on-by-default
*"end with a long break"* toggle. The code picked a side silently.

| Option | Case for | Case against |
|---|---|---|
| **A · Accept the shipped behaviour, write it into `F8.md` as a correction** | the behaviour is coherent, tested and already merged; the cost is a sentence | ratifies by shipping, which is the failure being documented |
| B · Rule both from first principles, recompute, change code if it disagrees | the gate does its job properly | `T1`–`T3` are merged and in the owner's hands; re-deriving may change device behaviour under a feature already being used |
| C · Halt `F8` | maximal rigour | expensive, and the thing being protected is a sentence |

**Recommend A** — and note what it costs. A ratifies a contradiction that was closed by building past
a note the plan itself marked **BLOCKING**. That is worth saying out loud each time it happens, because
the second time it stops being an exception.

**`O37` must not send anyone to a device until the 102 is written down as intended.** As it stands, the
owner would be asked to confirm a figure no document justifies.

### DEC-5 · `D33`

Ratified 2026-09-09, **never applied**. v1.5 is thirteen units in a stated order; `zenpom-v1.5.md:70`
still says *"Ten features and one chore"*, `CLAUDE.md:10` still enumerates eleven, and six plan files
cite stale item numbers. **Nothing could have caught it** — see DEC-6.

There is no real alternative. **Apply it today.** Owner-only: the agent does not edit a ratified
baseline. This is the single item on the list where being wrong costs a *built feature* rather than a
document.

### DEC-6 · The amendment ratchet has two holes

**Hole 1 — punctuation.** `DeltaIntegrityTests.swift:299` matches the literal string `**Currently:**`.
Four deltas write `**Currently**,` — `D31`, `D32`, `D33`, `D34` — and are invisible to the ratchet.
`D33` is one of them. *(A reviewer reported this as "every delta since 2026-09-09"; `D35` uses the colon
form and is seen. It is four, and the precision matters — an overstated finding is refuted and then the
real one dies with it.)*

**Hole 2 — one baseline is unguarded.** `everyRatifiedSpecAmendmentIsApplied` reads **only**
`docs/specs/SPEC.md`. `zenpom-v1.5.md` is an equally ratified baseline with no amendment ledger, no
baseline file and no ratchet. `D33` amends it. Nothing would ever have gone red.

**Recommend fixing both**, and a third: `00-deltas.md:60` states *"36 deltas"* above 37 headings, and
the index test asserts membership but never the count — the identical hole `O35` recorded for the old
"24 deltas" claim, reopened at a new number. **Add the count assertion, then break it and record what
failed.** A ratchet nobody has seen fail is not a ratchet.

---

## 2 · The defect that can corrupt the log

**Independent of all six decisions, and it is the only one that touches the thing the app exists for.**

`ZenTomato/WatchLink/Phone/WatchTapInbox.swift:60`

```swift
if let found = try? context.fetch(existing), found.isEmpty == false {
  return .duplicate
}
```

If the read **throws**, `try?` yields `nil`, the `if let` fails, and control falls through to
`context.insert(row)` — writing the duplicate this line exists to prevent. `Distraction.id` is a plain
`var id: UUID` with **no `@Attribute(.unique)`**; a grep for `Attribute(.unique)` over the whole tree
returns nothing, so there is no database backstop either. WatchConnectivity guarantees *at-least-once*
delivery, so redelivery is ordinary traffic.

The function's own doc comment states the guarantee this one line solely enforces:

> *"two rows where there was one tap inflates the counts the fortnightly review reads — quietly,
> plausibly, and always upward."*

**The reachability argument is the project's own.** `StatsQuery` has an entire `.unreadable` state built
for exactly the case of a refused SwiftData read. Two files in the same app disagree about whether that
can happen. **The phone write path is careful — `TimerEngine.recordDistraction` commits synchronously,
deletes the row on save failure, and carries two independent block-ownership guards. The watch path is
not.** That asymmetry is the finding.

**Fix:** replace `try?` with a real `catch` that returns a failure rather than falling through, add
`@Attribute(.unique)` to `Distraction.id`, and write the test first so it is seen to fail. A defect fix,
so no gate.

**Also major, same class of "the fix covered one caller":** `MusicCoordinator.swift:467`'s
`skipForward()` still makes the blocking cross-process read on the main actor that produced the watchdog
kill in `docs/crashes/ZenTomato-2026-08-26-134602.ips`. `A18`'s fix covered `refreshIsPlaying()` and left
this one. The comment at `:766` — *"NOTHING IS READ ON THIS THREAD, AND THAT IS THE WHOLE POINT"* — is
true of the method and false of the class. Skip is the one music control the spec allows during a
sprint. `SpyMusicPlayer` already blocks genuinely, so the test is four lines.

---

## 3 · The prerequisite nobody had noticed

**`scripts/check-open-register.sh` validates `OPEN.md` only.** The file about to be declared canonical
has **no validator at all**.

That is how `00-register.md:95` can state *"Extracted 16 open owner items"* above a table holding 22,
and how `C29`'s fifteen truncated rows survived for weeks.

> **Moving authority to the unguarded document is the specific thing to avoid.** Whatever else is
> decided, a validator for `00-register.md` — self-count, ID uniqueness, sorted by ID, every row has a
> status — comes **before** generation, and is proven by breaking it.

---

## 4 · Migration order

Owner-only steps marked ⚑. Each agent step is a separate commit, so a mistake is revertible.

1. ⚑ Rule DEC-1 … DEC-6.
2. ⚑ **Apply `D33`** — the spec's table and its *"Ten features and one chore"* line; `CLAUDE.md:10`
   stops enumerating and points at the spec instead.
3. Fix both ratchet holes, add the count assertion, **run the mutations and record what failed**.
4. Fix `WatchTapInbox.swift:60` and `Distraction.id`, failing test first.
5. Backfill the register in order: `A` rows → chore rows → `## Mutations (M)` → `## Hooks (H)` →
   `## Risks (RR)` → the `:95` footer → DEC-2's resolution.
6. Build the register validator. **Prove it by reintroducing the wrong footer count and watching it go
   red.** Wire into `make checks`, and add the missing `check-status` to that target while there.
7. ⚑ **Read the backfilled register once and confirm it is complete.** This is the irreversible gate.
8. Generate `OPEN.md`. **Publish a row-by-row diff against today's file.** Any row present today and
   absent tomorrow is a backfill bug, not a row to accept.
9. Correct `F8.md` — the `More rest` cell, and Ruling C as ruled in DEC-4. **Only then** does `O37` go
   to a device.
10. Fix the six false plan headers, `F1.md`'s citation of the **rejected** `D6`, and the three comments
    that state the opposite of the code.

---

## 5 · Findings for Turing 2.0

**Written for the coordinating role, not for this project.** These are candidates for promotion into
`docs/conventions.md`; none is ratified. They continue the numbering in
`docs/handoffs/turing-v2.md`, which holds eight.

### 9 · A generator inherits the truthfulness of its source, and then certifies it

`C28` replaced a hand-written status page with a generated one and wired it to CI. The page now prints
`Decisions (D) | 1` for a project with 37 decisions — because it faithfully counts a register holding
one row.

**The wrong number is now machine-attested.** Before, it was somebody's stale prose and a reader might
doubt it. Now a header says GENERATED, a CI step passes, and the number is wrong.

**The check:** when generating a page from a source, **validate the source in the same change**. A
generator is an amplifier — it makes the source's accuracy visible at scale and its inaccuracy
authoritative. Shipping the generator first and the source validation later is shipping the amplifier
before the signal.

### 10 · Deduplicate before escalating, and re-derive the headline claim

Of ~59 raw claims from two reviewers, **16 distinct sites** survived. More usefully: **the two most
dramatic headlines were both overstated**, and both were caught only because a third pass re-ran the
arithmetic rather than reading the report.

- *"Every delta ratified since 2026-09-09 is invisible to the ratchet."* → **four deltas**; `D35` is
  seen.
- *"The preset control's entire justification is invalid."* → **the presets diverge under both rules**;
  what was owed was a two-line correction.

**Both underlying findings were real.** Had either shipped at its stated severity, the refutation would
have killed the headline and taken the real defect with it — the pattern `conventions.md` already
records, where a true finding was refuted because of how it was framed.

**The check:** a condensing pass is not editorial. It **re-runs the load-bearing claims** and
adjudicates where reviewers disagree, and it says which reviewer it overruled and on what evidence.

### 11 · A register ID allocated in a commit message cannot be allocated safely again

`conventions.md` Axis 2 already says a register ID must not appear in a commit message. The mechanism
was not stated, and this project then demonstrated it: `F8-M6` and `F8-M10`–`M13` exist **only** in the
text of two commits. They are cited in no plan, no test, no register — a grep over the tree returns
nothing. Meanwhile `F8-M7` and `F8-M8` were each allocated twice, for different mutations, because the
plan's table had closed at `M5` and the only writable surface left was the commit message.

**The mechanism, which is the part worth promoting:** a commit message is **append-only and
unreadable-back**. Nothing can enumerate what has been allocated there, so the next allocation cannot
know what is taken. **An ID must be allocated in a file that the next allocator will read.**

### 12 · A handoff is an artifact that makes claims, and nothing tests it

`turing-v2.md` §7 asserted that two files had *"drifted five items apart."* It was written confidently
from one `sort | tail` of each, it was wrong in the direction that made the problem look small, and it
is **the first document a resuming session reads**. It survived two sessions and was corrected only
when an unrelated measurement contradicted it.

**The check:** every quantitative claim in a handoff carries the command that produced it, or it is
written as an impression rather than a number. And a corrected handoff entry is **corrected in place
with the error left visible**, never silently rewritten — the correction is the content.

### 13 · "One canonical record" is a claim about mechanism, not about file count

The instinct behind *"two files to maintain is exactly what we need to avoid"* is right, and it does not
follow that merging two files fixes it. `OPEN.md` and the register drifted because **nothing generated
one from the other** — not because there were two. A single hand-maintained file drifts from reality
just as reliably; it merely has nothing to disagree with, so the drift is invisible.

**The check:** before merging two sources, ask which one a **mechanism** will maintain. If the answer is
"a person, carefully", the merge buys tidiness and not correctness — and it costs whatever the discarded
file held. Here that would have been 16 closed rows, 83 lines of prose, and a paragraph recording that
the distraction tally over-reports for one block, which exists nowhere else and is a caveat on the one
outstanding item the whole milestone turns on.

-----
September 16, 2026

#AI/Claude
