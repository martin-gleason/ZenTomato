#!/usr/bin/env python3
"""Print a runnable harness for CLAIM 4 of `scripts/check-todoist-facts.sh`.

WHY THIS EXISTS. `CLAIM 4` shipped broken and the owner found it, not a test. The
embedded Python compiled — `scripts/check_embedded_python.py` said so — but the
shell feeding it had `sed '\\$d'` with a stray backslash, so the body came back
EMPTY and python died in a `JSONDecodeError` on the owner's machine. That is the
second-artefact problem (`D46`) one layer down: the thing a human is told to run
was never run by anything.

It cannot be run in CI against the real API, because it needs the owner's token.
So this lifts the claim's own code out of the shipped script, stubs `api_get` with
a fixture shaped like a real response, and runs it. What is exercised is the
script's real plumbing — its `body`, its `code`, its embedded programs — not a
copy of them.

The fixture is chosen so the two answers differ: three projects of which ONE
carries no `color` key (the workspace shape), and three tasks whose priorities are
not all equal, so "most common is the default" has something to find.

Usage: bash <(scripts/tests/probe_facts_claim4.py)
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
FACTS = ROOT / "scripts/check-todoist-facts.sh"

PROJECTS = ('{"results":[{"id":"p1","name":"Dissertation","color":"berry_red"},'
            '{"id":"p2","name":"Household","color":"olive_green"},'
            '{"id":"p3","name":"Shared"}]}')
TASKS = ('{"results":[{"id":"t1","content":"File the form","priority":4},'
         '{"id":"t2","content":"Water the plant","priority":1},'
         '{"id":"t3","content":"Read a chapter","priority":1}]}')


def main() -> int:
    text = FACTS.read_text(encoding="utf-8")

    helpers = re.search(r"(body\(\) \{.*?\}\ncode\(\) \{.*?\})", text, re.S)
    if helpers is None:
        print("probe_facts_claim4.py: check-todoist-facts.sh no longer defines "
              "body() and code() together", file=sys.stderr)
        return 2
    marker = text.find('say "CLAIM 4')
    if marker < 0:
        print("probe_facts_claim4.py: CLAIM 4 is not in check-todoist-facts.sh",
              file=sys.stderr)
        return 2
    start = text.rindex('if [ "${phase2}" = false ]; then', 0, marker)
    end = text.index('\nsay "Done.', marker)

    print("#!/bin/bash")
    print("set -uo pipefail")
    print('API="https://example.invalid/api/v1"')
    print("phase2=false")
    print("""say() { printf '\\n%s\\n' "$1"; }""")
    print("""json() { python3 -c "$1"; }""")
    print(helpers.group(1))
    print("api_get() {")
    print('  case "$1" in')
    print(f"""    *projects*) printf '%s\\n200' '{PROJECTS}' ;;""")
    print(f"""    *tasks*) printf '%s\\n200' '{TASKS}' ;;""")
    print("  esac")
    print("}")
    print(text[start:end])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
