#!/bin/bash
#
# check-wholesale-rewrite.sh — refuse a commit that replaces a document wholesale.
#
# WHAT HAPPENED, AND WHY A HOOK RATHER THAN A RULE
# On 2026-08-24 the agent ran `cat > docs/plans/F7.md` on a file it had never opened, destroying 153
# lines of plan written at F1 — including decisions it then failed to reproduce, among them
# idempotency-by-UUID for watch taps, without which duplicate delivery silently inflates the
# distraction counts the fortnightly review reads.
#
# The precise hole: the agent's `Write` tool REFUSES to overwrite a file that has not been read in
# the current session. Shell redirection through `Bash` has no such guard. The protection existed and
# was walked around, so the fix cannot be another instruction to be careful — CLAUDE.md already says
# "Before deleting or overwriting, look at the target."
#
# This is not the first time. `docs/reviews/F1.md` carries a section titled "Deletion damage,
# assessed", and earlier in this project a runaway `git checkout HEAD --` destroyed 350 of 377 lines
# of BlockLiveActivity.swift. Wholesale replacement has now happened twice.
#
# WHAT IT CHECKS
# For every MODIFIED (never added, never renamed) file under a watched directory, the proportion of
# the original that survives. Deleting more than THRESHOLD percent of a file in one commit is
# replacement rather than editing, and requires saying so.
#
# THE ESCAPE HATCH IS DELIBERATE AND NARROW
# A real rewrite is a legitimate act. It just has to be declared: put a line reading
#   Rewrites: <path> — <why>
# in the commit message, one per file. That turns an accident into a statement somebody can review,
# which is the whole intent — the same reasoning as the Todoist allowlist, where widening the rule
# means editing a committed file so the change appears in a diff.
#
# WHERE IT RUNS
# `commit-msg`, not `pre-commit` — because the escape hatch is a line in the commit message and
# pre-commit never sees one. The staged index is fully available at commit-msg time, so the diff it
# reads is the same diff pre-commit would have read.
#
# EXIT CODES
#   0  nothing replaced wholesale, or every replacement was declared
#   1  at least one undeclared wholesale rewrite
#   2  a usage or configuration failure

set -uo pipefail

readonly THRESHOLD=60
readonly WATCHED='^(docs/|ZenTomato/|ZenTomatoTests/|scripts/|CLAUDE.md)'

message_file="${1:-}"
if [ -n "${message_file}" ] && [ -r "${message_file}" ]; then
  commit_message="$(cat "${message_file}")"
else
  commit_message=""
fi

failed=0

# --diff-filter=M: modifications only. An added file has nothing to destroy, and a rename is
# reported by git as a rename rather than as a rewrite.
while IFS= read -r path; do
  [ -z "${path}" ] && continue
  echo "${path}" | grep -qE "${WATCHED}" || continue

  old_lines="$(git show "HEAD:${path}" 2>/dev/null | wc -l | tr -d ' ')"
  [ "${old_lines:-0}" -lt 20 ] && continue   # too small for the ratio to mean anything

  # Lines removed, from the staged diff against HEAD.
  removed="$(git diff --cached --numstat -- "${path}" | awk '{print $2}')"
  [ -z "${removed}" ] && continue

  percent=$(( removed * 100 / old_lines ))
  [ "${percent}" -le "${THRESHOLD}" ] && continue

  if printf '%s' "${commit_message}" | grep -qF "Rewrites: ${path}"; then
    echo "check-wholesale-rewrite.sh: ${path} — ${percent}% replaced, declared in the message. OK."
    continue
  fi

  failed=1
  echo "check-wholesale-rewrite.sh: FAIL — ${path}"
  echo "  ${removed} of ${old_lines} lines removed (${percent}%), which is replacement, not editing."
  echo "  Did you mean to? Read the file first — every feature's plan was written at F1 and a"
  echo "  document already existing at the path you are writing is the normal case."
  echo
  echo "  If the rewrite is intended, declare it in the commit message:"
  echo "    Rewrites: ${path} — <why>"
  echo
done < <(git diff --cached --name-only --diff-filter=M)

if [ "${failed}" -ne 0 ]; then
  echo "check-wholesale-rewrite.sh: commit refused."
  exit 1
fi

echo "check-wholesale-rewrite.sh: OK — no undeclared wholesale rewrite."
exit 0
