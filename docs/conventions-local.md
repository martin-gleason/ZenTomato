# Conventions — ZenTomato, local

Rules true of **this project only**. The inherited baseline is the pinned copy in
`docs/conventions.md`, which is never edited (`D24`).

ZenTomato predates the canonical document layout and keeps its own. That is recorded
here rather than corrected, because the project is thirteen days from a hard stop and
its paths are cited across plans, reviews and source comments.

---

## Artifacts

- `SPEC.md` — intention, the contract.
- `docs/plans/F<N>.md` — the build, per feature; hooks get defined here.
- `docs/chores/C<N>.md` — the plan for a chore, when it needs one. `C1`–`C5` were single lines in
  `SPEC.md` and needed no file; anything with tasks and a verification step gets one.
- `docs/reviews/F<N>.md` — adversarial review log, per feature.
- `docs/reviews/OPEN.md` — every outstanding item from every review, in one table. A *Still open*
  section inside one review is invisible from the next one.
- `docs/plans/00-deltas.md` — every proposed and ratified change to the contract.

## Learning dial

| Level | Human | Agent |
|---|---|---|
| **5% (floor)** — *this project* | Review every PR, log it | Authors everything |
| 10% | + occasional small pieces | Authors; "why" notes in PRs |
| 20% | Authors 🎓 features, coached | Stubs 🎓, tutors, authors the rest |
| 50% | Authors the core | Scaffolds, reviews, tutors |

🎓 on a feature overrides the dial (human builds it, coached). A deadline or language veto in the planning prompt overrides 🎓. Not used in v0.1.
