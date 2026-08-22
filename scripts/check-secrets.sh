#!/bin/bash
#
# check-secrets.sh — keep credentials out of the repository.
#
# CLAUDE.md, non-negotiable: "Secrets never enter the tree." This is the script
# that makes that a fact rather than a promise. It runs in the pre-commit hook
# (fast feedback) and again in continuous integration (because a pre-commit
# hook is bypassed with `git commit --no-verify`, and branch protection is the
# only gate that actually holds).
#
# THREE CHECKS, IN ORDER OF HOW LIKELY THEY ARE TO CATCH A REAL MISTAKE
#
#   1. FORBIDDEN FILES. `.env`, a generated `Secrets.xcconfig`, or a signing
#      key (`*.p8`, `*.p12`, `*.mobileprovision`, `*.cer`) must never be
#      committed. .gitignore already covers all of these; this check catches
#      the case where somebody used `git add -f`, which .gitignore cannot stop.
#
#   2. KEY-SHAPED LITERALS. A long opaque value assigned to something named
#      like a credential, in tracked source. This is the "pasted it in to test
#      something and forgot" failure, which is the one that actually happens.
#
#   3. GITLEAKS, when it is installed. A far broader ruleset than anything
#      worth hand-writing here. It is wrapped rather than depended on, so a
#      developer without it installed still gets checks 1 and 2 — and
#      continuous integration installs it, so the full ruleset always runs
#      before anything can merge.
#
# PLACEHOLDER CONVENTION
# Test fixtures must contain values that are obviously not real. A value
# beginning EXAMPLE_, FAKE_, DUMMY_, TEST_ or CHANGEME is treated as a
# placeholder and skipped by check 2. If you need a fake credential anywhere in
# this repository, name it that way.
#
# EXIT CODES
#   0  clean
#   1  something that looks like a secret is in, or is entering, the tree
#   2  a usage failure

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

staged_only=false

usage() {
  cat <<'USAGE' >&2
usage: check-secrets.sh [--staged]

  --staged   Examine only the files staged for commit. This is what the
             pre-commit hook uses. Without it, every tracked file is examined,
             which is what continuous integration uses.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --staged) staged_only=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "check-secrets.sh: unknown argument '$1'" >&2; usage; exit 2 ;;
  esac
done

cd -- "$REPO_ROOT"

failures=0

report() {
  if [[ $failures -eq 0 ]]; then
    echo "check-secrets.sh: FAIL — possible credential in the tree" >&2
    echo >&2
  fi
  failures=$((failures + 1))
  echo "  $*" >&2
}

# --- Check 0 · .env must actually be git-ignored ---------------------------
# This runs FIRST and unconditionally, before the file lists below, because it
# is the one check whose subject may be invisible to git entirely.
#
# Checks 1 and 2 only ever look at files git already knows about, so they cannot
# see this failure: if the `.env` line were removed from .gitignore, the real
# credential file would sit in the tree as a plain untracked file, unseen by
# every other check here, until the day somebody typed `git add .`.
#
# Asking git directly is cheap, and .env is this project's single
# highest-consequence file — the only one on disk holding a real value.
if [[ -f .env ]] && ! git check-ignore -q .env; then
  report ".env exists but is NOT git-ignored. One 'git add .' commits a real" \
         $'\n         credential. Restore the `.env` line in .gitignore before doing' \
         $'\n         anything else.'
fi

# The mirror of the above: the template must NOT be ignored, or the repository
# silently stops documenting which keys are required.
if [[ -f .env.example ]] && git check-ignore -q .env.example; then
  report ".env.example is git-ignored, but it is meant to be committed. The" \
         $'\n         `!.env.example` negation in .gitignore has stopped working.'
fi

# --- Which files are we looking at? ----------------------------------------
files=()
if [[ "$staged_only" == true ]]; then
  # ACMR = added, copied, modified, renamed. Deletions cannot leak anything.
  while IFS= read -r file; do
    [[ -n "$file" ]] && files+=("$file")
  done < <(git diff --cached --name-only --diff-filter=ACMR)
else
  while IFS= read -r file; do
    [[ -n "$file" ]] && files+=("$file")
  done < <(git ls-files)
fi

# Note: an empty list is NOT an early exit. Check 0 above has already run, and
# it is the one that matters most; skipping out here would have silently
# disabled it whenever nothing happened to be staged.
if [[ ${#files[@]} -eq 0 ]]; then
  echo "check-secrets.sh: no tracked or staged files to examine."
fi

# --- Check 1 · forbidden files ---------------------------------------------
for file in "${files[@]-}"; do
  [[ -n "$file" ]] || continue
  base="$(basename -- "$file")"
  case "$base" in
    .env.example)
      # The one committed member of the family. Its values are empty by
      # contract; check 2 below verifies that.
      ;;
    .env|.env.*)
      report "${file} — a .env file must never be committed. It is the only" \
             $'\n         file on disk that holds a real credential.'
      ;;
    Secrets.xcconfig)
      report "${file} — generated from .env by scripts/gen-secrets.sh and" \
             $'\n         git-ignored. Delete it from the commit; `make secrets` recreates it.'
      ;;
    *.p8|*.p12|*.mobileprovision|*.cer)
      report "${file} — a signing key or provisioning profile. These live in" \
             $'\n         Keychain and in the Apple Developer portal, never in a repository.'
      ;;
  esac
done

# --- Check 1b · .env.example must stay empty -------------------------------
# The committed template documents which keys are required. The moment one of
# them has a value, the template has become a leak.
if [[ -f .env.example ]]; then
  while IFS= read -r line; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    if [[ "$line" == *=* && -n "${line#*=}" ]]; then
      report ".env.example — the key '${line%%=*}' has a value. This file is" \
             $'\n         committed; every value in it must be empty.'
    fi
  done < .env.example
fi

# --- Check 2 · key-shaped literals in tracked source -----------------------
# Deliberately narrow. It looks for a name that means "credential" next to a
# long opaque value. Prose is not scanned: docs/ and *.md discuss these keys by
# name constantly, and a check that fires on documentation gets switched off.
#
#   name part:  anything containing secret / token / password / passwd /
#               api_key / apikey / client_secret / access_key
#   value part: 16 or more characters of the alphabet real tokens use
readonly CREDENTIAL_PATTERN='(secret|token|password|passwd|api[-_]?key|access[-_]?key)[a-z0-9_]*[[:space:]]*[:=][[:space:]]*"?[A-Za-z0-9_/+.-]{16,}'

is_placeholder() {
  # Case-insensitive check for the documented fake-value prefixes.
  local text
  text="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
  [[ "$text" == *EXAMPLE* || "$text" == *FAKE* || "$text" == *DUMMY* \
     || "$text" == *CHANGEME* || "$text" == *PLACEHOLDER* || "$text" == *NOT_A_REAL* ]]
}

for file in "${files[@]-}"; do
  [[ -n "$file" ]] || continue
  [[ -f "$file" ]] || continue
  case "$file" in
    docs/*|*.md|LICENSE) continue ;;
    # This script contains the pattern it searches for, by definition.
    scripts/check-secrets.sh) continue ;;
  esac

  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    line_number="${hit%%:*}"
    text="${hit#*:}"
    if is_placeholder "$text"; then
      continue
    fi
    report "${file}:${line_number} — looks like a credential assigned in source." \
           $'\n         If it is real: remove it, rotate it, and put it in .env.' \
           $'\n         If it is a test fixture: rename the value so it contains' \
           $'\n         EXAMPLE, FAKE, DUMMY or PLACEHOLDER.'
  done < <(grep -nEi --binary-files=without-match "$CREDENTIAL_PATTERN" -- "$file" 2>/dev/null || true)
done

# --- Check 3 · gitleaks, when present --------------------------------------
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks_args=(git --no-banner --redact)
  if [[ "$staged_only" == true ]]; then
    gitleaks_args+=(--staged)
  fi
  # `--redact` so a finding never prints the value it found into a terminal or,
  # worse, into a public CI log.
  if ! gitleaks "${gitleaks_args[@]}" .; then
    report "gitleaks reported a finding — see its output above."
  fi
elif [[ "${CI:-}" == "true" ]]; then
  # In CI the broad ruleset is not optional: this is the gate that holds.
  echo "check-secrets.sh: gitleaks is not installed on this runner, and CI=true." >&2
  echo "                  The secret-scan gate cannot be satisfied without it." >&2
  exit 1
else
  echo "check-secrets.sh: note — gitleaks is not installed, so only the built-in"
  echo "                  checks ran. Install it with 'brew install gitleaks' for"
  echo "                  the full ruleset. Continuous integration always runs it."
fi

if [[ $failures -gt 0 ]]; then
  echo >&2
  echo "  ${failures} problem(s) found. Nothing has been committed." >&2
  exit 1
fi

echo "check-secrets.sh: OK — no credential found in the tree."
