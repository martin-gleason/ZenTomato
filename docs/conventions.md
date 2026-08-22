# Conventions — pomo-v01

Standalone copy. This repo is its own source of truth; nothing is imported from a parent workspace.

## Structure (the only axis with IDs)

- **Feature** `F<N>` — a deliverable unit of user value. Decomposes into Tasks.
- **Task** `F<N>-T<M>` — an implementation step inside a feature.
- **Chore** `C<N>` — an operational task the human performs. The parallel track.
- **Retrofit** `F<N>b`, `F<N>c` — a second pass on an already-shipped feature.

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
- `docs/reviews/F<N>.md` — adversarial review log, per feature.
- `CLAUDE.md` — how the agent moves between them. Lean; prune anything the agent wouldn't get wrong without it.

-----
August 21, 2026

#AI/Claude
