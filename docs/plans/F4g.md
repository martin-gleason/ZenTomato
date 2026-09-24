# F4g — the external-pause test could not fail for the right reason

**Status:** **built and merged as a defect fix.** No gate: the app was failing to do what the
contract already says — or rather, a test was claiming it did.
**Kind:** retrofit on `F4` (music). `F4c`–`F4f` are taken.
**Spec:** `docs/specs/SPEC.md` line 26, the one music control allowed during a sprint.
**Trigger:** CI failure on `C33`, a documentation-only branch that changes no Swift.

---

## What happened

`C33` could not merge. Its CI reported:

```
✘ "a pause from elsewhere hides the button"
  MusicSkipVisibilityTests.swift:70: Expectation failed: (coordinator.isPlaying → true) == false
  ↳ a pause from Control Centre must hide the skip button
```

`C33` touches no Swift. **The instinct at this point is to re-run the job**, and a re-run would
probably have gone green, and the defect would still be here. That instinct is the finding as much as
the code is.

## The defect, in both directions

`A18` — the watchdog fix — moved the playback read **off the main actor**. `isPlaying` now lands a
turn after the announcement that caused it. Two tests in this suite drove the load with

```swift
await Task.yield()
await Task.yield()
```

and hoped. That is two hops of hope, and the number of hops is an implementation detail.

| Where | `isPlaying` before the pause | `#expect(isPlaying == false)` | Verdict |
|---|---|---|---|
| This machine | `false` — the load's own read had not landed either | **passes** | **vacuous.** The pause was never noticed; the button was never shown |
| The CI runner | `true` — the load did land | **fails** | real assertion, un-awaited read |

**One cause, opposite symptoms.** Green here for the wrong reason, red there for the right one. A test
that is vacuous on the author's machine and real on CI is indistinguishable from a flaky test, which is
why it survived.

**`awaitPendingPlaybackRead()`'s own doc comment predicted this**, and is worth quoting because it was
written before the failure and not after:

> *"The alternative was to sprinkle more `Task.yield()` calls and hope: that idiom already exists in
> these tests, it depends on how many hops the implementation happens to take, and it turns a real
> regression into an intermittent one the day that number changes."*

The helper was added for the **read**. The **load** was left on hope.

## What was changed

**`MusicCoordinator.awaitPendingSound()`** — the missing `#if DEBUG` helper, awaiting `soundTask` the
way the existing one awaits `playbackReadTask`. A test that wants to know whether the skip button is
visible needs both: the load decides whether anything is playing, the read decides whether this object
has noticed.

**`externalPauseIsNoticed`** awaits both, and **asserts its precondition** — that the button was
visible before the pause. Without that line the expectation is satisfied by a button that was hidden
throughout.

**`lateStatusChangeIsPickedUp` was also unsound and is also fixed.** It asserted
`coordinator.isPlaying == player.isPlaying`, which is **satisfied when both are `false`** — exactly
what a load that never completed leaves behind. It could not distinguish *"re-read correctly"* from
*"nothing happened at all."* It now asserts against `true`, with the fixture's own state asserted
first.

**Fixing only the failing test would have left its partner able to go vacuous the same way.** The pair
has to be sound together. That is the lesson `F8`'s breakless-shape defect already taught — one test of
a matched pair updated, the other not — and this is the second time it has produced a defect.

---

## Mutations run against the shipped code

| Mutation | Result |
|---|---|
| `F4g-M1` · restore the two guessed `Task.yield()` calls, keeping the precondition | **caught** — 639 tests / 1 issue, and the failure is at the **precondition** (`:96`), not the main assertion. With the yields the load has not completed, so the precondition is what catches it |
| `F4g-M2` · the exact shipped state — guessed yields **and** no precondition | **ESCAPED. 639 tests passed.** This is the demonstration, not a disappointment: the test that shipped cannot detect the behaviour it names |

**`F4g-M2` is the most valuable row in this file.** It reproduces the false assurance and shows it
green. The project's conventions say *a test that has never been shown to fail is not evidence*; this
is the complementary case — **a test shown to pass while the thing it checks is broken.**

**`F4g-M1` was attempted once and killed by memory pressure before it reported.** That run is not
recorded as a result. It was re-run with headroom after clearing 771 MB of `DerivedData`, and only the
second run is evidence.

### Evidence

```
clean build, fix in place        639 tests in 94 suites passed   ** TEST SUCCEEDED **
F4g-M1                          639 tests / 1 issue             ** TEST FAILED **
F4g-M2                          639 tests passed                (escaped, by design)
fix restored                    639 tests in 94 suites passed   ** TEST SUCCEEDED **
make lint                       no violations
```

## What this does not do

- **It does not touch `skipForward()`.** `MusicCoordinator.swift:467` still makes the blocking
  cross-process read on the main actor that the `A18` fix left behind — the other half of the watchdog
  door. That is a real defect with its own trigger and it is not this unit.
- **It adds no production behaviour.** `awaitPendingSound()` is `#if DEBUG` and is not in the shipping
  binary.
- **It does not audit the rest of the suite for the same `Task.yield()` idiom.** The helper's doc
  comment says *"that idiom already exists in these tests"*, so there are others. A sweep is worth a
  chore; it is not this defect fix.
