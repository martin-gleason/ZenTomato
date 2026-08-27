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
`*Exported by ZenPom 0.9.0 (8).*` A page filed in a notebook and read six months
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

**Settings names the build.** A row reading `ZenPom 0.9.0 (8)`, selectable so it
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

## The regression the first build introduced, and the fix

**Found by the owner within an hour, across eight blocks:** *"it appears stopping
the alarm cancels the break."*

`handleDismiss()` passed `mayAutoStart: false`. That was written when a dismiss was
**rare** — before the alarm was allowed to fire, the boundary handled block ends
and it chained. Letting the alarm through made dismissing the *normal* way a block
ends, so a rule written for an edge case began governing every block.

`D4` is explicit that it must not: *"The break timer starts running the instant the
block ends, behind the sheet."*

**`completed` is the honest condition.** A dismiss before the end instant is
somebody abandoning a block and must chain into nothing; a dismiss after it is
somebody acknowledging a block that finished, and the break follows.

The original worry — that a dismiss might arrive from a locked phone with nobody
there — does not survive contact with what a dismiss is: **a deliberate tap on a
button**. That is the same evidence of presence this method already relies on to
offer a sheet at all. Refusing to start the break while accepting the tap as proof
somebody is present would be two opposite readings of one gesture.

Two tests, both directions: `dismissingAFinishedBlockStartsItsBreak` and
`dismissingEarlyStartsNothing`.

**The lesson is about blast radius rather than about breaks.** Nothing was wrong
with the old reasoning when it was written. What changed is that a path which ran
almost never became the path that runs every time — and no test noticed, because
every test of that path had been written under the old assumption too.

## The second regression: a stale alarm ending the block after it

**Found in a compressed sprint** — 1-minute focus, 2-minute break: focus ended,
the sheet appeared, the break started, and then *"alarm fired, reset short
break."*

The alarm that fired was the **focus block's**, arriving after the break had
begun. It reached `handleDismiss()`, which acts on whatever is running *now* —
the break — found a block that had not reached its end, and abandoned it.

**A hole in the sparing rule, not in the alarm fix.** Scheduling spares an alarm
that is `.alerting` so the next block cannot silence it, and nothing then cleans
that alarm up. It outlives its block and its dismiss lands on the next one.

### The fix comes from the app's own invariant

`DismissBlockIntent` already records it: *"there is no longer a dismiss button on
the running countdown… the only way to arrive here is a sounding alarm."* Checked
rather than trusted — `ZenTomatoActivity` contains **no buttons at all**, and the
intent is referenced in exactly one place, AlarmKit's `stopIntent`.

An alarm only sounds at its own block's end. So **a dismiss arriving while the
current block has not ended cannot be a person abandoning it** — it belongs to an
earlier block. The engine now ignores it.

**Nothing is cancelled on the way out**, which is the tempting wrong fix:
`cancelAlarm()` clears everything outstanding and would take the running block's
alarm with it, leaving the break to end in silence. No cleanup is needed — this
path runs *because* somebody dismissed that alarm, so iOS has already ended it.

### A test was encoding the vanished path

`abandonedBlockRecorded` drove its invariant through `handleDismiss()`, from when
that meant "abandon this block". Left pointed there it was worse than a dead test:
it made a **stale** alarm look like a legitimate abandon, and would have defended
the behaviour that killed the owner's break.

The invariant is real and still held — abandoning is `stop(reason:)`, which is
what the stop sheet calls. The test now drives that.

## The third: breaks never sounded, and the asymmetry was the clue

**Sprint 2, sound on:** every focus block alarmed. **Not one break did.** Four
focus blocks, three breaks, and a perfectly clean split.

That asymmetry is the whole diagnosis. A focus block ends when somebody
**dismisses its alarm** — so by the time the next block is scheduled, that alarm
has certainly fired. A break ends **by itself**, and `begin()` schedules the next
alarm at the same instant, cancelling everything not yet `.alerting`. The break's
alarm is due exactly then and often still reads `.countdown`, so it is cancelled a
moment before it would have sounded.

**Sparing by state was a race, and a human was the only thing winning it.**

So `schedule` now takes `sparing:` and the engine names the alarm of the block
that just ended. Identity cannot lose a race with itself. The `.alerting` check
stays as a second line, but nothing depends on it any more.

### The natural experiment that confirmed it

**Sprint 3 ran on build 6 — before the sparing fix** — and produced the cleanest
evidence of the whole investigation without anyone designing it.

Three breaks. Two ended with the app in front of the owner: **no alarm**. The
third ended **while the phone was on the lock screen**: **the alarm fired.**

Same build, same settings, same block kind. The only variable was whether the app
was awake to reach the boundary — which is exactly what the race predicts. Awake,
the engine chains and cancels the break's alarm before it can sound. Suspended,
nothing chains, nothing cancels, and iOS rings it.

**A hypothesis that predicts an odd result in advance is worth more than one that
explains it afterwards**, and this one was written down before the sprint that
produced it. It also rules out the alternatives: nothing about music, orientation
or the sound setting changed between those three breaks.

## Build 7 verified: two full sprints, sixteen blocks

**2026-08-27, both sprints run to the long break.**

| | Sound on, music on | Sound off, music off |
|---|---|---|
| Focus blocks | 4 of 4 alarmed | 4 of 4 alarmed |
| **Breaks** | **3 of 3 alarmed** | **3 of 3 alarmed** |
| Sheets | appeared with taps, absent without | same |
| Chaining | every block, no resets | every block, no resets |
| Music | paused at each break, resumed at each focus | — |

**The breaks are the result.** Before this fix, not one break alarmed with the app
in front of the owner; the only one that ever did was the one that ended on the
lock screen. Six for six now, across both configurations.

Nothing reset, nothing was abandoned, and no stale alarm landed on a later block —
so the two earlier regressions stay fixed rather than trading places with this one,
which is what the previous three attempts each did.

**Incidentally the heaviest test the tally has had:** the last focus block carried
**one internal and twelve external** taps, and all thirteen were recorded and all
thirteen reached the sheet.

### What this closes, and what it does not

**`O6`'s first half is answered: an active Focus does not stop the alarm.** The
DND sprint ran with Do Not Disturb on throughout and the alarm fired at every
block end, including one that arrived on the lock screen.

That is not a footnote. `SPEC.md` F2 chose AlarmKit over a notification *because*
an alert had to survive a Focus, and until now nobody had ever checked whether the
premise held. It does.

**The second half is still untested, and not by oversight.** That sprint ran with
the app's own sound setting **off**, which substitutes `Silence.caf` — so nothing
could have made a noise whatever the ringer switch was doing. What remains is a
single block: **sound on, ringer switch off**.

## The fourth: stale alarms accumulating, found with Do Not Disturb on

**The most useful sprint yet, because DND changed how the alert behaves.** A
break's alert appeared and *vanished before it could be dismissed*; later blocks
then found alarms from earlier ones still registered, and *"turning off alarm
turned off the stale alarm"* rather than the current one. One alert survived over
thirty seconds without disappearing.

**Caused by my own fix, one step earlier.** Sparing began as a state check —
"never cancel an alarm that is `.alerting`" — added before identity sparing
existed. An alarm that has fired and **not** been dismissed stays `.alerting`
indefinitely, so the state check spared it at every subsequent boundary. Nothing
ever cleared it, and a sprint accumulated **one stale alarm per block**.

DND is what exposed it: without a dismissal, alarms stopped being cleaned up, and
the accumulation became visible within a single sprint instead of never.

**Identity does the whole job.** Exactly one alarm may survive a schedule — the
block that just ended, whose alarm is ringing or about to. Everything else belongs
to a block that is over. `sparingAlerting` is now `false` on the scheduling path,
and the two rules no longer overlap.

**The general shape, since this is the fourth in a row:** each fix was correct
about the case in front of it and wrong about the case next to it. Cancel
everything → the ringing alarm dies. Spare what is ringing → the ringing alarm
never dies. The answer was never a better predicate on *state*; it was to stop
asking about state at all and name the one alarm that matters.

## Build 8, Do Not Disturb: alarms fire through a Focus

**2026-08-27, second DND sprint.** Alarms fired through Do Not Disturb throughout.

That is the **second independent confirmation** of `O6`'s first half, on a
different build from the first. The first came from a sprint run to test something
else entirely — which made it good evidence but accidental evidence. This one was
run to test exactly this.

`SPEC.md` F2 chose AlarmKit over a notification *because* an alert had to survive a
Focus. Until yesterday nobody had checked whether the premise held; it now holds
twice.

## Device check

1. **Two focus blocks, ringer on, phone locked — one with music, one without.**
   Both must sound. That is the test the diagnosis predicted and the one that
   proves it.
2. **Dismiss the alarm** and confirm the sheet appears with the taps on it.
3. **Settings → About** reads `ZenPom 0.9.0 (8)`.
4. **Export** and check the last line names the build.
