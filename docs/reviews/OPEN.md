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
| O6  | **The alarm firing through an active Focus, and through silent mode** — **HALF ANSWERED 2026-08-27, twice** | F2 | **Through a Focus: yes, confirmed on two builds.** A sprint with **Do Not Disturb on** fired the alarm at every block end, including one on the lock screen; a second DND sprint on build 8 repeated it, and was run to test exactly this rather than answering it by accident. That is the half `SPEC.md` F2's whole design rests on — AlarmKit was chosen over a notification precisely so an alert would survive a Focus — and it holds. **Through silent mode: still untested, and not by oversight.** That sprint ran with the app's own sound setting **off**, which substitutes `Silence.caf`, so nothing could have made a noise whatever the ringer was doing. What remains is one block: **sound on, ringer switch off**. |
| O20 | **No choice of alarm sound** *(needs a delta — `D24` proposed)* | F2 | The owner: *"the default alarm sucks, and will be quite jarring to folks using an app with Zen in the name."* A sound picker is a **seventh** setting, and `PolishFenceTests` pins `AppSettings` at six — a bound that was mutation-tested against an alarm-sound picker specifically. So this cannot be built without ratifying the delta first. |
| O21 | **Music cannot be restarted during a break** *(needs a delta — `D25` proposed)* | F4 | Reported as a regression; the code says otherwise. Both halves — the switch disabled while any block runs, and transport controls limited to `kind == .work` — date from F4's first commit `e107dea` and have not changed since. `SPEC.md` line 27 says music *"Pauses. Resumes at the next pomodoro."*, so a break deliberately offers **zero** music controls. Making one available is a change to the contract, not a bug fix. |
| O7  | **Sound off**                                                | F2     | AlarmKit has no silent case, so one of the six locked settings rests entirely on a bundled silent audio file. |
| O8  | **VoiceOver on hardware**                                    | F2, F5 | The countdown was coarsened to whole minutes to cut announcement spam; whether iOS re-announces at all is runtime behaviour nobody has listened to. F5 adds the capture buttons' labels, values and announcements. |
| O9  | **The merged stop sheet with taps in it, at AX5**            | F5     | The single surface D14 was written for. Three chained sheets on one view, and the switched-off confirm button, unexercised at the largest text size. |
| O10 | **Apply the nine outstanding spec amendments**               | C6     | `SPEC.md` still states things that are no longer true. Counted in `docs/specs/AMENDMENT-BASELINE.txt`; the agent may not close these. |
| O11 | **F7's gate: D2 into `SPEC.md`**                             | F7     | `docs/plans/F7.md`: *"Until D2 is merged into `SPEC.md`, this feature does not exist and no line of it may be written."* Part of O10, listed separately because it blocks a feature. |
| ~~O16~~ | ~~**Branch protection on `main` — it has never existed**~~ **CLOSED 2026-08-24** | C1 | PR required, CI required, linear history, rebase-only, no force pushes. |
| ~~O13~~ | ~~**Developer Mode on the watch, then provision it**~~ **CLOSED 2026-08-24** | C8 | Root cause: the new Watch Ultra 3 has never had Developer Mode turned on, so Xcode cannot register it, so no watchOS profile can include it — and the watch app is signed with an iOS profile instead. iOS installs the phone app and silently skips the watch app. Blocks F7's device check. Check with `scripts/check-watch-provisioning.sh` |
| ~~O14~~ | ~~**Does the music row give a real answer now?**~~ **CLOSED 2026-08-27 — yes.** Settings → Music reads **Connected** on the device, in Todoist's vocabulary. Open since the MusicKit-entitlement confusion; the App ID work (`C11`) and `F4c`/`F4d` between them answered it. — *now also readable in Settings → Music, which is the faster check* — *the App ID half is done; see `docs/chores/C11.md`* | C8, C11 | The App ID is explicit and MusicKit is enabled on it under App Services. The premise that a missing **entitlement** caused `ICError -7013` was wrong — there is no MusicKit entitlement for an iOS app. So whether those errors persist, and whether the subscription check now succeeds, is a device question rather than a settled one. |
| O15 | **F7's device check — three wrist taps, phone in another room** | F7 | D2's *Done when*, and the only thing that can close F7. Then the harder half: taps made genuinely out of range, arriving later with their **original** timestamps. |
| ~~O17~~ | ~~**Search in the music picker**~~ **CLOSED 2026-08-27 — built and verified on the owner's own library**, which is the only fixture that counted. `D23` ratified, `F4e` shipped. | F4c | The other half of the note that produced F4c. A library of a few hundred playlists is unusable without one, but a search field is new functionality rather than a rearrangement, so it wants a delta argued rather than assumed. |
| ~~O18~~ | ~~**No `PrivacyInfo.xcprivacy`**~~ **CLOSED 2026-08-27 — added, and fenced.** Declares no tracking, nothing collected, no required-reason API, and `PrivacyManifestTests` holds it to that: the three arrays must stay empty, and the shipped Swift is searched for the five required-reason API families with comments stripped. Verified present in the built bundle rather than in `project.yml`. Formerly: | C12 | Verified rather than assumed: no required-reason API is used (the only `UserDefaults` in the tree is a word in a comment) and nothing is collected or sent, so Apple does not require a manifest. Worth adding anyway so "collects nothing" is machine-readable rather than a claim in a README. |
| ~~O19~~ | ~~**The App Store name — "ZenTomato" is taken**~~ **CLOSED 2026-08-25 — the name is `ZenPom`** | C9, C10 | App Store Connect returned `409 DUPLICATE.DIFFERENT_ACCOUNT` on the first upload attempt: the name is in use by another account. Costs nothing in code — bundle ID and home-screen name are unaffected — but no build can be uploaded until an app record exists, and no record can be created without a name. Effectively permanent once builds ship under it, and it is the name the public GPL repo carries, so it is `C10`'s decision too. |
| O22 | **A CLA or copyright assignment, before the first outside pull request** — *`CONTRIBUTING.md` is drafted and awaits ratification* | C10, C18 | Falls out of the dual-licence ruling. Dual licensing works because the owner holds all the copyright — and stops working the moment one outside contribution is merged under GPL-3.0 with no broader grant. **That is how VLC's situation actually arose**: a contributor who held rights and later objected, not Apple auditing licences. Urgent because a stranger can open a PR tomorrow, not because of TestFlight. |
| O23 | **Progress bars appear full rather than filling** | F5 | Owner's note during sprint 2: *"progress bars should fill up, not just appear full."* Cosmetic, and not looked at yet. |
| ~~O24~~ | ~~**The dual-licensing report is fetchable by SHA on GitHub**~~ **RULED 2026-08-27 — accepted, not purged** | C13 | Removed from the tree in `c4358c2` but still reachable by its 40-character object id, as any removed-but-not-rewritten blob is. The owner accepted the exposure rather than rewrite history. **The reasoning, so nobody reopens it:** the object is unreachable from any branch and needs the exact SHA to fetch, while rewriting `main` would change every commit id in the repository — and this project cites commit ids constantly, in plans, reviews and merged PR bodies. The cure alters more than the disease. `docs/*-report.md` and the archive globs stop a recurrence. |
| ~~O25~~ | ~~**The plan gate was being skipped**~~ **RULED 2026-08-27 — rule kept, agent to stop skipping it** | C6 | Raised by the adversarial reviewer on `F4c`, where the plan was committed one second after the code it gates, and true of most of 2026-08-27's work. A plan written afterwards is a justification and cannot do the gate's job — giving the owner a moment to say *"don't build that"* while it is still cheap. Defect fixes proceed (the `D22` precedent); everything else waits for a yes. Written into `conventions.md`. |
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

### Found in F6b's closing read, and fixed — 2026-08-24

**A project-attached block showed nothing on the wrist.** `SPEC.md` line 16: *"A pomodoro is
attached to exactly one Todoist task (or, if no task is chosen, to a project)."* The wire
field the phone sends the watch was called `taskTitle` and carried only the first of those, so
a block attached to a whole project arrived with a countdown and **nothing to say what it was
counting** — half the cases the spec allows, silently blank.

Nobody flagged it: the reviewers read the counting, the scope and the page, and the watch
came later. It only appears if you plan a project rather than a task and then look at your
wrist. Fixed by sending whatever the block is attached to, in the order the spec states them.

**And a break now says where the buttons went.** They vanish during a break, correctly —
`SPEC.md` makes them *"tappable during a pomodoro"* — but a control that disappears without a
word reads as a fault. The phone answers this by reserving the space (D19); a wrist has none
to reserve, so it answers in a sentence.

### Watch item — stopping a block offered nothing to complete

**Reported 2026-08-24, to be retried.** The owner: *"i stopped the pomodoro and couldn't
select what was completed."*

**The wiring is there.** `StopReasonSheet` carries the completion control, and the stop path
populates its subject before presenting — `TimerView.swift:842`, the same call the
end-of-block path makes. So this is not a missing feature; it is one of four specific
conditions, and knowing which turns a repeat into a diagnosis.

`currentCompletionSubject()` returns nothing unless **all four** hold:

| Condition | If it fails |
|---|---|
| A Todoist token is stored | the section cannot appear at all |
| The block had an attachment | nothing to complete |
| That attachment is a **task** | **a block attached to a *project* has no task to tick off** |
| The task has a title snapshot | nothing to name |

**The third is the likeliest, and it is by design.** `SPEC.md`: *"A pomodoro is attached to
exactly one Todoist task (or, if no task is chosen, to a project)."* Only a task can be
completed, so a project-attached block correctly offers nothing.

**There is a second reading, and it is the more interesting one.** "Select what was
completed" may mean choosing from the session plan rather than ticking off the one attached
task. That is not what the app does — it offers the block's own task and nothing else — and
it is close to the owner's stated use case: *"At the end of a pomodoro, but before the break,
I want to capture what I completed."* If that is what was expected, this is a spec question
for v1.1 rather than a defect, and it needs a delta.

**What to note on the retry:** what the block was attached to — a task, a project, or nothing
— and whether the section was absent entirely or present but disabled. Those two answers
separate all four conditions from the expectation gap.

### Device results — 2026-08-24

**Interruptions, from the owner:** *"phone call paused the timer and the music, when
answered. it seems to be working. headphones and siri activation pause but keep working."*

**The timer did not pause, and could not have.** There is no `pause` function, no
`isPaused` and no `pausedAt` anywhere in `TimerEngine`; a block's end rests on `endsAt`, an
absolute instant, and remaining time is `endsAt.timeIntervalSince(instant)`. The music
interruption handler reaches music only. What paused was the audio, which is correct, while
the call held the screen. The no-pause rule ratified on 2026-08-21 is intact.

**One thing to confirm during the full sprint, cheaply:** that a block interrupted by a call
still *ends at the right wall-clock minute*. The design says it must; nobody has watched it.

**Alarm through an active Focus: pass.** The reason D3 chose AlarmKit over a local
notification, proven on hardware for the first time.

**CarPlay: pass.** The owner: *"the song played through the app and didn't miss a beat."*
O4 closes — all three interruption paths now exercised.

**Playlist looping: pass.** *"the playlists repeats."* O5 closes. The loop had only ever been
asserted against a stand-in; no real playlist had run out until now.

**Wrist taps at over fifty feet: pass, informally.** *"the watch taps were captured a distance
over 50 feet."* D2's *Done when* asks for the phone in another room; fifty feet is past that.
O15 stays open only until the full pass confirms it with the timestamps checked, which is the
half that actually matters — that a queued tap arrives saying **when it happened**, not when
it was delivered.

**A defect the wrist found, and it was costing data.** The owner: *"tapping the app in the
watch has a long delay — more than 2 seconds — and it led to an excessive number of I and E
clicks."*

`transferUserInfo` was being called synchronously on the main actor, with the counters
incremented *after* it returned. So nothing on screen moved for over two seconds and the
button read as dead — and every extra press was a real tap that became a real row. **A laggy
button was quietly inflating the one number this app exists to produce.** Fixed: the transfer
moved off the main actor, the counters raised before it, and a tally now appears the instant a
button is pressed.

**The taps already made are real rows and are still in the database.** There is no capture
surface and no editor, by design, so nothing in the app can remove them. Any export covering
that block will over-report. Worth knowing before O1 is judged.

## Needs the agent

| # | Item | From | Why it is still open |
|---|---|---|---|
| A1 | **`try?` on the three `StatsQuery` fetches** | F6 | A refused database read renders as a confident "you did nothing", on the one screen whose entire premise is being trusted, and as `No pomodoros in this range.` in a document filed as truth. |
| ~~A2~~ | ~~**`noIdentifiersInOutput` is largely tautological**~~ **CLOSED 2026-08-24** — routed through a real store, verified by mutation | F6 | Four of its five assertions cannot fail: the fixture contains no identifiers. The structural guarantee is real; the executed half is decorative. |
| ~~A3~~ | ~~**Main-thread render and disk I/O on every range change**~~ **CLOSED 2026-08-24 by measurement** | F6 | `refreshExport()` builds the whole document and sweeps the temp directory synchronously, eagerly, whether or not anyone taps Export. |
| ~~A4~~ | ~~**The temp sweep deletes every `ZenTomato-*.md`**~~ **CLOSED 2026-08-24** — per-launch directory | F6 | Including one an open share extension may still be reading. |
| ~~A5~~ | ~~**Dead code with load-bearing documentation**~~ **CLOSED 2026-08-24** — `StatsRange.everything` deleted | F6 | `StatsRange.everything(endingOn:in:)` and `StatsPeriod.recordedSpan` have no caller outside tests and describe an all-time export the range control does not offer. |
| ~~A6~~ | ~~**`StatsRange.swift:35` states the opposite of the shipped UI**~~ **CLOSED 2026-08-24** | F6 | It says "no free-form date pickers" against a control whose own header says "Two pickers and a reset." |
| ~~A7~~ | ~~**Markdown metacharacters in Todoist titles are not escaped**~~ **CLOSED 2026-08-24** | F6 | A task named `**Thesis**` renders as markup in the exported page. |
| A8 | **Time-zone change re-attributes historical days** — *researched, ruled, pinned* | F6 | Correct across DST — every boundary goes through `Calendar` — but a device that changes zone makes two exports of the same fortnight disagree. Unspecified and untested. |
| ~~A9~~ | ~~**The performance test asserts `< 1s` against a 16 ms budget**~~ **CLOSED 2026-08-24** — tightened to 250 ms | F6 | A 60× regression passes green. |
| ~~A10~~ | ~~**The palette lint rule does not cover `Stats/`, `Export/`, `Sprint/`**~~ **CLOSED 2026-08-24** — and `ZenTomatoWatch/`, `Todoist/`, `Plan/`, `Music/` | F6 | Nothing violates it today; the guard has a hole. |
| ~~A11~~ | ~~**The no-writes fence test omits `update` and `comment`**~~ **CLOSED 2026-08-24** | F6 | Two of the four words `CLAUDE.md`'s hook names. The real gate — the allowlist — is untouched, so the test's comment overstates it. |
| A18 | **Watchdog kill: `playbackState` is a blocking XPC call on the main thread** — *diagnosed, fix designed, not built* | F4 | `docs/crashes/ZenTomato-2026-08-26-134602.ips`: `0x8BADF00D`, ten seconds of wall clock against **0.053s of app CPU** — blocked, not looping. Stack ends in `xpc_connection_send_message_with_reply_sync` under `MPMusicPlayerController.playbackState`. `F4-contract.md` §8 chose to read it live on purpose and did not price it as IPC. **No test could have caught it**: the stand-in returns instantly, and nothing in the suite distinguishes a property read from a cross-process call. See `docs/chores/C16.md`. |
| A17 | **Why the alarm is silent when the phone is silent** | F2 | Unknown, and **not to be guessed at** — three framework assumptions have already been wrong this week. The configuration itself is idiomatic: `AlarmManager.AlarmConfiguration.timer(...)` with `sound: .default` when the setting is on and `.named("Silence.caf")` when off, and `Silence.caf` is confirmed present in the shipped bundle. Two candidate causes, and one device check separates them — see `docs/chores/C14.md`. |
| A16 | **The query costs 57 ms for an all-time range** | F6b | Found by measuring for A3 — the cost is the query, not the render. ~0.22 ms per day of range, so the 16 ms budget is crossed at about ten weeks; the default fortnight is 3 ms. **Deliberately not fixed:** `F6-contract.md` pre-decided a `@ModelActor` and warned against taking it pre-emptively, *"since a suspension point is where the last two features found their real bugs"*. Recorded with the number so it can be decided with rather than about. |
| ~~A12~~ | ~~**A task finished on another device is still offered until the next refresh**~~ **CLOSED 2026-08-24** — the mirror forgets it on `.alreadyGone` | F3 | `.alreadyGone` enters neither the D21b set nor a cache deletion. Pre-existing; widening D21b's trigger would change its meaning from *completed* to *believed gone*. |
| ~~A13~~ | ~~**`docs/reviews/F6.md` does not follow the F1–F5 template**~~ **CLOSED 2026-08-24** | C6 | Six logs, two shapes. |
| ~~A15~~ | ~~**`MusicSubscription.current` is deprecated in process**~~ **CLOSED 2026-08-24 — not actionable on iOS** | F4 | The device log carries: *"it has recently become deprecated to request the music subscription status in process; the new supported code path fetches it in itunescloudd, but you need to add `com.apple.security.exception.mach-lookup.global-name com.apple.itunescloud.music-subscription-status-service` to your sandbox"*. Works today. Worth doing before it stops. |
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
