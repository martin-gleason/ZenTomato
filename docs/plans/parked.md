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
