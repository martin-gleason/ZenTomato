# Conventions — pomo-v01

Standalone copy. This repo is its own source of truth; nothing is imported from a parent workspace.

## Structure (the only axis with IDs)

- **Feature** `F<N>` — a deliverable unit of **user value**. Decomposes into Tasks.
- **Task** `F<N>-T<M>` / `C<N>-T<M>` — an implementation step inside a feature or a chore.
- **Chore** `C<N>` — an operational task that produces **no user-visible change**: repo setup,
  credentials, documentation, process, tooling, corrections. Each chore names its **owner** —
  the human, the agent, or both. Chores are the parallel track.
- **Retrofit** `F<N>b`, `F<N>c` — a second pass on an **already-shipped** feature.

### Feature or chore? Ask what it delivers, never who does it

**The test is one question: would a user of the app notice?** If yes it is a feature; if no it is a
chore. Ownership is a *property* of the unit, not the thing that classifies it.

This is written down because it was got wrong. `C6` was first opened as `F7a` — an agent-authored
documentation and tooling correction, filed as a feature because the agent does it and because
chores were then defined as *"an operational task the human performs."* That definition left agent
work that is not a feature with nowhere to go, so it went somewhere wrong. Chores now cover it, and
the owner is stated on the unit.

Two corollaries worth stating, because both were live at the time:

- **A retrofit is a second pass on something already shipped.** `F7a` was not: `F7` had not been
  built. A correction to an unbuilt feature's *plan* is a chore, not a retrofit.
- **A correction spanning several features belongs to none of them.** `C6` fixes documentation
  across `F1`–`F6`. Numbering it after any one of them would have implied an ownership it does not
  have.

## Lifecycle (metadata, not a container)

- **Phase** — design / build / test / deploy. A tag on a unit. `F3` in build phase is still `F3`, never "Phase 3."

## Authorization

- **Gate** — the boundary crossed only with the owner's explicit yes. Every feature is a gate. Every phase change inside a feature is a gate.

## Merge

- **PR** — one feature branch, one or more Tasks, merged to `main` by **rebase-and-merge**. No squash, no merge commits — every commit stays for audit.
- **Branch:** `F<N>/<slug>` (e.g. `F2/timer-engine`).
- **Commit:** `<type>(<id>): <description>` — `feat(F2-T1): persist timer state across background`. Types: `feat`, `fix`, `test`, `chore`, `docs`, `refactor`, `ci`.

## Learning dial

| Level | Human | Agent |
|---|---|---|
| **5% (floor)** — *this project* | Review every PR, log it | Authors everything |
| 10% | + occasional small pieces | Authors; "why" notes in PRs |
| 20% | Authors 🎓 features, coached | Stubs 🎓, tutors, authors the rest |
| 50% | Authors the core | Scaffolds, reviews, tutors |

🎓 on a feature overrides the dial (human builds it, coached). A deadline or language veto in the planning prompt overrides 🎓. Not used in v0.1.

## Working loop

Route the gate (deep spec vs. direct plan) → **Ultrathink** plan → **ultracode** build → **adversarial review** (end of feature, start of session) → **verification with evidence** → conventional commit → PR → logged review.

Spec authority stays with the owner. The agent proposes deltas; the owner ratifies. The agent never edits the contract it is held to.

## Artifacts

- `SPEC.md` — intention, the contract.
- `docs/plans/F<N>.md` — the build, per feature; hooks get defined here.
- `docs/chores/C<N>.md` — the plan for a chore, when it needs one. `C1`–`C5` were single lines in
  `SPEC.md` and needed no file; anything with tasks and a verification step gets one.
- `docs/reviews/F<N>.md` — adversarial review log, per feature.
- `docs/reviews/OPEN.md` — every outstanding item from every review, in one table. A *Still open*
  section inside one review is invisible from the next one.
- `docs/plans/00-deltas.md` — every proposed and ratified change to the contract.

### Directory names are lowercase, and plural unless the word has no plural

Added 2026-08-27, after `docs/Verbiage/` reached `main` as the only capitalised
directory in the repository.

**macOS is why nobody saw it.** The folder was made lowercase, git recorded it
capitalised, and a case-insensitive filesystem never disagreed — so it passed a
review that could not have caught it. A Linux or CI checkout treats
`docs/Verbiage` and `docs/verbiage` as two different paths, which costs an
afternoon exactly once.

**Plural, because these are categories of artifact:** `plans/`, `reviews/`,
`chores/`, `specs/`, `handoffs/`, `learnings/`, `crashes/`, `sounds/`.

**Two singulars are allowed, and both for the same reason** — the word has no
plural to use. `archive/` is a literal noun; `verbiage/` is a mass noun. Neither
is an exception to the rule so much as a case the rule does not reach.
- `CLAUDE.md` — how the agent moves between them. Lean; prune anything the agent wouldn't get wrong without it.

### Read the plan before you write it

A plan for every feature `F1`–`F7` was written at `F1` and committed in `cb2ba1b`. **A file existing
at the path you are about to write is the normal case, not the exception.** `docs/plans/F7.md` was
destroyed by a shell redirect onto a path nobody had opened; it is restored, and `H3` in `C6` closes
the hole. Read the target first — the answer may already be in it, ratified, months ago.

-----
August 21, 2026

#AI/Claude
