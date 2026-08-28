# F2d — adversarial review

**Branch:** `F2d/silence-the-alarm` · **Plan:** `docs/plans/F2d.md` ·
**Delta:** `D26`

Three passes. **DO NOT MERGE**, **DO NOT MERGE**, **DO NOT MERGE**.

## The shape of this one

**Three of the most serious defects on this branch were introduced by the fix for
the previous finding.** That is the `F2b` pattern — four successive alarm fixes,
each caused by the one before — arriving in the feature built to close `F2b`'s
last complaint. It is recorded here rather than in a commit message because it is
the thing worth remembering about `F2d`.

The sequence, in full:

1. The Silence button was placed **above** the primary control, and Start and Stop
   were **disabled** while it showed, on the argument that a control which shifts
   under a finger must not do anything.
2. Pass one: *"there is a dead screen, and it is the failure path"* — when iOS
   refuses to stop the alarm, `ringingAlarmID` stayed set, so all three controls
   were unpressable with no way out but relaunching. **Fix: clear the flag on both
   branches.**
3. Pass two: that clear **recreated `O26`**. `alertingUpdates()` de-duplicates
   against its last value and a refused stop changes no AlarmKit state, so the id
   is never yielded again — the Silence button gone for the rest of the session
   while the bell is still ringing. **Fix: re-read the truth on failure, and
   reserve the button's space so nothing needs disabling.**
4. Pass three: the reserved space was an **unreviewed layout change to every state
   of the main screen** — sixty fixed points outside the ScrollView that exists
   because the screen already does not fit at the largest text sizes, with no
   preview covering it.
5. What shipped: the Silence button **takes the primary control's slot**. Same
   `minHeight`, so no layout change anywhere, nothing disabled, no dead space.

**The objection that drove steps 1–4 was weaker than it looked.** The position
changes identity when the alarm rings — but `isRunning` flips then anyway, so Stop
was becoming Start there regardless. What changes is what a mis-aimed tap hits:
Silence, which is what somebody reaching for a ringing phone wants.

## The worst finding, which was not about placement

**Silencing inside the auto-start window swallowed the reflection prompt.**
`handleDismiss()` bumped `abandonGeneration` as its first line, above the
`guard completed`. A focus block ends, `end()` chains into `begin()`, `begin()`
suspends on a real AlarmKit round trip, the alarm rings in that window, Silence is
tapped — `handleDismiss()` sees the *new* block, which has not completed, bumps
and returns, and `publishReflection` then refuses to publish the finished block's
prompts.

**The distraction log is the point of this app**, and it failed in exactly the case
`D26` exists for. The bump now happens after the guard: bumping belongs to
abandoning, and nothing above that line abandons.

**The test for it was written wrong and passed with the bug reinstated.** It never
rang an alarm, so `silenceAlarm()` returned at its first guard and the window was
never entered. Corrected, it fails with the bug and passes with the fix — both
confirmed by putting the bug back.

## Tests that could not fail

Three, all found by review rather than by running:

- **The drift test** called `handleDismiss()` directly rather than the intent's
  real route through `TimerEngineHolder`, and compared two methods that differ
  only by the call its assertions never inspected.
- **Bounded waits were unasserted.** A wait that times out leaves nothing ringing,
  `silenceAlarm()` returns at its first guard, and every assertion after it holds
  vacuously. `requireRinging()` now uses `#require`, which stops the test — it was
  written as `#expect` first, which is the same mistake one level down.
- **Two negative assertions matched exact historical strings**, so any reformat of
  a re-added `.disabled` would slip past. Now a search for `alarmIsRinging` inside
  any `.disabled(` line.

## Prose that contradicted the tree

**Twice, and the second time in the commit that fixed the first.**

Pass two found both plans' evidence blocks were from runs predating the fix commit
— evidence for a tree that was not being merged. Pass three found that the same
commit's message and a new file's header claimed a file split that **never
happened**: nothing was removed from `SilenceAlarmTests`, it had never held a
source fence, and the limit had not been crossed. `SilenceControlFenceTests`
carries that correction in its own header rather than a quiet rewrite.

`O29` was also left describing the reverted design after `O30` was fixed for
exactly that in the same commit.

## Verdict and evidence

See `docs/plans/F2d.md` for the `make ci` output of the merged tree. The device
check is `O29`, and it is **half answered**: with the app open the owner reported
*"silence button was amazing. all tests fired."* With the screen locked everything
fired except the reflection sheet, which is `D29` — a different decision, proposed
and not ratified.

`O31` — the watch alert's button reads Stop where this app sets Done — is recorded
and explicitly not guessed at.
