# F2d — the alarm can be silenced from the app

**Retrofit on F2.** Builds `D26`, ratified 2026-08-28 and applied to `SPEC.md`
line 39 as `A10`.

**Gated 2026-08-28, built 2026-08-28.** The owner's yes was *"continue with f2c and f2e"* — `F2c` was already merged, so it named this plan and `F2e`.

## What the contract now says

> While the alarm is ringing the timer screen shows one control that silences it
> and moves the sprint on, exactly as the system alert's own Dismiss does.

## What is actually broken

The owner tried to stop a ringing alarm in a short break and could not:

> This wasn't a stop the timer bug. stop the alarm bug.

**The gap is certain and needed no reproduction.** `cancelAlarm()` is reachable
from a *confirmed* Stop and one internal path, and **no view observes
`Alarm.State.alerting`**. The only control that ends a ringing alarm belongs to
iOS. If that alert is missed — the app was already open, the phone was in a
pocket, the alert was swiped — ZenPom has no off switch for a noise it started.

**What is already right, and is why this is small.** `AlarmManager.shared.alarms`
carries each alarm's `state`, so `.alerting` is observable; `cancel(id:)` silences
one; and `handleDismiss()` is already the exact "silence and advance" path, written
and tested for `DismissBlockIntent`. Nothing here needs a new idea. It needs the
state on screen and one button wired to a method that exists.

## The decision the owner made, and what it commits us to

**Silence *and advance*, like Dismiss.** Not silence-only. So the button runs
`handleDismiss()` — the block records as **completed**, not abandoned; the
reflection prompt appears if that block earned one; the next block auto-starts if
auto-start is on and stays queued if it is not.

**It is not `stop(reason:)` and it must never become it.** Stop ends the *sprint*
and `SPEC.md` prices that exit deliberately — it asks why and will not proceed
without an answer. Silencing an alarm is a different act with a different
consequence. **One button carrying both meanings is how the `F2b` arc produced
four fixes in a row**, and it is the single most likely way to get this wrong.

## Tasks

**F2d-T1 — knowing the alarm is ringing.** The app needs `.alerting` as observable
state, not a poll. `AlarmKit` is expected to expose an updates sequence alongside
`AlarmManager.shared.alarms`; **that is to be read in the SDK rather than assumed**
— three framework assumptions have been wrong on this alarm already, and the cost
each time was a device round trip. If no such sequence exists, the fallback is to
refresh on the same events the engine already reconciles on, and the plan says so
rather than discovering it mid-build.

The state belongs to `AlarmScheduling`, not to a view: the protocol is the seam
every test uses, and a view reaching into `AlarmManager` directly would be the
second alerting path this codebase says it does not have.

**F2d-T2 — the control.** On `TimerScreen`, visible **only** while our alarm is
alerting. `TimerControls` already has the vocabulary; this is a third case beside
`.start` and `.running`.

**It must not occupy the Start/Stop position.** That position changes identity on
`isRunning`, which is exactly what happens at the instant an alarm begins — a
control appearing there at that moment would land under a finger aimed at
something else. Placement is a design question the build will bring back with a
screenshot rather than settle here.

**F2d-T3 — one path, not two.** The button calls the same engine method
`DismissBlockIntent` calls. A second implementation of "dismiss" that drifts from
the first is this project's most repeated defect, and `AlarmSoundDecision`'s test
seam is the template for proving two entry points agree.

## Tests

- while no alarm is alerting, the control does not exist
- while our alarm is alerting, it does
- tapping it silences the alarm — asserted against the stand-in's cancel record
- tapping it records the block **completed**, never abandoned, and never opens the
  stop sheet
- it honours auto-start both ways
- **the app's own button and `DismissBlockIntent` reach the same engine call** —
  the drift test, and the one worth having
- an alarm belonging to a block that has already ended by other means does not
  raise the control

## Done when

On the device: let a block end, and with the app **in the foreground** silence the
alarm from inside ZenPom without touching the system alert. Then let one end with
the app closed and confirm the system alert still works and the two do not fight.

## Deliberately not in this feature

**No change to Stop, and no change to the stop sheet.** They came up in the first
reading of this report and the owner corrected it. Touching them here would be
building on a diagnosis that was withdrawn.

**No fix for `C20`.** The alarm sounding with sound *off* is a different failure
with an unfinished diagnosis. It is one minute of device time away from being
decided, and `C20` says what to run.


## What shipped

**`alarmUpdates` exists, and was read rather than assumed.**
`AlarmKit.swiftinterface` in the iOS 26.5 SDK carries
`AlarmManager.alarmUpdates: some AsyncSequence<[Alarm], Never>`, and — the part
that mattered — **`stop(id:)` alongside `cancel(id:)`**. Those are different
operations: `cancel` is for an alarm still counting down, `stop` for one already
alerting. The protocol keeps them separate for the same reason, so it cannot grow
a method that sometimes works.

`AlarmScheduling` gains three members: `alertingAlarmID` for a cheap read,
`alertingUpdates()` for a stream whose **first value is the current state**, and
`stopAlerting(id:)`. The stream's first value is what makes a screen opened *while
the bell is already ringing* draw the button — which is the only case this feature
exists for.

**The engine reuses `handleDismiss()` and adds nothing to it.** `silenceAlarm()`
stops the noise, then dismisses. The order is not interchangeable:
`DismissBlockIntent` runs *after* iOS has ended the alert, so reaching that method
from inside the app means nothing has been silenced yet — dismissing alone would
have advanced the sprint and left the alarm ringing, which is the reported defect
with an extra step.

### Placement, which took three attempts

The plan refused to settle this in prose and said it would come back. It came back
twice more.

**What shipped: the Silence button takes the primary control's slot.** Both button
styles carry `minHeight: Spacing.controlHeight`, so it is a swap with no layout
change anywhere — nothing moves, nothing is disabled, and no other state gains
dead space.

**First attempt: above the primary control, with Start and Stop disabled.** The
argument was that a control which shifts under a finger must not do anything. It
produced a screen with three controls and **nothing pressable** when iOS refused
to stop the alarm.

**Second attempt: reserve the space permanently so nothing shifts.** That put
sixty fixed points of blank page into *every* state of the main screen, outside
`centreColumn`'s ScrollView — which exists precisely because this screen's content
already does not fit at the largest accessibility sizes — and moved the numeral's
optical centre that `column`'s own doc argues for. It was also unpreviewed: none
of the twenty-four `#Preview` blocks covered a ringing alarm.

**The objection that started all this was weaker than it looked.** The position
changes identity at the instant the alarm rings — but `isRunning` flips at that
same instant, so Stop was becoming Start there anyway. What actually changes is
what a mis-aimed tap hits: `Silence`, which is what somebody reaching for a
ringing phone wants, instead of `Stop`, which ends the sprint and demands a
written reason.

Three previews were added with it, including one at `.accessibility5`.

## Evidence

**Regenerated after the sixth adversarial pass, from that run and no other.**
The block that stood here was a `555/84` run of an earlier tree — the third time
on this branch that committed evidence described something other than the tree
being merged. It is pasted from the log rather than retyped.

```
$ make ci
check-lint.sh: OK — no lint violations.
check-todoist-writes.sh: OK — no Todoist endpoint outside the allowlist.
check-secrets.sh: OK — no credential found in the tree.
check-licence-wording.sh: OK — no disjunctive licence wording.
check-open-register.sh: OK — the register renders as tables.
run-script-tests.sh: 15 passed, 0 failed
check-release-build.sh: OK — Release compiles with no warnings of ours.
✔ Test run with 559 tests in 85 suites passed
```





Nineteen tests across `SilenceAlarmTests`, `SilenceDismissAgreementTests` and `SilenceControlFenceTests`. **One found a real bug before any device did**:
`handleDismiss()` clears `lastFailure` as its first act — correctly, so a new
block does not inherit the last one's complaint — which meant a failure to
silence was being written and then wiped a line later. Somebody would have been
left with a ringing alarm and a screen saying nothing was wrong. The report now
happens after the dismiss.

The one worth naming is `theButtonAndTheSystemAlertAgree`: the same state is
driven twice, once through the app's button and once through the path
`DismissBlockIntent` runs, and the recorded outcome must match. Two
implementations of "dismiss" drifting apart is this project's most repeated
defect, and here they would drift silently — one is a button, the other is a
system intent nobody watches.

## Still to check on the device — `O29`

**Half answered.** With the app in the foreground the owner reported *"silence
button was amazing. all tests fired."* What remains is the second run:

Let a block end with the app **closed**, dismiss from the system alert as usual,
and confirm the two paths do not fight — no double advance, no stuck button.


## What the adversarial review changed

**Pass one: DO NOT MERGE, seven blocking findings.** Five more passes followed; `docs/reviews/F2d.md` logs them all. The two worth naming here:

**Silencing inside the auto-start window swallowed the reflection prompt.**
`handleDismiss()` bumped `abandonGeneration` as its *first* line, above the
`guard completed else { return }`. So: a focus block ends, `end()` chains into
`begin()`, `begin()` suspends awaiting a real AlarmKit round trip, the alarm rings
in that window, Silence is tapped — `handleDismiss()` sees the *new* block, which
has not completed, bumps the counter and returns. `publishReflection` then found
the generation moved and published nothing. **The distraction log is the point of
this app**, and the case it failed in is the exact one `D26` was built for: the
app in the foreground when the bell goes. The bump now happens after the guard,
because bumping belongs to abandoning and nothing above that line abandons.

The test for it **was written wrong first and passed with the bug reinstated** —
it never rang an alarm, so `silenceAlarm()` returned at its first guard and the
window was never entered. Corrected, it fails with the bug and passes with the
fix, both confirmed by putting the bug back.

**A refusal from iOS left a dead screen, and the first two fixes for it were both
wrong.** `ringingAlarmID` was cleared only on success, and Start and Stop were
disabled while it was set — three controls, nothing pressable, no way out but
relaunching. Clearing it on *both* branches fixed that and **recreated the
original defect**: `alertingUpdates()` de-duplicates against its last value and a
refused stop changes no AlarmKit state, so the id is never yielded again and the
Silence button is gone for the rest of the session while the bell is still
audible.

That re-read was itself defective — `alertingAlarmID` swallows a throw as `nil`,
and the moment iOS is most likely to refuse a *read* is the moment it has just
refused a *stop*. **What shipped is the throwing `currentAlertingAlarmID()`**,
with "could not ask" keeping the id it already had; and the dead screen solved
where it belonged, in the placement above, so nothing is disabled at all.

Also taken: the drift test **could not fail for the reason it was written** — it
called `handleDismiss()` directly rather than the intent's real route through
`TimerEngineHolder`, and compared two methods that differ only by the call it
never inspected. It now goes through `TimerEngineHolder.dismissRunningBlock()`,
checks the reflection offer too, and has a sibling asserting that `handleDismiss()`
alone does *not* silence. The `AsyncStream` termination handler is installed before
the task exists rather than after. And the two tests `F2d.md` promised and the
first build shipped without — auto-start honoured both ways — are here.
