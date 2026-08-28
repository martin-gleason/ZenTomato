#!/bin/bash
#
# Refuse the one sentence that would dissolve the copyleft.
#
# WHAT THIS PROTECTS
# ZenPom is GPL-3.0-or-later EVERYWHERE, paired with an App Store distribution
# exception (LICENSE-EXCEPTION.md) — the copyright holder's pledge not to enforce
# the one GPL/App Store conflict. One licence, one pledge. The arrangement Signal,
# Nextcloud and Telegram use.
#
# The failure this guards is REDESCRIPTION. An earlier design of this project
# used a separate MIT grant for binaries, and the summary "dual licensed under
# GPL-3.0 or MIT" was one helpful sentence away at all times. That design is
# gone; the sentence remains the threat, because a permissive licence named as an
# ALTERNATIVE to the GPL — any permissive licence, in any wording — offers the
# copyleft away for the price of a disjunction. Someone describing the App Store
# arrangement loosely ("it's basically MIT on the store") writes it without
# meaning to.
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
#   "ZenPom is GPL-3.0-or-later. The App Store copy is the same software under
#    the same licence, with a non-enforcement pledge for the one conflict."
# The licence is named alone. The pledge is described as a pledge.
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
allow='^(LICENSE|LICENSE-EXCEPTION\.md|docs/chores/C18\.md|\.claude/agents/adversarial-reviewer\.md)$'
files=$(git ls-files '*.md' 'LICENSE*' '.claude/**' 2>/dev/null | grep -vE "$allow" || true)

[ -z "$files" ] && { echo "check-licence-wording.sh: OK — nothing to read."; exit 0; }

# A GPL name and an MIT name separated by a disjunction, in either order, within
# a single line. Case-insensitive, and tolerant of the ways people write GPLv3.
disjunction='(or|either|\/|,|choice of|your option|whichever)'
gpl='GPL[- ]?v?3(\.0)?([- ]or[- ]later)?|GNU General Public'
permissive='MIT|BSD|Apache([- ]2(\.0)?)?|ISC|zlib'
pattern="(($gpl)[^.]{0,40}${disjunction}[^.]{0,20}($permissive))|(($permissive)[^.]{0,40}${disjunction}[^.]{0,20}($gpl))"

hits=$(grep -inEH "$pattern" $files 2>/dev/null || true)

if [ -n "$hits" ]; then
  echo "check-licence-wording.sh: FAIL — a disjunctive licence phrase."
  echo
  echo "$hits" | sed 's/^/  /'
  echo
  echo "  Naming a permissive licence as an ALTERNATIVE to the GPL offers the"
  echo "  copyleft away: anyone who wants the source takes the permissive option."
  echo
  echo "  ZenPom has ONE licence and ONE pledge:"
  echo "    GPL-3.0-or-later, everywhere            — LICENSE"
  echo "    an App Store non-enforcement pledge     — LICENSE-EXCEPTION.md"
  echo
  echo "  Name the licence alone. Describe the pledge as a pledge. See"
  echo "  docs/chores/C18.md."
  exit 1
fi

echo "check-licence-wording.sh: OK — no disjunctive licence wording."
