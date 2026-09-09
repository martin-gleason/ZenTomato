# zenpom — definitions

**Status:** **RATIFIED by the owner, 2026-09-09.** This is the contract for what the words mean.
**Purpose:** one place that says what each word means, so the app, the copy, the export and the plans
cannot drift apart. Cited by `docs/plans/F8.md` and `docs/plans/F9.md`.

**This file is a baseline**, ratified directly by the owner as `SPEC.md` was. It is not edited to
match reality: **a change to any definition below is a `D<n>`**, proposed by the agent and ratified by
the owner, never a tidy-up.

---

## The words

| Word | Means | Notes |
|---|---|---|
| **Pomodoro** (**pom**) | **One focus block.** The work interval alone. | Indivisible. The break is not part of it. |
| **Break** | The rest that **follows** a pom | Short by default; long at the end of a sprint. |
| **Cycle** | **One pom plus the break that follows it** | The unit that tiles the clock. 25 + 5 = 30. |
| **Sprint** | **The set of poms you run before the long break** | The setting is `pomodorosPerSprint`. A sprint of one is legal. |
| **Plan** | **What you will work on, in order** | The existing `SessionPlan`: Todoist items, chosen ahead of time. Creates nothing. |
| **Shape** | **How a stretch of time is cut into blocks** | `F8`. *"Fit a sprint to 2 hours"* produces a shape. |
| **Block** | Any single timed span — a pom or a break | What the engine schedules and the alarm ends. |
| **Distraction** | An interruption, tallied in the moment | **Internal** or **External**. Never "I" and "E" in front of a user. |
| **Stopped early** | A block abandoned before its end | Recorded with a reason, not hidden. Has its own export section. |

---

## Why a pomodoro is the focus block, and not the focus block plus its break

**The method is explicit and so is its author.** A Pomodoro is 25 minutes of *pure work* and is
**indivisible** — "there is no such thing as half a Pomodoro." The published steps put the break
outside it: *"When your session ends, mark off one Pomodoro and record what you completed. Then enjoy
a five-minute break."* You mark the pomodoro off **before** the break begins.

**Three further reasons, specific to this app:**

1. **The copy links to a source that says so.** `docs/verbiage/ZenPom Instructions.md` sends the
   reader to Todoist's explainer, which defines a pomodoro as the work interval. A help screen that
   contradicts the page it cites teaches the reader to distrust it.
2. **The code already says so**, everywhere and consistently. `pomodorosPerSprint` counts focus
   blocks; `BlockKind` separates work from short and long break; `SettingsBounds.minutes` bounds one
   block, not a pair. Redefining the word would mean either renaming that surface or leaving the code
   and the copy permanently disagreeing.
3. **The export already says so.** Counts are per focus block. Changing the word changes what every
   historical row means, retroactively, in a file whose whole job is being readable at the fortnightly
   review.

## Why **cycle** exists, and what it is for

The unit *"one pom plus its break"* is real, useful, and was worth naming — it is the thing that
actually tiles a stretch of clock time, and it is why "I have two hours" divides so much more neatly
by 30 than by 25.

Giving it its own word means `F8` can do honest arithmetic in cycles without taking *pomodoro*'s
name for it, and without the app teaching a definition the method does not hold.

**Where each is used:** the log, the stats and the export count **poms**, because that is what work
is measured in. `F8` computes in **cycles**, because that is what time is measured in.

## Why **plan** and **shape** are two words

`SessionPlan` already exists in the source and already means *"the ordered list of things you mean to
work through."* A shape is a different thing: **what** you will work on versus **how the time is cut
up**. They compose — a two-hour shape working through a plan is the ordinary case.

Using one word for both would put two unrelated meanings on the same noun in the same app, which is
the failure this file exists to prevent.

## Words that are retired

Not to be used in shipped copy, UI strings, or new code. `F9-T2` builds the fence that enforces this.

| Retired | Because | Use |
|---|---|---|
| A "Pomodoro" meaning the whole set | Draft one's *"One full set of this is a Pomodoro!"* teaches a word the app contradicts | **sprint** |
| A "Pomodoro" meaning focus + break | Contradicts the method and the source the copy cites | **cycle** |
| "I" and "E" as user-facing labels | `DistractionButtons` already spells them out, deliberately | **Internal**, **External** |
| "Plan" meaning a division of time | Collides with `SessionPlan` | **shape** |

---

## The ruling, and the alternative that was refused

**Ratified 2026-09-09.** The owner proposed that a pom is *"a full cycle of focus and break"*, asked
for it to be checked against the method, and — on the evidence below — ratified the table above
instead. Recorded here so it is not re-litigated, and so the reasoning survives the decision.

**The evidence, five sources, unanimous.** A pomodoro is the work interval; the break follows it.

| Source | Wording |
|---|---|
| Wikipedia | *"For the purposes of the technique, a pomodoro is an interval of work time."* |
| Cirillo, the technique's author | *"A Pomodoro is indivisible… marks 25 minutes of pure work."* |
| TechTarget | *"Each work interval is called a pomodoro."* |
| Todoist — **the page this app's own help copy links to** | *"When your session ends, mark off one Pomodoro… **Then** enjoy a five-minute break."* |
| Emory University Libraries | the same |

**Two details settle it beyond a preference.** The *indivisibility* rule only parses if the break is
outside — a unit you are already resting inside cannot be abandoned, and this app already implements
that distinction, with a `Stopped early` section in the export. And the *counting* only parses if the
break is outside: every source says a long break comes after four pomodoros, which would mean four
breaks followed by a fifth if a pomodoro already contained one.

**The proposal was not invented, and it was not discarded.** *"A pomodoro is thirty minutes"* is
common usage in timer apps and blogs — but the unit those descriptions are reaching for is the one
that tiles the clock, and the canonical vocabulary leaves it unnamed. That gap is real, and `F8`
walks straight into it: two hours divides neatly by thirty and badly by twenty-five. So the unit is
kept and named **cycle**. The owner's arithmetic survives; only the label changed.

**What ruling the other way would have cost**, kept on the record because a refused option should
show its price: `pomodorosPerSprint`, `BlockKind`, the stats counts and the export's historical
meaning would all have shifted; the help screen would have had to stop citing a source that
contradicts it; and **every past export would silently have changed meaning** — the one artefact that
must stay readable across time, since it is what the fortnightly Rhodia review is read from.

-----
September 9, 2026

#AI/Claude
