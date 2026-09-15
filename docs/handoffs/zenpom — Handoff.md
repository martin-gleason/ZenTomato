# zenpom — Handoff

**For:** the first session of a dedicated zenpom coding project.
**From:** the ZTD 3.0 project, where zenpom was born as `pomo-v01` on August 21, 2026.
**Status of this doc:** durable context only. It is **not** the spec and **not** the plan. `SPEC.md` in the repo is the contract; `docs/plans/F<N>.md` are the builds. Where this doc and the repo disagree, **the repo wins.**

---

## First session protocol — do this before anything else

Do not resume blind. In order:

1. **Read the repo, not this doc, for state.** `SPEC.md`, `docs/conventions.md`, `CLAUDE.md`, `git log --oneline`, open PRs, `docs/plans/`, `docs/reviews/`. This handoff was written without repo access and deliberately does not assert what has shipped.
2. **Fire the adversarial reviewer** (`.claude/agents/adversarial-reviewer.md`) against what's merged. Standing rule: at the start of every session and the end of every feature.
3. **Re-read the outstanding feature list** in `SPEC.md`.
4. **Then** open the v0.2 respec gate below. Not before.

---

## What zenpom is

An iOS Pomodoro timer built against a fixed toolset. Todoist is the only place tasks live; Apple Music is the audio. Its actual reason for existing is **the distraction log** — an internal/external tally taken in the moment, with a one-sentence prompt at the end of a pomodoro, exportable to Markdown for the fortnightly Rhodia review. It is a Self-Knowledge instrument that happens to have a timer attached. If a scope decision ever threatens the log, the log wins.

Public GitHub repo, **GPL-3.0-or-later**, copyleft. Swift 6 / SwiftUI / SwiftData / MusicKit. No third-party dependencies without a ratified spec delta.

---

## Standing rules — these survive any respec

These are not v0.1 scope decisions. They are properties of the app, and reopening scope does not reopen them.

- **No capture surface.** zenpom never accepts a new task from the user. This is a rule from the owner's productivity system (single capture surface = Field Notes), not a feature gap. A "quick add" button is a violation, however it's framed.
- **Todoist writes are limited to completing a task.** No create, update, move, or comment paths. Enforced by hook, not by prose.
- **Todoist owns the hierarchy.** No local project/section/tag models beyond a cache of Todoist's.
- **Secrets never enter the tree.** Client credentials in a git-ignored `Secrets.xcconfig`; user token in Keychain.
- **Local only.** On-device SwiftData. No analytics. No network except Todoist and MusicKit.
- **The agent never edits `SPEC.md`.** It proposes a delta in a plan summary; the owner ratifies.

---

## Division of labor

**Marty specs and reviews. Claude authors all Swift.** Learning level is **5% — the floor**: the agent authors everything, the owner reviews every PR and logs it, no 🎓 features.

The consequence that matters: **every PR description is written for a reviewer who reads code but not Swift.** What changed, why, what to test on the device, what could break. This is the whole learning surface at 5%, so it is not optional politeness — it is the deliverable.

If the dial should move now that this is a dedicated coding project rather than a bounded side sprint, that is a legitimate question for the respec gate. Propose; let Marty lock it. Never change it silently.

---

## Conventions (pointer, not a copy)

`docs/conventions.md` in the repo is authoritative. In brief, so a session can sanity-check itself:

- **Feature** `F<N>` → **Task** `F<N>-T<M>`. **Chore** `C<N>` = work the *human* does. **Retrofit** `F<N>b`.
- **Phase** is a tag, not a container. A feature in build phase is still `F3`.
- **Gate** = the boundary crossed only with an explicit yes. Every feature is a gate.
- Branch `F<N>/<slug>`; commits `<type>(<id>): <description>`; **rebase-and-merge only**.
- Loop: route the gate → **Ultrathink** plan → **ultracode** build → **adversarial review** → verification *with evidence* (the command and its output in the PR) → PR → logged review.
- Hooks are deterministic; prose is advisory. `swiftlint --strict`, `xcodebuild test`, a grep gate against Todoist write paths, gitleaks, branch protection.

---

## What changed on September 8, 2026

Three things, and the third is the one a new session will get wrong if it isn't told:

1. **The TOGAF exam is cancelled.** Marty is not sitting OGEA-101 and is not taking the systems analyst role. The study track that occupied the parallel lane is closed.
2. **The project is renamed** `pomo-v01` → **zenpom**. Repo, bundle ID, scheme, and README are a **human chore** (next free `C<N>`), not agent work, and should be done before further feature branches to avoid renaming across open PRs.
3. **The fence came down, and it was load-bearing.** Every Phase 2 item — watchOS, macOS, CloudKit sync, playlist *creation*, task *creation* — was deferred with the words "post-exam." The hard stop was September 13, 2026. Both of those were anchored to a date that no longer exists. **zenpom currently has no scope fence at all.** Marty has decided to reopen scope and respec to v0.2, which is a legitimate decision he made deliberately. It is not a licence to skip the gate.

---

## The v0.2 respec gate

Run this as a gate, with Ultrathink, before any new feature branch.

**The failure mode being guarded against, stated plainly:** this project's owner has a named, recurring pattern of starting bounded and expanding mid-sprint, sometimes as avoidance. It has been caught in the act more than once — a card-sort tool that nearly became an iOS app, and zenpom itself, which was originally an expansion off a study sprint. The exam was the mechanism that held it. That mechanism is gone and **has not yet been replaced.** An agent that helps enthusiastically here without asking for a new fence is not being helpful.

**The gate must produce four things:**

1. **A new hard stop.** A date, or a shipped-artifact condition ("v0.1 running on the phone daily for two weeks"). Marty picks. Without one, v0.2 has no end state and no place to declare victory.
2. **A capped feature list.** A number decided up front, then filled — not a list that grows to fit the items. Phase 2 has five candidates; a v0.2 that takes all five is not a respec, it's the absence of one.
3. **An earned-entry test for every item admitted.** For each candidate, in writing: *what does this let me do that v0.1 doesn't?* Note the one answer that does not count — **"there's more time available now"** is a statement about capacity, not about value. It is the exact reasoning that produced the pattern this gate exists to catch.
4. **A restated Phase 3.** Whatever doesn't make v0.2 goes into a named fence with the same discipline the Phase 2 fence had, minus the dependency on a cancelled exam.

**Sequencing question to put to Marty first, before the candidate list:** is v0.1 actually shipped and in daily use? A respec that runs before the first version has been lived with is speccing against a guess. If v0.1 is merged but unlived, the strongest v0.2 scope may be "use it for two weeks, log what's missing, then respec" — which is a real answer, not a stalling one.

**Phase 2 candidates inherited, for the gate to sort:** watchOS app · macOS app · CloudKit sync · Apple Music playlist creation · Todoist task creation *(note: task creation collides with the no-capture-surface standing rule above — it is not a simple scope question and should be treated as a rule change requiring its own argument, not a feature)*.

---

## Open chores (human work, not agent work)

Verify each against the repo; this list is from August and may be stale.

- `C1` — GitHub repo with branch protection (PR required, CI required, rebase-merge only)
- `C3` — Todoist OAuth app registration *(blocks the Todoist feature gate)*
- `C<next>` — rename `pomo-v01` → `zenpom` across repo, bundle ID, scheme, README
- Apple Developer account provisioning for device installs

---

## Out of scope for the coding project

The dedicated project builds zenpom. It does not inherit the rest of the ZTD 3.0 lane. Specifically off the table here:

- Productivity-system redesign, habit cadence, review rituals
- Career decisions — the CDO curriculum, the PhD question, cert selection
- Job search, resume, LinkedIn
- Joyous Rebellion and the Rust track

If any of these surface mid-build, the right move is the standing one: **"Is this the current sprint, or the backlog?"** — capture it and send it back to the ZTD project.

---

## Two notes on tone, for the agent

**Socratic first, solutions second.** Marty's best decisions come from being asked to articulate what he already knows. On a respec gate especially, ask before proposing.

**Direct and honest, not diplomatic.** He has explicitly asked to be told the uncomfortable thing, gently. Naming a scope violation is doing the job, not obstructing it. Name it, refer it back to the agreed terms, and let him decide whether to reopen them — he is the one who ratifies.

-----
September 8, 2026

#AI/Claude
