# F2c — the alarm sound can be chosen

**Retrofit on F2.** Builds `D24`, ratified 2026-08-27 and applied to `SPEC.md`
line 30.

**Gated 2026-08-27, built 2026-08-28.** The owner's yes was "build f2c".

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

## What shipped

**Everything the plan asked for, including the sounds.** The catalogue, the
seventh stored field, the snapshot plumbing, `AlarmSoundDecision` with sound-off
winning, the Settings picker, the on-screen credits, both bell files, and eleven
tests.

**The plan's `Done when` is now runnable, and has not been run** — see `O24`. The
bells were trimmed and converted from a waveform; a file that is correct in
`afinfo` can still be inaudible through a phone speaker or unpleasant at the end
of a focus block, and that is a judgement only the owner makes.

### The decision the plan did not anticipate

`AlertConfiguration.AlertSound.named(_:)` resolves against the bundle, and when
the file is absent there is no error, no warning and no fallback — the alarm
simply makes no noise. Shipping a picker that offers a sound the target does not
contain would reintroduce the exact defect `D24` was ratified to fix, through the
fix itself.

So `AlertSound.playable` is computed from the bundle rather than written down, and
an unplayable sound is unreachable from every direction: not offered, not stored,
not scheduled, and never credited on screen. **Would this be written the same way
if every sound were always present?** Yes — that is `D16`'s test, and it passes
for a reason unrelated to today: a resource failing to reach a target is the third
silent-install failure this project has had, and `project.yml` records the other
two. Deriving the catalogue from the bundle means the next one shrinks a picker
instead of silencing an alarm.

### What the adversarial review changed

The reviewer returned **DO NOT MERGE** on the first pass. Six blocking findings,
all fixed here:

- **`D25` cited four times where `D24` was meant.** `D25` is music during a break,
  which shipped as `F4f`. The attribution ruling is `D24`'s. A comment naming the
  wrong ratification is a corrupted audit trail in a project amended only by
  numbered deltas.
- **The precedence rule had no test and could not have one.** `sound(enabled:choice:)`
  was `private static` and returned a framework type that is not usefully
  comparable, so the rule the plan called *"most likely to be got backwards"* was
  held by a comment. It is now `AlarmSoundDecision.decide`, and
  `AlarmSoundDecisionTests` asserts it exhaustively over the catalogue.
- **The attribution fence compared two `switch` statements in one file.** `D24`
  says *every bundled sound file*, so it now enumerates `ZenTomato/Resources` and
  names `Silence.caf` as the one file we made ourselves. The old version could not
  have seen a sound added to the target and never credited.
- **The bell files were already in the tree.** Untracked, at the repository root,
  since 2026-08-27. `O23` said the owner had to supply them; the owner already
  had. See `docs/sounds/candidates.md` for the trim, and `O23` for the correction.
- **`docs/chores/C18.md` still described an MIT grant** that commit `870dba8`
  removed — a title, a table row and three task rows, live on `main`, that would
  have put MIT copy in the About screen. Corrected, and `O25` records the
  structural fix.
- **The evidence was a bare string.** Replaced below.

Two of its non-blocking findings were also worth taking: `PolishFenceTests` now
asks `Schema` instead of grepping a file — F2c had shown that a property can be
moved out of a regex's reach — and `AlertSound.playable` is a `static let`, since
`isPlayable` was doing a filesystem lookup on the main actor on every evaluation
of the settings screen's `body`.

## Evidence

`make ci` — lint, the Todoist allowlist, the secret scan, both licence checks, the
register check, the shell tests, the full suite, and a Release compile:

```
$ make ci
check-lint.sh: OK — no lint violations.
check-todoist-writes.sh: OK — no Todoist endpoint outside the allowlist.
check-secrets.sh: OK — no credential found in the tree.
check-licence-wording.sh: OK — no disjunctive licence wording.
check-open-register.sh: OK — the register renders as tables.
run-script-tests.sh: 14 passed, 0 failed
✔ Test run with 527 tests in 79 suites passed after 4.521 seconds.
check-release-build.sh: OK — Release compiles with no warnings of ours.
```

**The three licence tests were shown to fail before they passed.** A guard that
has never refused anything is not known to work, and this one demonstrably was
not — the per-channel phrase sat in `C18.md`'s own title for a day while the check
reported OK every time. It could not be tested at all, because it always read its
own repository; `LICENCE_CHECK_ROOT` is the seam that makes it testable, and the
first run of the new cases was `11 passed, 3 failed`.

**The bells reach the bundle**, checked in the product rather than in
`project.yml` — the failure mode `C18-T5` names:

```
$ find DerivedData -name "*.caf" -path "*ZenTomato.app*"
Silence.caf
SmallBell.caf
StruckBell.caf
```

**Not evidence, and not claimed as any:** nothing here has been heard. `O24`.
