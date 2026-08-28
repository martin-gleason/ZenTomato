# F2c — adversarial review

**Branch:** `F2c/choose-the-alarm-sound` · **Plan:** `docs/plans/F2c.md` ·
**Deltas:** `D24`

Two passes. The first returned **DO NOT MERGE** with six blocking findings; the
second, after `cdc870c`, returned **MERGE** with none.

## What the first pass found, and what it cost

**The single most valuable finding was not about code.** `O23` recorded that the
agent could not fetch the two CC0 bells from Freesound and that the owner would
have to supply them. **Both files had been in the repository since the day
before**, untracked, at the root. The `curl` that returned a login page was real;
the conclusion drawn from it was never checked against the tree, and it was
written into the register as fact.

Without that finding, `F2c` would have merged as a picker with one option, a
hidden control, and a hand-off asking the owner for something they had already
done.

The other five:

**The rule the plan called most likely to be got backwards had no test, and could
not have had one.** `sound(enabled:choice:)` was `private static` and returned
`ActivityKit.AlertConfiguration.AlertSound`, which is unreachable from a test and
not usefully comparable. The plan's own test list named *"sound off beats a chosen
sound"*; the branch claimed it in a commit message. It was held by a comment.

**Four `D25` citations where `D24` was meant.** `D25` is music during a break,
which shipped as `F4f`. The attribution ruling is `D24`'s. The error propagated
into the review brief before the reviewer read the deltas and caught it.

**The attribution fence compared two `switch` statements in the same file** —
`fileName` against `attribution`, both in `AlertSound.swift`, which any edit
touches together. `D24` says *every bundled sound file*. The fence could not see a
sound added to the target and never credited, which is precisely how attribution
rots.

**`docs/chores/C18.md` still described an MIT grant** that commit `870dba8` had
removed the same day it was written — in its title, its table, and three
forward-looking task rows, live on `main`. Anyone building the About screen from
that task list ships MIT copy in the app. `scripts/check-licence-wording.sh`
passed on it every time: the check read disjunctions only, and a sentence that
assigns a copyleft licence to the repository and a permissive one to the binary
offers no choice between them, so nothing in it is disjunctive.

(That sentence is written the long way round on purpose. The check now refuses
the short form, and refused this file the first time it was committed — which is
the guard working, not a false positive. The four documents allowed to quote the
phrase are allowed because they must; a review log does not have to, and the way
this check dies is one more filename appended to that list.)

**The evidence was a bare string.** `524 tests passed` with no command and no
output, against `CLAUDE.md`'s *"assertions are not evidence"*.

## What the second pass found

**Verdict: MERGE. No blocking findings.** Seven non-blocking, all taken:

**The widened fence was still bypassable.** It read one directory for `.caf`
only. The reviewer planted `Resources/Uncredited.aiff` and `Resources/Sub/Hidden.caf`
and the suite reported 527 passed. Reproduced here before fixing — the same
blindness in a smaller shape, one pass later. Now a recursive walk over six audio
extensions; with the same files planted it fails naming `Uncredited.aiff`.

**`*.wav` in `.gitignore` was unscoped**, so it also swallowed
`ZenTomato/Resources/`. A future `.wav` alert sound would have worked on this
machine, been skipped by `git add`, and never reached CI — the silent-install
shape `project.yml` already records three instances of. Scoped to
`docs/sounds/sources/*.wav`.

**`LICENCE_CHECK_ROOT` could disable the check by succeeding.** Pointed anywhere
without tracked markdown it printed OK and exited 0. An empty read is now a
failure, and there is a test that points it at an empty directory and requires a
refusal.

**Two loops were vacuous.** `for … where isPlayable == false` runs zero times now
that all three sounds ship files — a test that passes while asserting nothing, and
the suite counts it. The bundle state is now handed in:
`decide(soundEnabled:choice:isPlayable:)`, with a test that the two-argument form
agrees with it so the seam cannot drift into a second implementation.

**Two stale sentences.** `AppSettingsAlertSound.swift`'s doc comment still gave
its reason for existing as a regex that the same commit had deleted, and
`C18.md:167` still framed a per-binary licence grant below the corrected task.

**No `docs/reviews/F2c.md`.** This file.

## The charges that came back clean

**Scope**, both passes. Nothing reaches Watch, Mac, CloudKit, widgets, themes or
streaks. No Todoist endpoint added or altered. No credential in the tree, a
fixture or a log line.

**`D16`, designed-not-prepared.** `AlertSound.playable` is computed from the
bundle, and the question is whether that is preparation for sounds arriving. It is
not: `named(_:)` resolving to a missing file is silence with no error and no
warning, so a picker offering an absent sound reintroduces the exact defect `D24`
was ratified to fix. It would be written this way if no sound were ever added.

**The bundle question.** `AlertSound.swift` compiles into the app alone —
`project.yml` gives the Live Activity extension and the watch target explicit file
lists, and neither includes `ZenTomato/Alarm/`. `ZenTomatoTests` sets `TEST_HOST`
to `ZenTomato.app`, so `Bundle.main` is the same bundle in tests as in the app.

**The bells reproduce.** The reviewer re-ran both `ffmpeg`/`afconvert` pairs from
`docs/sounds/candidates.md` against the ignored sources and got byte-identical
SHA-256 for both files. `StruckBell.caf`'s final 0.1 s measures −67 dB, so it ends
on the first strike's decay and never reaches the second strike at 3.75 s.

## Evidence

```
$ make ci
check-lint.sh: OK — no lint violations.
check-todoist-writes.sh: OK — no Todoist endpoint outside the allowlist.
check-secrets.sh: OK — no credential found in the tree.
check-licence-wording.sh: OK — no disjunctive licence wording.
check-open-register.sh: OK — the register renders as tables.
run-script-tests.sh: 15 passed, 0 failed
✔ Test run with 528 tests in 79 suites passed
check-release-build.sh: OK — Release compiles with no warnings of ours.
```

Three of the licence tests and the widened attribution fence were each shown to
**fail** before they passed.

## Still open

`O24` — **nobody has heard these bells.** They were measured, trimmed and
converted from a waveform. A file that is correct in `afinfo` can still be
inaudible through a phone speaker, or wrong at the end of a focus block. `F2c`'s
*Done when* is a taste check and it has not been run.

`O25` — `C18.md` needs splitting so it can leave the licence-check allowlist.
