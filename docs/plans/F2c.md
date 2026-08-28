# F2c — the alarm sound can be chosen

**Retrofit on F2.** Builds `D24`, ratified 2026-08-27 and applied to `SPEC.md`
line 30.

**PLAN ONLY. Awaiting the owner's yes.**

## What the contract now says

> | Timer customization | … sound on/off, **which alert sound**, auto-start next
> block on/off. **Nothing else.** |

The last two words survived the amendment on purpose. The list moved by exactly
one setting and stayed closed.

## Why it exists

> the default alarm sucks, and will be quite jarring to folks using an app with
> Zen in the name.

The naming argument is the strong one. This app makes exactly one sound, at the
one moment it speaks, and that sound is currently a klaxon chosen by iOS.

## What the framework allows, already checked

`AlarmKit` takes `ActivityKit.AlertConfiguration.AlertSound`, which has **exactly
two members**: `.default`, and `.named(_:)` resolving to **a file in this app's
bundle**. iOS's ringtone library is not reachable from an app, so there is no
system-sound picker to build and never was.

The mechanism is proven here: `Silence.caf` already ships and is what the sound-off
setting rests on.

## The seventh setting, and the fence it moves

`AppSettings` gains `alertSound`. `PolishFenceTests` pins that type at **six**
fields — a bound mutation-tested with *an alarm-sound picker specifically* as the
hypothetical seventh. **The fence moves by one, deliberately, in this diff**, and
the number in the test changes with a comment saying which setting bought it.

**A seventh field is a schema change.** `AppSettings` is a `@Model`, so this is
the first migration since the app went on a device with real history on it. `O2`
— migration over an existing install — is unverified, and this makes it load-bearing
rather than theoretical.

## Tasks

**F2c-T1 — the sounds.** Two CC0 bells are verified in
`docs/sounds/candidates.md`. **`Bell0005.WAV` is 41.7 seconds and must be trimmed**
to its first strike: iOS caps custom notification sounds at 30 seconds, and an
alert that runs for forty is wrong whether or not the cap applies. Converted to
CAF with `afconvert`, as `Silence.caf` already is.

Two bells are two variations of one idea. A third that differs *in kind* would give
the setting a reason to exist — but that is the owner's to choose, not the agent's.

**F2c-T2 — the setting.** `alertSound` on `AppSettings`, defaulting to the system
default so no existing install changes behaviour. A migration, and `O2`'s first
real exercise.

**F2c-T3 — the scheduler.** `AlarmKitScheduler.sound(enabled:)` becomes
`sound(enabled:choice:)`. Sound **off** still wins over any choice —
`Silence.caf` — because that setting is the person saying *no noise*, and a chosen
sound must not override it.

**F2c-T4 — the picker.** A row in Settings, under the existing sound switch. No
preview playback: playing an alarm inside Settings is a new audio path, `AlarmKit`
does not offer it, and `AVAudioPlayer` for it would be a second sound system.

**F2c-T5 — attribution.** The owner's ruling: **every sound attributed, with a
link.** Stricter than CC0 requires. A bidirectional fence — every bundled sound has
exactly one entry, every entry has a name and a URL, and the counts match both
ways. **A credit with no sound is a false statement about someone's work**, which
is worse than a missing one.

Shown on the About screen, which `C18` unblocked. If that screen is not built when
this lands, the sound picker carries the attribution — a list nobody can reach is
not attribution.

## Tests

- the chosen sound reaches the scheduler
- **sound off beats a chosen sound** — the rule most likely to be got backwards
- the default is the system default, so an existing install is unchanged
- **migration**: a store written before this field opens and reads back with the
  default
- the attribution fence, both directions
- `PolishFence` at **seven**, with the comment saying which setting moved it

## Done when

On the device: choose a bell, run a block to its end, hear it. Then turn sound
**off**, run another, and hear nothing.
