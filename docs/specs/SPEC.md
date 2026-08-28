# pomo-v01 — v0.1 Spec (the contract)

**Status:** DRAFT for ratification. Marty ratifies; then it's the contract. The agent never edits this file — it proposes deltas in a plan summary and Marty merges them.
**License:** GPL-3.0-or-later (copyleft, open source). Public GitHub repo.
**Hard stop:** the day work resumes or **September 13, 2026**, whichever is first. Unmerged work returns to backlog, no forensics.
**Platform:** iOS, with a watchOS companion (F7). Mac, CloudKit sync, playlist creation, and task *creation* are Phase 2 — see Out of Scope.

## Why

A focus timer that works with the fixed toolset (Todoist, Apple Music) so that study and work blocks run without a second app to vacuum. Todoist remains the only place tasks live. The app's unique value is the distraction log: Self-Knowledge data, tallied in the moment and readable at the two-week Rhodia review.

## Vocabulary

- **Pomodoro** — one timed work block followed by a short break. Default 25/5.
- **Sprint** — a set of N pomodoros ending in a long break. Default 4, then 15.
- **Task / Project / Section** — Todoist's terms, Todoist's data. The app defines none of its own. A pomodoro is attached to exactly one Todoist task (or, if no task is chosen, to a project). Before a sprint, the user may build a **session plan**: an ordered list of Todoist tasks and projects, drawn from the cache, which the timer works through. Each pomodoro attaches to the plan's current item, so the one-task-per-pomodoro rule is unchanged. A plan creates nothing and writes nothing.
- **I / E** — internal / external distraction.

## Locked decisions

| Decision | Value |
|---|---|
| Task source | Todoist. **All** projects, sections, and tasks are visible in the picker. |
| Todoist writes | **Complete a task** only. No create, no edit, no comment. Enforced by hook, not by prose. |
| Music source | Apple Music (MusicKit). User picks an existing playlist or song from their library. Playlist loops when it ends. |
| Music during a sprint | Skip-forward and stop are the only controls. Stop silences the music for the remainder of the current block; the timer is unaffected and the next block starts music again. Music can be toggled on/off before a sprint. |
| Music during breaks | Pauses, and can be switched back on by hand. Resumes by itself at the next pomodoro. |
| Distraction capture | Two buttons, I and E, tappable during a pomodoro. A tap records timestamp + task. At the end of that pomodoro the app prompts for one sentence per tap (skippable). If the phone was locked or the app was away, the prompt waits and appears when the app is next opened — unless so long has passed that nobody could still be in that block, or the app was closed after the block had already been reckoned up, in which cases the taps stay recorded and the prompt is dropped. |
| Stats | Counts for everything: pomodoros per task, project, and day; I/E per task and day. Plus a Markdown export via the share sheet for the Rhodia review. |
| Timer customization | Work length, short break, long break, pomodoros-per-sprint, sound on/off, which alert sound, auto-start next block on/off. Nothing else. Each alert sound can be played once from the settings screen before it is chosen. While a block is running these are read-only, and the screen says so. |
| Data | Local only (SwiftData). Todoist token in Keychain. No analytics, no accounts, no server. |
| Minimum iOS | 26.0. Minimum watchOS 26.0. |

## Features (the agent's track)

Each feature is a gate. Crossing it needs Marty's verbal yes on the plan.

- **F1 — Skeleton.** SwiftUI app, SwiftData store, settings model, SwiftLint, GitHub Actions CI (build + unit tests on a macOS runner), `LICENSE`, `README`. *Done when:* CI is green on `main` and the app launches to an empty timer.
- **F2 — Timer engine.** Pomodoro / short / long break cycle per settings. Survives backgrounding (state persisted). Block ends fire through AlarmKit, so the alert sounds through silent mode and through an active Focus. While the alarm is ringing the timer screen shows one control that silences it and moves the sprint on, exactly as the system alert's own Dismiss does. A Live Activity on the Lock Screen and in the Dynamic Island is required, not optional — AlarmKit's countdown API mandates one. *Done when:* unit tests cover the cycle and a backgrounded timer ends on time on a device.
- **F3 — Todoist.** Sign in with a Todoist personal API token, entered once and stored in Keychain; fetch projects, sections, tasks; picker; attach a task to the current pomodoro; **complete** a task with one button at the end of a pomodoro. *Verify at build time:* the current Todoist API version and rate limits (a third-party timer broke in early 2026 on a deprecated endpoint — don't repeat that). *Done when:* token entry, pick, and complete work against Marty's real account.
- **F4 — Apple Music.** MusicKit authorization; library playlist/song picker; play, loop, skip; on/off toggle; pause on breaks. *Verify at build time:* background audio entitlement and MusicKit behavior with the timer in background. *Done when:* a playlist plays through a full sprint on a device with the screen locked.
- **F5 — Distraction log.** I/E buttons on the running-timer screen; tap → record; end-of-pomodoro sentence prompt; persisted. At the end of a pomodoro the app presents one sheet containing a sentence field per distraction tap (each skippable) and, once F3 has landed, the Complete-task button. The break timer starts running the instant the block ends, behind the sheet — reflection never consumes break time. The auto-start-next-block setting governs the pomodoro after the break, not this sheet. *Done when:* a pomodoro with three taps yields three records with the right task and timestamps.
- **F6 — Stats and export.** Counts per task, project, day; I/E per task, day; Markdown export. *Done when:* the export of one real study day is readable in the Rhodia without translation.
- **F7 — Watch companion.** watchOS 26 companion app. The phone is the source of truth and runs the only timer engine. The watch displays the running block, the block kind, and the attached task, and puts the I and E distraction buttons on the wrist. The watch never runs a timer of its own, never controls music, never picks a task, and never edits a distraction note. *Done when:* three wrist taps during a pomodoro, with the phone in another room, yield three records on the phone with the right task and timestamps.

Suggested build order: F1 → F2 → F5 → F3 → F4 → F6. The timer and the log are usable by Marty after F5, before either integration lands.

## Chores (Marty's track)

- **C1** — Create the GitHub repo, add the GPL-3.0 LICENSE, turn on branch protection for `main` (PR required, CI must pass, rebase-and-merge only).
- **C2** — Confirm minimum iOS from the phone. Confirm the Apple developer account is active; create the App ID with the MusicKit capability.
- **C3** — Register an OAuth app in the Todoist developer console; put the client ID and secret where CLAUDE.md says secrets go (never in the repo).
- **C4** — Install builds on the iPhone (TestFlight or Xcode); the device tests in F2–F4 are yours.
- **C5** — Name the fixed afternoon PR-review slot and put it in Fantastical. Reviews never happen in the morning window.

## Out of scope for v0.1 (Phase 2, post-exam)

standalone watchOS · macOS · CloudKit sync · creating a default "focus playlist" · creating, editing, or commenting on Todoist tasks · any capture surface of any kind · widgets beyond the Lock Screen Live Activity · themes · streaks, badges, or any gamification layered on top of Todoist's own.

A feature request that isn't on the list above gets one question — *is this v0.1 or Phase 2?* — and the answer is written here before anything is built.

## Hook intentions

The plan defines these; listing them here states what the spec wants protected.

1. **No task creation.** A check that fails the build if any code path calls a Todoist create/update/comment endpoint.
2. **No secrets in the tree.** Secret-scan on pre-commit and in CI.
3. **Lint and tests gate merge.** SwiftLint clean, tests green, enforced by branch protection — not by promise.
4. **Scope fence.** Adversarial review at the end of every feature checks the diff against this file's feature list and out-of-scope list.

-----
August 21, 2026

#AI/Claude

## Amendments applied

D1 D2 D3 D4 D17 D18 D20 D24 D25 D26 D27 D28 D29

Ratified deltas whose text has been written into this file. `DeltaIntegrityTests` reads this list;
`docs/specs/AMENDMENT-BASELINE.txt` counts what is still outstanding, and the exact replacement text
for each is in `docs/specs/AMENDMENTS-TO-APPLY.md`.
