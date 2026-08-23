# CLAUDE.md — pomo-v01

iOS Pomodoro timer. Todoist is the task store; Apple Music is the audio; the distraction log is the point. Spec: `docs/specs/SPEC.md` (the contract). Plans: `docs/plans/F<N>.md`, one per feature, written at the gate.

@docs/conventions.md

## Non-negotiable

- **Scope is `SPEC.md` F1–F6 and nothing else.** Anything not listed there is Phase 2. Do not build it, stub it, or "prepare for it." If it seems necessary, write `Proposed spec delta:` in the plan summary and stop.
- **Todoist is the only task hierarchy.** No local projects, tags, or task models beyond a cache of Todoist's. The only write to Todoist is *complete task*. Never call create, update, or comment endpoints.
- **No capture surface.** The app never accepts a new task from the user. This is a standing rule from the owner's productivity system, not a feature gap.
- **Secrets never enter the tree.** Build settings use Xcode's own mechanism: `Config/App.xcconfig` is committed and holds safe defaults, ending in `#include? "Secrets.xcconfig"`. `Config/Secrets.xcconfig` is git-ignored and is the only file holding a real value; `Config/Secrets.example.xcconfig` is its committed, empty template. The user's Todoist token lives in Keychain. (Delta D6b; D6 was rejected.)
- **Local only.** SwiftData on device. No network calls except Todoist and MusicKit. No analytics.
- **Hard stop September 13, 2026.** Unmerged work is abandoned cleanly, not rushed.

## Stack

Swift 6, SwiftUI, SwiftData, MusicKit, URLSession, async/await. Minimum iOS 26.0; watchOS 26.0 if F7 lands. (Delta D1; C2 is answered.) SwiftLint. GitHub Actions on a macOS runner. No third-party dependencies without a spec delta.

## Learning level: 5% (floor)

The agent authors everything. The owner reviews every PR and does not write Swift. Therefore **every PR description is written for a reviewer who can read code but not Swift**: what changed, why, what to test on the device, what could break. No 🎓 features in v0.1.

## Workflow

1. **Gate → plan.** Before any feature: Ultrathink. Re-read `SPEC.md`, batch clarifying questions, paraphrase the feature back, write `docs/plans/F<N>.md`. Flag `Deep spec required:` if the gate is decision-dense. Wait for the owner's yes.
2. **Build.** ultracode unless the plan says otherwise. One feature branch `F<N>/<slug>`. Small commits, conventional-commit format, feature ID in scope.
3. **Adversarial review — mandatory.** Fire `.claude/agents/adversarial-reviewer.md` at the end of every feature and at the start of every session. Never resume blind: open with a review of what shipped and a re-read of the outstanding list in `SPEC.md`.
4. **Verify with evidence.** A feature is done when a command returns pass and the output is in the PR: `xcodebuild test`, `swiftlint`, and the device check the spec names. Assertions are not evidence.
5. **PR.** Open it, link the plan, log the review result in `docs/reviews/F<N>.md`. Rebase-and-merge only.

## Hooks (deterministic; prose is advisory)

| Hook | Surface | Protects |
|---|---|---|
| `swiftlint --strict` | pre-commit + CI | Lint gate |
| `xcodebuild test` | CI | Test gate |
| grep for Todoist create/update/comment paths → fail | pre-commit + CI | No-capture rule |
| secret scan (gitleaks) | pre-commit + CI | Secrets rule |
| Branch protection: PR + CI + rebase-merge | GitHub settings | Merge discipline |

Hook code is built under F1 and follows the gate model like any other code.

-----
August 21, 2026

#AI/Claude
