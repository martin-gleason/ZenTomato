# F2d — adversarial review

**Branch:** `F2d/silence-the-alarm` · **Plan:** `docs/plans/F2d.md` ·
**Delta:** `D26`

Seven passes. **DO NOT MERGE** every time.

**This file has been one pass behind the code twice.** It said "three" until the
fifth pass caught it, with four and five living only in commit messages; it then
omitted six until the seventh caught that too — which is precisely what `conventions.md`
says the register exists to prevent: *"a Still open section inside one review is
invisible from the next."* A whole pass being invisible is worse.

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

## Pass four

**Six blocking.** The reported defect was still alive in the commonest path: a
focus block with taps in it, ending with the app in the foreground, presented the
**reflection sheet over the Silence button** — a modal with no silence control of
its own, covering the only thing that could stop the noise. The sheet now waits
and presents when the alarm stops.

`O26` was recreated a *third* time, one layer down: the failure branch re-read
`alertingAlarmID`, whose `try?` reads "could not ask" as "nothing is ringing" —
and the moment iOS is most likely to refuse a read is the moment it has just
refused a stop. There is now a throwing `currentAlertingAlarmID()`.

**The stand-in could not model that**, so the test written to catch it passed
against the exact code it was written to catch. Fixed, and the test then fails
without the fix — confirmed by the fifth pass independently.

`lastFailure` was a blind overwrite: clearing it on a successful silence wiped
whatever `handleDismiss()` had legitimately just set — the *next* block failing to
schedule or to save. Also: two stale comments still describing the reverted
reserved-space design, and a preview depicting a screen the app cannot produce.

## Pass five

**Eight blocking, and five of them one class:** comments, docs and a delta
describing behaviour the code no longer has. `synchronize()`'s comment still
refused the prompt `D29` had just made it offer; `boundaryReached()` still claimed
to be *"the only place a reflection sheet is ever offered"* when two other paths
now do; `end()`'s parameter doc said *"True only from `boundaryReached()`"*; a
deleted test's doc comment was left dangling above its neighbour asserting the
reversed rule; and **the ratified `D29` made a false statement about its own
scope** — it claimed a prompt does not survive termination, which this branch's
own test disproves, because the taps are rehydrated from the store and the offer
is derived from them.

**The preview fix left both previews impossible**, for a field the correction did
not read: `Capture.forBlock` is `guard isRunning, kind == .work`, so neither an
idle screen nor a break has a capture pair, and both literals carried one.

**And the headline fix of pass four had no test at all.**
`ReflectionWaitsForAlarmFenceTests` now holds both halves — the sheet waits, and
something retries when the alarm stops, because waiting without a retry trades a
covered button for a lost prompt.

## Pass six

**Eight blocking, and the pattern had become the finding.** Two were code: the
previews were impossible for a *third* time — a capture pair, then a `kicker` no
`BlockKind` produces, then a music row a break cannot show, each correction
reading the fields it was told about and not the next one — and the
`.alarmSilenceFailed` withdrawal added in pass five was a race that could strand
the very message it withdrew, because `silenceAlarm()` writes it after a genuine
suspension and the update stream does not yield `nil` twice.

The previews stopped being hand-written and became derived. The withdrawal gained
an `isSilencing` guard.

The other six were the record disagreeing with the tree: a fourth comment still
asserting the pre-`D29` rule on the very property the three fixed ones describe,
`D29` carrying both its correction and the claim it refutes forty lines apart,
this plan documenting the *reverted* silence-failure handling as shipped, and the
evidence blocks stale for a third time.

## Pass seven

**Two code defects, both on one line written by the previous fix**, and both in
`silenceAlarm()`'s failure report.

The write branch was still a blind overwrite: a stop refused by an unwell alarm
system is likely followed by a *schedule* refused by the same one, and this
replaced "this block won't sound an alarm when it ends" with advice about the
previous block. The running block having no alarm is the more serious of the two,
and the comment directly above already said so — about the other branch.

And the guard added in pass six to stop a stale message **suppressed a real one**:
a `nil` read straight after a refused stop is exactly the disagreement
`AlarmScheduling` calls load-bearing, so the person could be left with no button
*and* no explanation. The message is now written whenever a silence is refused, as
long as nothing more serious is already there.

The fourth version of `previewAlarmRingingIdle` was still impossible, for a reason
the derivation cannot fix: it was derived from `previewIdle`, the
never-run-anything state, where no alarm has ever been scheduled. Deriving from a
model faithfully does not make the flipped flag producible. It now comes from
`previewSprintComplete` — a long break that has just ended, which is precisely
when a sprint's last alarm rings and the timer waits.

## Verdict and evidence

See `docs/plans/F2d.md` for the `make ci` output of the merged tree. The device
check is `O29`, and it is **half answered**: with the app open the owner reported
*"silence button was amazing. all tests fired."* With the screen locked everything
fired except the reflection sheet, which is `D29` — a different decision, since
ratified and built.

`O31` — the watch alert's button reads Stop where this app sets Done — is recorded
and explicitly not guessed at.
