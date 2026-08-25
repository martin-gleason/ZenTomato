# F4e — search in the music picker

**Retrofit on F4.** Depends on **D23**, ratified by the owner on 2026-08-25 as written: search is F4
meeting a requirement the contract already states, so `SPEC.md` is unchanged and
no amendment is owed.

## The problem, in the owner's words

> The app is built to play playlists for concentration. If it takes multiple
> seconds to find a track, we're likely to get distracted. A search bar for music
> is a bare minimum here, which is the point of the limited feature set for v1.

The failure is not that the list is long. It is **when** the list is long: the
picker is opened in the seconds before a focus block starts, which is the worst
possible moment to lose two minutes. This app manufacturing a distraction
immediately before the block it is protecting is the same shape as `F7`'s watch
latency, which inflated the very log it existed to keep.

## What was found on the way in, and it matters more than the feature

`MusicPickerScreenModel`'s doc comment stated, in bold:

> **THERE IS NO SEARCH FIELD ON THIS SHEET.** The design sketched one, and the
> ratified scope fence forbids it by name — a text field of any kind in this
> feature is a finding.

**That was false when it was written.** `F4-contract.md` §7 says the opposite:

> Page it, and if paging turns out to need a search field, that field must offer
> nothing when it finds nothing — `NoCaptureSurfaceTests` already covers the idiom
> and the same test must cover this picker.

The search field was **pre-authorised at the F4 gate**, conditionally. Paging did
turn out not to be enough — the owner scrolled a real library for over two
minutes — so the condition was met and the permission was live the whole time.

Two things follow. First, `D23` is smaller than it looked: it records a decision
the contract had already provided for. Second, and worth more: **a confident
sentence in a code comment is not a ratified decision.** That one asserted a fence
that did not exist, and it would have ended this investigation before it started
if the contract had not been read. The false paragraph is quoted in the corrected
comment rather than deleted, for the same reason `C8.md` keeps its wrong claim
visible.

The condition is now discharged: `MusicNoCaptureTests` covers this picker with the
same two mechanisms — by shape and by vocabulary — that `NoCaptureSurfaceTests`
applies to the Todoist one.

## Why this is small

The picker **already holds the entire library in memory**. `MusicPickerScreenModel`
builds `playlistRows` and `songRows` up front, and `page(_:shown:)` reveals them
into the list as the last drawn row appears. That paging is exactly why the scroll
never ended.

So search is a filter over rows that are already there:

- **no MusicKit request**, no network, no new permission
- **no model, no cache, no persistence** — the query is view state and dies with
  the sheet
- **no new token, role, or type**

`D23` fixes the boundary: **the catalogue is never searched, only the library.**

## Tasks

**F4e-T1 — filter the rows.** A `matches(_:)` on `MusicPickerScreenModel.Row`,
case- and diacritic-insensitive, matching anywhere in the name rather than only at
the start — people remember a word from the middle of *"Late Night Piano Studio"*.
Pure function, tested directly.

**F4e-T2 — the field.** `.searchable` on the list. Both sections filter; a section
with no matches disappears rather than showing an empty header.

**F4e-T3 — nothing found.** One line saying so, naming what was typed. Never an
error state: an empty result is a normal answer.

**F4e-T4 — paging interacts correctly with filtering.** The live defect risk. The
reveal counters (`shownPlaylists`, `shownSongs`) are *counts*, so a filter that
narrows 400 rows to 3 must not leave the list believing it has already revealed
120. Counters reset when the query changes.

**F4e-T5 — the selected item stays visible.** If something is chosen and the query
excludes it, the tick must not silently vanish from a list that still claims to be
the picker. Decide and pin: the chosen row is exempt from the filter.

## One thing the plan did not anticipate

Both pickers needed the same matching rule, and the Todoist one already had it as
a `private extension` inside `PickerScreenModel.swift`. Writing it a second time
is precisely the defect `F4c` was opened to fix — two copies pass every test on
the day they are written and drift on the third edit, and then a playlist with an
accent is findable while a task with the same accent is not.

It moved to `SearchMatching.swift` and both pickers call it.

## Tests

- `matches(_:)` directly: middle-of-name, case, diacritics, empty query returns
  everything, whitespace-only query returns everything
- filtering a fixture library of 400 playlists to a known 3
- **the paging fence** (T4): after a query narrows the list, the reveal count is
  back to one page — mutation-verified by removing the reset
- **the fence that matters:** no `MusicLibraryRequest`, no `MusicCatalog*` type,
  and no new `@Model` anywhere in the diff. `D23` says the catalogue is never
  searched; a test says it too, because "we decided not to" is not enforcement
- `PolishFence` unchanged: no new token, model, protocol, or `AppSettings` field

## Verification

```
check-lint.sh: swiftlint 0.65.1 --strict
check-lint.sh: OK — no lint violations.
run-script-tests.sh: 9 passed, 0 failed
✔ Test run with 483 tests in 72 suites passed after 3.654 seconds.
```

470 before, 483 after. Four mutations, each caught and restored:

| Mutation | Test that caught it |
|---|---|
| M16 · An empty query returns nothing instead of the whole library | `anEmptyQueryGivesTheLibraryBack` |
| M17 · The paging reset removed from the view | `theViewResetsThePagingWhenTheQueryChanges` |
| M18 · Matching narrowed to prefix-only | `ignoresCapitalsAndAccents` |
| M19 · The empty state becomes a `ContentUnavailableView` — a slot for an action | `theEmptyStateHasNoSlotForAnAction` |

## Done when

A library of a few hundred playlists yields the right one in **one gesture and a
few keystrokes**, on the device, with the timer screen behind it — measured
against the owner's own library, not a fixture.

## Not in this

**Searching the Apple Music catalogue.** Out of scope by `SPEC.md` line 25 — *"an
existing playlist or song from their library"* — and explicitly excluded by `D23`.

**Recently-played, favourites, or any ordering that remembers.** That is state
this app would have to keep, and `D16` says no.
