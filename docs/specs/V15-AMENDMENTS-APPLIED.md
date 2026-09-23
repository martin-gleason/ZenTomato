# Amendments applied to `docs/specs/zenpom-v1.5.md`

**This file is not part of the baseline.** `docs/specs/zenpom-v1.5.md` is ratified, and the agent
never edits a ratified baseline — `C31` needed `D40`, ratified by the owner, before one character of
it could change. `SPEC.md` carries its own `## Amendments applied` list because the **owner** edits
`SPEC.md`. v1.5's ledger therefore lives beside the spec rather than inside it: an instrument
*about* the baseline, in the same relationship `docs/specs/AMENDMENT-BASELINE.txt` already has to
`SPEC.md`. Created by `C32` under `D41`.

Whether this list should one day move inside `zenpom-v1.5.md` is an **open question for the owner**,
recorded in `docs/chores/C32.md`. It would be an edit to a ratified baseline and would need a `D<n>`
of its own.

`docs/specs/V15-AMENDMENT-BASELINE.txt` counts what is still outstanding, and
`DeltaIntegrityTests.everyRatifiedV15AmendmentIsApplied` fails if that number grows.

**What listing an id here does.** The detector self-closes for most deltas: once the amendment is
applied, the text the delta says the spec *currently* says is gone, the fragment stops matching, and
the delta stops being counted with no list to maintain. This list exists for the case that does not
self-close — where an applied amendment still matches on an incidental fragment. `D31` is exactly
that case today, so the outstanding count **does** currently depend on this list. Do not read this
file as decorative.

## Amendments applied

D31 D33

## The evidence, one line each

- **`D31`** — `C22` is struck. `docs/specs/zenpom-v1.5.md:62` reads *"Thirteen units — twelve
  features and one chore (`D31` struck the second)"*, and the earned-entry section carries
  *"`C22` · **STRUCK by `D31`, ratified 2026-09-09.**"*. `D31`'s own quoted text, *"which licence the
  binaries carry"*, no longer occurs in the spec. It still matches the detector on the incidental
  backticked path `docs/plans/parked.md`, which is why it is listed here rather than left to
  self-close.

- **`D33`** — applied by `C31` under `D40`, on 2026-09-22, thirteen days after ratification. The
  order table at `docs/specs/zenpom-v1.5.md` carries `F18` and both halves of `F19`, and the spec
  states *"Fourteen positions over thirteen units"*.

  **`D33` IS HERE BECAUSE A PERSON PUT IT HERE, AND THAT IS WHAT `O46` IS ABOUT.** The detector never
  counted `D33` and still does not. `C32`'s review found two reasons and fixed one: `D33` declares no
  document inside its `Currently` block, so it was judged against `SPEC.md` — the wrong baseline —
  until the declaration rule learned to read a delta's **preamble**, where `D33` writes *"Owed because
  `docs/specs/zenpom-v1.5.md` is a ratified baseline"*. The second reason is not fixable by verbatim
  matching: `D33` amends an order **table** and quotes it as a comma list of ids, every one of them
  under the twelve-character fragment floor, so there is no verbatim overlap to find. Reconstructed
  against the pre-`C31` tree and run, the finished detector's answer to *"would this have gone red for
  `D33`?"* is **False**. `docs/specs/V15-AMENDMENT-BASELINE.txt` records the measurement and `O46`
  holds it open. **So this list is not a formality for `D33` — it is the only record there is**, and
  the next applied v1.5 amendment goes here.
