# Notes on draft one — checked against what the app actually does

**The copy is the owner's and has not been edited.** `docs/plans/parked.md` sets
the division of labour for the v1.1 explainer: the owner writes the verbiage, a
design tool places it, the agent executes. So this is a **reviewer's note**, not a
rewrite, and every call below is the owner's to make.

Everything here was checked in the source rather than remembered.

## The tone is right, and that is the hard part

The draft explains the *method* before the *buttons*, which is the correct order —
somebody who does not know why a distraction gets tallied cannot be taught it by a
tooltip. And it says what the app is for in two sentences. That is the part that
usually takes five drafts.

## Three factual mismatches with the app

### 1. "One full set of this is a Pomodoro!" — the app calls that a **sprint**

This is the one worth fixing first, because it teaches a word the app then
contradicts.

In the technique, **one pomodoro is one focus block** — the 25 minutes. A set of
them with breaks is a *set* or, in this app, a **sprint**.

The app is unambiguous about it: the setting is `pomodorosPerSprint`, the Settings
section is headed **Sprint**, and `SettingsView` carries a note that *"a sprint of
one pomodoro is a real setting."* A reader taught that the whole set is "a
Pomodoro" will open Settings and find a control that disagrees with the sentence
they just read.

### 2. "At the end of the focus sprint you can write a sentence" — it is at the end of the **block**

The sentence is written in the end-of-block sheet, at the moment a block ends
(`ReflectionFieldList`: *"at the end of the block"*). Not at the end of the
sprint. As written it promises a sheet that never appears where it says it will.

### 3. "once the timer starts, it doesn't stop" — true of **pausing**, not of stopping

There is deliberately **no pause control** — `AlarmKitScheduler` says so in as many
words, and that is the method's principle honoured in the UI.

But a block *can* be abandoned, and the app takes that seriously enough to have a
whole export section called **"Stopped early"** that records the reason. So a
reader who takes the sentence literally will be surprised by a stop control, and
will not know that stopping is recorded rather than hidden.

Worth a clause, because "you can stop, and it is written down" is a *feature* of
the distraction log rather than an admission.

## One claim I could not fully verify

> built to work with … Todoist, but it is not necessary

**Probably true, and it is the right thing to say** — the app records blocks with
no task attached (the export has a *"No task"* line), and the Todoist sign-in is a
row you navigate to rather than a wall.

But **`C9` flagged first-launch-without-a-token as an open question** and nobody
has run it: *"what a tester actually sees on first launch … is a screen asking for
a Todoist personal API token — and whether that is acceptable for somebody who is
not the owner."* This claim is the first thing a tester will test. Worth
confirming on a fresh install before it ships in writing, because being wrong here
is worse than being silent.

## Small things

- *"sets of timed 'blocks'"* → reads as a typo for **sets a series of** (or "sets
  off")
- *"external(Barking dogs"* → missing space
- *"feeling board"* → **bored**
- *"tempatation"* → **temptation**
- The trailing `2026-08-26T10:12:22-05:00` looks like an editor stamp rather than
  copy
- **Buttons: no mismatch.** The draft calls them *External* and *Internal*, and
  the app labels them exactly that — `DistractionButtons` has a comment explaining
  why they are words rather than "I" and "E". These agree.

## What draft one does not cover yet

`docs/plans/parked.md` scopes v1.1 as *"what each button does"* plus the explainer.
The explainer is here and the two capture buttons are here. Still unwritten:

- **Skip** and **Stop** on the music row
- The **attachment line** — what a block is attached to, and that it is frozen
  while a block runs
- The **sprint dots**
- What the **Settings** six do

Not a criticism of a first draft; just the remaining list.

## A convention question, not a correction

Every other `docs/` subdirectory is plural — `specs/`, `plans/`, `chores/`,
`reviews/`, `handoffs/`, `learnings/` — and `docs/conventions.md` says the only
acceptable singular is `docs/archive/`, "a literal noun, not a category of
artifacts."

`verbiage` is a mass noun with no plural, so it is arguably the same case as
`archive`. Flagging it once so it is a decision rather than drift; `docs/copy/` is
the other option and has the same property.
