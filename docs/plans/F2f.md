# F2f — The Island tomato fills as the sprint runs

**Status:** **PLANNED, NOT BUILT. AWAITING THE OWNER'S YES.** Written at the gate 2026-09-27; the work
is scheduled for 2026-09-28. Ratified as `D52` and applied to `docs/specs/zenpom-v1.5.md` as position
**15** of fifteen.

**Delta:** `D52`, ratified 2026-09-27, with the baseline waiver in the owner's own words — *"The tomato
is authorized and ready to go add it to v1.5."*

**A retrofit of `F2`, not a new feature.** The Lock Screen and Dynamic Island Live Activity shipped
under `F2` — `SPEC.md:39`: *"A Live Activity on the Lock Screen and in the Dynamic Island is required,
not optional — AlarmKit's countdown API mandates one."* Changing what its compact presentation draws is
a second pass on something already shipped. `F2b`–`F2e` are taken; `conventions.md` is explicit that the
letter is an identifier and not an index.

---

## Paraphrasing it back

> *"Also, I see the coffee cup. I want that tomato in v1.5."*
> *"the tomato fills in as the sprint progresses, replacing the coffee cup."*
> *"fills by finished pomadoro -- you can have the cup on the break."*

**A focus block in the Dynamic Island draws a tomato that is as full as the sprint is done.** One
pomodoro of four finished, the tomato is a quarter full. It is a picture of the sprint, not of the block
— the countdown beside it is already the picture of the block. A break keeps the coffee cup it has now.

## THE FIRST THING THIS PLAN FOUND, AND IT CHANGES THE WORK

**The coffee cup is the BREAK symbol. It was never on a focus block.** `BlockLiveActivity.swift:311`:

```swift
Image(systemName: kind == .work ? "timer" : "cup.and.saucer")
```

So the owner saw the cup *because they were looking at a break*, and `D52`'s phrase *"replacing the
coffee cup"* is loose. What the tomato actually replaces is **`"timer"`, the focus glyph** — and the
owner's own second sentence says so without contradiction: *"you can have the cup on the break."* The
cup does not move, is not restyled, and is not conditional. Nothing about the break case changes at all.

**This is the whole reason a plan is written before the code.** Built from `D52`'s title alone, the
first commit would have gone looking for a cup on a focus block, not found one, and either invented a
cup to replace or replaced the break symbol — shipping a tomato where the rest is and a timer glyph
where the work is, exactly inverted, with a green test suite.

## The second thing it found: the ruling made the feature possible, not merely cheaper

`F2`'s central design rule is that **the app never pushes an update into the Live Activity**
(`BlockLiveActivity.swift:4-16`): iOS is handed the instant the block ends and `Text(timerInterval:)`
counts down by itself, once a second, with the app asleep or not running. The comment is explicit that
a future change *"wanting to push updates into this card"* has drifted.

**Filling by elapsed time would have required exactly that** — a smoothly filling tomato is a
per-second redraw of a value only the app knows, and there is no mechanism for it that does not breach
the rule the whole feature rests on.

**Filling by finished pomodoro needs no mechanism at all.** An AlarmKit alarm is scheduled per block
(`TimerEngine.scheduleAlarm(for:)`), so every boundary already replaces the activity's attributes — and
`completedInSprint` is already on them. The tomato changes when the count changes, for free, on a path
that already exists and is already exercised. **The owner's ruling is therefore not a simplification of
the feature; it is the version of the feature that fits the architecture.** That is recorded because it
is the kind of agreement that looks like luck and is worth understanding before somebody "improves" it.

## What is already true, and needs no work

| What | Where | State |
|---|---|---|
| `completedInSprint` and `pomodorosPerSprint` reach the extension | `BlockLiveActivity.swift:50`, `:151` — `SprintCount(completed:total:)` | **shipped** |
| A shaped sprint's reduced count reaches them correctly | `F8-T4`, confirmed on device by the owner: *"the sprint dots were right"* | **shipped and verified** |
| The Island renders at all | verified on device 2026-08-23; the empty Island on 2026-09-27 was another app's Live Activity holding the slot | **shipped** |
| Dark ink inside the Island | `islandInk()` — forces the dark half of every role without naming a colour | **shipped** |

**So there is no data work and no plumbing.** This feature is a shape, a number already in hand, and
three call sites.

## The rulings this plan needs · owner: **human**

Four questions. Two are *small* and are asked because guessing them wrong is invisible; two are
*ordering* questions that change what gets built tomorrow.

### Ruling A — does the tomato appear in the **minimal** presentation?

`minimal` is one glyph roughly twenty points square, shown when another app's activity shares the
Island. At that size *"a quarter full"* is a few pixels of difference.

- **Option 1 — the tomato appears, filling.** Consistent, and probably unreadable.
- **Option 2 — the tomato appears, always whole.** It says *focusing*, which is all that size can say,
  and it matches what `BlockSymbol`'s own comment already argues about the break symbols: *"a third
  glyph splitting two kinds of rest would be a distinction nobody could see at that size."*
- **Option 3 — minimal keeps the timer glyph.** No new drawing at that size at all.

**The agent would pick option 2** and the reason is the existing comment: this file has already decided
once that a distinction nobody can see is not worth drawing, and the same logic applies to a fill
fraction at twenty points. Stated rather than assumed because it is a visible difference.

### Ruling B — what does the tomato do when the block has **ended** or is **paused**?

The readout has `.ended` and `.paused` modes (`:188`, `:179`) and `BlockSymbol` currently ignores both —
it draws by `kind` alone. A tomato that keeps its fill through the alert is honest; one that fills the
last quarter *as the alarm rings* would be claiming a pomodoro that has not been recorded yet.

**The agent would keep the fill at the count on the row** and let it move when the next block's
attributes arrive, which is the same thing the sprint dots already do. It is one line either way and it
is the one place this feature could tell a small lie about how much work was done.

### Ruling C — does the **Lock Screen** presentation change too?

The owner's sentences are about the Island. The Lock Screen is the presentation they actually watched
work, and it has room for words and a `SprintCount` already. This plan proposes **Island only**, on the
grounds that the Lock Screen is not short of space and already says the same thing in numerals. **If the
tomato is wanted there as well it is a fifth task**, not a free extension of the third.

### Ruling D — THE ORDERING QUESTION, AND IT IS THE ONE THAT MATTERS

**`F16`, the tomato garden, also draws tomatoes, and it sits at position 13 — before this at 15.**

Two units in one milestone drawing the same fruit is one tomato or two, and the choice is made by
whichever is built first:

- **Build `F2f` tomorrow** → it invents the tomato, and `F16` must reuse it or the app has two tomatoes
  that do not match. The Island's is tiny, monochrome-ish and drawn on black; the garden's is large, on
  a light surface, and repeated dozens of times. **A shape that serves both is a harder shape than
  either alone**, and designing it under the Island's constraints first is the wrong end.
- **Build `F16` first, `F2f` after** → the garden's tomato is the tomato, and this feature reuses it at
  a small size. This is what the ratified order already says, and the order was not written carelessly.
- **Build `F2f` tomorrow and accept two drawings**, with a note that `F15`'s graphics pass (position 12)
  reconciles them. Honest, and it front-loads a small win.

**The agent's recommendation is the third**, narrowly, and only because the owner asked for this
tomorrow: extract the shape into the shared design system from the first commit so `F16` has something
to reuse rather than something to match. **But this is the owner's to decide and it is the one thing on
this page that cannot be undone cheaply** — a tomato shipped in the Island sets the app's visual idea of
a tomato, and the garden is the feature where a person will actually look at one.

---

## Tasks

Four. The first delivers **nothing user-visible** and is labelled so.

| Task | What it delivers | Owner |
|---|---|---|
| `F2f-T1` | The fill, as a value — no drawing | **agent** |
| `F2f-T2` | The tomato shape, in the design system | **agent** |
| `F2f-T3` | The three Island presentations use it | **agent** |
| `F2f-T4` | The device check — a sprint watched from the Island | **human** |

### `F2f-T1` — How full is the tomato · owner: **agent** · *no user-visible change*

One value type that answers *how full, and which glyph* from the numbers already on the activity's
attributes. No `View`, no drawing, no `Image`.

**Why this is a task and not the first half of the drawing task.** There is no UI test target in this
project, so anything expressed only inside a `View` body is a rule nothing checks — the same reason
`ShapeSheetActions` exists apart from `ShapeSheet`, and the same reason `F8`'s `onFit` closure is the
one line no test can reach. A fill fraction computed inside `BlockSymbol` would be untestable by
construction; computed here it is four assertions and a mutation.

**The denominator is the frozen `pomodorosPerSprint` from the attributes, and nothing else.** A tomato
computing its own total from settings would disagree with the sprint dots drawn beside it the moment a
shape reduced the count — which is precisely the defect `F8-T4` names for this exact surface, and the
owner has already confirmed the dots are right on the device.

*Edges the tests must cover, because each is reachable and each draws something wrong:*

- **Zero of four** — a sprint just begun. An empty tomato, not a missing one.
- **Four of four** — the last pomodoro finished, the long break about to run. Full, not overflowing.
- **A total of zero**, which `:212` already says happens: *"a block with no sprint count in that case
  rather than inventing a number."* The fill must be *absent*, not `0/0` and not a division by zero.
- **Three of three**, the shaped sprint, filling in thirds.
- **`completed` greater than `total`**, which should be impossible and must clamp rather than draw past
  the rim.

*Checkpoint:* the value, asserted at five counts, with the `0` total returning nothing.

### `F2f-T2` — The tomato, drawn · owner: **agent**

A `Shape` or `Canvas` tomato that fills from the bottom to a fraction, at the three sizes the Island
uses.

**It names a `ColorRole` and never a `Palette` step.** `.swiftlint.yml`'s `palette_outside_token_layer`
rule covers `ZenTomatoActivity` explicitly, and it matches across a line break since `F13-M14`. **If no
existing role means *tomato red*, this task stops and asks** — a new semantic role is a design-system
change, and inventing one inside a widget is how a token layer stops being one.

**It is drawn for black.** `islandInk()` forces the dark half of every role because the Island is always
black; a fill that relies on a light surface for contrast will look right in a preview and vanish on the
phone.

**Where it lives decides Ruling D.** If the owner takes the recommendation, this type goes in the shared
design system where `F16` can reuse it, not in `BlockLiveActivity.swift`.

*Checkpoint:* previews at all three sizes and five fill levels, read on a black ground.

### `F2f-T3` — The Island uses it · owner: **agent**

`BlockSymbol` takes the counts as well as the kind: a tomato for `.work`, the cup unchanged for both
breaks. Three call sites — expanded `:42`, compact leading `:60`, minimal `:72` — and Ruling A decides
what the third one does.

**The break path must be untouched, and a test should say so**, because "the cup stays" is the half of
this feature that is easiest to break while changing the file it lives in.

*Checkpoint:* the Release build, and the previews at `:729`–`:862` still rendering.

### `F2f-T4` — Watched from the Island · owner: **human**

`SPEC.md`'s standard: closed on hardware, by the owner, with a build number and their own words.

Run a sprint and glance at the Island, not the app. Answer: **does the tomato say how far through the
sprint you are without you having to think?** Then run a **shaped** sprint of three pomodoros and check
it fills in thirds rather than quarters. Then look at it during a break and confirm the cup is there.

*Checkpoint:* recorded as an `O<n>`, closed by the owner with the build number.

---

## Mutations

| Mutation | The named test that must fail |
|---|---|
| `F2f-M1` · Compute the denominator from the settings' `pomodorosPerSprint` instead of the frozen attribute | the three-pom shaped-sprint assertion in `T1` — it fills in quarters against a sprint of three |
| `F2f-M2` · Return a fill of zero for a total of zero instead of no fill at all | the zero-total assertion — a sprint with no count draws an empty tomato as though no work had been done |
| `F2f-M3` · Draw the tomato for every kind, dropping the cup | the break-path assertion in `T3` — this is the *"you can have the cup on the break"* ruling, and it is one character to break |
| `F2f-M4` · Let a `completed` above `total` through unclamped | the clamp assertion — a fill past the rim |

**`F2f-M3` is the one most likely to be written toothless.** A test that asserts *the tomato appears on
a focus block* passes happily while the cup has been replaced everywhere. The assertion has to be on the
**break** case, which is the one nobody is thinking about while building the tomato.

## Evidence

`make ci` in the PR: lint, the Todoist allowlist, secrets, licence wording, the register, the script
tests, the full suite with its count, and the Release build. Plus `F2f-T4`, closed by the owner with a
build number.

**Four mutations, run and seen to fail before the tasks are called done.** A test that has never been
shown to fail is not evidence.

**And one piece of evidence that is not a test:** the previews, read on a black ground. There is no
snapshot testing in this project, so the drawing itself is checked by eye at the gate and on the device —
which is stated here rather than left implied by a green suite.

## Scope fence

**`D48` is the fence to watch, and this passes it — but only in the form ratified.** `D48` forbids
*"streaks, badges, goals, records, targets, comparisons, or any gamification"*, with one exception for a
display that only ever accumulates. **A filling tomato is not that exception** — it is bounded by one
sprint and empties at the next — so it stands on a different argument: `D48`'s harm is *a quantity a
person can lose*, and there is nothing here to lose. It records nothing, remembers nothing across
sprints, and cannot be protected by under-reporting a distraction.

**The moment it remembers, it is a streak.** A tomato that stayed full after a sprint ended, or showed
yesterday's, or counted sprints, would be the exact mechanism `D48` exists to prevent. That is the line
and it is one field away.

**Also outside this feature:** the Lock Screen presentation unless Ruling C says otherwise · the watch ·
the garden's tomato (`F16`) · any animation of the fill, which would need pushed updates and breaks
`F2`'s central rule · and any change to the countdown, which is not this feature's business.

-----
September 27, 2026

#AI/Claude
