# F2e — the settings screen: locked while running, and audible before choosing

**Retrofit on F2c.** Builds `D27` and `D28`, both ratified 2026-08-28 and applied
to `SPEC.md` line 30 as `A11` and `A12`.

**Gated 2026-08-28, built 2026-08-28.** The owner's yes was *"continue with f2c and f2e"*.

## Why these are one feature and not two

They are the same screen, and **`D27` deletes `D28`'s hardest case.** A preview
that can be started while a block is running has to decide what happens when the
block's own alarm fires mid-preview, and whether a preview may play over a
running block's music. Locked settings mean neither situation exists. Building
`D28` first would mean designing an interaction and then deleting it.

## What the contract now says

> Each alert sound can be played once from the settings screen before it is
> chosen. While a block is running these are read-only, and the screen says so.

## D27 — locked while running

**The engine was already correct, and that is worth stating plainly.** Settings
freeze into `TimerSettingsSnapshot` at block start and nowhere else, so the
owner's mid-sprint change landed on the *next* block — exactly what the screen
promised. Nothing here fixes a bug; it removes a choice that was confusing to have.

> I was able to change the sounds from small bell to struck bell in a sprint. both
> sound good --- but i shouldn't be able to do that.

**The whole customization block, not the one row the owner hit.** A screen where
one row greys out and four above it do not is a screen that invites the question
*why that one*, and there is no answer a person can see.

**What is not locked, and why that is not an exception.** Todoist sign-in and the
music selection are not timer settings: they are not in `AppSettings`, are not
snapshotted, and `SPEC.md` gives music its own row explicitly permitting changes
during a sprint. `D27` covers the customization row only.

**The running-block note has to change.** *"Changes take effect when it ends, not
now"* becomes a sentence saying the rows are locked. Leaving the old wording under
controls nobody can touch would be the screen lying about itself.

## D28 — hearing a sound before choosing it

**`F2c` ruled this out, and the reason it gave still stands:** *"playing an alarm
inside Settings is a new audio path, `AlarmKit` does not offer it, and
`AVAudioPlayer` for it would be a second sound system."* The owner has now hit the
gap that reason costs — three sounds in a picker, and no way to hear one without
running a block to its end.

**`Default` cannot be previewed and the screen must say so.** It is iOS's own
alert sound, not a file this app holds. A row that silently does nothing when
tapped reads as broken; a row that says *"the system alert sound"* reads as
honest.

### The audio-session decision, which is the whole of the risk

**A preview must be audible on a phone with the ringer switch off.** The sound
being chosen *will* be audible then — that is what `AlarmKit` is for — so a
preview that goes quiet teaches the opposite of the truth about the thing it is
previewing.

**And it must not stop the person's music.** Those two together are the session
category question, and it is the one part of this that can go wrong quietly:
`AVAudioSession` misconfiguration does not crash, it just behaves differently on
a device than in a simulator. **Verified on the device, not asserted.**

## Tasks

**F2e-T1 — lock the customization rows.** Durations, sprint size, sound switch,
alert sound, auto-start. Disabled together, from one flag, so a row cannot be
added later that forgets to join them.

**F2e-T2 — the note.** New wording, appearing on the same condition as the lock.

**F2e-T3 — the preview player.** One bundled file, played once, no loop. A small
type that owns `AVAudioSession` and `AVAudioPlayer` and nothing else. It is a
second audio system and it should be small enough to read in one sitting.

**F2e-T4 — the preview control.** In the sound picker, per row, and **not** on
`Default`. Locked with everything else while a block runs, which is `D27` paying
for itself.

**F2e-T5 — a preview cannot outlive its screen.** Stopped when the picker closes,
the settings sheet closes, or the app leaves the foreground. **A sound with no off
switch is `D26`'s defect arriving by a second door**, and it would arrive in the
feature built to prevent people choosing sounds blind.

## Tests

- every customization row is disabled while a block runs, and enabled when none is
- **the lock is one flag** — a test that fails if a row is added outside it
- the note says the rows are locked, and appears exactly when they are
- `Default` offers no preview; the other two do
- the preview stops on close, on dismiss, and on backgrounding
- a preview plays at most once per tap — no loop
- **the engine is untouched**: no path to `TimerSettingsSnapshot` changes, because
  `D27` is a screen rule and freezing already worked

## Done when

On the device, and both halves need a phone:

1. Start a block, open Settings, and confirm nothing in the customization block
   can be changed and the note says why.
2. With no block running and **the ringer switch off**, preview each bell and hear
   it. Then start a playlist, preview again, and confirm the music survives.

## Deliberately not in this feature

**No preview of `Default`.** It is not ours to play.

**No volume control, and no "preview at alarm volume".** An alert plays at the
system's alarm volume, which an app cannot set. A preview that pretended to would
be a worse lie than a preview that is simply quieter.

**No change to the music system.** The preview player does not route through
`MusicCoordinator`, and `MusicCoordinator` does not learn about previews.


## What shipped

**`D27` is one modifier on one `Group`.** Durations, sprint size and the whole
*When a block ends* section lock together from a single `.disabled(isBlockRunning)`
— because the failure this guards is not today's code being wrong, it is next
year's row being added outside the group. A fence asserts the group holds all
three and that there is exactly one such modifier, and it was **shown to fail**:
moving `whenABlockEnds` out of the group turns the suite red.

Music and Todoist stay editable, and the fence asserts they are *outside* the
group rather than merely that they work. Neither is in `AppSettings`, neither is
snapshotted, and `SPEC.md` gives music its own row permitting changes during a
sprint.

**The note changed, and had to.** *"Changes take effect when it ends, not now"*
was true when the rows were editable and a lie the moment they were not. It now
says they are locked. The footer also lost its sentence about a block keeping the
sound it started with: nobody can change it mid-block any more, so there is
nothing to explain.

### `D28` — selecting a sound plays it

**The platform's own idiom, not a new control.** iOS's Settings › Sounds picker
works exactly this way: tapping a row selects *and* plays. The alternative was a
custom picker screen with a play glyph on every row — more surface on a screen
this app has kept deliberately bare, and a second way to do one thing.

Whether the pushed list stays up on selection is iOS's behaviour and is asserted
nowhere; a `.navigationLink` picker may pop straight back. Either way the sound is
heard at the moment it is chosen and can be changed again immediately. An earlier
draft of this section described the list staying up as though it were designed
here. It is not.

`Default` is the one that cannot be played, because it is iOS's alert sound rather
than a file ZenPom holds. The player refuses and **the footer says so**, because a
row that silently does nothing reads as broken.

**The preview configures no audio session of its own, and the first version's
attempt to was wrong twice.** It set `.playback` with `.mixWithOthers` and
deactivated the session on stop. `AudioSessionInterruptions.prepareForPlayback()`
already sets `.playback` with **no options** and its own comment says the session
is *"deliberately never turned off again"* — so the preview left the process in a
mixable session for the rest of its life, which stops the interruption notices
`F4`'s music-resume depends on arriving in the ordinary way, and handed the
session back every time Settings was closed even if nothing had played.

It now asks for the same preparation the music path asks for, which is idempotent
by design, and never deactivates. `.playback` is what makes a preview audible with
the ringer switch off, and that matters: the chosen sound certainly will be
audible then, so a preview that goes quiet on a silent phone teaches the opposite
of the truth. **The trade-off is stated rather than hidden** — with one
non-mixable policy a preview can interrupt another app's audio, exactly as
starting a block's music already does. One session, one policy.

**A preview cannot outlive its screen.** Stopped on `onDisappear` and on the scene
leaving `.active`, because backgrounding does not fire the former. A sound still
playing after the screen has gone would be `D26`'s defect arriving inside the
feature built so nobody has to choose a sound blind.

## Evidence

**Regenerated after the eighth adversarial pass, from that run and no other.**
The lines are taken from that log; the `swiftlint` banner and the timing are
trimmed and `check-release-build` is shown last, so this is a faithful summary
rather than a verbatim paste.

```
$ make ci
check-lint.sh: OK — no lint violations.
check-todoist-writes.sh: OK — no Todoist endpoint outside the allowlist.
check-secrets.sh: OK — no credential found in the tree.
check-licence-wording.sh: OK — no disjunctive licence wording.
check-open-register.sh: OK — the register renders as tables.
run-script-tests.sh: 15 passed, 0 failed
check-release-build.sh: OK — Release compiles with no warnings of ours.
✔ Test run with 562 tests in 85 suites passed
```







Seven new tests. They are **fences over source rather than view tests**, and that
limit is stated rather than glossed: this project has no UI test target, and both
rules here are structural — *"every customization row is locked by one flag"* and
*"a preview cannot outlive its screen"* are claims about how the file is written.
What no fence can check is whether it looks right, which is what the device check
is for.

`SettingsForm` crossed its 250-line lint ceiling by one line, so the section all
three of `D24`, `D27` and `D28` landed in moved to an extension in the same file —
a separate declaration for the length rule, same file so `private` access survives.

## Still to check on the device — `O30`

1. Start a block, open Settings, confirm nothing in the customization block can be
   changed and the note says why. Music and Todoist should still work.
2. With no block running and **the ringer switch off**, select each bell and hear
   it — `.playback` is what should make that audible.
   Then start a playlist and select again. **The app's music is expected to keep
   playing** (same app, same session); audio from *another* app may be interrupted,
   which is the stated trade-off of one non-mixable policy and is the same thing
   starting a block's music already does.
   Then **stop and start the music again after previewing**, which is the check
   that matters most: the reverted `.mixWithOthers` version would have left the
   session mixable for the life of the process and broken `F4`'s interruption
   handling in a way nothing on screen would show.
3. Start a preview and immediately leave the screen — and separately, background
   the app mid-preview. Both must go quiet.
