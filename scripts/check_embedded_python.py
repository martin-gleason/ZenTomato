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

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# How a `json '...'` argument can end in these scripts. A block is closed by the
# first of these that appears, because bash does no expansion inside single
# quotes and therefore the first unescaped quote ends the string.
# HOW A BLOCK CAN END. `api_get` callers close with `')"`, a bare pipeline with a
# newline, a redirect with `' > ` or `' >> `. An unrecognised ending used to
# `break` out of the scan silently, which meant the check could report OK over a
# program it had never looked at.
TERMINATORS = ("')\"", "'\n", "' > ", "' >> ", "')")

# HOW A BLOCK CAN START, and this list was the whole of the first version's
# blindness. It held two entries, so a heredoc (`python3 - <<'PY'`) and a
# double-quoted `python3 -c "` were not checked at all — three genuinely broken
# programs in one script reported OK. Found by F13's adversarial review, which
# also found that the script had a count and no floor, in a project whose harness
# contract requires one. `F13-M16`.
OPENERS = ("json '", "python3 -c '")
HEREDOC = re.compile(r"python3\s+(?:-\s+)?<<\s*'?([A-Za-z_][A-Za-z0-9_]*)'?\s*$", re.M)
# `python3 -c "..."` — double quoted, so the shell processes the inside before
# python sees it. `scripts/check-watch-provisioning.sh` has two of these, and
# neither was checked by the first version of this script. They are checkable,
# because bash's processing inside double quotes is small and deterministic:
# `\"` becomes `"`, `\$` becomes `$`, and `${var}` becomes whatever the variable
# held. See `bash_expanded`.
DOUBLE_QUOTED = re.compile(r"python3\s+-c\s+\"\n(.*?)\n\"", re.S)

# A `python3 -c "$1"` is a DISPATCHER and not a program: its content is one
# variable, and the programs it runs are passed in from elsewhere (and are caught
# by the single-quote opener). Checking it would mean compiling the string `$1`.
DISPATCHER = re.compile(r"python3\s+-c\s+\"\$\{?\w+\}?\"")

# A shell variable's value is unknowable here, so it becomes a string literal that
# is valid wherever a value would be. `'${devices_json}'` is already inside quotes
# in the script, so the substitution keeps it a plain path-shaped word.
VARIABLE = re.compile(r"\$\{(\w+)\}|\$(\w+)")


def bash_expanded(source: str) -> str:
    """What python actually receives from a double-quoted `-c` argument."""
    out = VARIABLE.sub("X", source)
    return out.replace('\\"', '"').replace("\\$", "$").replace("\\\\", "\\")

# The floor. An exit code cannot show a scan that stopped finding things, so the
# count may not fall below what the tree held when this was last looked at.
FLOOR = 13


def programs(text: str) -> tuple[list[tuple[int, str]], list[int]]:
    """Every embedded program as (line, source), plus the lines it could not read.

    The second list is the point. The first version returned only what it
    understood and said nothing about the rest, so a program it could not parse
    the boundaries of was indistinguishable from a program that compiled.
    """
    found: list[tuple[int, str]] = []
    unreadable: list[int] = []

    for opener in OPENERS:
        i = 0
        while True:
            start = text.find(opener, i)
            if start < 0:
                break
            start += len(opener)
            ends = [e for e in (text.find(t, start) for t in TERMINATORS) if e >= 0]
            if not ends:
                unreadable.append(text[:start].count("\n") + 1)
                break
            end = min(ends)
            found.append((text[:start].count("\n") + 1, text[start:end]))
            i = end + 1

    # Heredocs: `python3 - <<'PY' ... PY`. The delimiter is whatever the script
    # named, and it ends the block on a line of its own.
    for match in HEREDOC.finditer(text):
        delimiter = match.group(1)
        body_start = text.index("\n", match.end()) + 1
        closing = re.search(rf"^{re.escape(delimiter)}\s*$", text[body_start:], re.M)
        line = text[:body_start].count("\n") + 1
        if closing is None:
            unreadable.append(line)
            continue
        found.append((line, text[body_start:body_start + closing.start()]))

    # Double-quoted `-c`, expanded the way bash would before python sees it.
    for match in DOUBLE_QUOTED.finditer(text):
        if DISPATCHER.search(text[match.start():match.start() + 60]):
            continue
        found.append((text[:match.start(1)].count("\n") + 1,
                      bash_expanded(match.group(1))))

    return sorted(found), sorted(unreadable)


def main() -> int:
    paths = ([ROOT / a for a in sys.argv[1:]]
             if len(sys.argv) > 1
             else sorted((ROOT / "scripts").glob("*.sh")))
    checked = 0
    failures: list[str] = []
    skipped: list[str] = []
    for path in paths:
        text = path.read_text(encoding="utf-8")
        found, unreadable = programs(text)
        for line in unreadable:
            skipped.append(f"{path.relative_to(ROOT)}:{line}")
        for line, source in found:
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

    # AN UNREADABLE BLOCK IS A FAILURE, NOT A GAP. Saying nothing about a program
    # whose boundaries could not be found is how this check reported OK over three
    # broken programs in its own first version.
    if skipped:
        print(f"{name}: FAIL — {len(skipped)} embedded program(s) could not be "
              f"read, so nothing is known about them:", file=sys.stderr)
        for s in skipped:
            print(f"  {s}", file=sys.stderr)
        print("  Rewrite the call in a form this checker understands "
              "(a heredoc, or single-quoted `python3 -c '...'`).", file=sys.stderr)
        return 1

    # THE FLOOR. `docs/conventions.md`'s harness contract requires one, because an
    # exit code cannot show a scan that quietly stopped finding things.
    if checked < FLOOR:
        print(f"{name}: FAIL — found {checked} embedded programs, floor is {FLOOR}. "
              f"Either some were removed, in which case lower the floor "
              f"deliberately, or the scanner stopped recognising them.",
              file=sys.stderr)
        return 1

    print(f"{name}: OK — {checked} embedded Python programs in "
          f"{len(paths)} script(s) compile (floor {FLOOR}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
