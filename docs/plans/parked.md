# Parked — v1.1 and v1.5

Work the owner has decided on that is **explicitly not v0.1**. Recorded so it is
not re-litigated every time it comes up, and so that nobody builds it early.

**Nothing here may be built, stubbed, or prepared for.** `CLAUDE.md`'s scope rule
and `D16`'s test — *would I write this the same way if the parked feature were
never coming?* — both still apply. `PolishFenceTests` enforces the vocabulary side
of it: the words below may appear in this file and must not appear in shipped
Swift.

A parked item is a decision, not a plan. Each gets a real plan at its own gate.

---

## v1.1 — the release candidate

### Instructions, and an explainer of the Pomodoro technique

**Decided 2026-08-26.** The app currently explains nothing. Every control is
legible to the person who built it and to nobody else, and the technique itself is
assumed.

Two pieces:

- **What each button does** — the capture buttons, the skip and stop controls, the
  attachment line, the sprint dots.
- **A short explainer of the Pomodoro technique**, for somebody meeting it here.

**Division of labour, as the owner set it:**

| Who | What |
|---|---|
| Owner | Writes the verbiage |
| Claude design | Places and animates it |
| Agent | Completes the execution |

This is the first v0.1-adjacent work with a **design tool in the loop**, and the
first where the owner supplies the words rather than the agent. Worth noticing at
the gate: the learning dial says the agent authors everything, and here it does
not author the copy.

**Open question for its gate.** An explainer is a surface, and this app has
deliberately almost none. Where it lives — first run, a help sheet, inline hints —
is the whole design question, and *"first run"* is the answer that most easily
becomes an onboarding flow nobody wanted. The `no capture surface` rule is not
threatened by it, but the calm-screen rule is.

### An About screen

**Decided 2026-08-27.** Holds the licensing text, and — once `D24` lands — the
**attribution and link for every bundled alert sound**, which the owner has ruled
is required regardless of what the licences demand.

**Blocked, and only partly on effort.** `C10` ruled dual licensing but has not yet
settled *which* licence the binaries carry. An About screen that names a licence
before that is answered would state a claim that may then have to be corrected in
a binary already on people's phones — which is the one kind of mistake a licence
notice must not make.

**Version and build do not wait for it.** They ship now as a plain Settings row;
About absorbs them later. Splitting them is deliberate: the useful half is
unblocked, and the blocked half is blocked for a reason that has nothing to do
with version numbers.

### Divide a stretch of time into a plan

**Raised 2026-08-27.** The owner:

> select a time for a sprint and have it be divvied up by ZenPom: example — say I
> have 2 hours to work on something. I want to break it up into 3 sprints over 120
> minutes, with a good focus block and a minimum 5 minute break and a 10 minute
> long break.

**The idea inverts how the app works today**, and that is what makes it
interesting rather than a settings tweak. Right now you state the *parts* — block
lengths, pomodoros per sprint — and the total falls out. This states the *total*
and asks the app for the parts.

It is a good fit for the thing this app is actually for: you rarely have "four
pomodoros", you have "the two hours before a meeting".

**Four questions it cannot be built without answering.** None is a blocker; all
four are decisions somebody has to take, and taking them at the gate is cheaper
than discovering them mid-build.

**1. Does it change the six settings, or run one plan?** The larger fork by far.
Writing the answer into `AppSettings` silently redefines the person's defaults
because they once had a two-hour gap. Running it as a one-off means the engine
must follow a schedule that differs from settings — and today
`TimerSettingsSnapshot` is taken from `AppSettings` at every block. That is a real
change to the timer, not a screen on top of one.

**2. The arithmetic does not come out even, and the remainder is user-visible.**
Two hours does not divide into 25/5 blocks without something giving. Round the
blocks? Pad the last break? Finish early, or run over? Every answer is a different
promise: *"I will fill your two hours"* and *"I will not overrun your two hours"*
cannot both be kept.

**3. It presses on `autoStartNextBlock`, which currently defaults to off** for a
stated reason — *"a timer that starts a work block while you are still away from
the desk is a timer that lies about how long you worked."* A plan that has to
finish by a wall-clock time drifts the moment somebody dawdles between blocks. So
either the plan is advisory and drifts, or it advances by itself and the default
that protects the log has to be revisited.

**4. It forces the vocabulary to be settled.** The request says *"3 sprints over
120 minutes"*, and a sprint in this app is a whole set of pomodoros — three of
them at today's defaults is five hours, not two. Draft one of the v1.1 copy has
the mirror-image slip, calling a whole set *"a Pomodoro"*
(`docs/verbiage/NOTES-on-draft-one.md`).

Neither is careless. **The words are genuinely unsettled**, and a screen that
prints *"3 × 25 minutes with two 5-minute breaks"* has to name what it is
printing. This feature would settle it by force. Worth settling **before** it,
ideally in the v1.1 explainer, which is already the place the app teaches the
words.

**Version: v1.5, recommended.** Not because it is unwelcome — it is the most
genuinely useful idea raised since the export. But v1.1 is the release candidate
and its job is to explain what exists; this adds a screen, a solver, and a change
to how the engine gets its block lengths. Shipping it into an RC would mean the
first version anyone else uses is also the first version with an untested engine
path.

---

## v1.5

### A ZenPom Focus, and a Shortcuts automation

**Decided 2026-08-26.** The owner asked whether the app could hide or pause other
apps' notifications during a sprint. **It cannot, and no app can** — verified in
the SDK: nothing in `Intents`, `AppIntents` or `UserNotifications` sets a Focus or
suppresses another app's notifications, and the one Focus API an app gets
(`SetFocusFilterIntent`) runs the other way, letting a Focus tell the app to change
*its own* behaviour.

The owner wants **both** routes, and they are genuinely different:

**1. A ZenPom Focus — instructions only, no code.** A runbook for building a Focus
in iOS Settings that allows ZenPom and silences the rest. Pure documentation; it
could be written today and works on the shipped build. Its only cost is that the
person has to turn it on.

**2. A Shortcuts automation — needs one new App Intent.** This app already
declares `DismissBlockIntent`, so the mechanism exists. A second intent —
*"start a sprint"* — would let an automation the **owner builds** run *Turn On Do
Not Disturb* alongside it. The app still never touches Focus; it becomes something
a Shortcut can trigger.

Route 2's honest framing: it is a capability the owner **assembles**, not one this
app grants. That is a feature of the design rather than a limitation — an app that
could silence your phone's other notifications is an app Apple would not ship.

### The design handoff

`docs/ZenTomato redesign scope.zip` is v1.5's input — icons, a scope README,
recreation notes, an HTML mock. **Tracked deliberately**, against the `docs/*.zip`
rule directly above its exception in `.gitignore`, because ignored it lived on one
disk and was destroyed twice in a morning by ordinary git operations.

### Spotify

Raised at `F4c` and parked there. The music state lives in Settings beside
Todoist's because this app has two services and they should be legible in the same
shape — **not** because a third is coming. `D16` is the standing check on that, and
`F4c`'s review upheld it: there is no provider abstraction anywhere, and there must
not be one until this is a gate of its own.

### A more independent watch app

Raised when the owner asked whether the watch could exist on its own. `SPEC.md` F7
is explicit that the phone is the source of truth and runs the only timer engine,
and `D2` ratified that. Loosening it is a v1.5 conversation and a large one.
