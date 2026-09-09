# zenpom — v1.5 Spec (DRAFT for ratification)

**Status:** DRAFT. The agent proposes; Marty ratifies. Until ratified, nothing here may be built.
**Baseline:** `docs/specs/SPEC.md` (v0.1) remains the contract for everything it covers. This file
adds to it and never edits it. Where the two disagree, v0.1 wins until a `D<n>` says otherwise.
**Source:** `docs/plans/parked.md`, which holds the decisions this milestone is assembled from.
**Supersedes:** the v1.1 / v1.5 split in `parked.md`. v1.1 is absorbed (owner, 2026-09-09).

## The vision sentence — unchanged

> A focus timer that works with the fixed toolset so that study and work blocks run without a second
> app to vacuum — whose actual reason for existing is the distraction log.

**v1.5 does not change what zenpom is for**, and that is the test to re-read at this gate. Every item
below either serves the log or gets a sentence saying why it earns space beside it.

---

## Why this milestone exists, and the risk it carries

v0.1 was fenced by an exam. The exam was cancelled on 2026-09-08, and **the fence came down with
it.** The handoff names the pattern plainly: this project's owner starts bounded and expands
mid-sprint, sometimes as avoidance, and the mechanism that held it is gone.

So this milestone is written with the fence stated **first**, before the feature list, and the list
is capped before it is filled. The one argument that does not count for admitting an item is
*"there's more time available now"* — that is a statement about capacity, not value.

### The four things this gate must produce

| # | Required | State |
|---|---|---|
| 1 | A new hard stop | **proposed below — needs Marty's yes** |
| 2 | A capped feature list, number decided before filling | **proposed: 4 features + 2 chores** |
| 3 | An earned-entry test for every item admitted | **written below, one per candidate** |
| 4 | A restated Phase 3 fence | **written below** |

---

## 1. The hard stop

**Proposed, shipped-artifact rather than a date** (Marty's choice, 2026-09-09):

> **v1.5 is done when a two-hour arrival has been planned by the app and run to completion on the
> device on three different days, and the distraction log from each was read in the Rhodia without
> translation.**

Three runs, three days, because one run can succeed by luck and two can share a mood. It ties the
release to the feature that justifies it: if the planner is not being used on real two-hour gaps,
v1.5 did not ship, whatever is merged.

**It also has a precondition.** v0.1 is not landed — `O1` has never been run, and the export that is
the whole point of the app has never been read beside the Rhodia. **v1.5 opens when v0.1 lands**,
which means `O1` plus the outstanding device checks. Speccing is fine now; building is not.

---

## 2. The cap

**Four features and two chores. Decided before the list was filled.**

The number comes from observed throughput, not ambition: v0.1's six features needed nine retrofits
(`F2b`–`F2e`, `F4c`–`F4f`, `F6b`) and one branch took eleven adversarial passes. A milestone of four
features is a milestone of roughly ten units once retrofits are counted honestly.

**Nine candidates were assessed. Five did not make it.** The list below is complete; nothing was
dropped silently.

---

## 3. The candidates, each against the earned-entry test

> *What does this let me do that v0.1 doesn't?*

### ADMITTED

#### F8 — Divide a stretch of time into a plan

**Earns entry:** it lets you start from *"I have two hours before a meeting"*, which is the input you
actually arrive with. v0.1 requires the opposite — you state the parts and the total falls out. You
rarely have "four pomodoros"; you have the gap before the next thing.

Marty overruled the agent's v1.5 recommendation on this one when it was parked, on the grounds that
it is *"the feature that makes the app worth using."* That reading holds, and it is why this feature
is the spine of the milestone rather than one item on it.

**It is a change to the timer, not a screen on top of one**, and `parked.md` names four decisions it
cannot be built without. They are gate questions for `docs/plans/F8.md`, not spec questions, with one
exception noted under `F9`:

1. Does it write the six settings, or run one plan the engine follows without touching them?
2. Two hours does not divide evenly. *"I will fill your two hours"* and *"I will not overrun your two
   hours"* cannot both be kept — which promise does zenpom make?
3. It presses on `autoStartNextBlock`, which defaults off for a stated reason: *a timer that starts a
   work block while you are still away from the desk is a timer that lies about how long you worked.*
   A wall-clock plan drifts the moment somebody dawdles.
4. It forces the vocabulary to be settled. **This one is not deferrable — see `F9`.**

#### F9 — Instructions, and an explainer of the Pomodoro technique

**Earns entry twice over.**

First: the app currently explains nothing. Every control is legible to the person who built it and to
nobody else. That is acceptable for an instrument of one and disqualifying for anything else.

Second, and the reason it is sequenced **before** `F8`: **it settles the vocabulary `F8` would
otherwise settle by force.** Marty's own request said *"3 sprints over 120 minutes"* — but a sprint
in this app is a whole set of pomodoros, so three of them is five hours, not two. Draft one of the
v1.1 copy has the mirror-image slip, calling a whole set *"a Pomodoro"*
(`docs/verbiage/NOTES-on-draft-one.md`). Neither is careless; the words are genuinely unsettled, and
a planner screen that prints *"3 × 25 minutes with two 5-minute breaks"* has to name what it prints.

**Division of labour, as the owner set it — and it is a departure from the dial:**

| Who | What |
|---|---|
| Owner | Writes the verbiage |
| Claude design | Places and animates it |
| Agent | Completes the execution |

The learning dial says the agent authors everything. Here it does not author the copy. That is the
owner's ruling and is recorded rather than quietly reconciled.

**Its open design question, for the gate:** an explainer is a surface, and this app deliberately has
almost none. *"First run"* is the answer that most easily becomes an onboarding flow nobody wanted.
The `no capture surface` rule is not threatened; the calm-screen rule is.

#### F10 — A "start a sprint" App Intent

**Earns entry:** it lets a sprint actually be undistracted, which is the precondition for the log
measuring anything. Today you can start a sprint only by opening the app and tapping.

The app already declares `DismissBlockIntent`, so the mechanism exists. A second intent lets a
Shortcut **the owner builds** run *Turn On Do Not Disturb* alongside starting a sprint.

**Honest framing, carried over from `parked.md`:** this is a capability the owner *assembles*, not
one zenpom grants. The app still never touches Focus. It cannot — verified in the SDK: nothing in
`Intents`, `AppIntents` or `UserNotifications` sets a Focus or suppresses another app's
notifications, and the one Focus API an app gets (`SetFocusFilterIntent`) runs the other way. An app
that could silence your other notifications is an app Apple would not ship.

#### F11 — RESERVED, and deliberately empty

**The fourth slot is unfilled on purpose.** Two candidates below have real merit and an unanswered
question each; one of them takes this slot once its question is answered. A cap filled to the brim on
day one is a cap that has already failed — the slot exists so the milestone can absorb one thing it
learns while building, without reopening scope.

### CHORES

#### C21 — A zenpom Focus runbook

**No user-visible change, therefore a chore, not a feature.** Written instructions for building a
Focus in iOS Settings that allows zenpom and silences the rest. Pure documentation, works on the
shipped build, could be written today. Its only cost is that the person has to turn it on.

**Owner: agent.** It pairs with `F10` — same goal, two routes, and `parked.md` records that the owner
wants both.

#### C22 — Settle which licence the binaries carry

**Blocks the About screen and nothing else.** `C10` ruled dual licensing but never settled *which*
licence the binaries carry. An About screen naming a licence before that is answered states a claim
that may have to be corrected in a binary already on people's phones — the one kind of mistake a
licence notice must not make.

**Owner: human.** It is a decision, not a task.

### NOT ADMITTED — Phase 3

Each with the reason, so none is re-litigated.

| Candidate | Why not |
|---|---|
| **An About screen** | Blocked on `C22`, and blocked for a good reason. Small once unblocked; a strong claimant for `F11` if `C22` closes early. Version and build already ship as a plain Settings row — the useful half was deliberately split out and is done. |
| **The redesign** (`docs/ZenTomato redesign scope.zip`) | **Fails the earned-entry test as written** — it does not let you do anything you cannot do now. That may be a failure of the *statement* rather than the work; see the open question below. |
| **Spotify** | Fails outright. The toolset is fixed and Apple Music is in it. `D16` is the standing guard, and `F4c`'s review upheld it: there is no provider abstraction anywhere and there must not be one until this is a gate of its own. |
| **A more independent watch app** | Contradicts ratified `D2` — the phone is the source of truth and runs the only timer engine. Loosening that is a large conversation, and a large conversation is exactly what a cap exists to defer. |
| **A watch-face complication** (`D30`, proposed) | Excluded by `SPEC.md` line 58 by name — *"widgets beyond the Lock Screen Live Activity"*. Needs `D30` ratified before it is even a candidate. Also a claimant for `F11`. |

---

## 4. The Phase 3 fence

**Phase 3 is: Spotify · a more independent watch app · macOS · CloudKit sync · playlist creation ·
any capture surface of any kind · themes · streaks, badges or gamification.**

Restated with the same discipline the Phase 2 fence had, minus the dependency on a cancelled exam.
**A feature request that is not on the admitted list above gets one question — *is this v1.5 or
Phase 3?* — and the answer is written here before anything is built.**

**Task creation is not on either list, and that is deliberate.** It collides with the no-capture-
surface standing rule, which is a property of the owner's productivity system rather than a scope
decision. It is not a feature request; it is a rule change, and it would need its own argument.

---

## Standing rules — untouched by this milestone

Reopening scope does not reopen these. They are properties of the app.

- **No capture surface.** zenpom never accepts a new task from the user.
- **Todoist writes are limited to completing a task.** Enforced by hook, not prose.
- **Todoist owns the hierarchy.**
- **Secrets never enter the tree.**
- **Local only.** No analytics; no network except Todoist and MusicKit.
- **The agent never edits `SPEC.md`.**

---

## Hook intentions for v1.5

Existing hooks carry forward. Two are added, and both exist because this milestone's shape invites a
specific failure:

1. **The vocabulary stays settled.** Once `F9` names the words, a check that fails the build when
   shipped Swift uses the retired ones. `PolishFenceTests` already does this for parked vocabulary
   and is the model.
2. **The planner does not silently rewrite settings.** Whichever way question 1 of `F8` is answered,
   a test asserts it — because "it wrote my defaults because I once had a two-hour gap" is a defect
   nobody would notice until their next ordinary sprint ran wrong.

---

## Open questions for Marty — these block ratification

1. **The cap: is four the right number?** Four features and two chores, with the fourth slot held
   empty. Say a different number and the list is re-cut to it.

2. **The hard stop: is three runs on three days the right condition?** It is the piece of this
   document most worth arguing with, because it is the only thing that ends the milestone.

3. **The redesign — what does it let you do?** It is in `parked.md` as v1.5's input, with a tracked
   zip and a stated history of being destroyed twice, so it clearly matters. But no sentence anywhere
   says what problem it solves, and I will not invent one to justify admitting it. Answer that and it
   is a strong claimant for `F11`.

4. **`F9` before `F8` — agreed?** The vocabulary argument says the explainer must come first. That
   inverts the obvious order, since `F8` is the exciting one, and putting the writing task first is
   the sort of sequencing that quietly slips.

5. **Does the learning dial move?** The handoff flags this as legitimately reopenable now that this
   is a dedicated coding project rather than a bounded sprint. `F9` already breaks the 5% floor by
   having the owner write the copy. Propose; do not change silently.

-----
September 9, 2026

#AI/Claude
