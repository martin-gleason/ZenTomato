# F6b — the polish and performance pass

**Gate plan. Nothing built. Awaiting your yes.**
**Retrofit**, not a feature: `conventions.md` defines `F<N>b` as a second pass on an
already-shipped feature, and F6 merged in PR #8. It adds no unit of user value; it repairs
and measures units that exist.

**Two companions, planned here because they are one sitting's work between them:**
`F4b` (one item) and `F3c` (one item). Named separately because they belong to different
features and a retrofit that spans features belongs to none of them.

## Where the work came from

Every item is already written down. Three adversarial reviews and four device sessions
produced fourteen agent-side findings in `docs/reviews/OPEN.md`, and **eleven of them are
F6** — unsurprising, since F6 was the feature whose reviewers had the most to read.

Nothing here is new scope. If an item is not in that register, it does not belong in this
pass.

## The one that is not cosmetic

**A1 — `try?` on the three `StatsQuery` fetches.** A refused database read currently renders
as a confident *"Nothing on Fri 21 Aug"* on screen, and as `No pomodoros in this range.` in a
document filed in a paper notebook as truth.

That is the only item here that makes the app **state something false**. Everything else is
untidiness, a weak test, or a cost nobody has measured. It goes first, and if the pass is cut
short it is the one that must land.

The app already has the right pattern, from F4: `exportUnavailable = "The export couldn't be
prepared. Your history is fine."` — a failed read is reported as a failed read, and the
sentence reassures about the data rather than the feature.

## Tasks

### F6b-T1 — A refused read stops lying *(A1)*

`period(_:)` reports that it could not read, and the screen and the export each say so in
one quiet line, distinct from "nothing recorded". Three fetches, one new case, and the two
call sites already have somewhere to put it.

### F6b-T2 — Measure before optimising *(A3, A9, and the honest half of "performance")*

**This project's rule is that assertions are not evidence, and it applies to speed.** The
only performance numbers anyone has are `period(fortnight)` at 3.1 ms over 1,044 blocks and
`period(.day(today))` at 0.83 ms. Everything else is assumed.

Measure, on the device and with a realistic store, and write the numbers into the PR:

- `refreshExport()` — the whole document built and the temp directory swept, **synchronously
  on the main actor, on every range change**, whether or not anyone taps Export. A DatePicker
  drag fires it repeatedly. *(A3)*
- The Todoist refresh over a real account, paginated.
- The music library load, which the owner reported as slow during F4 and which
  `MusicLibraryCache` was built to answer — never measured since.
- Watch state delivery, now that the wrist has a fixed 2-second defect behind it.

**Then optimise only what the numbers indict.** A3 is the strong candidate and the fix is
known — render off the main actor, and lazily rather than eagerly — but it gets done because
a number says so, not because it reads badly.

**A9 belongs here**: the performance test asserts `< 1 second` against a 16 ms budget, so a
sixty-fold regression passes green. A bound that cannot fail is the same defect as a test
that cannot fail, and this repository has found three of those already.

### F6b-T3 — The tests that cannot fail *(A2, A11)*

`noIdentifiersInOutput` asserts against a fixture containing no identifiers, so four of its
five assertions are tautologies. Build the document from `StatsStoreFixture` through
`StatsQuery`, whose rows carry real ids.

The no-writes fence forbids `create`, `move`, `reopen` and `POST /tasks` but not `update` or
`comment` — two of the four words `CLAUDE.md` names. The real gate is untouched, so nothing
is exposed; the test's comment simply claims more than it checks.

### F6b-T4 — Comments that are wrong, and code with no caller *(A5, A6, A13)*

`StatsRange.swift:35` says *"no free-form date pickers"* about a control whose own header
says *"Two pickers and a reset."* **A comment asserting the inverse of the code is a defect
in a codebase reviewed by reading**, and this one has already misled once.

`StatsRange.everything(endingOn:in:)` and `StatsPeriod.recordedSpan` have no caller outside
tests and document an all-time export the range control does not offer. Delete them, or ship
the control — and deleting is the honest default.

`docs/reviews/F6.md` still does not follow the F1–F5 template. It was left open in C6
deliberately, because restructuring it means replacing most of a document and `H3` refuses
that without a declaration. Doing it inside a pass that is already touching F6 is the right
moment.

### F6b-T5 — The export's remaining sharp edges *(A4, A7, A8)*

- The temp sweep deletes **every** `ZenTomato-*.md` on each write, including one an open
  share extension may still be reading. Write into a per-launch subdirectory.
- Markdown metacharacters in Todoist titles are not escaped: a task named `**Thesis**`
  renders as markup on the page. Only affects the Rhodia read, which is the whole point of
  the feature.
- A device that changes time zone re-attributes historical days, so two exports of the same
  fortnight disagree. Correct across DST already — every boundary goes through `Calendar` —
  but the time-zone case is unspecified and untested. **Decide the rule, write it down, pin
  it with a test.** This one may want your ruling rather than mine: it is a question about
  what a fortnight *means* when you have moved.

### F6b-T6 — Close the guard's hole *(A10)*

The palette lint rule's `included` regex covers `App|Views|Models|Timer|Alarm|Shared` and not
`Stats/`, `Export/`, `Sprint/` — nor, now, `ZenTomatoWatch/`. Nothing violates it today.
A guard with a hole is one that will one day be believed when it should not be.

### F4b — `MusicSubscription.current` is deprecated in process *(A15)*

Apple's own warning, in every device log: the supported path fetches in `itunescloudd` and
needs a sandbox exception. Works today. **It is a companion to `O14`** — the app has no
MusicKit entitlement at all while it is signed with the team wildcard, so this and that
should be verified in one sitting.

### F3c — `.alreadyGone` leaves a task offerable *(A12)*

A task finished on another device enters neither D21b's set nor a cache deletion, so it is
still offered until the next refresh. **Pre-existing and deliberately not fixed during F6**:
widening D21b's trigger would change its meaning from *completed* to *believed gone*, which
is a different rule and wants stating as one.

## What this pass will not do

- **No new features.** Nothing that is not already in `docs/reviews/OPEN.md`.
- **No spec deltas.** If an item turns out to need one, it stops and is written up. A8 is the
  likeliest candidate.
- **A14 stays a watch item.** The rewind was reported once, never reproduced, and
  `docs/reviews/F4.md` already carries the diagnostic order and four ranked fixes. Chasing an
  unreproduced fault is how a polish pass becomes a fortnight.

## Sequencing, and the thing that governs it

**F7 must merge first.** It is code-complete and unmerged, its branch carries the watch work,
and F6b touches `Stats/` and `Export/` which F7 does not — so doing them in the wrong order
buys a rebase for nothing. F6b branches off `main` once F7 lands.

**Twenty days to 13 September.** In priority order if the pass is cut short: T1 (the app
stops stating something false), then T2's measurements (because unmeasured performance work
is guesswork), then T3 (tests that cannot fail have already let three real defects through
here). T4 through T6 are genuine but survivable.

## Verification

`make ci` green. Every optimisation in T2 accompanied by a before-and-after number in the PR.
No device check of its own — this pass changes nothing a device test would exercise that the
outstanding owner items do not already cover.
