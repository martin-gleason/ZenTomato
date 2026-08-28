# F4f — music can be switched on during a break

**Retrofit on F4.** Builds `D25`, ratified 2026-08-27 and applied to `SPEC.md`
line 27.

**Planned first, approved by the owner, then built** — the second piece of work to
go through the gate in the right order since it was reaffirmed.

## What the contract now says

> | Music during breaks | Pauses, and **can be switched back on by hand**. Resumes
> by itself at the next pomodoro. |

Three obligations in one sentence, and the third is the one already true:

1. A break still **pauses** music by itself.
2. The switch **can be used** during a break.
3. The next pomodoro **resumes** without being asked.

## What the owner actually asked for

> no music during a break is ok, and changing music during a sprint is limited
> (turn off, fast forward), **I should be able to turn on music during a Short
> Break**

Narrower than "music in breaks". Not auto-play, not transport controls, not a
break that behaves like a work block. **One control, re-enabled, in one place.**

## Why it does nothing today

`MusicRowModel` sets `isTogglable: false` the moment any block is running, so
during a break the switch is **disabled** — which is why tapping produces no
effect rather than a wrong one. The picker's toggle is likewise
`.disabled(isBlockRunning || !isAvailable)`.

## Tasks

**F4f-T1 — the row rule.** `isTogglable` becomes true during a break and stays
false during a work block. The work-block lock is deliberate and unchanged: `D19`
puts the music decision *before* a sprint, and a switch that can be flipped
mid-focus is a decision surface in the middle of the thing this app protects.

**F4f-T2 — the playback rule.** `MusicPlaybackPhase.shouldSound` requires
`kind == .work`. It must allow a break **only when the person has just asked for
it**, which is a different condition from "music is enabled" — otherwise every
break would play, and obligation 1 above breaks.

So the state is *"sound was requested for this break"*, set by the switch and
cleared at the next boundary. It is **not** a seventh setting and not persisted:
it is one Bool on the coordinator, alive for one block.

**F4f-T3 — the picker's toggle.** Same relaxation, same rule, so the two surfaces
cannot disagree about whether the switch works.

**F4f-T4 — the transport stays absent.** `transportIsLive` keeps `kind == .work`.
Skip and stop do not appear in a break even when sound is playing, because the
owner asked for the switch and nothing else — and `D19.3` reserves the row's
height precisely so controls appearing mid-cycle cannot move the countdown.

**F4f-T5 — the next pomodoro is unaffected.** Obligation 3. Music resuming at the
next work block must not depend on what happened during the break, in either
direction: a break where music was switched on must not suppress the resume, and
one where it was switched off must not prevent it.

## Tests

- the switch is usable in a break and locked in a work block
- a break is **silent by default** — the regression that would satisfy T1 and
  break the contract
- sound requested during a break stops at the boundary, without being asked
- the next work block resumes regardless of what the break did, both directions
- no skip, no stop, during a break with sound playing
- `PolishFence` unchanged: `AppSettings` stays at **six**, no new model, no new
  persistence

**The second and third are the ones worth having.** "Music can be switched on"
is easy to implement as "breaks play music", which passes a careless reading of
the contract and contradicts its first clause.

## Done when

On the device: a short break starts silent, the switch turns music on, the block
ends and music stops without being asked, and the next pomodoro plays as it always
did.

---

## Built, 2026-08-27

### The design call the plan did not settle

`isOn` is the standing intention, so **during a break with music enabled the
switch already read "on" while nothing was playing** — leaving nothing to switch
back on, which is exactly what the contract promises. That forced the answer:
**inside a break the switch shows and sets *this break*.** It goes off when the
break pauses the music, and putting it back on plays for that block only.

The switch changing state at a boundary is the point rather than a glitch — it
mirrors what the music did.

`isEnabled` is left alone by a break toggle, so a sprint's music setting is still
decided before the sprint, where `D19` put it.

### Two fences moved, both by exactly one control

`theSwitchIsLockedWhileABlockRuns` asserted the switch was locked in **every**
block kind. The work-block half survives and is the half worth keeping; the break
half was the old contract.

`MusicFenceTests` asserted **zero** controls during a break. It now permits one
and adds a separate assertion that **skip and stop are still absent** — the count
was doing two jobs, and only one of them changed.

### The mutation that got through

**Deleting the line that clears the request at a boundary left every test green.**
Every test in `MusicInABreakTests` at that point exercised the pure rule, and this
is about the state the rule is fed — so the flag could outlive its break and reach
a later block with nothing objecting.

That is precisely the defect `D20`'s silence flag shipped with: set, never
cleared, 291 tests green because none of them crossed a boundary. Three
coordinator-level tests now cover it, and the mutation fails two of them.

### Verification

| Mutation | Caught by |
|---|---|
| M22 · a break plays whenever music is switched on | `aBreakIsSilentEvenWithMusicSwitchedOn` |
| M23 · the request is never cleared at a boundary | `theRequestDiesWithTheBreakItWasAbout`, `aSecondBreakStartsSilent` |
