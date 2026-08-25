# F4c — adversarial review

**Branch:** `F4c/music-status-in-settings` · **Plan:** `docs/plans/F4c.md`

## The charge that mattered

*This is Spotify preparation wearing a polish pass as a disguise.* The owner said
v1.5 in the same breath as the request, which is exactly the circumstance `D16`
was written for, and "follow best practices" is the most respectable available
cover for a provider abstraction.

**Not upheld, on the evidence in the diff.** There is no protocol, no enum with
one case, no `MusicService` anything, no parameter that exists only to be varied
later. The section is named "Music" and hard-codes Apple Music throughout. The
`D16` question — *would I write this the same way if Spotify were never coming?*
— answers yes for a reason that has nothing to do with Spotify: **Settings
already holds Todoist's service state**, and the app has two services.

## Findings

**1. The shared function is load-bearing and invisible at runtime.** Collapsing
the picker's four footer cases into one call is the correct fix for drift, but
nothing at runtime can tell one copy of a string from two. Two duplicated
constants pass every behavioural assertion until the day they diverge, and that
day is a fortnight after somebody edits one screen.

*Addressed:* `thePickerAndSettingsCannotDisagree` reads the picker's source and
fails both if it stops calling `settingsFooter(for:)` and if it reaches past it
to a private constant. Mutation-verified in both directions.

**2. The preview default could make the section a permanent lie.**
`SettingsForm.musicAvailability` defaults to `.notAsked` so the screen draws in a
preview with nothing behind it — the arrangement the Todoist collaborators
already use, so it is the consistent choice. But a screen that always reports
"Not set up" *looks* like it is working and answers nothing, and that failure is
indistinguishable from success by eye.

*Addressed:* `settingsIsGivenTheRealState` asserts `TimerView` passes
`music.availability`. This is the mutation the suite would most plausibly have
missed and the one worth having.

**3. The tests read the source tree rather than the rendered view.** A legitimate
weakness: they prove the section is written, not that it is on screen. A snapshot
harness would prove more.

*Accepted, not fixed.* This project has no snapshot infrastructure and adding one
for a two-row section is a larger change than the change. The gap is named here
rather than papered over, and the device check below is what actually closes it.

**4. The finding underneath the bug is not fixed anywhere.** Four correct
sentences, four passing tests, and none of it reachable — because every
assertion tested the string and none tested the route. Other copy in this app
could be unreachable in exactly this way right now and the suite would be green.

*Recorded, not fixed.* No cheap general mechanism exists; naming it is worth more
than a bad one.

## Verdict

**Merge.** In bounds, tested, and the tests fail when the code is broken.

Two things stay open and are not this branch's to close: the device check that
the Settings row gives a real answer (`O14`), and search in the picker, which
wants a delta (`O17`).
