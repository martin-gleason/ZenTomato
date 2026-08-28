#!/bin/bash
#
# run-script-tests.sh — the four shell-level tests from docs/plans/F1.md, plus
# the ones that turned out to be missing.
#
#   noWritesHookCatchesNewEndpoint  a fixture with an unlisted Todoist URL exits
#                                   non-zero
#   noWritesHookCatchesBarePath     the same, written as a host-less path —
#                                   a regression test; see the test for why
#   noWritesHookCatchesBuilderPath  the same, written with URL.appending(path:)
#                                   — a regression test; see the test for why
#   noWritesHookAllowsClose         a fixture with only allowlisted endpoints
#                                   exits zero
#   secretsFileIsGitIgnored         Config/Secrets.xcconfig is ignored and the
#                                   committed template is not
#
# WHY THESE ARE NOT SWIFT TESTS
# They run other programs. `Foundation.Process` — the API for launching a
# subprocess — is unavailable on iOS, so a test that shells out cannot live in
# an iOS unit-test bundle. Writing them here keeps them honest: they invoke the
# real scripts, with the real arguments, and read the real exit codes.
#
# The last two matter more than they look. A hook that has never been shown to
# FAIL is not known to work, and that one guards a non-negotiable.
#
# EVERYTHING RUNS IN A TEMPORARY DIRECTORY. No test touches the repository's own
# Config/Secrets.xcconfig, so running this can never disturb a working
# build or read a real credential.

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPTS_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly REPO_ROOT="$(cd -- "${SCRIPTS_DIR}/.." && pwd)"
readonly FIXTURES_DIR="${SCRIPT_DIR}/fixtures"

readonly CHECK_TODOIST="${SCRIPTS_DIR}/check-todoist-writes.sh"
readonly CHECK_REWRITE="${SCRIPTS_DIR}/check-wholesale-rewrite.sh"
readonly ALLOWLIST="${SCRIPTS_DIR}/todoist-allowed-endpoints.txt"
readonly CHECK_LICENCE="${SCRIPTS_DIR}/check-licence-wording.sh"

work_dir="$(mktemp -d -- "${TMPDIR:-/tmp}/zentomato-script-tests.XXXXXX")"
# shellcheck disable=SC2064  # expand work_dir now, while it is still in scope.
trap "rm -rf -- '${work_dir}'" EXIT

passed=0
failed=0

pass() {
  printf '  ok    %s\n' "$1"
  passed=$((passed + 1))
}

fail() {
  printf '  FAIL  %s\n' "$1" >&2
  shift
  while [[ $# -gt 0 ]]; do
    printf '        %s\n' "$1" >&2
    shift
  done
  failed=$((failed + 1))
}

echo "run-script-tests.sh"
echo

# ---------------------------------------------------------------------------
# The no-writes hook.
#
# The fixtures are stored with a .txt extension so they are never mistaken for
# source, and copied into a temporary directory as .swift so the checker sees
# them exactly as it would see real code.
# ---------------------------------------------------------------------------
stage_fixture() {
  local fixture="$1" dir="$2"
  mkdir -p -- "$dir"
  cp -- "${FIXTURES_DIR}/${fixture}" "${dir}/Fixture.swift"
}

test_no_writes_hook_catches_new_endpoint() {
  local name="noWritesHookCatchesNewEndpoint"
  local dir="${work_dir}/forbidden"
  local output_file="${work_dir}/forbidden.out"
  local status=0

  stage_fixture "todoist-forbidden.txt" "$dir"
  "$CHECK_TODOIST" --allowlist "$ALLOWLIST" "$dir" >"$output_file" 2>&1 || status=$?

  if [[ $status -eq 0 ]]; then
    fail "$name" \
      "an unlisted Todoist endpoint passed the check" \
      "this is the non-negotiable the hook exists to protect"
    return
  fi

  if ! grep -q '/comments' "$output_file"; then
    fail "$name" "it failed, but the output does not point at the offending endpoint"
    return
  fi

  pass "$name"
}

test_no_writes_hook_allows_close() {
  local name="noWritesHookAllowsClose"
  local dir="${work_dir}/allowed"
  local output_file="${work_dir}/allowed.out"
  local status=0

  stage_fixture "todoist-allowed.txt" "$dir"
  "$CHECK_TODOIST" --allowlist "$ALLOWLIST" "$dir" >"$output_file" 2>&1 || status=$?

  if [[ $status -ne 0 ]]; then
    fail "$name" \
      "the check rejected source that only calls allowlisted endpoints" \
      "a hook this tight blocks legitimate work and will be switched off" \
      "--- output ---" \
      "$(cat -- "$output_file")"
    return
  fi

  pass "$name"
}

# ---------------------------------------------------------------------------
# noWritesHookCatchesBarePath
#
# REGRESSION TEST. The hook used to recognise a bare, host-less path only for
# the nouns that were already allowlisted, so `let commentsPath = "/comments"`
# matched nothing and passed — even though the allowed fixture proves the
# host-less shape is one this codebase uses. The hook was blind to the
# endpoints it exists to forbid, in the form F3 is most likely to write them.
#
# Kept separate from noWritesHookCatchesNewEndpoint because that one only ever
# exercises full URLs. Both shapes have to be shown to fail, or only one of
# them is actually guarded.
# ---------------------------------------------------------------------------
test_no_writes_hook_catches_bare_path() {
  local name="noWritesHookCatchesBarePath"
  local dir="${work_dir}/bare"
  local output_file="${work_dir}/bare.out"
  local status=0

  stage_fixture "todoist-bare-path.txt" "$dir"
  "$CHECK_TODOIST" --allowlist "$ALLOWLIST" "$dir" >"$output_file" 2>&1 || status=$?

  if [[ $status -eq 0 ]]; then
    fail "$name" \
      "a host-less Todoist path passed the check" \
      "this is the shape a base-URL constant plus a path produces, and it is" \
      "the most likely way a forbidden endpoint actually gets written"
    return
  fi

  # Naming /sync specifically: it is the endpoint that can perform every
  # mutation Todoist supports, so it is the one that must never slip through.
  if ! grep -q '/sync' "$output_file"; then
    fail "$name" \
      "it failed, but did not report /sync" \
      "--- output ---" \
      "$(cat -- "$output_file")"
    return
  fi

  pass "$name"
}

# ---------------------------------------------------------------------------
# noWritesHookCatchesBuilderPath
#
# REGRESSION TEST. `URL.appending(path:)` and `appendingPathComponent(_:)` take
# the component with NO leading slash, so `base.appending(path: "sync")`
# contains no `/sync` and the hook's path pattern could never see it. Four such
# lines passed while the script printed its success message.
#
# Kept separate from the bare-path test because that one only ever exercises
# string literals that already begin with a slash. This is the shape idiomatic
# modern Swift actually produces, and it has to be shown to fail or it is not
# known to be guarded.
# ---------------------------------------------------------------------------
test_no_writes_hook_catches_builder_path() {
  local name="noWritesHookCatchesBuilderPath"
  local dir="${work_dir}/builder"
  local output_file="${work_dir}/builder.out"
  local status=0

  stage_fixture "todoist-builder-path.txt" "$dir"
  "$CHECK_TODOIST" --allowlist "$ALLOWLIST" "$dir" >"$output_file" 2>&1 || status=$?

  if [[ $status -eq 0 ]]; then
    fail "$name" \
      "a Todoist endpoint built with appending(path:) passed the check" \
      "this is the shape F3 is most likely to be written in"
    return
  fi

  local endpoint
  for endpoint in '/comments' '/sync'; do
    if ! grep -q -- "$endpoint" "$output_file"; then
      fail "$name" \
        "it failed, but did not report ${endpoint}" \
        "--- output ---" \
        "$(cat -- "$output_file")"
      return
    fi
  done

  pass "$name"
}

# ---------------------------------------------------------------------------
# secretsFileIsGitIgnored
#
# The other checks in check-secrets.sh only ever look at files git already
# tracks or has staged, so none of them can see the failure where the private
# xcconfig stops being ignored: the file just sits there untracked, invisible,
# until somebody types `git add .` and commits a live credential.
#
# This asserts the guard is wired up and answering, on this actual repository.
# ---------------------------------------------------------------------------
test_secrets_file_is_git_ignored() {
  local name="secretsFileIsGitIgnored"

  if ! git -C "$REPO_ROOT" check-ignore -q Config/Secrets.xcconfig; then
    fail "$name" \
      "Config/Secrets.xcconfig is not git-ignored in this repository" \
      "it is the only file on disk holding a real credential"
    return
  fi

  if git -C "$REPO_ROOT" check-ignore -q Config/Secrets.example.xcconfig; then
    fail "$name" \
      "the committed template IS ignored, but it is meant to be tracked" \
      "the repository would stop documenting which keys are required"
    return
  fi

  # A leftover .env from the pre-xcconfig setup is dead weight, not a supported
  # location — but for as long as one exists it must not be committable.
  # check-secrets.sh warns that it should be deleted; this only holds the line.
  if [[ -f "$REPO_ROOT/.env" ]] && ! git -C "$REPO_ROOT" check-ignore -q .env; then
    fail "$name" \
      "a leftover .env is present and not git-ignored" \
      "nothing reads it any more, but it may still hold real values"
    return
  fi

  pass "$name"
}


# ---------------------------------------------------------------------------
# The wholesale-rewrite hook.
#
# Run against a REAL throwaway git repository rather than a stub, because the
# check reads the staged index through `git diff --cached` and `git show HEAD:`.
# A fake would only prove the fake works.
# ---------------------------------------------------------------------------
make_rewrite_repo() {
  local dir="$1"
  mkdir -p -- "${dir}/docs/plans"
  git -C "$dir" init -q
  git -C "$dir" config user.email t@example.com
  git -C "$dir" config user.name Test
  # 40 lines, comfortably over the 20-line floor the check applies.
  seq 1 40 | sed 's/^/original line /' > "${dir}/docs/plans/F9.md"
  git -C "$dir" add docs/plans/F9.md
  git -C "$dir" commit -qm "add a plan"
}

# A repository holding one markdown file, so the licence check has something to
# read. It runs `git ls-files`, so the file has to be tracked, not merely present.
make_licence_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init --quiet
  git -C "$dir" config user.email t@example.com
  git -C "$dir" config user.name test
  printf 'placeholder\n' > "${dir}/README.md"
  git -C "$dir" add README.md
  git -C "$dir" commit --quiet -m init
}

# Runs the real check inside a throwaway repo whose README says "$1".
licence_check_on() {
  local dir="$1" line="$2"
  printf '%s\n' "$line" > "${dir}/README.md"
  git -C "$dir" add README.md
  ( LICENCE_CHECK_ROOT="$dir" "$CHECK_LICENCE" >/dev/null 2>&1 )
}

# **THE CHECK HAS TO BE SHOWN TO FAIL.** A licence guard that has never refused
# anything is not known to work — and this one demonstrably was not: the
# per-channel phrase sat in docs/chores/C18.md's own title for a day while the
# check reported OK on every run.
test_licence_check_catches_a_disjunction() {
  local name="licenceCheckCatchesADisjunction"
  local dir="${work_dir}/licence-disjunction"
  make_licence_repo "$dir"

  if licence_check_on "$dir" 'ZenPom is dual licensed under GPL-3.0 or MIT.'; then
    fail "$name" "the check allowed the one sentence that voids the copyleft"
    return
  fi
  pass "$name"
}

test_licence_check_catches_a_per_channel_grant() {
  local name="licenceCheckCatchesAPerChannelGrant"
  local dir="${work_dir}/licence-channel"
  make_licence_repo "$dir"

  # Nothing here is disjunctive, which is exactly why the original pattern
  # could not see it.
  if licence_check_on "$dir" 'GPL-3.0 for the repository, MIT for the app.'; then
    fail "$name" "the check allowed a permissive licence named per channel" \
      "this is the form that was live on main for a day"
    return
  fi
  pass "$name"
}

test_licence_check_catches_the_binary_phrasing() {
  local name="licenceCheckCatchesTheBinaryPhrasing"
  local dir="${work_dir}/licence-binary"
  make_licence_repo "$dir"

  if licence_check_on "$dir" 'The compiled binary is licensed under MIT.'; then
    fail "$name" "the check allowed a grant the project does not make"
    return
  fi
  pass "$name"
}

# And the other half, which is what keeps it alive: a check that fires on the
# word "commit" gets deleted within a week. `MIT` is a substring of both words
# below and neither is a licence claim.
test_licence_check_allows_ordinary_prose() {
  local name="licenceCheckAllowsOrdinaryProse"
  local dir="${work_dir}/licence-prose"
  make_licence_repo "$dir"

  if ! licence_check_on "$dir" 'Run the checks before a commit; the app is permitted to chain a block.'; then
    fail "$name" "the check fired on ordinary prose" \
      "MIT is inside commit and permitted — word boundaries are load-bearing"
    return
  fi
  pass "$name"
}

# The pledge must remain sayable. LICENSE-EXCEPTION.md describes what the app
# does NOT do, and a fence that cannot tell a mention from a use is switched off.
test_licence_check_allows_the_pledge() {
  local name="licenceCheckAllowsThePledge"
  local dir="${work_dir}/licence-pledge"
  make_licence_repo "$dir"

  if ! licence_check_on "$dir" 'ZenPom ships solely under GPL-3.0-or-later, with a non-enforcement pledge.'; then
    fail "$name" "the check refused the arrangement that actually ships"
    return
  fi
  pass "$name"
}

test_rewrite_hook_refuses_wholesale_replacement() {
  local name="rewriteHookRefusesWholesaleReplacement"
  local dir="${work_dir}/rewrite-refuse"
  make_rewrite_repo "$dir"

  printf 'a three line\nreplacement of\nforty lines\n' > "${dir}/docs/plans/F9.md"
  git -C "$dir" add docs/plans/F9.md
  printf 'docs(F9): rewrite\n' > "${dir}/msg"

  if ( cd "$dir" && "$CHECK_REWRITE" msg >/dev/null 2>&1 ); then
    fail "$name" "the check allowed a 92%% replacement with no declaration"
    return
  fi
  pass "$name"
}

test_rewrite_hook_allows_a_declared_rewrite() {
  local name="rewriteHookAllowsADeclaredRewrite"
  local dir="${work_dir}/rewrite-declared"
  make_rewrite_repo "$dir"

  printf 'a three line\nreplacement of\nforty lines\n' > "${dir}/docs/plans/F9.md"
  git -C "$dir" add docs/plans/F9.md
  printf 'docs(F9): rewrite\n\nRewrites: docs/plans/F9.md — superseded by the new gate\n' > "${dir}/msg"

  if ! ( cd "$dir" && "$CHECK_REWRITE" msg >/dev/null 2>&1 ); then
    fail "$name" "a declared rewrite was refused" \
      "the escape hatch is what keeps the check from being deleted"
    return
  fi
  pass "$name"
}

test_rewrite_hook_allows_ordinary_editing() {
  local name="rewriteHookAllowsOrdinaryEditing"
  local dir="${work_dir}/rewrite-edit"
  make_rewrite_repo "$dir"

  # Change six of forty lines. Editing, not replacement.
  sed -i.bak '1,6s/original/revised/' "${dir}/docs/plans/F9.md" && rm -f "${dir}/docs/plans/F9.md.bak"
  git -C "$dir" add docs/plans/F9.md
  printf 'docs(F9): tighten the summary\n' > "${dir}/msg"

  if ! ( cd "$dir" && "$CHECK_REWRITE" msg >/dev/null 2>&1 ); then
    fail "$name" "ordinary editing was refused" \
      "a check that fires on normal work is one somebody turns off"
    return
  fi
  pass "$name"
}

test_rewrite_hook_ignores_a_new_file() {
  local name="rewriteHookIgnoresANewFile"
  local dir="${work_dir}/rewrite-add"
  make_rewrite_repo "$dir"

  printf 'brand new\n' > "${dir}/docs/plans/F10.md"
  git -C "$dir" add docs/plans/F10.md
  printf 'docs(F10): a new plan\n' > "${dir}/msg"

  if ! ( cd "$dir" && "$CHECK_REWRITE" msg >/dev/null 2>&1 ); then
    fail "$name" "adding a file was treated as a rewrite" \
      "an added file has nothing to destroy"
    return
  fi
  pass "$name"
}

test_no_writes_hook_catches_new_endpoint
test_no_writes_hook_catches_bare_path
test_no_writes_hook_catches_builder_path
test_no_writes_hook_allows_close
test_secrets_file_is_git_ignored
test_rewrite_hook_refuses_wholesale_replacement
test_rewrite_hook_allows_a_declared_rewrite
test_rewrite_hook_allows_ordinary_editing
test_rewrite_hook_ignores_a_new_file
test_licence_check_catches_a_disjunction
test_licence_check_catches_a_per_channel_grant
test_licence_check_catches_the_binary_phrasing
test_licence_check_allows_ordinary_prose
test_licence_check_allows_the_pledge

echo
echo "run-script-tests.sh: ${passed} passed, ${failed} failed"
[[ $failed -eq 0 ]]
