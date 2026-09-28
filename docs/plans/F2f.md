# F2f — The Island tomato fills as the sprint runs

**Status:** **RULING A IS ANSWERED — `D55`, the handoff's fill. `T1` IS A SPIKE AND STARTS FIRST.**
Previously: PLANNED, NOT BUILT, RULING A BLOCKING. Written at the
gate 2026-09-27 and **revised the same evening** once the owner pointed at
`docs/ZenTomato redesign scope.zip`, which the first draft did not know existed and which specifies this
feature — differently. The work is scheduled for 2026-09-28. Ratified as `D52` and applied to `docs/specs/zenpom-v1.5.md` as position
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

## THE DESIGN HANDOFF SPECIFIES THIS FEATURE, AND IT SPECIFIES IT DIFFERENTLY

**Read 2026-09-27, after this plan's first draft, at the owner's prompting — and the first draft did not
know it existed.** `docs/ZenTomato redesign scope.zip` → `design_handoff_v1.5_upgrade/`. It is `F15`'s
tracked design input, protected by an explicit `.gitignore` negation, and it names this feature by name:

> **Island tomato ("Ripen")** — the Dynamic Island compact/minimal glyph becomes a tomato that **fills
> with red as the block runs**, derived purely from start/end dates.

> **Island** (always dark-resolved roles): the compact-leading / minimal `timer` glyph and the expanded
> leading glyph become the **Ripen tomato**: circle outline r9 (`#948F84` 1.2px), red `#E06A50` fill
> **rising from the base as the block elapses** (rect clipped to the circle, scaleY = progress, origin
> bottom), leaf crown `#8AA163` on top drawn over the fill. 24×26 viewBox as drawn; render at glyph size.

**Two things follow, and the first is a question only the owner can answer.**

### The conflict: the handoff fills per BLOCK by elapsed time; the owner ruled per SPRINT by finished pomodoro

| | Handoff | Owner, 2026-09-27 |
|---|---|---|
| What fills it | **elapsed time** within the block | **finished pomodoros** in the sprint |
| What it is a picture of | how far through *this block* you are | how far through *the sprint* you are |
| How it moves | smoothly, continuously | in steps, at boundaries |

These are different features that happen to look similar. **The owner's ruling is later and the owner is
the authority, so this plan builds the ruling** — but the handoff is a tracked input the owner
commissioned, and the conflict is surfaced rather than silently resolved in the ruling's favour. `F16`
hit the same collision over the garden and the owner settled it explicitly (*"go with F16's form"*); this
one has not been put to them.

**It also confirms one thing this plan worked out independently:** the handoff says the tomato replaces
*"the compact-leading / minimal `timer` glyph"* — the **timer**, not the cup. Two readings of the code,
arrived at separately, agreeing.

### THE CORRECTION: THIS PLAN'S FIRST DRAFT MADE A CONFIDENT CLAIM THAT IS FALSE

The first draft said that filling by elapsed time *"would have required"* a per-second push and that
*"there is no mechanism for it that does not breach the rule the whole feature rests on."* **That is
overstated, and the handoff knew better** — `recreation-notes.md:33`:

> Countdown is self-driving `Text(timerInterval:)` — app pushes NO updates; any tomato fill must derive
> purely from start/end dates (**`ProgressView(timerInterval:)` idiom**).

`ProgressView(timerInterval:)` is real, is self-driving in a Live Activity exactly as
`Text(timerInterval:)` is, and needs no pushes. So *a* self-driving elapsed-time indicator is available
and the claim that none exists was wrong.

**What survives the correction, stated narrowly this time.** A self-driving *bar* exists; a self-driving
*custom-shaped fill* does not. `ProgressViewStyle.Configuration.fractionCompleted` is `nil` for a
timer-interval progress view, so a custom style cannot read the fraction and clip a tomato to it — which
is precisely what the handoff's *"rect clipped to the circle, scaleY = progress"* needs. The handoff's
tomato would therefore be **static between the system's own occasional re-renders**, not smoothly
rising, unless it is built out of the system bar rather than out of a clipped shape.

**So the honest position is narrower and more useful than the first draft's:** filling by finished
pomodoro is *certainly* free, because an alarm is scheduled per block
(`TimerEngine.scheduleAlarm(for:)`), every boundary already replaces the activity's attributes, and
`completedInSprint` is already on them. Filling by elapsed time is *possible* but needs a construction
nobody has demonstrated in this app, and `conventions.md` is explicit that a claim about what another
system can do is not ratifiable until something has run. **If the owner prefers the handoff's version, a
spike comes before the delta.**

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

**Five questions, and Ruling A is new and blocking.** Two are *small* and are asked because guessing
them wrong is invisible; the rest change what gets built tomorrow.

### Ruling A — THE FILL · **ANSWERED: THE HANDOFF. `D55`.**

> *"go with the handoff, but keep the coffee icon from today's conversation."*

**Elapsed time over the block**, rising from the base, derived purely from the block's start and end
instants. `D55` supersedes `D52`'s fill rule; `D52`'s *"finished pomodoro"* is kept in the register
rather than struck, because it answered the question in front of it before the handoff was read.

**The cup stays on breaks** — now ruled twice, and the handoff agrees independently: it replaces *"the
compact-leading / minimal `timer` glyph"*, which is the focus glyph.

**This changed the tasks and the mutations below, and it made the spike mandatory rather than
precautionary.** The fill no longer comes from a count this app already has; it comes from a mechanism
nobody here has demonstrated.

### Ruling B — does the tomato appear in the **minimal** presentation?

(Was Ruling A.) `minimal` is one glyph roughly twenty points square, shown when another app's activity shares the
Island. At that size *"a quarter full"* is a few pixels of difference.

- **Option 1 — the tomato appears, filling.** Consistent, and probably unreadable.
- **Option 2 — the tomato appears, always whole.** It says *focusing*, which is all that size can say,
  and it matches what `BlockSymbol`'s own comment already argues about the break symbols: *"a third
  glyph splitting two kinds of rest would be a distinction nobody could see at that size."*
- **Option 3 — minimal keeps the timer glyph.** No new drawing at that size at all.

**The agent would pick option 2** and the reason is the existing comment: this file has already decided
once that a distinction nobody can see is not worth drawing, and the same logic applies to a fill
fraction at twenty points. Stated rather than assumed because it is a visible difference.

### Ruling C — what does the tomato do when the block has **ended** or is **paused**?

The readout has `.ended` and `.paused` modes (`:188`, `:179`) and `BlockSymbol` currently ignores both —
it draws by `kind` alone. A tomato that keeps its fill through the alert is honest; one that fills the
last quarter *as the alarm rings* would be claiming a pomodoro that has not been recorded yet.

**The agent would keep the fill at the count on the row** and let it move when the next block's
attributes arrive, which is the same thing the sprint dots already do. It is one line either way and it
is the one place this feature could tell a small lie about how much work was done.

### Ruling D — does the **Lock Screen** presentation change too?

The owner's sentences are about the Island. The Lock Screen is the presentation they actually watched
work, and it has room for words and a `SprintCount` already. This plan proposes **Island only**, on the
grounds that the Lock Screen is not short of space and already says the same thing in numerals. **If the
tomato is wanted there as well it is a fifth task**, not a free extension of the third.

### Ruling E — THE ORDERING QUESTION · **MOSTLY ANSWERED BY THE HANDOFF**

**`F16`, the tomato garden, also draws tomatoes, and it sits at position 13 — before this at 15.** The
first draft of this plan asked whether that meant one tomato or two and called it the expensive,
irreversible decision.

**The handoff answers it: one shape.** It specifies the same circle-plus-sepal-crown in a 24×26 box for
the garden's glyph, the Island's glyph and the app icon, differing only in radius, whether the body is
filled or outlined, and the crown's colour. So the shape is shared by construction and neither feature
invents it.

**What is left of the question is small and is still the owner's:** the Island's version is *outlined*
with a rising fill, the garden's is *solid*. One type with a style parameter, or two drawings of one
specified shape? The agent would write one type — the handoff describes one object seen twice — and
would put it in the shared design system from the first commit so `F16` reuses it rather than matching it.

~~Two units in one milestone drawing the same fruit is one tomato or two, and the choice is made by
whichever is built first:~~ **The remaining ordering considerations, kept because they still bear on
which to build tomorrow:**

- **Build `F2f` tomorrow** → it invents the tomato, and `F16` must reuse it or the app has two tomatoes
  that do not match. The Island's is tiny, monochrome-ish and drawn on black; the garden's is large, on
  a light surface, and repeated dozens of times. **A shape that serves both is a harder shape than
  either alone**, and designing it under the Island's constraints first is the wrong end.
- **Build `F16` first, `F2f` after** → the garden's tomato is the tomato, and this feature reuses it at
  a small size. This is what the ratified order already says, and the order was not written carelessly.
- **Build `F2f` tomorrow and accept two drawings**, with a note that `F15`'s graphics pass (position 12)
  reconciles them. Honest, and it front-loads a small win.

**The agent's recommendation is the third**, and the handoff makes it much safer than it looked: the
shape is specified, so building the Island first cannot set a *different* visual idea of a tomato from
the garden's. Extract it into the shared design system from the first commit and `F16` reuses it.

**The one thing on this page that still cannot be undone cheaply is Ruling A** — whether the fill
follows the owner's ruling or the handoff's — because it decides what the tomato *means*, and the two
mean different things.

---

## Tasks

Five. The first is a **spike** and produces no shippable code; the second delivers nothing user-visible.

| Task | What it delivers | Owner |
|---|---|---|
| `F2f-T1` | **The spike** — can a custom-shaped fill self-drive at all? | **agent** |
| `F2f-T2` | The tomato, drawn, from the handoff's geometry | **agent** |
| `F2f-T3` | The fill, driven by whatever `T1` established | **agent** |
| `F2f-T4` | The three Island presentations use it; breaks untouched | **agent** |
| `F2f-T5` | The device check — a block watched from the Island | **human** |

### `F2f-T1` — THE SPIKE · owner: **agent** · *no shippable code*

**`conventions.md`: a decision about what another system can do is not ratifiable until something has
run.** The handoff's fill is exactly such a decision, and the agent's reasoning about it has already been
wrong once — first claiming no self-driving mechanism exists at all, then narrowing to *none for a custom
shape*, which is better argued and still unrun.

**What is established:**

- `Text(timerInterval:)` and `ProgressView(timerInterval:)` self-drive in a Live Activity with no pushes.
- A custom `ProgressViewStyle` reads `fractionCompleted` as **`nil`** for a timer-interval progress view,
  so it cannot clip a shape to the fraction.
- A widget's own views are rendered to a snapshot; arithmetic in the extension is evaluated once per
  render, not per second.

**So the handoff's literal construction — *"rect clipped to the circle, scaleY = progress"* — cannot work
as written**, because `progress` would be whatever it was at the last render.

**The candidate that might.** Put the *system's own* self-driving progress view inside the tomato and let
it do the moving: a `ProgressView(timerInterval:countsDown:)`, rotated a quarter turn so its bar runs
bottom-to-top, clipped to the tomato's body. The extension never computes a fraction; iOS moves the bar
it already knows how to move. **Whether that survives rotation, clipping and a 24-point box is the
question, and it is answered by looking at it.**

*What the spike must produce, and it is not an opinion:*

1. A build on the phone whose Island shows the candidate construction during a real focus block.
2. The owner's answer to one question: **does the red rise during the block, or does it sit still?**
3. If it sits still, the same for the fallbacks, in order: a system **circular** progress view used as a
   ring around the tomato; and a fill that steps at boundaries, which is `D52`'s version and is already
   known to work.

*Checkpoint:* the observed behaviour, written into this plan with the build number — **and if it rises,
the delta's mechanism stops being unsettled.** If none of the three rises, the owner chooses, and the
choice is between a ring that moves and a tomato that steps.

**BUILT 2026-09-28.** All three candidates are drawn in the **expanded** Island region, beneath the
countdown, on focus blocks only — a break keeps its cup and the spike must not imply otherwise. Labelled
`A`, `B`, `C` so the answer can be given in one letter. The compact and minimal presentations are
untouched, because the question is *does it move*, and the expanded region is the one with room to show
three of anything.

*Awaiting the owner's observation. The question is exactly one sentence: **which of A, B, C actually
rises as the block runs?***

### `F2f-T2` — The tomato, drawn · owner: **agent**

**THE GEOMETRY IS SPECIFIED AND IS NOT INVENTED HERE.** The handoff gives it twice, at two sizes, and
the two agree:

| | Island tomato | Garden / icon tomato |
|---|---|---|
| body | circle r9, outline `#948F84` at 1.2px | circle r9, **filled** `#C0392B` |
| fill | `#E06A50` rising from the base | n/a — solid |
| crown | leaf `#8AA163`, over the fill | sepal crown `#4C5C36`, three triangles from the top point |
| box | 24×26 viewBox, rendered at glyph size | 24×26, the icon's is the same shape at r246 with a stem |

So this task **ports a specified shape**: a circle, a triangular sepal crown drawn over the fill, and a
1.2px outline, in a 24×26 box.

**The hex values do not survive contact with the lint rule, and that is correct.**
`.swiftlint.yml`'s `palette_outside_token_layer` covers `ZenTomatoActivity` explicitly and matches across
a line break since `F13-M14`, so `#E06A50` cannot appear in that target. Four values need roles, and the
handoff's own theme section is where they belong — *"all colors read from the active theme table"*, with
`Ripen` one of seven. **`F12` Themes is position 3, before this at 15, and owes its own delta**, so until
it lands there is no theme table to read a tomato red out of: this task adds the roles to the existing
table, which is a design-system change and is named as such rather than done inside a widget.

**Still open and the owner's:** does the Island tomato's red follow the active theme, or is it always
Ripen's red? A tomato that turns teal under the Teal theme is a decision, not a detail.

**It is drawn for black.** `islandInk()` forces the dark half of every role; the handoff says the same —
*"always dark-resolved roles"*. A fill relying on a light ground will look right in a preview and vanish
on the phone.

*Checkpoint:* previews at three sizes and five fill levels, read on a black ground.

### `F2f-T3` — The fill moves · owner: **agent**

Whatever `T1` established, wired to the block's start and end instants — which the readout already
carries as `.running(from:to:)` (`BlockLiveActivity.swift:205`). **No new data and no `.update()`**: the
handoff forbids it in the same words `F2` does.

**The one piece of arithmetic worth testing lives outside the view.** Even with the system driving the
bar, something has to decide *which* interval to hand it, and what to show for a block that is `.frozen`
or `.ended`. That is a pure function of the readout, it has four cases, and it goes in a value type
because a rule expressed only inside a `View` body is a rule nothing checks — the same reason
`ShapeSheetActions` exists apart from `ShapeSheet`.

*Edges:* a block already over when the Island is first drawn · a `.frozen` readout, which has seconds
remaining and no interval · `.ended` · and a zero-length interval, which must not divide by zero.

*Checkpoint:* the interval decision asserted at four readout states.

### `F2f-T4` — The Island uses it · owner: **agent**

`BlockSymbol` draws the tomato for `.work` and the **unchanged** cup for both breaks. Three call sites —
expanded `:42`, compact leading `:60`, minimal `:72` — and Ruling B decides the third.

**The break path must be untouched and a test must say so**, because *"keep the coffee icon"* is the half
of this feature easiest to break while editing the file it lives in.

*Checkpoint:* the Release build, and the previews at `:729`–`:862` still rendering.

### `F2f-T5` — Watched from the Island · owner: **human**

`SPEC.md`'s standard: closed on hardware, by the owner, with a build number and their own words.

Start a focus block and watch the Island — not the app. **Does the red rise as the block runs?** Then look
during a break and confirm the cup is there. Then check the minimal presentation by having another app's
Live Activity running alongside.

*Checkpoint:* recorded as an `O<n>`, closed by the owner with the build number.

## Mutations

| Mutation | The named test that must fail |
|---|---|
| `F2f-M1` · Hand the fill the *sprint's* span instead of the block's | the interval assertion in `T3` — a tomato that fills once over two hours instead of once per block, which is `D52`'s picture wearing `D55`'s mechanism and looks plausible |
| `F2f-M2` · Return a zero-length interval for a `.frozen` readout instead of the seconds it carries | the frozen-readout assertion — a divide-by-zero or a tomato stuck empty on a block that is genuinely part-run |
| `F2f-M3` · Draw the tomato for every kind, dropping the cup | the break-path assertion in `T4` — *"keep the coffee icon"*, and it is one character to break |
| `F2f-M4` · Compute the fraction in the extension and clip the shape to it, as the handoff literally describes | `T1`'s recorded observation — **this is the mutation that is also the rejected design**, and it fails by sitting still rather than by going red, which is why `T1` records what was seen on the phone and not only what a test said |

**`F2f-M3` is the one most likely to be written toothless.** A test asserting *the tomato appears on a
focus block* passes happily while the cup has been replaced everywhere. The assertion has to be on the
**break** case — the one nobody is thinking about while building a tomato.

**`F2f-M4` is the honest one.** It cannot be caught by the suite, because a static fill is not a failing
assertion — it is a picture nobody looks at. It is listed so that the reason the obvious implementation
was rejected is written down where the next person will find it, with the observation that rejected it.

## Evidence

`make ci` in the PR: lint, the Todoist allowlist, secrets, licence wording, the register, the script
tests, the full suite with its count, and the Release build. Plus `F2f-T4`, closed by the owner with a
build number.

**Three mutations run and seen to fail before the tasks are called done**, and **the fourth stated as
uncatchable**. A test that has never been shown to fail is not evidence — and a defect a test *cannot*
see is worth naming rather than quietly omitting, which is what `F2f-M4` is for.

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
