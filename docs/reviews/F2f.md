# F2f — Adversarial review log

> **Outstanding items from this review are tracked in [`docs/reviews/OPEN.md`](OPEN.md)**, with
> every other review's, so that an item left open here is visible from the next feature.

**Reviewed:** 2026-09-30 · **Feature:** F2f The Island tomato · **Branch:** `F2f/the-island-tomato`
(PR 59, **already merged** 2026-09-29 by rebase) · **Scope of the read:** the branch against `main`,
weighted to the four commits that built the tomato and the Lock Screen fix.

## Process

One adversarial reviewer ran at session start, per `CLAUDE.md` step 3 — *"Never resume blind."* It
did not know the branch had merged; its *do not merge* verdict is therefore recorded as a list of
post-merge follow-ups rather than a block. It ran `make test`, `make lint` and `make checks` itself,
and applied two mutations in a scratch copy of the tree, never in the repository.

## Evidence it gathered

- `make test`: **695 tests in 104 suites passed**.
- `make lint`: `swiftlint 0.65.1 --strict`, no violations. `make checks`: every gate OK.
- **Fill mutation — caught.** `completedInSprint` → `completedInSprint + 1` in
  `FocusAlarmMetadata.swift`; `theFillIsFinishedOverTotal` failed on four cases.
- **Break-path mutation (`F2f-M3`) — NOT caught.** `if kind == .work` → `if kind != .longBreak` in
  `BlockLiveActivity.swift`, so a short break drew a tomato. The suite stayed green.

## Findings

| # | Severity | Finding | Now |
|---|---|---|---|
| 1 | major | Nothing tests that a break keeps the cup; `F2f-M3` survives | `A26`, open |
| 2 | major | `F2f.md` still describes `D55`'s fill; its mutations target code that no longer exists | `A27`, open |
| 3 | major | Rulings B, C and the theme question were built without an answer — the minimal Island draws the filling tomato, and its colours ignore the theme | **Theme: answered by the owner 2026-09-30** — *"Tomato colors shouldn't ignore themes"* — and built in `F12` (`D58`). **Ruling B: the owner will judge it on the device** — *"I'll double check what the items show on the next test."* |
| 4 | major | `A25`'s commit says *verified on the device* with no build number | `A25`, open — the owner will retest with a screenshot of the build number |
| 5 | major | `.fixedSize()` may move the squeeze from the count to the countdown (reasoned, not run) | `A28`, open, device |
| 6 | minor | The minimal presentation's spoken label is likely hidden with the glyph (reasoned, not run) | `A29`, open, device |
| 7 | minor | The glyph has no fixed size and may squeeze the FOCUS kicker in the expanded Island | device round |
| 8 | minor | A comment in `BlockLiveActivity.swift` still described the `T1` spike | **fixed in `F12`**, which rewrote that comment while threading the theme through the same lines |
| 9 | minor | `TomatoFillTests.swift` names `BlockReadout` where it means `FocusAlarmMetadata` | open, one line |
| 10 | minor | `TomatoGlyph`'s unused `.solid` style prepares for `F16`, in the wrong colours for the garden | open, for `F16`'s gate |
| 11 | minor | The WidgetKit animation quote is secondary-sourced and not marked so in the code | open |
| 12 | minor | The tomato is never shown full: focus block N shows N−1 finished, and breaks show the cup | consistent with `D52`; for the owner's eye on the device |
| 13 | minor | Eleven commits on the branch — nineteen on `main` — put register IDs in commit scopes, which Axis 2 forbids | **merged; rebase-and-merge made them permanent.** For the owner: enforce the rule with a hook, or rule on it |
| 14 | minor | The branch carried more than `F2f` — `F8-T4/T5`, `D49`, `D51`, an `F6` fix and `F20`'s plan | merged; recorded |
| 15 | minor | No `## Harness` section and no test-count floor in `conventions-local.md` | open, project-wide |

## For the next device round

The review asks that the owner's next run also cover: the countdown beside the count at the largest
text size (`A28`); the minimal Island with VoiceOver on (`A29`); whether the fill animates at a block
boundary; the expanded Island's layout (finding 7); and — from `F12` — each theme's tomato.
