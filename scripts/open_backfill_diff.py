#!/usr/bin/env python3
"""Row-by-row diff of docs/reviews/OPEN.md against the hand-maintained file.

C37 made OPEN.md generated. The risk it carries is the one C29 already paid for:
a backfill that drops rows, or clips their text, while every gate stays green.
So the generation publishes this, and the rule it enforces is stated as a
failure and not as a hope:

    ANY ROW PRESENT BEFORE AND ABSENT AFTER IS A BACKFILL DEFECT.

Three dispositions, because a row can change legitimately:

  kept        the row's words align, in order, against its row in the new file
  reassigned  the text survives under a different id (the O23/O24/O25 collisions,
              recovered as C-7..C-10 in the hand-maintained `## Closed` table)
  reworded    the register states the same substance in its own words

`reworded` is the one disposition a script cannot decide. It is reported with
the lost spans printed in full so a human rules on each, and the ruling is
recorded in docs/chores/C37.md rather than inferred here. A tool that silently
called a paraphrase equivalent would be the truncating extractor again, wearing
a better hat.

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
DEFAULT_REV = "66232e8^"
RUN = 8   # an unaligned run this long is content, not a reflow

# Ruled by hand, recorded in docs/chores/C37.md. Each id's register text was read
# against OPEN.md's and found to carry the same substance in different words.
REWORDED = {"~~O3~~", "~~O4~~", "O46", "O48"}


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


def lost_runs(cells: list[str], after: list[list[str]]) -> list[str]:
    """Runs of a row's own words that do not align against its row in the new file.

    ALIGNED, NOT SHINGLED, and the difference is why the first two versions of
    this check lied in opposite directions. Shingling the joined row reported
    four false losses: the `CLOSED 2026-08-28` clause moved out of the title cell
    into `Why`, so every phrase spanning that seam vanished. Shingling per cell
    reported sixteen, because the seam is INSIDE one before-cell - title and
    closure marker shared it - and no per-cell window can see across a split the
    generator made. An in-order alignment against the whole row sees both, and
    reports as lost only what the new row has no counterpart for at all.
    """
    own = words(" ".join(cells))
    if len(own) < RUN:
        return []
    best = max(after, key=lambda a: difflib.SequenceMatcher(None, own, a).ratio())
    runs = []
    for tag, i1, i2, _, _ in difflib.SequenceMatcher(None, own, best).get_opcodes():
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
    after_text = OPEN.read_text(encoding="utf-8")
    after = [words(" ".join(r[1:])) for r in rows(after_text)]

    kept, reworded, defects = [], [], []
    for row in before:
        rid = row[0]
        spans = lost_runs(row[1:], after)
        if not spans:
            kept.append(rid)
        elif rid in REWORDED:
            reworded.append((rid, spans))
        else:
            defects.append((rid, spans))

    print(f"open_backfill_diff.py: {len(before)} rows before, "
          f"{len(rows(after_text))} after, against {rev}")
    print(f"  kept verbatim ......... {len(kept)}")
    print(f"  reworded, ruled in C37  {len(reworded)}")
    print(f"  UNACCOUNTED FOR ....... {len(defects)}")
    for rid, spans in reworded:
        print(f"\n  reworded {rid}:")
        for s in spans:
            print(f"      {s}")
    for rid, spans in defects:
        print(f"\n  DEFECT {rid} — text present before and absent after:")
        for s in spans:
            print(f"      {s}")
    return 1 if defects else 0


if __name__ == "__main__":
    sys.exit(main())
