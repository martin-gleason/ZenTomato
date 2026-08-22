#!/bin/bash
#
# run-script-tests.sh — the four shell-level tests from docs/plans/F1.md, plus
# the ones that turned out to be missing.
#
#   genSecretsIsReproducible        delete Secrets.xcconfig, regenerate,
#                                   byte-identical
#   genSecretsFailsLoudly           a required key with no value exits non-zero
#                                   and names the key
#   genSecretsGuardPassesWhenCurrent  --build-phase exits 0 on an up-to-date
#                                   file, twice running — a regression test;
#                                   see the test for why
#   genSecretsGuardFailsWhenStale   --build-phase exits 2 and says "stale" when
#                                   the file it wrote differs from the one on
#                                   disk
#   noWritesHookCatchesNewEndpoint  a fixture with an unlisted Todoist URL exits
#                                   non-zero
#   noWritesHookCatchesBarePath     the same, written as a host-less path —
#                                   a regression test; see the test for why
#   noWritesHookCatchesBuilderPath  the same, written with URL.appending(path:)
#                                   — a regression test; see the test for why
#   noWritesHookAllowsClose         a fixture with only allowlisted endpoints
#                                   exits zero
#   envIsGitIgnored                 .env is ignored and .env.example is not
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
# .env or Support/Secrets.xcconfig, so running this can never disturb a working
# build or read a real credential.

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPTS_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly REPO_ROOT="$(cd -- "${SCRIPTS_DIR}/.." && pwd)"
readonly FIXTURES_DIR="${SCRIPT_DIR}/fixtures"

readonly GEN_SECRETS="${SCRIPTS_DIR}/gen-secrets.sh"
readonly CHECK_TODOIST="${SCRIPTS_DIR}/check-todoist-writes.sh"
readonly ALLOWLIST="${SCRIPTS_DIR}/todoist-allowed-endpoints.txt"

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
# genSecretsIsReproducible
#
# The generated Secrets.xcconfig is disposable by design: deleting it and
# rebuilding must reproduce it exactly. That is what makes it safe to
# git-ignore. If the output contained a timestamp, a hostname, or an unstable
# key order, "delete it and rebuild" would silently become "and now your build
# differs from mine".
# ---------------------------------------------------------------------------
test_gen_secrets_is_reproducible() {
  local name="genSecretsIsReproducible"
  local out="${work_dir}/reproducible.xcconfig"
  local first="${work_dir}/reproducible.first"

  if ! "$GEN_SECRETS" --env "${FIXTURES_DIR}/env-complete" --output "$out" >/dev/null 2>&1; then
    fail "$name" "gen-secrets.sh failed on a complete .env fixture"
    return
  fi
  cp -- "$out" "$first"

  # Delete it, exactly as a developer clearing derived state would.
  rm -f -- "$out"

  if ! "$GEN_SECRETS" --env "${FIXTURES_DIR}/env-complete" --output "$out" >/dev/null 2>&1; then
    fail "$name" "gen-secrets.sh failed on the second run"
    return
  fi

  if cmp -s -- "$first" "$out"; then
    pass "$name"
  else
    fail "$name" \
      "regenerating Secrets.xcconfig did not produce a byte-identical file" \
      "the file is git-ignored, so a non-reproducible one is undetectable drift"
  fi
}

# ---------------------------------------------------------------------------
# genSecretsFailsLoudly
#
# An empty required key must stop the build and say WHICH key, because the
# alternative is an app that builds, installs, launches, and then fails at the
# OAuth callback with no clue why.
#
# Two assertions, and the second is the one with teeth: a non-zero exit alone
# would be satisfied by a crash. The message must name the key.
#
# WHY THIS PASSES `--require` RATHER THAN RELYING ON THE DEFAULT
# At F1 no key is required by default, because nothing in the app reads a
# Todoist credential yet and a build that cannot run without one is a gate that
# cannot run. The loud-failure MECHANISM still has to be proven to work, or F3
# will switch it on having never seen it fire. `--require` is what keeps the
# test honest without holding the F1 build hostage to an F3 credential.
# ---------------------------------------------------------------------------
test_gen_secrets_fails_loudly() {
  local name="genSecretsFailsLoudly"
  local out="${work_dir}/loud.xcconfig"
  local stderr_file="${work_dir}/loud.stderr"
  local status=0

  "$GEN_SECRETS" --require TODOIST_CLIENT_SECRET \
    --env "${FIXTURES_DIR}/env-missing-value" --output "$out" \
    >/dev/null 2>"$stderr_file" || status=$?

  if [[ $status -eq 0 ]]; then
    fail "$name" "gen-secrets.sh exited 0 on a .env with an empty required key"
    return
  fi

  if ! grep -q 'TODOIST_CLIENT_SECRET' "$stderr_file"; then
    fail "$name" \
      "it failed, but the message does not name TODOIST_CLIENT_SECRET" \
      "a failure that does not say which key is blank costs a debugging session"
    return
  fi

  # And it must not have written a half-configured file.
  if [[ -f "$out" ]]; then
    fail "$name" "it failed but still wrote ${out}"
    return
  fi

  pass "$name"
}

# ---------------------------------------------------------------------------
# genSecretsGuardPassesWhenCurrent
#
# REGRESSION TEST, and the most expensive omission in this file's history.
#
# `--build-phase` is the mode wired into the Xcode pre-build phase, so it runs
# on literally every build and every test run. Nothing here ever invoked it. The
# result was that a one-line comparison bug — comparing the file's bytes through
# a command substitution, which strips the trailing newline the generated file
# always ends with — made the guard fire on EVERY build, forever, on any machine
# and with any .env. The project could not be built or tested at all, while this
# harness reported "6 passed, 0 failed".
#
# The suite's own header states the doctrine that was violated: a hook that has
# never been shown to FAIL is not known to work. The converse is just as true
# and is what this test covers — a guard that has never been shown to PASS is
# not known to work either.
#
# Run twice, because the failure mode was specifically that a second, identical
# run still reported a change.
# ---------------------------------------------------------------------------
test_gen_secrets_guard_passes_when_current() {
  local name="genSecretsGuardPassesWhenCurrent"
  local out="${work_dir}/guard.xcconfig"
  local output_file="${work_dir}/guard.out"
  local status=0

  if ! "$GEN_SECRETS" --env "${FIXTURES_DIR}/env-complete" --output "$out" >/dev/null 2>&1; then
    fail "$name" "the supply run failed before the guard could be tested"
    return
  fi

  "$GEN_SECRETS" --build-phase --env "${FIXTURES_DIR}/env-complete" --output "$out" \
    >"$output_file" 2>&1 || status=$?
  if [[ $status -ne 0 ]]; then
    fail "$name" \
      "the guard reported a stale file immediately after writing it" \
      "every xcodebuild build and test would fail in PhaseScriptExecution" \
      "--- output ---" \
      "$(cat -- "$output_file")"
    return
  fi

  status=0
  "$GEN_SECRETS" --build-phase --env "${FIXTURES_DIR}/env-complete" --output "$out" \
    >"$output_file" 2>&1 || status=$?
  if [[ $status -ne 0 ]]; then
    fail "$name" \
      "the guard passed once and then failed on an identical second run" \
      "--- output ---" \
      "$(cat -- "$output_file")"
    return
  fi

  pass "$name"
}

# ---------------------------------------------------------------------------
# genSecretsGuardFailsWhenStale
#
# The other half. Making the guard pass is easy if it never fails; this proves
# it still does the job it exists for. The .env changes underneath a file that
# was generated from the previous one, which is exactly the situation the guard
# is there to catch — build settings were read when the project was loaded, so
# the running build is using the old values and must be told.
# ---------------------------------------------------------------------------
test_gen_secrets_guard_fails_when_stale() {
  local name="genSecretsGuardFailsWhenStale"
  local out="${work_dir}/stale.xcconfig"
  local output_file="${work_dir}/stale.out"
  local status=0

  if ! "$GEN_SECRETS" --env "${FIXTURES_DIR}/env-complete" --output "$out" >/dev/null 2>&1; then
    fail "$name" "the supply run failed before the guard could be tested"
    return
  fi

  # A different, complete .env: the callback scheme changes, nothing else.
  "$GEN_SECRETS" --build-phase --env "${FIXTURES_DIR}/env-changed" --output "$out" \
    >"$output_file" 2>&1 || status=$?

  if [[ $status -ne 2 ]]; then
    fail "$name" \
      "the guard exited ${status}, expected 2, after .env changed underneath it" \
      "a build using settings from the previous .env would proceed silently" \
      "--- output ---" \
      "$(cat -- "$output_file")"
    return
  fi

  if ! grep -qi 'stale' "$output_file"; then
    fail "$name" \
      "it failed, but the message does not explain that the file was stale" \
      "--- output ---" \
      "$(cat -- "$output_file")"
    return
  fi

  pass "$name"
}

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
# envIsGitIgnored
#
# The other checks in check-secrets.sh only ever look at files git already
# tracks or has staged, so none of them can see the failure where `.env` stops
# being ignored: the file just sits there untracked, invisible, until somebody
# types `git add .` and commits a live credential.
#
# This asserts the guard is wired up and answering, on this actual repository.
# ---------------------------------------------------------------------------
test_env_is_git_ignored() {
  local name="envIsGitIgnored"

  if ! git -C "$REPO_ROOT" check-ignore -q .env; then
    fail "$name" \
      ".env is not git-ignored in this repository" \
      "it is the only file on disk holding a real credential"
    return
  fi

  if git -C "$REPO_ROOT" check-ignore -q .env.example; then
    fail "$name" \
      ".env.example IS ignored, but it is meant to be committed" \
      "the repository would stop documenting which keys are required"
    return
  fi

  pass "$name"
}

test_gen_secrets_is_reproducible
test_gen_secrets_fails_loudly
test_gen_secrets_guard_passes_when_current
test_gen_secrets_guard_fails_when_stale
test_no_writes_hook_catches_new_endpoint
test_no_writes_hook_catches_bare_path
test_no_writes_hook_catches_builder_path
test_no_writes_hook_allows_close
test_env_is_git_ignored

echo
echo "run-script-tests.sh: ${passed} passed, ${failed} failed"
[[ $failed -eq 0 ]]
