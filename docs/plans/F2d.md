# F2d — the alarm can be silenced from the app

**Retrofit on F2.** Builds `D26`, ratified 2026-08-28 and applied to `SPEC.md`
line 39 as `A10`.

**PLAN ONLY. Awaiting the owner's yes.**

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
