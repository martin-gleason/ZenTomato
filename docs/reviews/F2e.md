# F2e — adversarial review

**Branch:** `F2d/silence-the-alarm` · **Plan:** `docs/plans/F2e.md` ·
**Deltas:** `D27`, `D28`

Reviewed alongside `F2d` across **seven passes**, every one returning DO NOT MERGE.
(This line said "three" until the fifth caught it, then "five" until the seventh did.) **The branch carries two features,
which `conventions.md` says it should not** — one feature branch, one feature. It
was raised in pass three and accepted rather than fixed: splitting a branch whose
two halves had already been reviewed together three times would have meant
re-reviewing both, and `D27` and `D28` genuinely interlock. Recorded as a
deviation, not as a precedent.

## The findings

**The preview was breaking the app's own audio, two ways.**
`AudioSessionInterruptions.prepareForPlayback()` sets `.playback` with **no
options**, and its own comment says the session is *"deliberately never turned off
again"*. The first version of `AlertSoundPreview`:

- set `.playback` with `.mixWithOthers`, leaving the process in a **mixable**
  session for the rest of its life — and a mixable session is not interrupted, so
  the interruption notices `F4`'s music-resume depends on stop arriving in the
  ordinary way;
- called `setActive(false)` on every `stop()`, including when nothing had ever
  played — so opening Settings and closing it again handed back a session the
  app's own music needs.

Neither would have shown on screen. It now asks for the same preparation the music
path asks for and never touches the session. **One app, one session policy.** The
trade-off is stated rather than hidden: with one non-mixable policy a preview can
interrupt *another* app's audio, exactly as starting a block's music already does.

**A device check written against reverted code.** `O30` and `F2e.md` still told the
owner to verify `.mixWithOthers` after the commit that deleted it, and the plan
contradicted itself twenty lines apart. The owner runs these once; an instruction
to confirm behaviour that cannot occur costs them the run. Both corrected, and the
check that actually matters was added: **stop and restart the music after a
preview**, since the reverted version would have broken `F4` invisibly.

**Two fences could pass while their promise was broken.** The scene-phase one
asserted `contains("scenePhase")`, which the `@Environment` declaration alone
satisfies — the whole `onChange` could be deleted and it stayed green. The audio
one checked for strings the corrected file no longer contains. Both rewritten; the
first now slices the block and counts both stops.

**A regex edit of the author's had mangled a doc comment** in `SettingsView.music`
— it ended mid-word at `music on der` — and silently deleted `@ViewBuilder`,
taking the `D19` rationale and the *"never amber, never a warning triangle"* rule
with it. Restored, and every line the branch removed from that file was diffed
against `main` to confirm nothing else went with it.

**An unverified claim about iOS.** The code and the plan both said the pushed
picker list stays up while a sound plays, as though it were designed here. It is
`.pickerStyle(.navigationLink)` behaviour, asserted nowhere, and may well pop
straight back. Both now say so.

## What came back clean

**Scope**, all seven passes. Nothing reaches Watch, Mac, CloudKit, widgets, themes
or streaks; no Todoist endpoint; no credential; no licence wording.

**`D27`'s lock is one modifier on one `Group`**, and the fence was shown to fail
when a section is moved out of it.

## The limit worth stating

**These are fences over source, not view tests.** There is no UI test target, and
*"every customization row is locked by one flag"* and *"a preview cannot outlive
its screen"* are claims about how a file is written. What no fence here can check
is whether the screen looks right, or whether a disabled `.navigationLink` picker
actually refuses to push — pass three named that specifically as unverified.

That is `O30`, and it is unrun.
