#!/bin/bash
#
# Refuse the one sentence that would dissolve the copyleft.
#
# WHAT THIS PROTECTS
# ZenPom licenses two different things two different ways: the SOURCE, on GitHub,
# under GPL-3.0-or-later; and the compiled BINARY, on the App Store, under MIT.
# That is licence-per-channel, and it is coherent because the owner holds the
# copyright.
#
# It is one sentence away from being worthless.
#
# "Dual licensed under GPL-3.0 or MIT" is the DISJUNCTIVE form: it offers both
# licences to everyone for the same artifact, so anybody who wants the source
# simply takes the MIT option and the copyleft protects nothing. Written that
# way, the arrangement is a long-winded way of saying MIT.
#
# WHY A SCRIPT RATHER THAN A NOTE IN THE README
# Every other part of this arrangement is a FILE somebody would notice was
# missing. This is a SENTENCE somebody would ADD, believing it to be a helpful
# summary of a licensing setup that takes two paragraphs to explain properly. The
# failure mode is a well-meaning simplification, which is exactly the kind a
# reviewer waves through.
#
# WHAT IT LOOKS FOR
# Not one phrase but a shape: a disjunction ("or", "either", "/", "choice of")
# sitting between the two licence names, anywhere in the same sentence. The
# wordings people would actually reach for are many; the shape is one.
#
# HOW TO SAY IT CORRECTLY
#   "The source is GPL-3.0-or-later. Binaries distributed by the copyright
#    holder are MIT."
# Two sentences, each naming what it covers. No "or" between the licences.
set -euo pipefail

cd "$(dirname "$0")/.."

# THE ALLOWLIST, AND WHY EVERY ENTRY IS A HOLE.
#
# A fence that cannot tell a MENTION from a USE fires on the sentence stating the
# rule, and is switched off within a month — the same lesson `StatsFenceTests` and
# `PolishFenceTests` learned by stripping comments before searching.
#
# These four documents exist to explain this rule, and must quote the forbidden
# phrase to do it. This check caught the reviewer brief the moment it was written,
# which is the evidence it works and also the reason this list exists.
#
# **Each entry is a file where the phrase would go unnoticed.** Keep the list at
# four. Anything added here needs an argument in the pull request, because the
# way this check dies is not somebody deleting it — it is somebody appending one
# more filename on a Friday.
allow='^(LICENSE|LICENSE-APP\.md|docs/chores/C18\.md|\.claude/agents/adversarial-reviewer\.md)$'
files=$(git ls-files '*.md' 'LICENSE*' '.claude/**' 2>/dev/null | grep -vE "$allow" || true)

[ -z "$files" ] && { echo "check-licence-wording.sh: OK — nothing to read."; exit 0; }

# A GPL name and an MIT name separated by a disjunction, in either order, within
# a single line. Case-insensitive, and tolerant of the ways people write GPLv3.
disjunction='(or|either|\/|,|choice of|your option|whichever)'
gpl='GPL[- ]?v?3(\.0)?([- ]or[- ]later)?|GNU General Public'
pattern="(($gpl)[^.]{0,40}${disjunction}[^.]{0,20}MIT)|(MIT[^.]{0,40}${disjunction}[^.]{0,20}($gpl))"

hits=$(grep -inEH "$pattern" $files 2>/dev/null || true)

if [ -n "$hits" ]; then
  echo "check-licence-wording.sh: FAIL — a disjunctive licence phrase."
  echo
  echo "$hits" | sed 's/^/  /'
  echo
  echo "  This offers BOTH licences for the SAME thing, so anyone who wants the"
  echo "  source takes MIT and the copyleft protects nothing."
  echo
  echo "  ZenPom licenses per channel, not per preference:"
  echo "    the source, on GitHub          — GPL-3.0-or-later"
  echo "    binaries from the copyright holder — MIT"
  echo
  echo "  Say it as two sentences, each naming what it covers, with no 'or'"
  echo "  between the licence names. See docs/chores/C18.md."
  exit 1
fi

echo "check-licence-wording.sh: OK — no disjunctive licence wording."
