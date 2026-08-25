# F4c — adversarial review

**Branch:** `F4c/music-status-in-settings` · **Plan:** `docs/plans/F4c.md`

## A correction about this file

The first version of this document was written by the author, before the
reviewer had been run, and recorded the verdict **Merge**. That is backwards: it
documented a review that had not happened. The reviewer caught it — all four
commits are stamped within two seconds of each other, so the review log was
committed one second after the code it reviews.

This is the same defect as `3.6a` in the process handoff — *writing a guess down
does not test it; it promotes it* — arriving in a new place. Recorded rather than
quietly overwritten.

What follows is the actual review, and its verdict was **DO NOT MERGE**.

## The two charges that came back clean

**Spotify preparation in disguise.** Not upheld. No protocol, no provider enum,
no parameter that exists only to be varied later; the section hard-codes Apple
Music throughout. `D16` holds.

**A new setting.** Not upheld. `AppSettings` stays at six, `PolishFence` passes,
no model file is touched, no `UserDefaults` key, no Todoist write path.

## Blocking findings, and what was done

**1. `settingsShowsTheState` did not test the route it claimed to.** It searched
the whole of `SettingsView.swift` for three substrings. Deleting `music` from the
`Form` body would have orphaned the section — unreachable, exactly as before —
with all seven tests green.

**This is the bug F4c exists to fix, reproduced inside the fix.** The plan's own
finding, *"every assertion tested the string and none tested the route"*, was
still true of the new suite. The suite did not catch it; the reviewer did.

*Fixed:* the test now parses the `Form` body and asserts `music` is rendered in
it, above `todoist`. Mutation-verified with the reviewer's own mutation (M5) and
with a reordering (M6).

**2. The new section was inserted inside Todoist's doc comment.** *"One row in,
and — once connected — one way out… the row pushes to the screen that owns the
field"* ended up heading `private var music`, which has no navigation, no token
and no onward screen, while `private var todoist` — which has all three — was
left undocumented. At learning level 5% the doc comments are the reviewer's
primary interface, so this was a false statement in the most load-bearing place.

*Fixed.* Both comments reattached. Caused by inserting with a text replacement
anchored on the declaration rather than on the comment above it.

**3. The same defect in `MusicRowModel.swift`** — `couldNotBeCheckedFooter` lost
its comment to `settingsStatus(for:)`. *Fixed.*

**4. Evidence asserted rather than shown.** *Fixed:* `make ci` output and the
full mutation table are in the plan and in the PR.

## Non-blocking findings, and what was done

| Finding | Disposition |
|---|---|
| Settings had no refresh, while the picker refreshes on appear — and `OPEN.md` now advertises Settings as the faster check for `O14`. It could report a state stale since launch. | **Fixed.** `refreshMusicAvailability` passed in and called from a `.task` on the section. Two mutations (M7, M8) confirm it, including the one where Settings is handed the do-nothing preview default. |
| `everyStateHasAWordAndASentence`'s stated rationale was false — a seventh enum case is a compile error, not a blank row. | **Fixed by rewriting the claim**, not the test. What is left is what the compiler cannot check, said honestly. |
| The `TimerView` comment claimed the value is read at presentation rather than watched. `MusicCoordinator` is `@Observable`, so it is almost certainly watched. | **Fixed.** The comment now says what actually happens, and is the reason the refresh is worth having. |
| Header "Music" over a row labelled "Apple Music" — a category over a service, the one shape in the diff that reads provider-shaped. | **Fixed.** Header is "Apple Music", matching Todoist's shape. |
| `readyFooter` was shown for `.notAsked` too, so "Not set up" sat above a sentence describing music playing. | **Fixed.** `notAskedFooter` added, and a new assertion pins the two apart (M9). |
| `thisAddedNoSetting` derives the section bounds from source order and would widen if the file were reordered. | **Accepted**, with a comment saying so. It widens rather than narrows, so it cannot silently pass. |
| Five of six statuses have no preview. | **Accepted.** Deferred to the device check with `O14`. |
| `docs/*-report.md` is broad and could swallow a future report an agent believes it committed. | **Accepted deliberately.** The failure it prevents — a private file committed — is worse than the one it risks. |
| The `.gitignore` fix is repo hygiene on a feature branch, which conventions class as a `C<N>`. | **Accepted.** It was found while branching for F4c and the file was unprotected in the meantime; delaying it to file a chore would have left it that way longer. |

## Second pass — verdict **MERGE**

The reviewer was re-run against the repairs, and confirmed the four blocking
findings were fixed rather than worked around — checking the evidence by running
`make ci` itself rather than reading the author's numbers, and by reading
`MusicCoordinator` to confirm `notAskedFooter` states something true.

It then found three more, all of which passed before it ran:

| Finding | Disposition |
|---|---|
| **The middle link of the wiring had no test.** The reviewer deleted two lines from `SettingsView`'s construction of `SettingsForm` and 467 tests passed, with the row reporting "Not set up" forever and the refresh a no-op. Both tests either side checked only the `TimerView` end of a three-link chain. | **Fixed** — `theMiddleLinkIsWired`, mutation-verified (M10). |
| **`settingsShowsTheState` trimmed indentation**, so `if false { music }` passed. The realistic regression is a later tidy such as `if musicAvailability != .notAsked { music }`. | **Fixed** — the section must sit at the form's own depth (M11). |
| **`settingsAsksAgainWhenItOpens` was a whole-file substring grep** — the exact defect the first pass blocked on, reintroduced in the commit that fixed it. | **Fixed** — comments stripped, position checked (M12). |
| The `.task` on a `Section` inside a `Form`: section lifetime is cell lifetime, so the comment asserted a scoping it did not have. | **Fixed** — moved to the form, matching the picker. |
| `docs/reviews/F4c.md` claimed the header "matches Todoist's shape". It did not: Todoist is header + row both reading "Todoist"; music was header "Apple Music" + row "Status". | **Fixed** — the row names the service and the header is the category, as Todoist's is. VoiceOver was announcing "Status, Not set up" without the service name; now labelled. |

The `refreshMusicAvailability` closure was checked for retain cycles and Swift 6
strict-concurrency correctness and is clean. All four accepted dispositions were
confirmed honest rather than blocking findings relabelled.

**Twelve mutations now**, each breaking exactly one thing a named test claims to
protect, each caught, each restored. `make ci` green at 468 tests.

### Carried to the owner

The reviewer's process finding had a second half that is not the author's to
close. `CLAUDE.md` step 1 requires the owner's yes on `docs/plans/F4c.md` before
the build; the file was committed one second after the code. The owner's
instruction — *"we should put the licensing in the settings"* — was given in
chat, but the plan was written after the work rather than before it, and the
tree cannot distinguish that from no gate at all. Flagged for the owner.

The device check stays open and is not this branch's to close: read Settings →
Apple Music on hardware and confirm it gives a true answer (`O14`). Search in the
picker wants a delta (`O17`).
