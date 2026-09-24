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
  printf 'GNU General Public License\n' > "${dir}/LICENSE"
  git -C "$dir" add README.md LICENSE
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
# **A CHECK THAT REPORTS OK ON AN EMPTY READ CAN BE SWITCHED OFF BY SUCCEEDING.**
# Pointed at a directory that is not this repository, it must refuse rather than
# find nothing and pass. This is the seam's own risk, tested.
test_licence_check_refuses_an_empty_read() {
  local name="licenceCheckRefusesAnEmptyRead"
  local dir="${work_dir}/licence-empty"
  mkdir -p "$dir"
  git -C "$dir" init --quiet
  git -C "$dir" config user.email t@example.com
  git -C "$dir" config user.name test

  if ( LICENCE_CHECK_ROOT="$dir" "$CHECK_LICENCE" >/dev/null 2>&1 ); then
    fail "$name" "the check passed on a directory with nothing in it" \
      "an env var that makes a guard succeed is an env var that disables it"
    return
  fi
  pass "$name"
}

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


# --- gen_status.py -----------------------------------------------------------
#
# THE PAGE THIS GENERATOR WRITES CLAIMED TO BE GENERATED BY IT FOR THE LIFE OF
# THE PROJECT, AND THE SCRIPT DID NOT EXIST (O42). So these tests exist to make
# the opposite mistake impossible: a generator nobody runs, and a --check nobody
# has seen fail, are the same defect wearing different clothes.
#
# Everything runs against a fixture repository in a temporary directory, never
# against this one.

# A GENERATOR THAT EXITS NON-ZERO MUST FAIL ONE TEST, NOT KILL THE SUITE.
# This runner sets `set -e`, so a bare `python3 gen_status.py` aborted the whole
# script the moment the generator returned 1 - the run printed its banner, exited
# 1, and reported NOTHING. That is a suite that stopped running, which the harness
# contract in docs/conventions.md names as the thing an exit code cannot show.
# Found by C37-M5, which broke splice_open and got no failure report back.
gen_or_fail() {
  local name="$1" dir="$2" out
  if ! out="$(python3 "${dir}/scripts/gen_status.py" 2>&1)"; then
    fail "$name" "the generator exited non-zero, and this test expected it to write" "$out"
    return 1
  fi
  return 0
}
# `|| return 0`, NOT `|| return`, at every call site. The first version returned
# the helper's 1, the test function returned 1, and `set -e` killed the runner at
# the top-level call - so the suite reported ONE failure and abandoned the other
# 43. `fail` has already recorded the failure by then; the test's own exit status
# carries no further information and must not be allowed to stop the run.

make_status_repo() {
  local dir="$1"
  mkdir -p "${dir}/scripts" "${dir}/docs/plans" "${dir}/docs/chores" "${dir}/docs/specs" \
           "${dir}/docs/reviews"
  cp "${SCRIPTS_DIR}/gen_status.py" "${dir}/scripts/gen_status.py"
  cp "${SCRIPTS_DIR}/check_register_rows.py" "${dir}/scripts/check_register_rows.py"

  # OPEN.MD IS PART OF THE FIXTURE SINCE C37, WITH BOTH MARKER PAIRS AND PROSE
  # OUTSIDE THEM. It is here because leaving it out broke every status test the
  # moment the generator learned to write this file - the fixture repo had no
  # OPEN.md, the marker refusal fired, and `make checks` failed on a file no test
  # was about. A fixture that omits an artefact the generator writes tests the
  # generator with that artefact switched off.
  cat > "${dir}/docs/reviews/OPEN.md" <<'OPENMD'
# Open items — fixture

Prose above the markers. This line is hand-maintained and must survive.

## Needs the owner

<!-- BEGIN GENERATED: owner -->
<!-- END GENERATED: owner -->

Prose between the regions, which must also survive.

## Needs the agent

<!-- BEGIN GENERATED: agent -->
<!-- END GENERATED: agent -->

Prose below the markers.
OPENMD

  cat > "${dir}/docs/specs/thing.md" <<'SPEC'
# Thing — spec

## The vision sentence

> A thing that does the thing.
SPEC

  cat > "${dir}/docs/plans/F1.md" <<'PLAN'
# F1 — First

**Status:** plan written, awaiting the gate.

F1-T1 and F1-T2 and F1-T2 again.
PLAN

  # THE THREE FIXTURE DELTAS CARRY THREE DIFFERENT STATUSES ON PURPOSE - one
  # ratified, one proposed, one rejected. A fixture where they agreed would
  # distinguish nothing, which is why C28 wrote its unknown-status fixture with
  # three differing rows. D3's heading carries the word REJECTED, which is FIRST
  # in the status precedence, so it is also the fixture that catches a status
  # window reaching into the following delta's heading.
  cat > "${dir}/docs/plans/00-deltas.md" <<'DELTAS'
# Proposed spec deltas — fixture

## Index

| Delta | Status | |
|---|---|---|
| **D1** | ratified | A decision that was ratified |
| **D2** | proposed | A decision that is only proposed |
| **D3** | REJECTED | A decision that was refused |

*3 deltas.*

## D1 — A decision that was ratified

**Ratified 2026-01-01.**

Body, so the status window does not reach the next heading.

## D2 — A decision that is only proposed

**Proposed 2026-01-02.**

Body, so the status window does not reach the next heading.

## D3 — ~~A decision that was refused~~ **REJECTED 2026-01-03.**

**Proposed 2026-01-03. REJECTED 2026-01-03.**

Body, so the status window does not reach the next heading.
DELTAS

  # `## Decisions (D)` IS A GENERATED REGION SINCE C34 (D37). The overlay heading
  # deliberately does not end in `(D)`, so SECTION_SYMBOL skips it and D2 is not
  # counted as a second D register.
  cat > "${dir}/docs/plans/00-register.md" <<'REG'
# Register

## Owner items (O)

| ID | Title | P | Status | Why |
|---|---|---|---|---|
| O1 | An item that is open | P0 | open | because |
| O2 | An item that is closed | P1 | closed | because |
| O3 | An item nobody gave a status | P2 |  | because |

## Decisions — owner fields

| ID | P | TD |
|---|---|---|
| D2 | P1 | td:6hFixtureFixture |

## Decisions (D)

<!-- BEGIN GENERATED: decisions — written from docs/plans/00-deltas.md (D37). -->
<!-- END GENERATED: decisions -->

## Hooks (H)

| ID | Title | P | Status |
|---|---|---|---|
| H1 | A hook whose title holds an escaped pipe in `a \| b` | P0 | closed |
| H2 | A hook with no pipe in it at all | P1 | open |
REG
}

test_status_check_passes_when_generated() {
  local name="statusCheckPassesWhenGenerated"
  local dir="${work_dir}/status-fresh"
  make_status_repo "$dir"

  gen_or_fail "$name" "$dir" || return 0
  if ! python3 "${dir}/scripts/gen_status.py" --check >/dev/null 2>&1; then
    fail "$name" "--check failed on a page it had just written" \
      "a check that cannot pass is one nobody will keep in CI"
    return
  fi
  pass "$name"
}

test_status_check_catches_a_hand_edit() {
  local name="statusCheckCatchesAHandEdit"
  local dir="${work_dir}/status-edit"
  make_status_repo "$dir"
  gen_or_fail "$name" "$dir" || return 0

  # THE MUTATION. The page says "do not edit by hand"; this edits it by hand,
  # changing a count to a number nobody derived. Before --check existed, this
  # was undetectable and is exactly how the real page came to report F8 as
  # having no code for six days.
  printf 'and one more line nobody generated\n' >> "${dir}/docs/plans/00-status.md"

  # The mutation must actually have changed the file. An edit that silently did
  # nothing would make the assertion below pass for the wrong reason, which is
  # how this test failed the first time it was run.
  if ! grep -q 'nobody generated' "${dir}/docs/plans/00-status.md"; then
    fail "$name" "the test's own mutation did not change the page" \
      "an assertion whose setup failed proves nothing"
    return
  fi

  if python3 "${dir}/scripts/gen_status.py" --check >/dev/null 2>&1; then
    fail "$name" "a hand edit to the generated page passed --check" \
      "the page's own header forbids hand edits; nothing was enforcing it"
    return
  fi
  pass "$name"
}

test_status_check_catches_a_stale_page() {
  local name="statusCheckCatchesAStalePage"
  local dir="${work_dir}/status-stale"
  make_status_repo "$dir"
  gen_or_fail "$name" "$dir" || return 0

  # The register changes and nobody regenerates — the real-world case. An item
  # is closed, so the open count and the open table must both move.
  perl -pi -e 's/\| O1 \| An item that is open \| P0 \| open \|/| O1 | An item that is open | P0 | closed |/' \
    "${dir}/docs/plans/00-register.md"

  if python3 "${dir}/scripts/gen_status.py" --check >/dev/null 2>&1; then
    fail "$name" "a register edit left the page stale and --check passed" \
      "this is the failure O42 describes: the page cannot correct itself"
    return
  fi
  pass "$name"
}

test_status_page_does_not_guess_an_absent_status() {
  local name="statusPageDoesNotGuessAnAbsentStatus"
  local dir="${work_dir}/status-unknown"
  make_status_repo "$dir"
  gen_or_fail "$name" "$dir" || return 0
  local page="${dir}/docs/plans/00-status.md"

  # O3 has an EMPTY status cell. It must be counted unknown, never open, and it
  # must not appear in the open table. conventions.md names this exact defect:
  # a status page that reported `open` for rows nobody had given a status, and a
  # register parser that returned the same value for every row while fifteen
  # assertions passed.
  if ! grep -q '^| Owner items (`O`) | 3 | 1 | 1 | 1 |$' "$page"; then
    fail "$name" "the O register did not count 1 open, 1 unknown, 1 closed" \
      "an absent status must be unknown, not open"
    return
  fi
  if grep -q 'O3' "$page"; then
    fail "$name" "a row with no status appeared in the open table" \
      "the page must not promote silence into a claim"
    return
  fi
  # And the fixture is not a tautology: the three rows differ, so a parser that
  # returned one value for all of them would fail the count above.
  if ! grep -q '| owner | O1 | P0 | open |' "$page"; then
    fail "$name" "the genuinely open row was missing from the open table" \
      "the check above would pass vacuously if nothing were listed"
    return
  fi
  pass "$name"
}


test_status_page_counts_a_scoped_mutation_id() {
  local name="statusPageCountsAScopedMutationId"
  local dir="${work_dir}/status-scoped"
  make_status_repo "$dir"

  # C33 backfilled `## Mutations (M)`, and 81 of this project's 103 mutation ids
  # are scoped to the unit that owns them — `F8-M1`, `C32-M7`. The generator's
  # row filter was `[A-Z]{1,2}\d+`, which rejects every one of them WITHOUT A
  # WORD, so the section would have reported 22 rows against 103 real ids on a
  # page CI keeps current.
  #
  # THE FIXTURE CARRIES THREE ROWS ON PURPOSE. One bare, one scoped, and one
  # junk. A fixture holding only the scoped row would pass under a filter that
  # accepted every string — the tautology with a green tick conventions.md
  # names — so the junk row is what makes this test able to fail in the other
  # direction.
  cat >> "${dir}/docs/plans/00-register.md" <<'REG'

## Mutations (M)

| ID | Title | P | Status |
|---|---|---|---|
| M1 | A bare, global mutation id |  | closed |
| F8-M1 | A mutation scoped to the unit that owns it |  | closed |
| MUTATION-X | Not an id at all |  | closed |
REG

  gen_or_fail "$name" "$dir" || return 0
  local page="${dir}/docs/plans/00-status.md"

  if ! grep -q '^| Mutations (`M`) | 2 | 0 | 0 | 2 |$' "$page"; then
    fail "$name" "the M register did not count exactly 2 rows" \
      "a scoped id must be counted (or the junk id must not be): $(grep -F 'Mutations (`M`)' "$page")"
    return
  fi
  pass "$name"
}

# C37 made docs/reviews/OPEN.md generated. These two are the artefact's own tests:
# the fixture gained an OPEN.md and, until these were written, NOTHING asserted
# that the splice wrote rows or that the prose outside the markers survived - the
# `D46` pattern, a second artefact emitted by a feature whose primary output is
# checked rigorously.
# THE SPLIT THE FACTS SCRIPT DEPENDS ON, AND WHICH SHIPPED BROKEN.
# `api_get` appends the HTTP status on its own last line, so every claim splits
# the response into body and code. That split was written out seven times, and
# two of the seven shipped as `sed '\$d'` — a stray backslash that sed rejects as
# an unterminated regular expression. The body came back EMPTY, python got
# nothing, and CLAIM 4 died in a JSONDecodeError on the owner's machine.
#
# `check_embedded_python.py` could not have caught it: the embedded Python
# compiled perfectly. It was the shell feeding it that was broken — the
# second-artefact problem `D46` names, one layer down.
#
# This drives the real functions out of the real script, on a fixture shaped like
# a real response, and asserts BOTH halves. It does not need a token: it never
# calls api_get.
# CLAIM 4 OF THE FACTS SCRIPT, RUN — not merely compiled.
# It shipped broken and the OWNER found it: the embedded python was fine, the
# shell feeding it had `sed '\$d'` with a stray backslash, the body came back
# empty, and python died in a JSONDecodeError on their machine. check_embedded_python
# said OK throughout, because the python was never the problem.
#
# CI has no Todoist token, so the claim cannot be run against the real API. This
# runs its REAL code — the script's own body/code helpers and its own embedded
# programs, lifted out by scripts/tests/probe_facts_claim4.py — against a fixture.
# The fixture is chosen so the two answers differ: one of three projects carries
# no `color` key, and the three tasks do not all share a priority.
test_facts_claim4_reports_from_a_fixture() {
  local name="factsClaim4ReportsFromAFixture"
  local out

  out="$(bash <(python3 "${SCRIPT_DIR}/probe_facts_claim4.py") 2>&1)" || {
    fail "$name" "CLAIM 4 exited non-zero against a fixture" "$out"
    return 0
  }

  # The colour half: it must count the projects, name the colours, and single out
  # the workspace-shaped one that sends no key.
  local wanted
  for wanted in \
    "3 project(s), 2 carrying a color key" \
    "berry_red" \
    "olive_green" \
    "1 project(s) send NO color key" \
    "Shared" \
    "VERDICT: colour is present as a NAME"
  do
    if [[ "$out" != *"$wanted"* ]]; then
      fail "$name" "CLAIM 4 did not report the colours" "missing: ${wanted}" "$out"
      return 0
    fi
  done

  # The priority half: the tally, and the one task whose priority is not the
  # default — which is the line the owner reads to answer the direction question.
  for wanted in \
    "3 task(s), 3 carrying a priority key" \
    "{1: 2, 4: 1}" \
    "lowest=1  highest=4  most common=1" \
    "priority=4  id=t1  File the form" \
    "P1 (most urgent) on the wire is"
  do
    if [[ "$out" != *"$wanted"* ]]; then
      fail "$name" "CLAIM 4 did not report the priorities" "missing: ${wanted}" "$out"
      return 0
    fi
  done

  # AND NO TRACEBACK, which is how the real failure presented.
  if [[ "$out" == *"Traceback"* || "$out" == *"unterminated"* ]]; then
    fail "$name" "CLAIM 4 produced an error rather than a report" "$out"
    return 0
  fi
  pass "$name"
}

test_the_facts_script_splits_body_from_status() {
  local name="factsScriptSplitsBodyFromStatus"

  # The functions are defined above the token prompt, so the file cannot simply
  # be sourced. Take the two definitions out of the shipped file — by name, so a
  # renamed or deleted helper fails this test rather than skipping it.
  local defs
  defs="$(grep -E '^(body|code)\(\) \{' "${SCRIPTS_DIR}/check-todoist-facts.sh")"

  if [[ "$(grep -c . <<<"$defs")" != "2" ]]; then
    fail "$name" "check-todoist-facts.sh no longer defines both body() and code()" \
      "got: ${defs}"
    return 0
  fi

  # A response shaped like the real thing: JSON, then the status on its own line.
  # The JSON deliberately contains a `$` and a trailing brace, so a split that
  # mangles either shows up.
  local response='{"results":[{"id":"p1","color":"berry_red","name":"A $ sign"}]}
200'
  # `|| got_body=""` IS NOT DEFENSIVE CLUTTER. The whole point of this test is a
  # `body()` whose sed fails, and under `set -e` a failing command substitution in
  # an assignment aborts the runner — which is how the first version of this test
  # killed the suite instead of failing, for the THIRD time today after
  # gen_or_fail and expect_validator_catches. A test about a broken command must
  # survive the command being broken.
  local got_body got_code
  got_body="$(eval "$defs"; body "$response" 2>/dev/null)" || got_body=""
  got_code="$(eval "$defs"; code "$response" 2>/dev/null)" || got_code=""

  if [[ "$got_code" != "200" ]]; then
    fail "$name" "code() did not return the status line" "wanted: 200" "got: ${got_code}"
    return 0
  fi
  if [[ "$got_body" != '{"results":[{"id":"p1","color":"berry_red","name":"A $ sign"}]}' ]]; then
    fail "$name" "body() did not return the response without its status line" \
      "got: ${got_body}"
    return 0
  fi
  # AND IT MUST BE PARSEABLE, which is the thing the script actually needs and
  # the assertion the broken version would have failed: an empty body is a
  # perfectly good string and a useless one.
  if ! printf '%s' "$got_body" | python3 -c '
import json,sys
d=json.load(sys.stdin)
sys.exit(0 if d["results"][0]["color"] == "berry_red" else 1)'; then
    fail "$name" "body() produced something python could not read as the response"
    return 0
  fi
  pass "$name"
}

test_open_regions_are_written_and_prose_survives() {
  local name="openRegionsAreWrittenAndProseSurvives"
  local dir="${work_dir}/open-splice"
  make_status_repo "$dir"

  cat >> "${dir}/docs/plans/00-register.md" <<'REG'

## Owner items (O)

| ID | Title | P | Status | Mode | From | Why | TD |
|---|---|---|---|---|---|---|---|
| O1 | An owner item still open | P1 | open | @Review | F1 | Because the owner has not ruled. | — |
| O2 | An owner item closed | — | closed | — | F1 | Closed on the device. | — |

## Agent items (A)

| ID | Title | P | Status | Mode | From | Why | TD |
|---|---|---|---|---|---|---|---|
| A1 | An agent item | P2 | open | @agent | F1 | Because nothing has run it. | — |
REG

  gen_or_fail "$name" "$dir" || return 0
  local open_md="${dir}/docs/reviews/OPEN.md"

  # The assertions read the FILE, not the function's return value. A closed row
  # is struck and an open one is not, which is the one thing a reader of this
  # file uses it for.
  if ! grep -q '^| O1 | \*\*An owner item still open\*\* | F1 | Because the owner has not ruled. |$' "$open_md"; then
    fail "$name" "the open owner row was not written as OPEN.md's own shape" \
      "got: $(grep -E '^\| O1 ' "$open_md")"
    return
  fi
  if ! grep -q '^| ~~O2~~ | ~~\*\*An owner item closed\*\*~~ | F1 | Closed on the device. |$' "$open_md"; then
    fail "$name" "the closed owner row was not struck" \
      "got: $(grep -E 'O2' "$open_md")"
    return
  fi
  if ! grep -q '^| A1 | \*\*An agent item\*\* | F1 | Because nothing has run it. |$' "$open_md"; then
    fail "$name" "the agent region was not written" \
      "got: $(grep -E '^\| A1 ' "$open_md")"
    return
  fi
  # An O row must not land in the agent region, nor an A row in the owner region.
  if [[ "$(awk '/BEGIN GENERATED: agent/,/END GENERATED: agent/' "$open_md" | grep -c '^| ~\?~\?O')" != "0" ]]; then
    fail "$name" "an owner row was written into the agent region"
    return
  fi
  # THE PROSE IS THE POINT. 83 lines of it exist only in the real file.
  local line
  for line in "Prose above the markers" "Prose between the regions" "Prose below the markers"; do
    if ! grep -q "$line" "$open_md"; then
      fail "$name" "prose outside the markers was destroyed: '${line}'"
      return
    fi
  done
  pass "$name"
}

test_open_generator_refuses_a_missing_marker() {
  local name="openGeneratorRefusesAMissingMarker"
  local dir="${work_dir}/open-marker"
  make_status_repo "$dir"

  local open_md="${dir}/docs/reviews/OPEN.md"
  gen_or_fail "$name" "$dir" || return 0
  local before
  before="$(cat "$open_md")"
  grep -v 'BEGIN GENERATED: owner' "$open_md" > "${open_md}.cut" && mv "${open_md}.cut" "$open_md"
  local cut
  cut="$(cat "$open_md")"

  local out status
  out="$(python3 "${dir}/scripts/gen_status.py" 2>&1)" && status=0 || status=$?

  if [[ "$status" == "0" ]]; then
    fail "$name" "the generator wrote into a file whose marker pair was broken" "$out"
    return
  fi
  if ! grep -q "Nothing was written" <<<"$out"; then
    fail "$name" "it failed, but did not say that nothing was written" "$out"
    return
  fi
  # NOTHING WAS WRITTEN is read off the file, not off the message. A generator
  # that prints the words and writes anyway is the failure this test is for.
  if [[ "$(cat "$open_md")" != "$cut" ]]; then
    fail "$name" "it said nothing was written and then wrote"
    return
  fi
  pass "$name"
}

test_status_page_names_the_agent_register() {
  local name="statusPageNamesTheAgentRegister"
  local dir="${work_dir}/status-agent"
  make_status_repo "$dir"

  # D36 opened `## Agent items (A)`. A register symbol gen_status.py does not
  # know falls into `extra`, which prints THE SYMBOL AS ITS OWN NAME, so the
  # page shipped `A (`A`)` - the register unnamed, on a page CI keeps current.
  # The assertion is on the rendered line, not on KNOWN_REGISTERS, because a
  # test that re-derives its expected value cannot see the path that produces
  # the real one.
  cat >> "${dir}/docs/plans/00-register.md" <<'REG'

## Agent items (A)

| ID | Title | P | Status |
|---|---|---|---|
| A1 | A finding only the agent can close | P1 | open |
| A2 | One that is closed |  | closed |
REG

  gen_or_fail "$name" "$dir" || return 0
  local page="${dir}/docs/plans/00-status.md"

  if ! grep -q '^| Agent items (`A`) | 2 | 1 | 0 | 1 |$' "$page"; then
    fail "$name" "the A register was not named, or was miscounted" \
      "got: $(grep -E '^\| (Agent items|A) \(`A`\)' "$page")"
    return
  fi
  pass "$name"
}


# --- The generated decisions region (D37) ------------------------------------

test_decisions_region_is_generated_from_the_deltas_file() {
  local name="decisionsRegionIsGeneratedFromTheDeltasFile"
  local dir="${work_dir}/decisions-region"
  make_status_repo "$dir"
  gen_or_fail "$name" "$dir" || return 0
  local reg="${dir}/docs/plans/00-register.md"

  # One row per delta, in ID order, carrying the status the DEFINITION declares -
  # not the index's, whose titles are paraphrases and whose Status column no test
  # checks. D3's `rejected` is the half that proves the precedence: its own body
  # says "Proposed 2026-01-03. REJECTED 2026-01-03."
  local want='| D1 | A decision that was ratified | — | ratified |  |
| D2 | A decision that is only proposed | P1 | proposed | td:6hFixtureFixture |
| D3 | ~~A decision that was refused~~ **REJECTED 2026-01-03.** | — | rejected |  |'
  local got
  got=$(sed -n '/BEGIN GENERATED: decisions/,/END GENERATED: decisions/p' "$reg" \
    | grep -E '^\| D[0-9]')
  if [[ "$got" != "$want" ]]; then
    fail "$name" "the generated region is not the three fixture deltas, sorted, with their own statuses" \
      "want: ${want}" "got:  ${got}"
    return
  fi

  # And the generator touched nothing outside the markers.
  if ! grep -q '^| O3 | An item nobody gave a status | P2 |  | because |$' "$reg"; then
    fail "$name" "the splice altered a hand-maintained row outside the region" \
      "the contract is text[:end of BEGIN] + rendered + text[start of END:]"
    return
  fi
  pass "$name"
}

test_decisions_region_carries_the_owner_overlay() {
  local name="decisionsRegionCarriesTheOwnerOverlay"
  local dir="${work_dir}/decisions-overlay"
  make_status_repo "$dir"
  gen_or_fail "$name" "$dir" || return 0

  # D30's real P0 and Todoist id exist in no column of 00-deltas.md, so a
  # regeneration that did not merge them would DELETE a link the owner's own sync
  # uses. The assertion is on the rendered row, not on the overlay dict.
  if ! grep -q '^| D2 | A decision that is only proposed | P1 | proposed | td:6hFixtureFixture |$' \
    "${dir}/docs/plans/00-register.md"; then
    fail "$name" "the overlay's P and TD did not reach the generated row" \
      "got: $(grep -E '^\| D2 \|' "${dir}/docs/plans/00-register.md")"
    return
  fi
  # The rows with no overlay entry must render `—` for P and an empty TD, not the
  # previous row's values - which is what a merge that leaks looks like.
  if ! grep -q '^| D1 | A decision that was ratified | — | ratified |  |$' \
    "${dir}/docs/plans/00-register.md"; then
    fail "$name" "a row with no overlay entry did not render — for P and an empty TD" \
      "got: $(grep -E '^\| D1 \|' "${dir}/docs/plans/00-register.md")"
    return
  fi
  pass "$name"
}

test_overlay_naming_an_undefined_delta_is_refused() {
  local name="overlayNamingAnUndefinedDeltaIsRefused"
  local dir="${work_dir}/decisions-overlay-bad"
  make_status_repo "$dir"
  gen_or_fail "$name" "$dir" || return 0
  local reg="${dir}/docs/plans/00-register.md"
  local before
  before=$(cat "$reg")

  # THE MUTATION. An overlay row keyed to a decision 00-deltas.md does not
  # define. A Todoist id keyed to nothing is C33's dropped-TD cell one file over,
  # so it must be REFUSED rather than dropped.
  perl -pi -e 's/^\| D2 \| P1 \|/| D44 | P1 |/' "$reg"
  if ! grep -q '^| D44 | P1 |' "$reg"; then
    fail "$name" "the test's own mutation did not change the overlay" \
      "an assertion whose setup failed proves nothing"
    return
  fi
  before=$(cat "$reg")

  local err
  err=$(python3 "${dir}/scripts/gen_status.py" 2>&1) && {
    fail "$name" "an overlay naming an undefined delta was accepted"
    return
  }
  if [[ "$err" != *"D44"* ]]; then
    fail "$name" "the refusal did not name D44" "got: ${err}"
    return
  fi
  if [[ "$(cat "$reg")" != "$before" ]]; then
    fail "$name" "the generator wrote to the register after refusing" \
      "a refusal that half-writes is worse than no refusal"
    return
  fi
  pass "$name"
}

test_markerless_register_is_refused() {
  local name="markerlessRegisterIsRefused"
  local dir="${work_dir}/decisions-markerless"
  make_status_repo "$dir"
  gen_or_fail "$name" "$dir" || return 0
  local reg="${dir}/docs/plans/00-register.md"

  # THE MUTATION. Delete the BEGIN marker, leaving the table and the END marker.
  perl -ni -e 'print unless /BEGIN GENERATED: decisions/' "$reg"
  if grep -q 'BEGIN GENERATED: decisions' "$reg"; then
    fail "$name" "the test's own mutation did not remove the marker" \
      "an assertion whose setup failed proves nothing"
    return
  fi
  local before
  before=$(cat "$reg")

  # WRITE MODE IS THE HALF THAT MATTERS. A generator that silently appends when it
  # cannot find its region, or writes nothing and prints success, is O42's defect
  # rebuilt one layer in.
  local err
  err=$(python3 "${dir}/scripts/gen_status.py" 2>&1) && {
    fail "$name" "write mode accepted a register with no BEGIN marker"
    return
  }
  if [[ "$err" != *"BEGIN GENERATED: decisions"* ]]; then
    fail "$name" "the refusal did not name the marker" "got: ${err}"
    return
  fi
  if [[ "$(cat "$reg")" != "$before" ]]; then
    fail "$name" "write mode altered the register after refusing"
    return
  fi
  if python3 "${dir}/scripts/gen_status.py" --check >/dev/null 2>&1; then
    fail "$name" "--check accepted a register with no BEGIN marker"
    return
  fi
  pass "$name"
}

test_hand_edit_inside_the_region_fails_check() {
  local name="handEditInsideTheRegionFailsCheck"
  local dir="${work_dir}/decisions-hand-edit"
  make_status_repo "$dir"
  gen_or_fail "$name" "$dir" || return 0
  local reg="${dir}/docs/plans/00-register.md"

  # THE MUTATION. Change a status by hand INSIDE the generated region - the same
  # shape as editing D35 from `ratified` to `proposed` in the real file.
  perl -pi -e 's/\| D1 \| A decision that was ratified \| — \| ratified \|/| D1 | A decision that was ratified | — | proposed |/' "$reg"
  if ! grep -q 'A decision that was ratified | — | proposed' "$reg"; then
    fail "$name" "the test's own mutation did not change the region" \
      "an assertion whose setup failed proves nothing"
    return
  fi

  local err
  err=$(python3 "${dir}/scripts/gen_status.py" --check 2>&1) && {
    fail "$name" "a hand edit inside the generated region passed --check"
    return
  }
  # The FAIL line must NAME THE FILE. Before C34 the message named none, because
  # there was only one artefact; with two, a diff with no filename sends the
  # reader to the wrong document.
  if [[ "$err" != *"FAIL — docs/plans/00-register.md"* ]]; then
    fail "$name" "the FAIL line did not name docs/plans/00-register.md" "got: ${err}"
    return
  fi
  pass "$name"
}

test_an_escaped_pipe_does_not_shift_a_row() {
  local name="anEscapedPipeDoesNotShiftARow"
  local dir="${work_dir}/escaped-pipe"
  make_status_repo "$dir"
  local reg="${dir}/docs/plans/00-register.md"

  # ASSERT THE FIXTURE FIRST. statusCheckCatchesAHandEdit failed the first time it
  # ran because it asserted the result of a mutation it had not landed.
  if ! grep -q 'escaped pipe in `a \\| b`' "$reg"; then
    fail "$name" "the fixture does not carry a row with an escaped pipe"
    return
  fi

  gen_or_fail "$name" "$dir" || return 0
  local page="${dir}/docs/plans/00-status.md"

  # THE DEFECT THIS PINS, found by C34's own gates. gen_status split a row on a
  # bare "|" while check_register_rows split on `(?<!\\)\|`, so a cell containing
  # an escaped pipe ENDED EARLY for one reader and not the other: every field
  # after it shifted one column left, H1's Status cell read `P0`, and because
  # `P0` is not in CLOSED the page printed a closed hook as OPEN. The validator
  # saw nothing, because by its own tokenizer the row was well formed.
  #
  # This is the confident-wrong-answer class C34 exists to stop, reached from
  # inside C34. The fix is one tokenizer imported by both readers, so the
  # assertion that matters is that the page agrees with the file.
  if ! grep -q '^| Hooks (`H`) | 2 | 1 | 0 | 1 |$' "$page"; then
    fail "$name" "the H register did not count 2 rows, 1 open, 0 unknown, 1 closed" \
      "an escaped pipe shifted the row and the page read Status from the wrong cell" \
      "got: $(grep -F 'Hooks (`H`)' "$page")"
    return
  fi

  # The same row must not surface in the open table, which is where a misread
  # status actually reaches the owner.
  if grep -q '^| owner | H1 |' "$page"; then
    fail "$name" "a closed hook appeared in the open table"
    return
  fi
  pass "$name"
}

test_ratified_decisions_are_not_counted_open() {
  local name="ratifiedDecisionsAreNotCountedOpen"
  local dir="${work_dir}/decisions-closed"
  make_status_repo "$dir"
  gen_or_fail "$name" "$dir" || return 0
  local page="${dir}/docs/plans/00-status.md"

  # `ratified` was not in gen_status.CLOSED, so all 40 ratified deltas would have
  # been counted OPEN and printed in the owner-owned open table - a wrong number of
  # exactly the class D37 was opened to fix. The fixture's three statuses differ,
  # so a vocabulary that bucketed them all one way fails this count.
  if ! grep -q '^| Decisions (`D`) | 3 | 1 | 0 | 2 |$' "$page"; then
    fail "$name" "the D register did not count 3 rows, 1 open, 0 unknown, 2 closed" \
      "got: $(grep -F 'Decisions (`D`)' "$page")"
    return
  fi
  if grep -q '^| owner | D1 |' "$page"; then
    fail "$name" "a ratified decision appeared in the open table" \
      "ratified is finished work; printing it as open is the number D37 was opened to fix"
    return
  fi
  if ! grep -q '^| owner | D2 |' "$page"; then
    fail "$name" "the genuinely proposed decision was missing from the open table" \
      "the check above would pass vacuously if nothing were listed"
    return
  fi
  pass "$name"
}

test_the_command_the_failure_message_prints_actually_fixes_it() {
  local name="theCommandTheFailureMessagePrintsActuallyFixesIt"
  local dir="${work_dir}/decisions-remedy"
  make_status_repo "$dir"
  gen_or_fail "$name" "$dir" || return 0

  # D46: a feature that tells a human to run something has emitted a SECOND
  # artefact, and it needs the same treatment as the first. So the command is
  # EXTRACTED from the failure message and run verbatim, rather than a command the
  # test re-derives and believes is the same one.
  perl -pi -e 's/\| ratified \|  \|/| proposed |  |/ if /A decision that was ratified/' \
    "${dir}/docs/plans/00-register.md"
  if ! grep -q 'A decision that was ratified | — | proposed' "${dir}/docs/plans/00-register.md"; then
    fail "$name" "the test's own mutation did not change the region" \
      "an assertion whose setup failed proves nothing"
    return
  fi

  local remedy
  # `|| true` because --check exits 1 by design here and `set -o pipefail` would
  # otherwise kill the run on the very failure this test is reading.
  remedy=$(python3 "${dir}/scripts/gen_status.py" --check 2>&1 \
    | sed -n 's/^ *Regenerate with: //p' | head -1 || true)
  if [[ -z "$remedy" ]]; then
    fail "$name" "the failure message printed no remedy to extract" \
      "a message that names no command is a message that cannot be tested"
    return
  fi
  if ! ( cd "$dir" && eval "$remedy" ) >/dev/null 2>&1; then
    fail "$name" "the command the failure message prints did not run: ${remedy}"
    return
  fi
  if ! python3 "${dir}/scripts/gen_status.py" --check >/dev/null 2>&1; then
    fail "$name" "the remedy ran but --check still fails: ${remedy}" \
      "the instruction the tool gives a human must actually fix what it reports"
    return
  fi
  pass "$name"
}

# --- check_register_rows.py --------------------------------------------------
#
# THE FIXTURE PASSES UNMUTATED, AND THAT IS WHAT MAKES EVERY TEST BELOW ABLE TO
# FAIL. A fixture that already failed the floor would exit 1 under every mutation
# for a reason no mutation caused - a tautology with a green tick. So it carries
# all seven register sections, an escaped pipe inside a code span, and
# C32-M9/C32-M10, the pair a lexical sort key mis-orders.

make_validator_repo() {
  local dir="$1"
  mkdir -p "${dir}/scripts" "${dir}/docs/plans"
  cp "${SCRIPTS_DIR}/gen_status.py" "${dir}/scripts/gen_status.py"
  cp "${SCRIPTS_DIR}/check_register_rows.py" "${dir}/scripts/check_register_rows.py"

  cat > "${dir}/docs/plans/00-register.md" <<'REG'
# Register — fixture

The generated region lies between the `BEGIN GENERATED: decisions` and
`END GENERATED: decisions` markers. THESE TWO MENTIONS ARE PROSE, NOT MARKERS,
and R9 must not count them — a file that cannot document its own region is worse
than a narrower match.

## Owner items (O)

| ID | Title | P | Status | TD |
|---|---|---|---|---|
| O1 | An open item | P0 | open |  |
| O2 | A closed item | P1 | closed |  |

## Decisions — owner fields

| ID | P | TD |
|---|---|---|
| D1 | P0 | td:6hFixtureFixture |

## Decisions (D)

<!-- BEGIN GENERATED: decisions — fixture -->
| ID | Title | P | Status | TD |
|---|---|---|---|---|
| D1 | A ratified decision | P0 | ratified | td:6hFixtureFixture |
| D2 | A proposed decision | — | proposed |  |
<!-- END GENERATED: decisions -->

## Chores (C)

| ID | Title | P | Status | Why | TD |
|---|---|---|---|---|---|
| C9 | A legacy chore the owner has not ruled on | P1 | unknown | because |  |
| C26 | A chore that is closed | P1 | closed | because |  |

## Agent items (A)

| ID | Title | P | Status |
|---|---|---|---|
| A7 | An agent finding | P1 | open |
| A8 | Another agent finding | P2 | closed |

## Mutations (M)

| ID | Title | P | Status | Run |
|---|---|---|---|---|
| C32-M9 | A scoped mutation id |  | closed | run |
| C32-M10 | The pair a lexical sort key mis-orders |  | closed | run |
| M1 | A bare, global mutation id |  | closed | run |

## Hooks (H)

| ID | Title | P | Status |
|---|---|---|---|
| H1 | A hook whose cell holds an escaped pipe in `a \| b` | P0 | closed |
| H2 | A hook that is not built yet | P1 | open |

## Risks (RR)

| ID | Title | P | Status |
|---|---|---|---|
| RR1 | A risk nobody has mitigated | P1 | open |
REG
}

# Run the validator against a fixture, printing stdout and stderr together.
validator_on() {
  python3 "$1/scripts/check_register_rows.py" 2>&1
}

# Every negative test has the same three steps: mutate, PROVE THE MUTATION
# LANDED, then assert. statusCheckCatchesAHandEdit failed the first time it ran
# for want of the middle step.
# IT RETURNS 0 EVEN WHEN IT FAILS, and that is deliberate. It is the LAST
# statement of nine test functions, so a `return 1` made each of those functions
# return 1, and `set -e` then killed the runner at the top-level call - the exact
# defect C37-M5 found at the sixteen generator sites, still live here. Trigger
# that found it: make check_register_rows.py exit 0 unconditionally; the run
# reported 33 of 44 tests and printed no summary line at all. `fail` has already
# recorded the failure; the exit status carries nothing further.
expect_validator_catches() {
  local name="$1" dir="$2" wanted="$3"
  local out
  if out=$(validator_on "$dir"); then
    fail "$name" "the validator passed a register it should have refused" "got: ${out}"
    return 0
  fi
  if [[ "$out" != *"$wanted"* ]]; then
    fail "$name" "the finding did not say what it was supposed to say" \
      "wanted a message containing: ${wanted}" "got: ${out}"
    return 0
  fi
  pass "$name"
}

test_the_shipped_register_passes_the_validator() {
  local name="theShippedRegisterPassesTheValidator"

  # THIS IS THE TEST THAT WOULD HAVE CAUGHT A LEXICAL SORT KEY. gen_status's old
  # key reported FOUR correctly-ordered mutation pairs as out of order, so R6 on
  # that key would have failed a correct file on its first run — and "a validator
  # that fails on something harmless gets disabled". It is the reason R6 can be an
  # error rather than a warning.
  local out
  if ! out=$(python3 "${SCRIPTS_DIR}/check_register_rows.py" 2>&1); then
    fail "$name" "the repository's own register does not pass the validator" "${out}"
    return
  fi
  if [[ "$out" != *"0 malformed"* ]]; then
    fail "$name" "the validator passed without reporting a count" \
      "an exit code cannot show a check that stopped reading" "got: ${out}"
    return
  fi
  pass "$name"
}

test_validator_passes_the_unmutated_fixture() {
  local name="registerValidatorPassesTheUnmutatedFixture"
  local dir="${work_dir}/validator-clean"
  make_validator_repo "$dir"
  local out
  if ! out=$(validator_on "$dir"); then
    fail "$name" "the fixture every negative test mutates does not pass unmutated" \
      "without this, every test below exits 1 for a reason no mutation caused" "${out}"
    return
  fi
  if [[ "$out" != *"14 rows across 7 register sections"* ]]; then
    fail "$name" "the fixture did not report 14 rows across 7 sections" "got: ${out}"
    return
  fi
  pass "$name"
}

test_validator_catches_a_surplus_cell() {
  local name="registerValidatorCatchesASurplusCell"
  local dir="${work_dir}/validator-surplus"
  make_validator_repo "$dir"
  # C33's EXACT DEFECT: a stray 7th cell copied from another table's column.
  # gen_status drops it in silence and `make check-status` stays green.
  perl -pi -e 's/^\| C26 \| A chore that is closed \| P1 \| closed \| because \|  \|$/| C26 | A chore that is closed | P1 | closed | because |  | \@chores |/' \
    "${dir}/docs/plans/00-register.md"
  if ! grep -q '@chores' "${dir}/docs/plans/00-register.md"; then
    fail "$name" "the test's own mutation did not add a cell"
    return
  fi
  expect_validator_catches "$name" "$dir" "7 cells where the section header has 6"
}

test_validator_catches_an_unescaped_pipe() {
  local name="registerValidatorCatchesAnUnescapedPipe"
  local dir="${work_dir}/validator-pipe"
  make_validator_repo "$dir"
  perl -pi -e 's/`a \\\| b`/`a | b`/' "${dir}/docs/plans/00-register.md"
  if grep -q 'a \\| b' "${dir}/docs/plans/00-register.md"; then
    fail "$name" "the test's own mutation did not unescape the pipe"
    return
  fi
  # THE MESSAGE MUST NAME THE QUOTING ERROR, not only the column count. A reader
  # sent to count columns for a defect that is an unescaped pipe looks in the
  # wrong place.
  expect_validator_catches "$name" "$dir" "unescaped pipe inside a \`code\` span"
}

test_validator_catches_a_duplicate_id() {
  local name="registerValidatorCatchesADuplicateId"
  local dir="${work_dir}/validator-dup"
  make_validator_repo "$dir"
  perl -pi -e 'print "| A7 | An agent finding | P1 | open |\n" if /^\| A8 \|/' \
    "${dir}/docs/plans/00-register.md"
  if [[ $(grep -c '^| A7 |' "${dir}/docs/plans/00-register.md") -ne 2 ]]; then
    fail "$name" "the test's own mutation did not duplicate A7"
    return
  fi
  expect_validator_catches "$name" "$dir" "A7 appears twice"
}

test_validator_catches_an_empty_status() {
  local name="registerValidatorCatchesAnEmptyStatus"
  local dir="${work_dir}/validator-empty-status"
  make_validator_repo "$dir"
  # R4 FIRES ON ZERO ROWS OF THE SHIPPED FILE. This mutation is its only evidence.
  perl -pi -e 's/^\| RR1 \| (.*) \| P1 \| open \|$/| RR1 | $1 | P1 |  |/' \
    "${dir}/docs/plans/00-register.md"
  if ! grep -qE '^\| RR1 \|.*\| P1 \|  \|$' "${dir}/docs/plans/00-register.md"; then
    fail "$name" "the test's own mutation did not blank the status"
    return
  fi
  expect_validator_catches "$name" "$dir" "RR1 has an empty \`Status\` cell"
}

test_validator_catches_an_unknown_status_outside_the_exception_set() {
  local name="registerValidatorCatchesAnUnknownStatusOutsideTheExceptionSet"
  local dir="${work_dir}/validator-vocab"
  make_validator_repo "$dir"

  # (a) A value in no vocabulary at all.
  perl -pi -e 's/^\| C26 \| (.*) \| P1 \| closed \|/| C26 | $1 | P1 | wontfix |/' \
    "${dir}/docs/plans/00-register.md"
  if ! grep -q 'wontfix' "${dir}/docs/plans/00-register.md"; then
    fail "$name" "the test's own mutation (a) did not change the status"
    return
  fi
  local out
  if out=$(validator_on "$dir"); then
    fail "$name" "a status of wontfix was accepted" "got: ${out}"
    return
  fi
  if [[ "$out" != *"C26 carries \`wontfix\`"* ]]; then
    fail "$name" "the finding did not name C26 and wontfix" "got: ${out}"
    return
  fi

  # (b) `unknown` — a value NINE OTHER ROWS LEGITIMATELY CARRY. This is the half
  # that proves the exception is by ID and not a blanket allowance; without it the
  # rule is a tautology on the shipped file.
  perl -pi -e 's/\| wontfix \|/| unknown |/' "${dir}/docs/plans/00-register.md"
  if ! grep -q '| unknown |' "${dir}/docs/plans/00-register.md"; then
    fail "$name" "the test's own mutation (b) did not change the status"
    return
  fi
  if out=$(validator_on "$dir"); then
    fail "$name" "C26 carrying \`unknown\` was accepted, so the exception is a blanket one" \
      "got: ${out}"
    return
  fi
  if [[ "$out" != *"C26 carries \`unknown\`"* ]]; then
    fail "$name" "the finding did not name C26 as outside the legacy exception set" "got: ${out}"
    return
  fi
  # And C9, which IS in the set, is still accepted — or the rule is just a ban.
  perl -pi -e 's/^\| C26 \| (.*) \| P1 \| unknown \|/| C26 | $1 | P1 | closed |/' \
    "${dir}/docs/plans/00-register.md"
  if ! validator_on "$dir" >/dev/null; then
    fail "$name" "C9's legitimate \`unknown\` was refused once C26's was fixed" \
      "the exception set must permit the nine rows it names"
    return
  fi
  pass "$name"
}

test_validator_catches_an_unsorted_section() {
  local name="registerValidatorCatchesAnUnsortedSection"
  local dir="${work_dir}/validator-unsorted"
  make_validator_repo "$dir"
  # Swap two adjacent H rows.
  perl -0pi -e 's/(\| H1 \|[^\n]*\n)(\| H2 \|[^\n]*\n)/$2$1/' "${dir}/docs/plans/00-register.md"
  if [[ $(grep -n '^| H2 |' "${dir}/docs/plans/00-register.md" | cut -d: -f1) -gt \
        $(grep -n '^| H1 |' "${dir}/docs/plans/00-register.md" | cut -d: -f1) ]]; then
    fail "$name" "the test's own mutation did not swap the rows"
    return
  fi
  expect_validator_catches "$name" "$dir" "H2 then H1 is out of ID order"
}

test_validator_catches_a_renamed_status_header() {
  local name="registerValidatorCatchesARenamedStatusHeader"
  local dir="${work_dir}/validator-header"
  make_validator_repo "$dir"
  # D38 proposed the column name `Mutation` for what gen_status reads as `title`;
  # a renamed column makes EVERY lookup miss and the page renders the whole
  # section `unknown` under a confident label.
  perl -pi -e 's/^\| ID \| Title \| P \| Status \|$/| ID | Title | P | State |/' \
    "${dir}/docs/plans/00-register.md"
  if ! grep -q '^| ID | Title | P | State |$' "${dir}/docs/plans/00-register.md"; then
    fail "$name" "the test's own mutation did not rename the header"
    return
  fi
  expect_validator_catches "$name" "$dir" "has no \`Status\` column"
}

test_validator_catches_an_unrecognised_row_id() {
  local name="registerValidatorCatchesAnUnrecognisedRowId"
  local dir="${work_dir}/validator-rowid"
  make_validator_repo "$dir"
  # The bare-only filter rejected all 81 scoped mutation ids WITHOUT A WORD. This
  # rule turns the generator's silent drop into a named refusal.
  perl -pi -e 's/^\| C32-M9 \|/| MUTATION-X |/' "${dir}/docs/plans/00-register.md"
  if ! grep -q '^| MUTATION-X |' "${dir}/docs/plans/00-register.md"; then
    fail "$name" "the test's own mutation did not change the id"
    return
  fi
  expect_validator_catches "$name" "$dir" "is not a register row id"
}

test_validator_catches_a_renamed_overlay_header() {
  local name="registerValidatorCatchesARenamedOverlayHeader"
  local dir="${work_dir}/validator-overlay-header"
  make_validator_repo "$dir"
  # THE HOLE C34's OWN REVIEW FOUND. R8 was gated on the section symbol, and
  # `## Decisions — owner fields` carries no `(D)` on purpose - so the one
  # hand-maintained table in the repository, the one holding the owner's priority
  # and a live Todoist link, was the one table whose column names nothing checked.
  # gen_status.owner_overlay refuses the same rename and writes nothing, so no
  # data was ever at risk; what was missing is R9's stated property, that the
  # validator ALONE names the cause instead of handing the reader a diff.
  perl -pi -e 's/^\| ID \| P \| TD \|$/| ID | Priority | Todoist |/' \
    "${dir}/docs/plans/00-register.md"
  if ! grep -q '^| ID | Priority | Todoist |$' "${dir}/docs/plans/00-register.md"; then
    fail "$name" "the test's own mutation did not rename the overlay header"
    return
  fi
  expect_validator_catches "$name" "$dir" "has no \`P\`, \`TD\` column"
}

test_validator_names_the_generated_region_in_its_remedy() {
  local name="registerValidatorNamesTheGeneratedRegionInItsRemedy"
  local dir="${work_dir}/validator-remedy"
  make_validator_repo "$dir"
  # THE REMEDY LINE IS AN ARTEFACT AND IT GETS ASSERTED AS ONE (D46). The footer
  # tells the reader to run the generator, which is false advice for a row BETWEEN
  # THE MARKERS: that region is rewritten from 00-deltas.md, so a hand fix there
  # is reverted by the very command the footer prints. Reproduced for real by a
  # delta title carrying an odd backtick; reproduced here inside the fixture.
  perl -pi -e 's/^\| D2 \| A proposed decision \|/| D2 | A `proposed decision |/' \
    "${dir}/docs/plans/00-register.md"
  if ! grep -q '^| D2 | A `proposed decision |' "${dir}/docs/plans/00-register.md"; then
    fail "$name" "the test's own mutation did not put an odd backtick in the region"
    return
  fi
  # `|| true` IS LOAD-BEARING: the file runs under `set -euo pipefail` and the
  # validator exits 1 by design here, so an unguarded command substitution
  # ABORTS THE WHOLE SUITE after the current test has printed `ok` - which is how
  # this test first "passed" while the nine tests after it never ran and no count
  # line was printed. The count line is the only thing that shows that.
  local out
  out=$(validator_on "$dir" || true)
  if [[ "$out" != *"INSIDE THE GENERATED REGION"* ]]; then
    fail "$name" "the footer did not say the finding was inside the generated region" \
      "got: ${out}"
    return
  fi
  if [[ "$out" != *"docs/plans/00-deltas.md"* ]]; then
    fail "$name" "the region-aware remedy did not name the source file" \
      "a reader sent to edit the generated region loses the edit on the next run" \
      "got: ${out}"
    return
  fi
  # AND THE ORDINARY CASE MUST NOT CARRY IT. A remedy printed unconditionally is
  # not a remedy, it is decoration - the same argument as "no warnings".
  local plain="${work_dir}/validator-remedy-plain"
  make_validator_repo "$plain"
  perl -pi -e 's/^\| RR1 \| A risk nobody has mitigated \| P1 \| open \|$/| RR1 | A risk nobody has mitigated | P1 |  |/' \
    "${plain}/docs/plans/00-register.md"
  out=$(validator_on "$plain" || true)
  if [[ "$out" != *"RR1"* ]]; then
    fail "$name" "the control mutation did not produce a finding of its own" "got: ${out}"
    return
  fi
  if [[ "$out" == *"INSIDE THE GENERATED REGION"* ]]; then
    fail "$name" "a finding outside the region was told to go and edit a ratified delta" \
      "got: ${out}"
    return
  fi
  pass "$name"
}

test_validator_refuses_an_empty_read() {
  local name="registerValidatorRefusesAnEmptyRead"
  local dir="${work_dir}/validator-empty"
  make_validator_repo "$dir"
  # THE FLOOR conventions.md's harness contract requires: "a shrinking suite is
  # blind, not clean". A check that prints OK on zero rows is the vacuous read
  # test_licence_check_refuses_an_empty_read already exists for.
  perl -ni -e 'print unless /^\|/' "${dir}/docs/plans/00-register.md"
  if grep -q '^|' "${dir}/docs/plans/00-register.md"; then
    fail "$name" "the test's own mutation did not remove the tables"
    return
  fi
  expect_validator_catches "$name" "$dir" "the parser read nothing"
}

test_status_page_names_the_agent_register
test_open_regions_are_written_and_prose_survives
test_the_facts_script_splits_body_from_status
test_facts_claim4_reports_from_a_fixture
test_open_generator_refuses_a_missing_marker
test_status_page_counts_a_scoped_mutation_id
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
test_licence_check_refuses_an_empty_read
test_licence_check_allows_ordinary_prose
test_licence_check_allows_the_pledge
test_status_check_passes_when_generated
test_status_check_catches_a_hand_edit
test_status_check_catches_a_stale_page
test_status_page_does_not_guess_an_absent_status
test_decisions_region_is_generated_from_the_deltas_file
test_decisions_region_carries_the_owner_overlay
test_overlay_naming_an_undefined_delta_is_refused
test_markerless_register_is_refused
test_hand_edit_inside_the_region_fails_check
test_ratified_decisions_are_not_counted_open
test_an_escaped_pipe_does_not_shift_a_row
test_the_command_the_failure_message_prints_actually_fixes_it
test_the_shipped_register_passes_the_validator
test_validator_passes_the_unmutated_fixture
test_validator_catches_a_surplus_cell
test_validator_catches_an_unescaped_pipe
test_validator_catches_a_duplicate_id
test_validator_catches_an_empty_status
test_validator_catches_an_unknown_status_outside_the_exception_set
test_validator_catches_an_unsorted_section
test_validator_catches_a_renamed_status_header
test_validator_catches_an_unrecognised_row_id
test_validator_catches_a_renamed_overlay_header
test_validator_names_the_generated_region_in_its_remedy
test_validator_refuses_an_empty_read

echo
echo "run-script-tests.sh: ${passed} passed, ${failed} failed"
[[ $failed -eq 0 ]]
