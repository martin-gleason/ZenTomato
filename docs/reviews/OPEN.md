# Open items — every review, one table

**Why this file exists.** Every review log from F1 onward carries a *Still open* section, three carry
*Still not verified*, and F4 carries a *Watch list*. Nothing aggregated them, so an item left open in
F2 was invisible by the time F6 was being reviewed. Six logs, six places to look, and no way to answer
"what is outstanding" without reading all of them.

Maintained at each review. An item leaves this table only when it is done or explicitly abandoned —
and abandoning is a decision that gets written down, not a thing that happens by the item scrolling
out of view.

**Owner** is who can actually close it. Most of the device checks cannot be closed by the agent under
any circumstances: no test in this repository can hear a sound come out of a phone or answer a
permission prompt.

---

## Needs the owner

| #   | Item                                                         | From   | Why it is still open                                         |
|-----|--------------------------------------------------------------|--------|--------------------------------------------------------------|
| O1  | **One real day's export, read beside the Rhodia**            | F6     | `SPEC.md`'s *Done when* for F6, and the only judgement of "readable without translation". The golden file is a format test, not the criterion. |
| O2  | **Migration over an existing install**                       | F6     | `CachedTask.isRecurring` and `CompletedTaskRecord.wasRecurring` are the first schema change since F2. The 2026-08-24 build was installed over the old app; if the history survived, lightweight migration worked. |
| O3  | **A full sprint with the screen locked, uninterrupted**      | F4     | `SPEC.md`'s *Done when* for F4. Every transition has been seen individually and a 4-pomodoro sprint completed, but never once as the single run the spec describes. |
| O4  | **Headphones, CarPlay, and an incoming phone call**          | F4     | Three audio-interruption paths, none exercised.              |
| O5  | **A playlist short enough to reach its end, to prove looping** | F4     | The loop is asserted in tests against a stand-in; no real playlist has run out. |
| O6  | **The alarm firing through an active Focus, and through silent mode** | F2     | This is *why* AlarmKit was chosen over a notification, and it has never been tested with a Focus on. |
| O7  | **Sound off**                                                | F2     | AlarmKit has no silent case, so one of the six locked settings rests entirely on a bundled silent audio file. |
| O8  | **VoiceOver on hardware**                                    | F2, F5 | The countdown was coarsened to whole minutes to cut announcement spam; whether iOS re-announces at all is runtime behaviour nobody has listened to. F5 adds the capture buttons' labels, values and announcements. |
| O9  | **The merged stop sheet with taps in it, at AX5**            | F5     | The single surface D14 was written for. Three chained sheets on one view, and the switched-off confirm button, unexercised at the largest text size. |
| O10 | **Apply the nine outstanding spec amendments**               | C6     | `SPEC.md` still states things that are no longer true. Counted in `docs/specs/AMENDMENT-BASELINE.txt`; the agent may not close these. |
| O11 | **F7's gate: D2 into `SPEC.md`**                             | F7     | `docs/plans/F7.md`: *"Until D2 is merged into `SPEC.md`, this feature does not exist and no line of it may be written."* Part of O10, listed separately because it blocks a feature. |
| O13 | **Developer Mode on the watch, then provision it** | C8 | Root cause: the new Watch Ultra 3 has never had Developer Mode turned on, so Xcode cannot register it, so no watchOS profile can include it — and the watch app is signed with an iOS profile instead. iOS installs the phone app and silently skips the watch app. Blocks F7's device check. Check with `scripts/check-watch-provisioning.sh` |
| O12 | **Three Todoist API facts, against a live token**            | F3b    | `scripts/check-todoist-facts.sh`. Whether an archived project resolves by id, whether sync reports deletions as tombstones or by silence, and whether old numeric task ids still resolve. |
**Owner response**

After f7 drops, we’ll test a 1 hour pomodoro sprint that addresses the following items:
- O1 - O3
- O5 - O8

The following should be applied before this is reviewed:
- O10 — Approved
- O11
- O12 — Approved

O4 will be scheduled sometime today.

## Needs the agent

| # | Item | From | Why it is still open |
|---|---|---|---|
| A1 | **`try?` on the three `StatsQuery` fetches** | F6 | A refused database read renders as a confident "you did nothing", on the one screen whose entire premise is being trusted, and as `No pomodoros in this range.` in a document filed as truth. |
| A2 | **`noIdentifiersInOutput` is largely tautological** | F6 | Four of its five assertions cannot fail: the fixture contains no identifiers. The structural guarantee is real; the executed half is decorative. |
| A3 | **Main-thread render and disk I/O on every range change** | F6 | `refreshExport()` builds the whole document and sweeps the temp directory synchronously, eagerly, whether or not anyone taps Export. |
| A4 | **The temp sweep deletes every `ZenTomato-*.md`** | F6 | Including one an open share extension may still be reading. |
| A5 | **Dead code with load-bearing documentation** | F6 | `StatsRange.everything(endingOn:in:)` and `StatsPeriod.recordedSpan` have no caller outside tests and describe an all-time export the range control does not offer. |
| A6 | **`StatsRange.swift:35` states the opposite of the shipped UI** | F6 | It says "no free-form date pickers" against a control whose own header says "Two pickers and a reset." |
| A7 | **Markdown metacharacters in Todoist titles are not escaped** | F6 | A task named `**Thesis**` renders as markup in the exported page. |
| A8 | **Time-zone change re-attributes historical days** | F6 | Correct across DST — every boundary goes through `Calendar` — but a device that changes zone makes two exports of the same fortnight disagree. Unspecified and untested. |
| A9 | **The performance test asserts `< 1s` against a 16 ms budget** | F6 | A 60× regression passes green. |
| A10 | **The palette lint rule does not cover `Stats/`, `Export/`, `Sprint/`** | F6 | Nothing violates it today; the guard has a hole. |
| A11 | **The no-writes fence test omits `update` and `comment`** | F6 | Two of the four words `CLAUDE.md`'s hook names. The real gate — the allowlist — is untouched, so the test's comment overstates it. |
| A12 | **A task finished on another device is still offered until the next refresh** | F3 | `.alreadyGone` enters neither the D21b set nor a cache deletion. Pre-existing; widening D21b's trigger would change its meaning from *completed* to *believed gone*. |
| A13 | **`docs/reviews/F6.md` does not follow the F1–F5 template** | C6 | Six logs, two shapes. |
| A14 | **The rewind that could not be reproduced** | F4 | Reported once, never seen again, most likely an artefact of the track name being one behind at the time. `docs/reviews/F4.md` carries the diagnostic order and four ranked fixes; **B** is recommended if it recurs. |

## Closed

| # | Item | From | How it closed |
|---|---|---|---|
| C-1 | CI had never run; `runs-on: macos-26` unverified | F1 | Green on PR #1, 2026-08-22. F1's largest open risk. |
| C-2 | The timer numeral shipped at ~34pt against a ratified 96pt | F1 | D7, ratified 2026-08-22. |
| C-3 | Cold launch flashed white before the stone page painted | F1 | D8, the launch colour set. |
| C-4 | `.env` held an `ACCESS_TOKEN` | F1 | D6b moved secrets to `.xcconfig`; no `.env` exists and it remains git-ignored. |
| C-5 | `## Projects` collapsed to one "No project" heading on real data | F6 | F3b and D22, 2026-08-24. |
| C-6 | D14 cited in ten files and defined nowhere | C6 | Recorded 2026-08-24; `DeltaIntegrityTests` now checks every citation. |
