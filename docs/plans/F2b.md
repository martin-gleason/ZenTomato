# F2b — the alarm always fires

**Retrofit on F2.** A defect fix: `SPEC.md` F2 promises the alert sounds "through
silent mode and through an active Focus", and the app cancelled it instead.

Two provenance changes ride along, because they share a build, an install and a
device pass: the export names what produced it, and Settings names the build.

## The defect

The owner, after a sprint: **"alarm only went off on the 3rd pomodoro."** Then,
separately: **"I was not asked to explain two external interruptions."**

Those turned out to be the same bug seen from two sides.

### Two doors, and the app went through both

**`boundaryReached()` cancelled the alarm.** That task only runs when the app is
awake, so reaching the line meant cancelling the alarm a moment before AlarmKit
made a sound. The line carried **no comment** — in an engine where the reason for
sixteen points of padding is written down, an unexplained line is usually an
unconsidered one.

The reasoning underneath it must have been that an awake app means somebody is
watching. **It does not**, and the owner is the one who said so:

> if the music is playing and the phone is face up or down, the alarm reminds the
> user to take a break. if there is no music, and the phone is face down, there
> needs to be an alarm.

A phone face down on a desk — which is what people do to remove distractions, and
therefore exactly when the alarm is the only thing that can reach them — has this
app frontmost and awake.

**The audio background mode made it worse rather than rarer.** A sprint playing
music keeps the app alive, so the boundary fired on time with the phone locked:
the alarm cancelled, and no screen in front of anyone to show a sheet on. **Neither
the noise nor the prompt** — which is precisely what the owner reported.

**And with auto-start on there was a second door.** Every `schedule()` clears what
is outstanding first, so that a stale alarm cannot sound four minutes into a later
block. With auto-start on, the next block is scheduled at the instant the previous
one ends — the same instant its alarm fires — so clearing the way silenced the
alarm to make room. Removing the boundary cancel alone would have left this open.

## What was built

**The boundary no longer cancels.** One line removed; the reasoning that replaced
it is longer than the line.

**Cancellation spares a ringing alarm.** `cancelOutstanding(sparingAlerting:)`
skips an alarm whose `Alarm.State` is `.alerting` when clearing the way for the
next block. **Checked in the SDK rather than inferred from the clock** — iOS
distinguishes `scheduled`, `countdown`, `paused` and `alerting`, and only the last
is a noise somebody is currently being made.

An explicit stop or dismiss passes `false` and silences everything, because being
asked for silence is exactly when silence is wanted.

**Dismissing the alarm offers the sheet.** The dismiss path refused a reflection,
on the grounds that a dismiss "arrives from a locked phone where there is no
screen in front of anybody". That is backwards: **dismissing an alarm is somebody
reaching for the phone**, the most reliable evidence this engine ever gets that a
person is present. The old rule refused a prompt at the one moment it was certain
of an audience.

Together those are the owner's ruling in two changes: **the alarm always sounds,
and the sheet follows it.**

## Deliberately not built

**Orientation detection.** The owner asked whether the phone can tell face-up from
face-down — it can, `UIDeviceOrientationFaceDown` — and whether the app should use
it. Working through the four cases, *every one of them wants an alarm*: music or
silence, face up or down. **A rule with no exceptions needs no sensor.** An
unconditional "the alarm always fires" is also one assertion a test can hold, where
"fires unless face-up and silent and frontmost" is a truth table nobody maintains.

**"The sheet has to collect something, even a skip."** The owner asked for it and
it is a real improvement to the log — but `D4` is ratified text saying the fields
are *"each skippable"*, and requiring an answer is different from allowing
dismissal. **That is a delta, not a fix**, and it is not in here.

## Two provenance changes

**The export names what made it.** One italic line at the bottom of every page —
`*Exported by ZenPom 0.9.0 (4).*` A page filed in a notebook and read six months
later should say what produced it. At the bottom because `D15` describes the
document as an order of questions and provenance answers none of them; in the
heading it would compete with the content on a page whose whole design goal is
that it reads without translation.

**On every document, including the empty and unreadable ones.** A page that
*sometimes* says what made it is worse than one that never does, because then its
absence means something and nobody knows what.

Treated as a **format decision inside F6, not a spec change**: `D15`'s five
sections and their order are untouched. Every golden changed by one line, and this
is the commit that says which decision changed and why — the standing rule being
that a golden never changes to make a test pass.

**Settings names the build.** A row reading `ZenPom 0.9.0 (4)`, selectable so it
can be copied into a report rather than transcribed. It exists because a crash
arrived this week and the only way to learn which code produced it was to read the
build number off the phone with `devicectl`. A tester cannot do that.

`AppSettings` still holds **six** values; this reports and cannot be changed.

**`AppBuild` is a type rather than a call to `Bundle.main`**, because the export is
compared byte for byte and a document reading the bundle would produce different
bytes in the test than in the app — forcing the golden to be regenerated, which is
the one thing forbidden by name. Tests pass `AppBuild.forGoldens`, fixed at
`1.0.0 (1)` so a release never rewrites every golden.

## Verification

`make ci`, and **six new tests** in `AlarmRingsThroughTests` — the tests that did
not exist, which is why this shipped. The spy gained `isAlerting`, because a
stand-in that could never be ringing would make the `.alerting` branch
untestable — the same gap that let `C16`'s blocking read ship.

Two existing tests changed, both deliberately and both explained in place:
`cancelPrecedesTheNextSchedule` (the engine no longer cancels between blocks; the
ordering it guarded now lives in the scheduler) and `sprintEndReturnsToIdle` (an
alarm whose time has passed is not a leak — it has already fired).

## Device results, 2026-08-27

| Block | App sound | Music | Phone | Alarm | Sheet |
|---|---|---|---|---|---|
| 1 | **off** | on | — | did not fire | — |
| 2 | **off** | off | — | fired | **appeared** |
| 4 | **on** | on | **upside down** | **fired** | none (no taps) |

**Block 4 is the test, and it passed.** Music playing, phone face down, sound on —
the exact combination that produced silence before this change, and the one the
diagnosis predicted would be fixed. The audio background mode keeps the app alive,
the boundary fires on time, and the alarm now survives it.

**Block 2 proves the second half.** The alert appeared, was dismissed, and the
sheet followed. That path used to refuse a reflection outright.

**Block 4 showing no sheet is correct, not a miss.** There were no distraction
taps, and `BlockReflection` refuses to exist without at least one — "no taps, no
sheet" is enforced by the type rather than by a condition somebody can forget.

### Blocks 1 and 2 were testing a muted alarm

With the app's **sound setting off**, `AlarmKitScheduler` substitutes
`Silence.caf` — half a second of digital nothing — because **AlarmKit has no
silent option**: its sound is either the system default or a named file from the
bundle, and those are the only two things iOS offers. So the alarm still fires,
the alert still appears, the block still ends; the phone simply makes no noise.

**That is `O7` working as designed**, and it means blocks 1 and 2 could not have
made a sound whatever this change did. The one real question left is whether the
*alert* appeared in block 1 — because in block 2, with the same setting, it did.

## Device check

1. **Two focus blocks, ringer on, phone locked — one with music, one without.**
   Both must sound. That is the test the diagnosis predicted and the one that
   proves it.
2. **Dismiss the alarm** and confirm the sheet appears with the taps on it.
3. **Settings → About** reads `ZenPom 0.9.0 (4)`.
4. **Export** and check the last line names the build.
