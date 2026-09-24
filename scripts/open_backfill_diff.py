#!/usr/bin/env python3
"""Row-by-row diff of docs/reviews/OPEN.md against the hand-maintained file.

C37 made OPEN.md generated. The risk it carries is the one C29 already paid for:
a backfill that drops rows, or clips their text, while every gate stays green.
So the generation publishes this, and the rule it enforces is stated as a
failure and not as a hope:

    ANY ROW PRESENT BEFORE AND ABSENT AFTER IS A BACKFILL DEFECT.

FOUR VERSIONS OF THIS CHECK HAVE LIED, EACH IN A DIFFERENT DIRECTION, AND THE
FOURTH PASSED ITS OWN REVIEW. They are recorded because the failure mode is this
project's most expensive one - an instrument that agrees with whatever it is
asked - and because every fix below was bought with a trigger that ran:

  id-level          called three lost rows zero. Ids are not rows: OPEN.md
                    carried two O23s, two O24s and two O25s.
  shingled per row  called a moved cell boundary a loss. The `CLOSED ...` clause
                    left the title cell, so every phrase spanning the seam went
                    missing - 4 rows, then 39 as the window grew.
  shingled per cell reported 16. The seam is INSIDE one before-cell, and no
                    per-cell window sees across a split the generator made.
  aligned, RUN=8,   reported zero while: the `From` column could be emptied on
  id allowlist      all 67 rows (1-4 words, always under the window); any 7-word
                    loss passed; a whole row could be deleted and matched
                    against a wrong counterpart; and four ids were allowlisted
                    BY ID, so `O46` could be deleted and the gate stayed green.

What it does now, and why each part is load-bearing:

1. EVERY BEFORE ROW IS PAIRED WITH ONE AFTER ROW, by id where the id survives
   and by best title match otherwise. An unpaired before row is a defect on its
   own, with no text comparison involved - that is what makes a deleted row
   impossible to hide behind a similar neighbour.
2. RUN = 3. Eight words is longer than most cells in the table. The `From`
   column is one to four words, and the whole claim of `C37` is that `From` came
   across.
3. THE ALLOWLIST HOLDS EXACT LOST RUNS, NOT IDS. A hand ruling is about wording
   on one day; encoding it as an id makes that row permanently undeletable. A
   run that no longer matches is a defect again, and a row that disappears is
   caught by 1 regardless of what it is allowed to reword.

What it still does not do, stated because a check whose limits are not written
down gets read as covering more than it does: it protects rows present in the
pinned file. Rows added after that file - `O36` onward - are the register's to
guard, and `scripts/check_register_rows.py` is what guards them.

Usage: scripts/open_backfill_diff.py [<rev-of-OPEN.md-before>]
Exit 1 if any row is unaccounted for.
"""
from __future__ import annotations

import difflib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OPEN = ROOT / "docs/reviews/OPEN.md"

# 62fce7c, not 66232e8^. The parent of C37's first commit exists only on this
# branch, and this project merges by rebase, so the sha it named would be
# rewritten and the gate would be permanently red on a fresh clone of main -
# exit 2, `cannot read OPEN.md at 66232e8^`. 62fce7c is the same tree for this
# file and is already on main.
DEFAULT_REV = "62fce7c"

RUN = 3          # an unaligned run this long is content, not a reflow
PAIR_FLOOR = 0.45  # below this, no after row is this row's counterpart at all

# Lost runs ruled BY HAND as paraphrase, keyed by the id that carries them. Each
# string is the exact run the alignment reports; change the wording and the run
# stops matching and the gate goes red again, which is the point. The ruling for
# each is in docs/chores/C37.md.
REWORDED: dict[str, tuple[str, ...]] = {
    "O48": (
        "from 00 deltas md per",
        "no register is counted twice",
        "and d37 said nothing about it second half c34 added ratified and resolved to",
        "raised by c34 s adversarial review as the agent s to propose and the owner s to ratify",
    ),
    "O47": ("in this app",),
    "O46": (
        "half the cause was a defect and is",
        "and d33 resolves to",
        "the other half is",
    ),
    "O3": ("spec md describes that run has now happened and it closes f4 s done when",),
    "O4": ("in the register 00 register md already carried it closed and this file never "
           "got the strikethrough which is exactly the second intake path failure docs "
           "conventions md warns about one caveat kept rather than smoothed over",),
    "O5": ("same staleness as",),
}


def rows(text: str) -> list[list[str]]:
    out = []
    for line in text.split("\n"):
        s = line.strip()
        if not s.startswith("|") or re.match(r"^\|[\s:|-]+\|$", s):
            continue
        cells = [c.strip() for c in re.split(r"(?<!\\)\|", s.strip("|"))]
        if cells and cells[0].lower() in ("#", "id"):
            continue
        out.append(cells)
    return out


def words(s: str) -> list[str]:
    return re.findall(r"[a-z0-9]+", s.lower())


def bare_id(cell: str) -> str:
    return cell.replace("~", "").strip()


def pair(before: list[list[str]], after: list[list[str]]) -> list[list[str] | None]:
    """One after row per before row: best text match, with a thumb on the id.

    NOT "the first row with the same id", which crossed the two `O23`s - the
    struck bell row claimed the progress-bar row's id and the progress-bar row
    was then reported GONE. A shared id is evidence and not an answer, because
    the ids in the before-file collide; the text decides, and the id breaks ties.

    An after row is claimed at most once. Without that, two before rows both
    match the closest neighbour and the second one's disappearance is reported as
    a rewording of the first.
    """
    ID_BONUS = 0.15
    taken: set[int] = set()
    out: list[list[str] | None] = []
    # Longest rows first: they discriminate best, and a short row left to choose
    # from what remains cannot steal a long row's counterpart.
    order = sorted(range(len(before)), key=lambda i: -len(" ".join(before[i][1:])))
    chosen: dict[int, list[str] | None] = {}
    for i in order:
        row = before[i]
        own = words(" ".join(row[1:]))
        key = bare_id(row[0])
        best, score = None, 0.0
        for j, cand in enumerate(after):
            if j in taken:
                continue
            r = difflib.SequenceMatcher(None, own, words(" ".join(cand[1:]))).ratio()
            if bare_id(cand[0]) == key:
                r += ID_BONUS
            if r > score:
                best, score = j, r
        if best is not None and score >= PAIR_FLOOR:
            taken.add(best)
            chosen[i] = after[best]
        else:
            chosen[i] = None
    for i in range(len(before)):
        out.append(chosen[i])
    return out


def lost_runs(cells: list[str], counterpart: list[str]) -> list[str]:
    """Runs of this row's words with no counterpart in the row it was paired to.

    Aligned, not shingled, and against the PAIRED row rather than the whole file:
    a phrase that survives somewhere else in the document is not this row's text
    surviving.
    """
    own = words(" ".join(cells))
    theirs = words(" ".join(counterpart[1:]))
    runs = []
    for tag, i1, i2, _, _ in difflib.SequenceMatcher(None, own, theirs).get_opcodes():
        if tag in ("delete", "replace") and i2 - i1 >= RUN:
            runs.append(" ".join(own[i1:i2]))
    return runs


def main() -> int:
    rev = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REV
    got = subprocess.run(["git", "show", f"{rev}:docs/reviews/OPEN.md"],
                         capture_output=True, text=True, cwd=ROOT)
    if got.returncode != 0:
        print(f"open_backfill_diff.py: cannot read OPEN.md at {rev}", file=sys.stderr)
        return 2
    before = rows(got.stdout)
    after = rows(OPEN.read_text(encoding="utf-8"))
    pairs = pair(before, after)

    kept, reworded, gone, changed = [], [], [], []
    for row, mate in zip(before, pairs):
        rid = row[0]
        if mate is None:
            gone.append(rid)
            continue
        allowed = REWORDED.get(bare_id(rid), ())
        runs = [r for r in lost_runs(row[1:], mate) if r not in allowed]
        if not runs:
            kept.append(rid)
        elif all(r in allowed for r in lost_runs(row[1:], mate)):
            reworded.append(rid)
        else:
            changed.append((rid, runs))
    reworded += [r[0] for r in []]

    print(f"open_backfill_diff.py: {len(before)} rows before, {len(after)} after, "
          f"against {rev}")
    print(f"  kept, or reworded within the ruling  {len(kept)}")
    print(f"  ROWS GONE ......................... {len(gone)}")
    print(f"  ROWS WITH TEXT UNACCOUNTED FOR .... {len(changed)}")
    for rid in gone:
        print(f"\n  GONE {rid} — present before, and no row after is its counterpart")
    for rid, runs in changed:
        print(f"\n  DEFECT {rid} — text present before and absent after:")
        for r in runs:
            print(f"      {r}")
    return 1 if (gone or changed) else 0


if __name__ == "__main__":
    sys.exit(main())
