#!/bin/bash
#
# gen-secrets.sh — turn the git-ignored `.env` into the git-ignored
# `Support/Secrets.xcconfig` that Xcode reads.
#
# WHY THIS EXISTS
# Xcode has no idea what a `.env` file is; it consumes `.xcconfig`. The owner
# keeps every project's secrets in `.env`, and one habit beats a per-project
# convention. So `.env` stays the only file that holds a real value, and
# `Secrets.xcconfig` becomes a generated, disposable artefact. Both are
# git-ignored; neither is ever committed.
#
# TWO MODES
#   (no flag)       SUPPLY. Regenerate Secrets.xcconfig. This is what `make
#                   secrets` runs, and `make generate` depends on it. This is
#                   the path that actually puts values into build settings.
#   --build-phase   GUARD. Run from inside Xcode. Regenerate, and if the file
#                   CHANGED, fail the build with an explanation. See below.
#
# THE ORDERING FACT THAT MAKES THE GUARD MODE NECESSARY
# An `.xcconfig` is parsed when the project is LOADED, before any build phase
# runs. A build phase that generates `Secrets.xcconfig` therefore cannot affect
# the settings of the build it is part of. Pretending otherwise would give us a
# mechanism that silently does nothing. Instead the build phase verifies, and
# says so out loud when the file it just wrote is not the file the build was
# loaded with.
#
# SECURITY RULES THIS SCRIPT OBEYS, AND WHY
#   * It never prints a value. Not on success, not in an error, not ever.
#     Error messages name the KEY and never the value.
#   * `set -x` is forbidden here. It would echo every expansion — including the
#     client secret — into the Xcode build log, which on CI is public.
#   * The project sets `showEnvVars: false` on the build phase for the same
#     reason: Xcode otherwise dumps every build setting into the log.
#
# REPRODUCIBILITY
# The output is a pure function of the input: fixed key order, fixed header, no
# timestamps, no hostnames. Deleting Secrets.xcconfig and regenerating must
# produce a byte-identical file, and `scripts/tests/run-script-tests.sh` proves
# it does.
#
# WHICH KEYS MUST HAVE A VALUE
# None, at F1. Every key is written through, empty if .env does not supply it.
# The reason is in the key contract below; the short version is that nothing in
# this repository reads a Todoist credential yet, and a build that cannot run
# without one is a gate that cannot run. `--require KEY` promotes a key on the
# command line, and F3 promotes the Todoist three by default.
#
# EXIT CODES
#   0  the file is present and current
#   1  a usage, input, or validation failure (message on stderr)
#   2  --build-phase only: the file was stale and has been regenerated

set -euo pipefail

# --- Locations -------------------------------------------------------------
# Resolved from this script's own location so the script works identically from
# a Makefile, from an Xcode build phase, and from the test harness.
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

# --- Key contract ----------------------------------------------------------
# Every key this pipeline knows about, written to the output in exactly this
# order. A key that is absent from .env, or present and empty, is written as an
# empty assignment. That is deliberate: an empty build setting is a legitimate
# state, and it keeps the output a pure function of the key list.
readonly KEYS=(
  TODOIST_CLIENT_ID
  TODOIST_CLIENT_SECRET
  TODOIST_OAUTH_CALLBACK_SCHEME
  DEVELOPMENT_TEAM
)

# WHICH KEYS ARE *REQUIRED*, AND WHY THAT LIST IS EMPTY TODAY
#
# A required key must be present AND non-empty, and the script refuses to write
# anything if one is missing. That check is worth having — an empty client
# secret builds an app that works right up until somebody tries to sign in,
# which is the worst possible place to discover it.
#
# But it is only worth having once something actually READS the value. At F1
# nothing does: there is no Todoist code in this repository at all, and the F1
# build contract says so in as many words — "NO Swift file and NO Info.plist key
# reads any of these values in F1". Demanding the three Todoist credentials now
# would mean that cloning this repository and running `make test` fails until
# you have registered an OAuth application with a third party, for a feature
# that does not exist yet. It also means continuous integration goes red until
# three repository secrets are configured, so "CI is green" — F1's entire
# done-when — would be an untested claim about a skeleton that makes no network
# calls.
#
# So the default required list is EMPTY, and the three Todoist keys are promoted
# back to required in F3, the feature that first reads them. The one-line change
# is to add them to DEFAULT_REQUIRED_KEYS below.
#
# The loud-failure MECHANISM is not weakened by this and is not left untested:
# `--require KEY` promotes a key on the command line, and
# scripts/tests/run-script-tests.sh uses it to prove the failure path still
# names the offending key and still refuses to write a half-configured file.
readonly DEFAULT_REQUIRED_KEYS=()

# --- Arguments -------------------------------------------------------------
build_phase_mode=false
env_file="${REPO_ROOT}/.env"
output_file="${REPO_ROOT}/Support/Secrets.xcconfig"
# Bash 3.2 — which is what macOS ships — aborts on `"${arr[@]}"` for an empty
# array under `set -u`, and `[@]-` yields one empty element rather than none. So
# the defaults are copied across with the empty element filtered out, which is
# correct whether the default list is empty or not.
required_keys=()
for default_required_key in "${DEFAULT_REQUIRED_KEYS[@]-}"; do
  [[ -n "$default_required_key" ]] && required_keys+=("$default_required_key")
done

usage() {
  cat <<'USAGE' >&2
usage: gen-secrets.sh [--build-phase] [--require KEY] [--env PATH] [--output PATH]

  --build-phase   Verify mode, for the Xcode pre-build phase. Regenerates the
                  file and exits 2 if its contents changed.
  --require KEY   Treat KEY as required: it must be present in the .env and
                  non-empty, or this script fails and names it. Repeatable.
                  (used by the tests; F3 makes the Todoist keys required by
                  default instead)
  --env PATH      Read this file instead of ./.env       (used by the tests)
  --output PATH   Write this file instead of
                  ./Support/Secrets.xcconfig             (used by the tests)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-phase)
      build_phase_mode=true
      shift
      ;;
    --require)
      [[ $# -ge 2 ]] || { echo "gen-secrets.sh: --require needs a key name" >&2; exit 1; }
      # Reject a key this pipeline does not know about. Without this a typo
      # would silently require nothing at all, which is the failure mode a
      # loud-failure check can least afford.
      known=false
      for known_key in "${KEYS[@]}"; do
        [[ "$known_key" == "$2" ]] && known=true
      done
      if [[ "$known" != true ]]; then
        echo "gen-secrets.sh: --require named '$2', which is not a key this script writes." >&2
        echo "                Known keys: ${KEYS[*]}" >&2
        exit 1
      fi
      required_keys+=("$2")
      shift 2
      ;;
    --env)
      [[ $# -ge 2 ]] || { echo "gen-secrets.sh: --env needs a path" >&2; exit 1; }
      env_file="$2"
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || { echo "gen-secrets.sh: --output needs a path" >&2; exit 1; }
      output_file="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "gen-secrets.sh: unknown argument '$1'" >&2
      usage
      exit 1
      ;;
  esac
done

# --- Reading .env ----------------------------------------------------------
# `.env` is READ, never SOURCED. Sourcing it would execute whatever it
# contains, which turns a config file into an arbitrary-code-execution surface
# inside a build.
#
# Accepted line shapes:   KEY=value   KEY="value"   KEY='value'
# Ignored:                blank lines, and lines whose first non-space is '#'
# A trailing carriage return is stripped so a file saved on Windows still works.
#
# Everything after the first '=' is the value, verbatim. In particular a '#'
# inside a value is NOT treated as a comment: secrets contain punctuation, and
# silently truncating one would be the worst possible bug here.
read_key() {
  local key="$1" file="$2" line value
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" == "${key}="* ]] || continue
    value="${line#*=}"
    # Strip one matched pair of surrounding quotes, if present.
    if [[ "$value" == \"*\" && ${#value} -ge 2 ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "$value" == \'*\' && ${#value} -ge 2 ]]; then
      value="${value:1:${#value}-2}"
    fi
    printf '%s' "$value"
    return 0
  done < "$file"
  return 1
}

# An xcconfig treats '//' as the start of a comment, so a value containing it
# would be silently truncated and the app would fail much later with a
# half-length credential. Catch it here, by key name only.
reject_unsafe_value() {
  local key="$1" value="$2"
  if [[ "$value" == *"//"* ]]; then
    echo "gen-secrets.sh: the value of ${key} contains '//', which an .xcconfig" >&2
    echo "                treats as the start of a comment. Remove it, or store" >&2
    echo "                the value in a form that does not contain '//'." >&2
    exit 1
  fi
}

if [[ ! -f "$env_file" ]]; then
  cat <<EOF >&2
gen-secrets.sh: no .env file at ${env_file}

  Copy the committed template and fill it in:

      cp .env.example .env
      \$EDITOR .env
      make secrets

  .env is git-ignored and is the only file on disk that holds a real
  credential. Continuous integration writes its own from encrypted repository
  secrets.
EOF
  exit 1
fi

# --- Build the file contents in memory -------------------------------------
# Assembled as a string first so the on-disk file is only ever replaced by a
# complete, validated document.
contents="// Support/Secrets.xcconfig — GENERATED FILE. DO NOT EDIT, DO NOT COMMIT.
//
// Written by scripts/gen-secrets.sh from the git-ignored .env at the repository
// root. Delete this file and run \`make secrets\` to recreate it byte for byte.
// Edit .env instead; any change made here is lost on the next build.
"

is_required() {
  local key="$1" required
  for required in "${required_keys[@]-}"; do
    [[ "$required" == "$key" ]] && return 0
  done
  return 1
}

for key in "${KEYS[@]}"; do
  # `|| true` because a missing key is not automatically an error; whether it is
  # depends on the required list, which is checked immediately below.
  value="$(read_key "$key" "$env_file" || true)"

  if is_required "$key" && [[ -z "$value" ]]; then
    echo "gen-secrets.sh: required key ${key} is missing or empty in ${env_file}" >&2
    echo "                Add a line reading '${key}=<value>'. An empty ${key}" >&2
    echo "                builds an app that fails later at sign-in, so the build" >&2
    echo "                stops here instead. See .env.example." >&2
    exit 1
  fi

  reject_unsafe_value "$key" "$value"
  contents+="${key} = ${value}"$'\n'
done

# --- Write, atomically -----------------------------------------------------
# Compare before writing so an unchanged file keeps its modification time. That
# keeps Xcode from treating every build as a project change, and it is what
# makes the --build-phase guard below meaningful.
mkdir -p -- "$(dirname -- "$output_file")"

# COMPARED AS BYTES, THROUGH `cmp`, AND NOT AS A SHELL STRING.
#
# This was a real bug and it is worth the paragraph. `$contents` ends in a
# newline, because every key line is appended with one. Command substitution —
# `$(cat file)` — strips every trailing newline by definition. So comparing
# `"$(cat -- "$output_file")" == "$contents"` compared a string that ends in a
# newline against one that never can, the two were never equal, `changed` was
# always true, and the `--build-phase` guard below fired on every single build.
# That made the project permanently unbuildable, locally and in CI, with a
# correct and complete .env, while printing a message telling the developer to
# "build again to pick them up" — advice that could never work.
#
# Piping into `cmp` compares the bytes that will actually be on disk against the
# bytes that are on disk. Nothing is mangled on the way.
changed=true
if [[ -f "$output_file" ]] && printf '%s' "$contents" | cmp -s - "$output_file"; then
  changed=false
fi

if [[ "$changed" == true ]]; then
  # Write to a temporary file in the SAME directory, then rename. A rename
  # within one filesystem is atomic, so an interrupted run can never leave a
  # half-written credentials file behind.
  tmp_file="$(mktemp "${output_file}.XXXXXX")"
  # The file holds a real secret: make it owner-readable only before anything
  # is written into it. (No `--` here: BSD chmod, which is what macOS ships,
  # does not accept an end-of-options marker.)
  chmod 600 "$tmp_file"
  printf '%s' "$contents" > "$tmp_file"
  mv -f -- "$tmp_file" "$output_file"
fi

if [[ "$build_phase_mode" == true && "$changed" == true ]]; then
  cat <<'EOF' >&2
error: Secrets.xcconfig was stale and has been regenerated.

  Build settings are read when the project is LOADED, which happens before this
  build phase runs, so this build is still using the previous values. Build
  again to pick up the new ones.

  This is not a mistake you made. It is what happens the first time after .env
  changes, and it is deliberately loud rather than silently wrong.
EOF
  exit 2
fi

# Report the path only. Never the contents.
echo "gen-secrets.sh: ${output_file} is current."
