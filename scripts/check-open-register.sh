#!/bin/bash
#
# Refuse a register whose tables have stopped being tables.
#
# WHAT HAPPENED, AND WHY THIS EXISTS
# docs/reviews/OPEN.md is the one place every outstanding item lives, and its
# conventions say so in as many words: a "Still open" section inside one review
# is invisible from the next one. The register IS the mechanism for not losing
# things.
#
# On 2026-08-24 the O16 row was struck through and lost a cell in the edit. A
# Markdown table with a malformed row stops being a table at that row in strict
# renderers — the owner's reader (Bear) drew the table down to O11 and rendered
# everything after it as loose text. Six items added over the following three
# days (O20–O25) were invisible in the reader the owner actually scans, and O22 —
# the one that gates the entire dual-licensing arrangement — was missed exactly
# this way. A second row (O14) had accumulated an EXTRA cell from a later edit,
# which pushes a column of text out of view instead.
#
# The failure is silent in every tool that touched it: git sees a text change,
# the diff reads fine, GitHub's renderer is forgiving enough to cope. Only a
# strict reader shows it, and nobody re-reads a table they believe they have
# already read. Hence a check: every row in a table must carry the same number
# of columns as its header. Nothing here parses Markdown properly — it counts
# pipes per contiguous table block, which is precisely the property strict
# renderers require.
set -euo pipefail

cd "$(dirname "$0")/.."

fail=0
for file in docs/reviews/OPEN.md; do
  [ -f "$file" ] || continue
  result=$(awk -v FILE="$file" '
    /^\|/ {
      pipes = gsub(/\|/, "|")
      if (expected == 0) expected = pipes
      else if (pipes != expected) {
        printf "  %s:%d: %d columns where the table has %d\n", FILE, NR, pipes - 1, expected - 1
        bad = 1
      }
      next
    }
    { expected = 0 }
    END { exit bad }
  ' "$file") || fail=1
  [ -n "$result" ] && echo "$result"
done

if [ "$fail" -ne 0 ]; then
  echo
  echo "check-open-register.sh: FAIL — a table in the register is malformed."
  echo
  echo "  A row with the wrong number of cells ends the table at that row in"
  echo "  strict renderers. Everything below it disappears from the table the"
  echo "  owner scans — which is how O22 was missed. Count the pipes."
  exit 1
fi

echo "check-open-register.sh: OK — the register renders as tables."
