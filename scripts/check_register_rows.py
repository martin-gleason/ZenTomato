#!/usr/bin/env python3
"""Refuse a register whose rows have stopped being well-formed.

WHAT HAPPENED, AND WHY THIS EXISTS. Three units in a row demonstrated the need,
each with a concrete failure, and none of them hypothetical.

  C33  Seven chore rows carried a stray 7th cell copied from another table's
       column. gen_status.parse_tables builds a row as
       {header[i]: cells[i] for i in range(min(len(header), len(cells)))}, so A
       SURPLUS CELL IS DROPPED WITH NO WARNING: `Why` parsed as the literal string
       "@chores", the real reasoning landed in `TD`, and the Todoist id was
       discarded. `make check-status` stayed green throughout.

  C33  Two rows carried an unescaped `|` inside backticks, which ends the row
       early in strict renderers.

  C36  C33 repaired ten rows and LEFT ONE BEHIND - and its own fix caused it.
       Correcting C15's status used rstrip(' |'), which stripped the trailing pipe
       AND the empty TD cell with it, leaving five fields against a six-column
       header. C33's commit message says "column-count audit: 0 malformed rows
       across all 7 sections" and THAT WAS TRUE WHEN IT RAN; the C15 edit came
       afterwards and nothing re-ran it.

So each rule below exists because something specific got through, and A CHECK
PERFORMED ONCE BY HAND IS A SNAPSHOT, NOT A GATE. That sentence is the whole
argument for this file.

WHY PYTHON RATHER THAN BASH. check-open-register.sh counts pipes with awk, which
cannot tell `\\|` from `|`, and this file uses escaped pipes legitimately. And this
must IMPORT from gen_status.py rather than restate it: a row the generator will
silently ignore must not be able to pass the file's own validator, and a section
the validator checks must be one the generator counts.

BUT IT COUNTS CELLS FROM THE RAW LINE ITSELF and deliberately does not reuse
parse_tables' dict comprehension - silently dropping the surplus cell is the exact
defect R1 exists to catch.

NO WARNINGS. EVERY FINDING IS AN ERROR. A warning printed inside a green CI step
is invisible, which is the "do not edit by hand" header with nothing behind it -
C28's whole lesson.

USAGE
    python3 scripts/check_register_rows.py     # exit 1 and list every finding
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from gen_status import (  # noqa: E402  - after the sys.path insert, deliberately
    BEGIN_MARKER,
    END_MARKER,
    OVERLAY_COLUMNS,
    OVERLAY_HEADING,
    ROW_ID,
    SECTION_SYMBOL,
    blank_fences,
    marker_lines,
    sort_key,
    table_cells,
)

ROOT = Path(__file__).resolve().parent.parent
REGISTER = ROOT / "docs/plans/00-register.md"
REL = "docs/plans/00-register.md"

# A cell boundary is an UNESCAPED pipe. `\|` inside a code span is a cell's
# contents, and awk cannot tell the two apart - which is why this is not bash.
#
# THE TOKENIZER IS IMPORTED, NOT RESTATED. This file defined its own copy until
# C34's own gates caught the consequence: gen_status split on a bare "|", this
# file on the escaped-pipe pattern, and a row containing `\|` therefore PASSED
# this validator while rendering shifted by one column on the page. Restating a
# rule is how two readers of one file come to disagree about it. What this file
# still does for itself is COUNT the cells and compare the count to the header
# (R1) - parse_tables' dict comprehension drops a surplus cell in silence, and
# that silence is the defect R1 exists to break.

# R5. The statuses a register row may carry.
#
# `unknown` IS NOT A MEMBER. gen_status maps an ABSENT status to the string
# `unknown` too, so the page cannot distinguish a row that says `unknown` from a
# row that says nothing - which is why R4 (empty cell) and R5 (bad value) are two
# rules and not one. C33's Chores preamble predicted that a check firing on an
# empty cell would fire on ZERO of the nine rows it was written for. It was right.
VOCABULARY = {"open", "closed", "held", "proposed", "ratified", "rejected",
              "resolved", "superseded", "struck", "abandoned", "done"}

# The nine legacy chore rows allowed to carry `unknown`, pending the owner's
# ruling. A SET OF IDS AND NOT A COUNT: a count of nine permits nine DIFFERENT
# rows to be swapped in. Each ruling deletes an id, so this set can only shrink.
UNKNOWN_LEGACY = {"C9", "C10", "C12", "C14", "C15", "C16", "C18", "C19", "C20"}

# The floor. conventions.md's harness contract requires one because "a shrinking
# suite is blind, not clean", and this repository already has
# test_licence_check_refuses_an_empty_read for the vacuous-read class.
#
# THE ROW COUNT IS DELIBERATELY NOT PINNED. 219 churns on every row added, and a
# check people edit to keep it quiet is not a check. What is pinned is that seven
# register sections exist and that none of them is empty.
MIN_SECTIONS = 7


cells_of = table_cells


def is_separator(cells: list[str]) -> bool:
    return bool(cells) and all(re.fullmatch(r":?-+:?", c) for c in cells)


def main() -> int:
    text = REGISTER.read_text(encoding="utf-8") if REGISTER.exists() else ""
    # FENCE-BLANKED, AND THE FUNCTION IS IMPORTED. The Mutations preamble embeds a
    # python snippet that splits register rows on a pipe, and a validator that reads
    # its own documentation as data is the parser that reported D15's fenced
    # `## Days` as a delta with no status. This file had its own copy of the loop
    # until C34's review: the copies had diverged in REACH - the generator did not
    # blank fences before looking for its markers - so the two readers disagreed
    # about a fenced example of the marker pair. One definition, two consumers.
    lines = blank_fences(text.splitlines())
    findings: list[tuple[int, str]] = []

    def report(lineno: int, message: str) -> None:
        findings.append((lineno, f"  {REL}:{lineno}: {message}"))

    # --- R9 · marker integrity ----------------------------------------------
    # No past failure. DEFENCE IN DEPTH for the mechanism C34 introduces, and
    # labelled as such rather than given a borrowed justification: the generator
    # refuses the same condition, so a lost marker already fails check-status.
    # This rule exists so `make check-register-rows` alone NAMES THE CAUSE
    # instead of handing the reader a diff.
    begins = marker_lines(lines, BEGIN_MARKER)
    ends = marker_lines(lines, END_MARKER)
    if len(begins) != 1 or len(ends) != 1 or (begins and ends and begins[0] > ends[0]):
        findings.append((0, f"  {REL}: {len(begins)} '{BEGIN_MARKER}' markers and "
                            f"{len(ends)} 'END' markers; expected one of each, BEGIN first"))

    # --- walk every markdown table ------------------------------------------
    heading = ""
    symbol = ""
    header: list[str] | None = None
    header_line = 0
    sections: dict[str, int] = {}
    seen_ids: dict[str, int] = {}
    previous: tuple[str, int] | None = None
    total_rows = 0

    for index, line in enumerate(lines):
        lineno = index + 1

        # A `###` ENDS A SECTION TOO, matching gen_status.parse_tables. The owner ruled
        # 2026-09-24 on `O48` that docs/conventions.md is contract: "one `##` per
        # register", so the owner-fields overlay is a `###` inside the `D` section. If
        # only `##` ended a section, the overlay's three-column rows would be checked
        # against the `D` table's five-column header and every one of them reported.
        # It carries no register symbol, so it is walked and never counted.
        if line.startswith("## ") or line.startswith("### "):
            heading = line[4:].strip() if line.startswith("### ") else line[3:].strip()
            m = SECTION_SYMBOL.search(heading)
            symbol = m.group(1) if m else ""
            if symbol:
                sections.setdefault(symbol, 0)
            header, seen_ids, previous = None, {}, None
            continue

        if not line.lstrip().startswith("|"):
            header = None       # a blank line or prose ends the table block
            continue

        cells = cells_of(line)
        if is_separator(cells):
            continue

        if header is None:
            header = [c.strip("* ").lower() for c in cells]
            header_line = lineno
            # --- R8 · header shape ------------------------------------------
            # parse_tables keys rows by the table's OWN header cells, so a
            # renamed or inserted column makes every lookup MISS and the page
            # renders `unknown` for the whole section under a confident label.
            # C28 chose that mapping deliberately so a miss could not map onto
            # the wrong field - but nothing detected the miss itself. D38
            # proposed the column name `Mutation`, which would have rendered
            # blank everywhere.
            #
            # R8 COVERS THE OVERLAY TOO, AND ITS NOT DOING SO WAS THE HOLE C34's
            # OWN REVIEW FOUND. `## Decisions — owner fields` carries no `(D)`
            # symbol ON PURPOSE, so it is not counted as a second D register - and
            # that same absence excluded the one hand-maintained table in the
            # repository from the one rule about column names. gen_status's
            # owner_overlay() refuses a missing column and writes nothing, so the
            # owner's `P` and Todoist link cannot actually be lost; what was
            # missing is R9's stated property, that `make check-register-rows`
            # ALONE names the cause. The columns come from gen_status.
            if symbol:
                if not header or header[0] != "id":
                    report(lineno, f"the `({symbol})` section's first column is "
                                   f"`{header[0] if header else ''}`, not `ID`")
                if "status" not in header:
                    report(lineno, f"the `({symbol})` section's header has no `Status` "
                                   f"column: {' | '.join(header)}")
            elif heading == OVERLAY_HEADING:
                missing = [c for c in OVERLAY_COLUMNS if c not in header]
                if missing:
                    report(lineno, f"`## {OVERLAY_HEADING}` has no "
                                   f"{', '.join('`' + c.upper() + '`' for c in missing)} column: "
                                   f"{' | '.join(header)}. gen_status.owner_overlay reads this "
                                   f"table by column name, so a renamed column is the owner's "
                                   f"priority and Todoist link asking to be dropped; the header "
                                   f"is {' | '.join(c.upper() for c in OVERLAY_COLUMNS)}")
            continue

        # --- R1 · cell count --------------------------------------------------
        if len(cells) != len(header):
            report(lineno, f"{len(cells)} cells where the section header has "
                           f"{len(header)} (header at line {header_line})")

        # --- R2 · code spans close inside their cell --------------------------
        # Such a row usually has too FEW cells and trips R1 as well - but if a
        # second defect in the same row restores the count, R1 sees nothing. This
        # catches the mechanism rather than its arithmetic consequence.
        for position, cell in enumerate(cells, start=1):
            if cell.count("`") % 2:
                report(lineno, f"cell {position} has an odd number of backticks, so a "
                               f"`code` span does not close inside it — the usual cause is "
                               f"an unescaped pipe inside a `code` span; write it \\|: "
                               f"{cell[:60]}")

        row_id = cells[0] if cells else ""

        # --- R3 · no duplicate ID within a section ----------------------------
        if row_id in seen_ids:
            report(lineno, f"{row_id} appears twice in `## {heading}` — also at line "
                           f"{seen_ids[row_id]}; conventions.md Axis 2: every ID appears "
                           f"exactly once")
        elif row_id:
            seen_ids[row_id] = lineno

        if not symbol:
            continue

        sections[symbol] = sections.get(symbol, 0) + 1
        total_rows += 1

        # --- R7 · every ID is a row id the generator will count ----------------
        # The bare-only filter rejected all 81 scoped mutation ids WITHOUT A WORD,
        # and would have reported 22 rows against 103 on a page CI keeps current.
        # This turns the generator's silent drop into a named refusal.
        if not ROW_ID.fullmatch(row_id):
            report(lineno, f"`{row_id}` is not a register row id gen_status.ROW_ID "
                           f"recognises, so the generator would drop this row in silence")

        # --- R4 and R5 · status -----------------------------------------------
        status = cells[header.index("status")].strip() if "status" in header \
            and header.index("status") < len(cells) else ""
        if not status:
            report(lineno, f"{row_id or 'this row'} has an empty `Status` cell; "
                           f"conventions.md Axis 2: a register row without one is invalid, "
                           f"not \"probably open\"")
        elif status.lower() == "unknown":
            if row_id not in UNKNOWN_LEGACY:
                report(lineno, f"{row_id} carries `unknown`, which is not in the pinned "
                               f"vocabulary. It is allowed only for the legacy rows "
                               f"{', '.join(sorted(UNKNOWN_LEGACY, key=sort_key))}, pending "
                               f"the owner's ruling")
        elif status.lower() not in VOCABULARY:
            report(lineno, f"{row_id} carries `{status}`, which is not in the pinned "
                           f"vocabulary {{{', '.join(sorted(VOCABULARY))}}}")

        # --- R6 · sorted by ID -------------------------------------------------
        # An ERROR and not a warning: a warning inside a green CI step is
        # invisible, and the fix is mechanical and local. The key is imported
        # from gen_status so the page's order and this rule are ONE definition.
        if previous and sort_key(previous[0]) > sort_key(row_id):
            report(lineno, f"{previous[0]} then {row_id} is out of ID order in "
                           f"`## {heading}` — conventions.md Axis 2: allocating the next "
                           f"number must not require scanning forty unsorted rows")
        previous = (row_id, lineno)

    # --- the floor ------------------------------------------------------------
    empty = sorted(sym for sym, count in sections.items() if not count)
    if len(sections) < MIN_SECTIONS or empty:
        detail = f"found {len(sections)} register sections"
        if empty:
            detail += f", and these have no rows: {', '.join(empty)}"
        findings.append((0, f"  {REL}: the parser read nothing — {detail}, "
                            f"expected at least {MIN_SECTIONS} sections each with rows"))

    if findings:
        for _, message in sorted(findings, key=lambda f: f[0]):
            print(message)
        print()
        print("check_register_rows.py: FAIL — a row in the register is malformed.")
        print()
        print("  A surplus cell is DROPPED IN SILENCE by scripts/gen_status.py, which builds a")
        print("  row as {header[i]: cells[i] for i in range(min(len(header), len(cells)))}. That")
        print("  is how C33 turned seven chore rows' `Why` into the literal string \"@chores\" and")
        print("  discarded seven Todoist ids while `make check-status` stayed green. A row one")
        print("  cell SHORT ends the table at that row in strict renderers, which is how six")
        print("  items vanished from the owner's reader. A status outside the pinned vocabulary")
        print("  is counted as open or as unknown by a page that cannot tell the two apart.")
        print()
        # THE REMEDY LINE IS ITSELF AN OUTPUT, AND IT WAS WRONG FOR ONE REGION.
        # conventions.md's validate-every-artefact rule counts anything a human is
        # told to run, and "run the generator" is false advice for a row BETWEEN
        # THE MARKERS: that region is written from docs/plans/00-deltas.md, so a
        # hand fix there is reverted by the very command the footer prints. Found
        # by making a delta title carry an odd backtick, which R2 caught on a
        # generated line. The condition is computed from the markers this run
        # actually found rather than assumed.
        if len(begins) == 1 and len(ends) == 1 and begins[0] < ends[0] and any(
                begins[0] + 1 < lineno < ends[0] + 1 for lineno, _ in findings):
            print("  A FINDING ABOVE IS INSIDE THE GENERATED REGION (lines "
                  f"{begins[0] + 2}–{ends[0]}). Editing it there is reverted by the next")
            print("  generator run: its source is the delta's own heading in "
                  "docs/plans/00-deltas.md,")
            print("  which is a ratified surface — so the fix is the owner's, not a "
                  "hand edit here.")
            print()
        print("  Fix the rows above. Then run: python3 scripts/gen_status.py && make check-status")
        return 1

    print(f"check_register_rows.py: OK — {total_rows} rows across {len(sections)} "
          f"register sections, 0 malformed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
