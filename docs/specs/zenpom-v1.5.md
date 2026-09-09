# zenpom — v1.5 Spec

**Status:** **RATIFIED by the owner, 2026-09-09.** This is the contract for v1.5.
**Baseline:** `docs/specs/SPEC.md` (v0.1) remains the contract for everything it covers. This file
adds to it and never edits it. Where the two disagree, v0.1 wins until a `D<n>` says otherwise.
**Vocabulary:** `docs/specs/definitions.md`, ratified 2026-09-09, governs every word used here.
**Sources:** `docs/plans/parked.md`, the open register, and the owner's gate of 2026-09-09.
**Ratified as a baseline**, the way `SPEC.md` and `definitions.md` were. From here it is not edited to
match reality: a change to scope, order or the stop condition is a `D<n>`.
**Supersedes:** the v1.1 / v1.5 split in `parked.md`. v1.1 is absorbed.

## The vision sentence — unchanged

> A focus timer that works with the fixed toolset so that study and work blocks run without a second
> app to vacuum — whose actual reason for existing is the distraction log.

**v1.5 does not change what zenpom is for.** Every item below either serves the log or says why it
earns space beside it.

---

## The fence: v1.5 is polish, v2.0 is platform

**Ratified 2026-09-09.** The milestone boundary is an architectural line rather than a number:

- **v1.5 — polish.** Everything that changes the app that already exists.
- **v2.0 — platform.** Everything that adds a **platform** or a **provider**.

**Why a line and not a cap.** The v0.1 fence was a date, anchored to an exam that was cancelled. A
number replacing it would have been arbitrary and defended arbitrarily. A line can be applied to an
item nobody has thought of yet, which is what a fence is for.

**And the honest caveat, recorded at the moment it was noticed.** Of eleven candidates assessed at
this gate, only three fell on the platform side. **The line admitted almost everything**, so it is
doing less fencing work than its shape suggests. What actually holds v1.5 is the stop condition
below, which does not care how long the list is.

---

## The hard stop

> **v1.5 ends when zenpom has driven four consecutive fortnightly Rhodia reviews from its own export.**

Not a date. Ratified 2026-09-09.

**It is feature-independent on purpose.** An earlier draft tied the stop to `F8` shipping, which made
the milestone hostage to its largest feature — if `F8` slipped, v1.5 could never end. This measures
the thing the app exists for instead, and stays reachable whatever gets cut.

**Four, not one.** One export can be readable by luck and two can share a mood. Four is roughly two
months of real use — long enough that the polish either helped or it didn't, and long enough to tell
which.

**It absorbs `O1`.** The first of the four *is* `O1`, v0.1's outstanding *Done when* for `F6`, which
has never been run. **The log has never once been read for its purpose.** That is the single most
important fact about this project's state and the stop condition now depends on fixing it.

---

## The work

**Ten features and two chores.** Larger than all of v0.1, which was six features — and those six
needed nine retrofits and a branch that took eleven adversarial review passes.

**The list is not expected to finish, and that is by design.** v1.5 ends on four Rhodia reviews,
whatever has shipped by then. So **order is the real decision**, not membership.

### Order — cheapest first, with `F8` first among equals

**Ratified 2026-09-09.** Two items cost no build time at all and go first. `F8` follows, because
deferring the feature the owner called *"the one that makes the app worth using"* behind six small
ones would be following a rule off a cliff. Everything after that is cheapest-first.

| # | ID | Item | Size | Delta owed? |
|---|---|---|---|---|
| 1 | `C21` | zenpom Focus runbook | zero code | no |
| 2 | `C22` | Which licence the binaries carry | a decision | no |
| 3 | `F8` | **Fit a sprint to the time you have** | L | no |
| 4 | `F12` | Themes | S | **yes** |
| 5 | `F13` | Todoist, with Todoist's flair | S | no |
| 6 | `F11` | About screen | S | no |
| 7 | `F14` | The watch can launch a pom | S/M | probably not |
| 8 | `F10` | A "start a sprint" App Intent | S/M | no |
| 9 | `F9` | Instructions and the explainer | M | no |
| 10 | `F15` | The graphics pass | M | no |
| 11 | `F16` | The tomato garden | M | **yes** |
| 12 | `F17` | A watch-face complication | M/L | **yes — `D30`** |

**The constraint that sets the pace is not build time.** At the 5% dial the owner reviews every PR in
one fixed afternoon slot. **Review capacity is the bottleneck**, and an order that front-loads small
PRs is an order that keeps that queue moving.

---

## Earned entry, one per item

> *What does this let me do that v0.1 doesn't?*

`C21` · **A sprint that is actually undistracted.** Written instructions for an iOS Focus that allows
zenpom and silences everything else. Pure documentation, works on the already-shipped build. The app
cannot set a Focus and no app can — verified in the SDK; the one Focus API an app gets runs the other
way.

`C22` · **Nothing on its own — it unblocks `F11`.** An About screen naming a licence before this is
settled would state a claim that might have to be corrected in a binary already on people's phones.
Admitting `F11` is what gives this chore a consumer; without it, it would not belong here.

`F8` · **Lets you start from "I have two hours before a meeting"**, which is the input you actually
arrive with. v0.1 requires the inverse: state the parts, and the total falls out. Fully specified in
`docs/plans/F8.md` — four rulings, floors, caps, and worked test data across seven budgets.

`F12` · **Lets the app look like something you chose.** Admitted partly on cost: the design system is
two-layer with 42 semantic colour roles, **zero** hardcoded colours in any view, and a SwiftLint rule
failing the build if `Palette.` appears outside the token layer. A theme is a swap of primitives
behind roles that already exist.

`F13` · **Lets you recognise your own projects at a glance.** Todoist's project colours and priority
flags are already fetched and cached, and currently thrown away. The picker is bland because it
discards data it already holds.

`F11` · **Ships the sound attribution the owner ruled is required** *regardless of what the licences
demand*. That makes it an obligation rather than a feature, and it is the reason this is not deferred
with the other small screens.

`F14` · **Lets a pom start from the wrist**, so the phone can stay in another room — which is the
condition `O15` already asks the watch to work under. **Launching is not independence:** the phone
still runs the only timer engine, so `D2` is untouched. The independent watch app remains v2.0.

`F10` · **Lets a Shortcut turn on Do Not Disturb and start a sprint together.** Its value over `C21`
is precisely the step you would otherwise forget during the sprint that needed it most.
`DismissBlockIntent` already proves the mechanism.

`F9` · **Lets anybody but the builder use the app**, and settles the vocabulary. `F9-T1` is already
complete — `definitions.md` is ratified — and it was the only part `F8` waited on.

`F15` · **Lets the app look professional rather than built.** The owner's words: *sharper,
professional grade*. Its input exists: `docs/ZenTomato redesign scope.zip`, tracked deliberately
because it was destroyed twice in one morning by ordinary git operations. **This answers the earned-
entry question the previous draft left open and refused the item over.**

`F16` · **Lets finished work show up as something that accumulates.** Poms grow the garden.

> **Ratified 2026-09-09: the garden accumulates and nothing is ever lost. No streaks, no badges, no
> broken chains.** A streak rewards an unbroken record; the log's value is honest tallying,
> *including bad days*. Once a streak is on screen there is a reason not to log the distraction that
> breaks it, or not to open the app at all on a bad day — and the instrument starts measuring the
> wish to protect a number. The standing rule is *if a scope decision threatens the log, the log
> wins*. **The incentive problem is the streak, not the reward**, so the reward is kept.

`F17` · **Lets a block be seen and started from the watch face.** Requested by the owner 2026-08-28.
Largest of the small items: it needs a separate watchOS widget extension that does not exist — the
only `WidgetKit` code in the tree is the iOS Live Activity. Pairs naturally with `F14`.

---

## Deltas this milestone owes

**Three items contradict the ratified v0.1 contract and cannot be built until each has a `D<n>`.**
Recorded here rather than discovered at a review.

| Item | What it contradicts |
|---|---|
| `F12` Themes | `SPEC.md`'s out-of-scope list names **themes** explicitly |
| `F16` Garden | The same list names *"streaks, badges, or any gamification"*. The delta must argue the **accumulate-only** form specifically, not gamification in general |
| `F17` Complication | `SPEC.md` line 58 — *"widgets beyond the Lock Screen Live Activity"*. `D30` is already proposed and unratified |

**`F14` probably owes nothing**, and the reasoning is recorded so it is checked rather than assumed:
`D2` says the watch never runs a timer of its own, and a launch command where the phone still runs
everything does not violate that. Confirm at its gate.

---

## v2.0 — platform

Deferred by the line, not refused. Each keeps its reasoning.

| Item | Note |
|---|---|
| **A macOS client** | A platform. Genuinely wanted; genuinely v2.0. |
| **iCloud / CloudKit sync** | A platform, and **the highest-risk item on either list.** The log is local-only today with no conflict resolution to get wrong. Sync is where the crown jewel would be lost. |
| **Spotify** | A provider. `D16` is the standing guard and `F4c`'s review upheld it: there is no provider abstraction anywhere and there must not be one until this is a gate of its own. |
| **YouTube Music** | A provider — **and a claim about someone else's system.** Whether it can be played from a third-party iOS app at all must be verified by something that runs before this is ratifiable. |
| **A more independent watch app** | Contradicts ratified `D2`. `F14` delivers the useful half without reopening it. |

## Never — not deferred

**No capture surface, and no Todoist task creation.** A property of the owner's productivity system,
not a scope decision. It is not a feature request; it is a rule change, and it would need its own
argument.

## Standing rules — untouched

Todoist writes are limited to completing a task · Todoist owns the hierarchy · secrets never enter the
tree · local only, no analytics · **the agent never edits `SPEC.md`**.

## Hook intentions

Existing hooks carry forward. Two are added:

1. **The vocabulary stays settled.** `F9-T2` — shipped Swift may not use a retired word.
   `definitions.md` holds the list.
2. **The garden cannot grow a streak.** A test that fails if any user-facing surface counts
   consecutive days or renders an unbroken chain. `F16`'s ruling is only real if something enforces
   it, and this is the one place a later change would quietly undo a decision made on the log's
   behalf.

-----
September 9, 2026

#AI/Claude
