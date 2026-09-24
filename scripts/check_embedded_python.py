#!/usr/bin/env python3
"""Every Python program embedded in a shell script must compile.

WHY THIS EXISTS, AND IT IS NOT HYPOTHETICAL. `scripts/check-todoist-facts.sh`
embeds eleven small Python programs as single-quoted arguments, and one of them —
the verdict block for `CLAIM 2`, the tombstone question — used a
backslash-escaped quote inside an f-string expression. No Python accepts that at
any version: PEP 701 allows quote REUSE inside f-strings, never a backslash
escape. The helper that runs them was `python3 -c "$1" 2>/dev/null`, so the
SyntaxError went to a discarded stream and `--phase2` printed its heading and then
nothing at all.

**That is the worst failure mode an instrument has: it reported "no evidence" in
exactly the same way it would have reported "no finding".** The script's whole job
is to settle questions nobody can settle by reading, and `O12`'s tombstone claim
could never have been settled by it.

So the compile is a check with an exit code rather than something somebody ran
once. Found 2026-09-24 while adding `CLAIM 4` for `F13-T5`.

Usage: scripts/check_embedded_python.py [<script>...]
Defaults to every `scripts/*.sh`. Exit 1 if any embedded program fails to compile.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# How a `json '...'` argument can end in these scripts. A block is closed by the
# first of these that appears, because bash does no expansion inside single
# quotes and therefore the first unescaped quote ends the string.
TERMINATORS = ("')\"", "'\n", "' > ", "')")
OPENERS = ("json '", "python3 -c '")


def programs(text: str) -> list[tuple[int, str]]:
    """Every embedded program, as (line number, source)."""
    found: list[tuple[int, str]] = []
    for opener in OPENERS:
        i = 0
        while True:
            start = text.find(opener, i)
            if start < 0:
                break
            start += len(opener)
            ends = [e for e in (text.find(t, start) for t in TERMINATORS) if e >= 0]
            if not ends:
                break
            end = min(ends)
            found.append((text[:start].count("\n") + 1, text[start:end]))
            i = end + 1
    return sorted(found)


def main() -> int:
    paths = ([ROOT / a for a in sys.argv[1:]]
             if len(sys.argv) > 1
             else sorted((ROOT / "scripts").glob("*.sh")))
    checked = 0
    failures: list[str] = []
    for path in paths:
        text = path.read_text(encoding="utf-8")
        for line, source in programs(text):
            checked += 1
            try:
                compile(source, f"{path.name}:{line}", "exec")
            except SyntaxError as err:
                where = f"{path.relative_to(ROOT)}:{line}"
                failures.append(f"{where}: {err.msg} (at embedded line {err.lineno})")

    name = Path(__file__).name
    if failures:
        print(f"{name}: FAIL — {len(failures)} of {checked} embedded programs "
              f"do not compile:", file=sys.stderr)
        for f in failures:
            print(f"  {f}", file=sys.stderr)
        print("  A SyntaxError here is silent if the caller discards stderr.",
              file=sys.stderr)
        return 1
    print(f"{name}: OK — {checked} embedded Python programs in "
          f"{len(paths)} script(s) compile.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
