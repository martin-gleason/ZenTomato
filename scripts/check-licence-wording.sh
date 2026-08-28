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

# The repository to read. Overridable ONLY so this check can be shown to fail:
# `scripts/tests/run-script-tests.sh` points it at throwaway repositories holding
# one sentence each. Nothing in the build sets it, so every real run reads this
# repository.
#
# **A guard that has never refused anything is not known to work.** This one had
# not: the per-channel phrase sat in `docs/chores/C18.md`'s own title for a day
# while the check reported OK on every run, and it could not be tested at all
# because it always read the same directory.
cd "${LICENCE_CHECK_ROOT:-$(dirname "$0")/..}"

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
# WORD BOUNDARIES, BECAUSE `MIT` IS INSIDE `commit` AND `permitted`.
# Both appear in this repository's prose constantly, and a check that fires on
# "before a commit" is a check somebody deletes rather than fixes.
permissive='(^|[^A-Za-z])(MIT|BSD|Apache([- ]2(\.0)?)?|ISC|zlib)([^A-Za-z]|$)'
pattern="(($gpl)[^.]{0,40}${disjunction}[^.]{0,20}($permissive))|(($permissive)[^.]{0,40}${disjunction}[^.]{0,20}($gpl))"

hits=$(grep -inEH "$pattern" $files 2>/dev/null || true)

# THE SECOND SHAPE, AND THE ONE THAT ACTUALLY GOT THROUGH.
#
# The pattern above reads a licence offered as an ALTERNATIVE. It cannot read a
# licence assigned PER CHANNEL — "GPL for the repo, MIT for the app" — because
# nothing in that sentence is disjunctive. That form was live on `main` for a day
# in `docs/chores/C18.md`, whose own title said it, and this check passed on it
# every time it ran.
#
# It is worth naming separately rather than widening the first pattern, because it
# is a different mistake: the first gives the copyleft away, the second describes
# a licence the project does not grant. ZenPom ships under ONE licence plus a
# non-enforcement pledge; a sentence promising MIT to anyone holding the binary
# is a promise nobody made.
channel='(app|binary|binaries|build|release|App Store|TestFlight|IPA|bundle)'
for_channel="($permissive)[^.]{0,20}(for|on|covers?|covering|licen[sc]ed under)[^.]{0,25}(the )?$channel"
channel_first="$channel[^.]{0,25}(is|are|ships? under|licen[sc]ed under)[^.]{0,20}($permissive)"
channel_hits=$(grep -inEH "($for_channel)|($channel_first)" $files 2>/dev/null || true)

if [ -n "$channel_hits" ]; then
  echo "check-licence-wording.sh: FAIL — a permissive licence named per channel."
  echo
  echo "$channel_hits" | sed 's/^/  /'
  echo
  echo "  ZenPom ships under ONE licence, GPL-3.0-or-later, plus the"
  echo "  non-enforcement pledge in LICENSE-EXCEPTION.md. Saying a permissive"
  echo "  licence covers the app or the binary describes a grant that does not"
  echo "  exist — the pledge is a promise not to sue, not a second licence."
  echo
  echo "  This is the form that got past the disjunction check for a day."
  exit 1
fi

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
