#!/bin/bash
#
# check-todoist-writes.sh — enforce the no-task-creation non-negotiable.
#
# WHAT IT ACTUALLY CHECKS, AND WHY IT IS NOT A GREP FOR "POST"
# The rule is not "no POST". Signing in exchanges an OAuth code with a POST,
# and completing a task is a POST, so a verb-based check would fire on the two
# calls the app is allowed to make and stay silent on the ones it is not.
#
# Instead: find every Todoist URL in the app's source, normalise it to a path,
# and require that path to appear in the committed allowlist
# `scripts/todoist-allowed-endpoints.txt`. The failure mode becomes "a NEW
# endpoint appeared", and widening the rule means editing a committed file,
# which shows up in the pull-request diff and in the adversarial reviewer's
# scope check. That visibility is the control.
#
# WHAT THIS CHECK DOES NOT GUARANTEE — READ BEFORE RELYING ON IT
# It enforces the endpoint SET, not the VERB. Creating a task is `POST /tasks`
# and reading tasks is `GET /tasks`: the same path, and this check compares
# paths. So a task-creation call site is, as this script stands, indistinguish-
# able from a task-read call site — and task creation is the single thing the
# no-capture non-negotiable exists to forbid.
#
# Nothing is exposed at F1: there is no Todoist code in this repository at all.
# But F3 must not be allowed to merge against a gate that does not do what its
# name says. THE PRECONDITION ON THE F3 GATE is that every Todoist request is
# routed through one function, so that this check can bind a METHOD to a PATH at
# the call site and compare the pair against the allowlist's METHOD column —
# together with a `POST /tasks`-shaped fixture in run-script-tests.sh that must
# exit non-zero before any F3 code merges. Until that lands, the METHOD column
# in the allowlist is documentation for a human reader and nothing more.
#
# WHAT IT SEARCHES, AND WHAT IT MUST NOT
# Only the app's own source trees: ZenTomato/, ZenTomatoTests/, Support/.
#
# `docs/` and `scripts/` are deliberately EXCLUDED. The plans quote Todoist
# endpoints in prose, and this script and its allowlist contain them by
# definition. Searching those directories would fail continuous integration on
# day one, for text that no compiler ever sees.
#
# EXIT CODES
#   0  no Todoist URL outside the allowlist
#   1  at least one unlisted Todoist URL (each is printed with file and line)
#   2  a usage or configuration failure

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

allowlist="${SCRIPT_DIR}/todoist-allowed-endpoints.txt"
search_roots=()

usage() {
  cat <<'USAGE' >&2
usage: check-todoist-writes.sh [--allowlist PATH] [PATH ...]

  With no PATH arguments the app's source trees are searched:
  ZenTomato/, ZenTomatoTests/, Support/. docs/ and scripts/ are never searched.

  --allowlist PATH   Use this allowlist instead of the committed one
                     (used by scripts/tests/run-script-tests.sh).
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allowlist)
      [[ $# -ge 2 ]] || { echo "check-todoist-writes.sh: --allowlist needs a path" >&2; exit 2; }
      allowlist="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "check-todoist-writes.sh: unknown argument '$1'" >&2
      usage
      exit 2
      ;;
    *)
      search_roots+=("$1")
      shift
      ;;
  esac
done

if [[ ${#search_roots[@]} -eq 0 ]]; then
  for candidate in "${REPO_ROOT}/ZenTomato" "${REPO_ROOT}/ZenTomatoTests" "${REPO_ROOT}/Support"; do
    [[ -e "$candidate" ]] && search_roots+=("$candidate")
  done
fi

if [[ ${#search_roots[@]} -eq 0 ]]; then
  echo "check-todoist-writes.sh: no source trees to search — nothing to check."
  exit 0
fi

if [[ ! -f "$allowlist" ]]; then
  echo "check-todoist-writes.sh: allowlist not found at ${allowlist}" >&2
  exit 2
fi

# --- Load the allowlist ----------------------------------------------------
# Only the PATH column is compared. The METHOD column is documentation for a
# human reader: it records the intent of each entry, which is what makes a
# future diff to this file legible.
#
# That is a real limitation, not a design flourish, and the header above says
# what it costs and what F3 has to do about it. `POST /tasks` (create a task)
# and `GET /tasks` (read tasks) are the same path, so this check cannot tell
# them apart.
allowed_paths=()
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  line="${line%%#*}"
  # Trim surrounding whitespace.
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" ]] && continue
  # Everything after the first run of whitespace is the path.
  path="${line#* }"
  path="${path#"${path%%[![:space:]]*}"}"
  allowed_paths+=("$path")
done < "$allowlist"

# --- Normalisation ---------------------------------------------------------
# Turns anything that looks like a Todoist reference into the canonical form
# used in the allowlist, so that a base-URL constant plus a short path and one
# long literal URL both compare equal.
#
#   0. drop the trailing quote or comma the match may have swept up
#   1. drop the scheme and host
#   2. drop any query string or fragment
#   3. drop the `/api/v1` version prefix
#   4. drop a trailing slash
#   5. replace any segment that is a substituted value with `{id}` — that is,
#      a segment of pure digits, or one containing a Swift string
#      interpolation `\(...)`, or one written as `{...}`
#
# A segment that is a hard-coded opaque identifier is deliberately NOT
# normalised. It will not match the allowlist and will fail the check, which is
# correct: a task identifier baked into source is a bug worth stopping.
normalise_path() {
  local candidate="$1" path segment result=""

  # A URL-BUILDER MATCH ARRIVES IN A DIFFERENT SHAPE AND IS REWRITTEN FIRST.
  #
  # `URL.appending(path:)` and `URL.appendingPathComponent(_:)` take the
  # component WITHOUT a leading slash — that is their calling convention — so
  # `base.appending(path: "sync")` contains no `/sync` anywhere and the
  # path pattern below could never see it. This turns the matched call back into
  # the path it builds: take what is inside the quotes and put the slash back.
  if [[ "$candidate" == *[Aa]ppend*"("* ]]; then
    candidate="${candidate#*\"}"   # drop everything up to the opening quote
    candidate="${candidate%\"}"    # drop the closing quote
    candidate="/${candidate#/}"    # exactly one leading slash
  fi

  # `grep -E` has no lookahead, so a match can carry the character that ENDED
  # the string literal — a quote, a comma, a semicolon. Strip those first, or
  # `/projects"` would never equal the allowlist's `/projects`.
  #
  # A closing parenthesis is deliberately NOT stripped: it is part of a Swift
  # interpolation, as in `/tasks/\(taskID)/close`.
  while [[ -n "$candidate" && "$candidate" == *[\"\',\;\ ] ]]; do
    candidate="${candidate%?}"
  done
  path="${candidate#*://}"
  # Remove the host, keeping the leading slash of the path.
  if [[ "$path" == *"/"* ]]; then
    path="/${path#*/}"
  else
    path="/"
  fi
  path="${path%%\?*}"
  path="${path%%#*}"
  path="${path#/api/v1}"
  [[ -z "$path" ]] && path="/"
  if [[ "$path" != "/" ]]; then
    path="${path%/}"
  fi

  # Declared empty first: with `set -u`, expanding an array that `read` never
  # populated (the API root, whose path is just "/") would abort the script.
  local -a segments=()
  local IFS='/'
  read -r -a segments <<< "${path#/}" || true
  for segment in "${segments[@]-}"; do
    if [[ -z "$segment" ]]; then
      continue
    elif [[ "$segment" =~ ^[0-9]+$ ]] || [[ "$segment" == *'\('* ]] || [[ "$segment" == \{*\} ]]; then
      result+="/{id}"
    else
      result+="/${segment}"
    fi
  done
  [[ -z "$result" ]] && result="/"
  printf '%s' "$result"
}

is_allowed() {
  local path="$1" allowed
  # The bare API root is always fine: it is what a base-URL constant
  # normalises to, and on its own it calls nothing.
  [[ "$path" == "/" ]] && return 0
  for allowed in "${allowed_paths[@]}"; do
    [[ "$path" == "$allowed" ]] && return 0
  done
  return 1
}

# --- Scan ------------------------------------------------------------------
# Two patterns, because a Todoist call can be written either way:
#   * a full URL containing the host, or
#   * a short path appended to a base-URL constant on another line.
#
# The trailing part of each pattern runs to the end of the string literal. It
# deliberately ALLOWS parentheses, because a real call site writes
# `"/tasks/\(taskID)/close"` — stopping at the `)` of the interpolation would
# silently drop the `/close`, and a check that reads half a path is worse than
# no check.
#
# WHY THE BARE-PATH NOUN LIST IS THE WHOLE TODOIST SURFACE, NOT JUST THE
# ALLOWLISTED ONES. A bare path carries no host, so the only thing that marks
# it as a Todoist reference is the noun. If this list held only the nouns that
# are already allowlisted, then `let path = "/comments"` — the exact shape the
# allowed fixture demonstrates for `/projects` — would match NOTHING, be seen
# by nothing, and sail through. The check would then be blind to precisely the
# endpoints it exists to forbid, while looking like it worked.
#
# So the list is every resource noun Todoist's API v1 exposes. The consequence
# is that this check FAILS CLOSED: a path named after a Todoist resource is
# reported unless the allowlist names it. A false positive costs one visible,
# reviewed line in the allowlist, or a rename. A false negative costs the
# non-negotiable this whole script exists to defend. That trade is not close.
#
# AND THE THIRD SHAPE: A URL BUILT WITH `appending(path:)`.
#
# This was a fail-open, found in review. `URL.appending(path:)` and
# `URL.appendingPathComponent(_:)` take the component WITHOUT a leading slash —
# that is their whole calling convention — so `base.appending(path: "sync")`
# contains no `/sync` and matched neither pattern above. Four such lines,
# including `/sync` and `/comments`, passed this check while it printed
# "OK — no Todoist endpoint outside the allowlist". That is the most idiomatic
# modern way to build a URL in Swift, and therefore the shape F3 is most likely
# to be written in. `normalise_path` above puts the slash back before comparing.
readonly URL_PATTERN='https?://[A-Za-z0-9._-]*todoist\.com[^"'"'"'[:space:]]*'
readonly TODOIST_NOUNS='api/v1|projects|sections|tasks|comments|labels|shared_labels|reminders|uploads|activities|backups|filters|workspaces|collaborators|templates|folders|sync|notes|items|emails|ical|completed|user'
readonly PATH_PATTERN="/(${TODOIST_NOUNS})[^\"'[:space:]]*"
readonly BUILDER_PATTERN="append(ing)?(PathComponent)?\\([^\"']*\"(${TODOIST_NOUNS})[^\"']*\""

violations=0

# The scan below greps case-INSENSITIVELY, so `/Tasks` and `API.TODOIST.COM`
# are seen too. The allowlist comparison downstream stays case-SENSITIVE, so a
# mixed-case path is reported rather than quietly accepted: Todoist paths are
# lowercase, and an odd-cased one is worth a human look.
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  # ripgrep-style `file:line:text` from grep -rn.
  location="${match%%:*}"
  rest="${match#*:}"
  line_number="${rest%%:*}"
  candidate="${rest#*:}"
  path="$(normalise_path "$candidate")"
  if ! is_allowed "$path"; then
    if [[ $violations -eq 0 ]]; then
      echo "check-todoist-writes.sh: FAIL — Todoist endpoint not on the allowlist" >&2
      echo >&2
    fi
    echo "  ${location}:${line_number}" >&2
    echo "      found:      ${candidate}" >&2
    echo "      normalised: ${path}" >&2
    violations=$((violations + 1))
  fi
done < <(
  # `*.xcconfig` IS DELIBERATELY NOT SCANNED, AND THE ONLY REASON IS SECRECY.
  #
  # Support/ is one of the default search roots, and the only .xcconfig that
  # ever exists in this repository is the generated, chmod-600
  # Support/Secrets.xcconfig. This script prints the text it matched to stderr,
  # which on CI goes into the build log, and GitHub masks exact secret values
  # rather than substrings of them — so a credential that happened to contain a
  # slash followed by a Todoist noun would be echoed into a public log. That
  # contradicts the rule the whole secrets design rests on: gen-secrets.sh never
  # prints a value, not on success, not in an error, not ever.
  #
  # Nothing is lost. A Todoist call site cannot exist in a build-settings file;
  # it can only exist in source, which is scanned. The `--exclude` is a second
  # lock on the same door in case a future root brings another .xcconfig in.
  grep -rEnoi --binary-files=without-match \
    -e "$URL_PATTERN" -e "$PATH_PATTERN" -e "$BUILDER_PATTERN" \
    --include='*.swift' --include='*.plist' \
    --include='*.json' --include='*.yml' --include='*.yaml' \
    --exclude='Secrets.xcconfig' \
    -- "${search_roots[@]}" 2>/dev/null || true
)

if [[ $violations -gt 0 ]]; then
  cat <<EOF >&2

  ${violations} endpoint reference(s) are not permitted.

  The only write this app may ever make to Todoist is completing a task. If the
  endpoint above is a legitimate READ that v0.1 needs, add it to
  ${allowlist}
  in the same commit, so the change is reviewed rather than assumed.

  If it creates, updates, moves, or comments on anything: that is the rule this
  check exists to stop. Delete it.
EOF
  exit 1
fi

echo "check-todoist-writes.sh: OK — no Todoist endpoint outside the allowlist."
