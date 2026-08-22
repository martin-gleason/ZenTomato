#!/bin/bash
#
# check-lint.sh — the lint gate.
#
# Runs `swiftlint --strict`, which makes every warning an error. The rules
# themselves live in `.swiftlint.yml`; this script only decides what happens
# when the tool is not installed.
#
# THE DEGRADATION RULE, AND WHY IT IS NOT SYMMETRIC
# On a developer's machine SwiftLint may legitimately be missing — a fresh
# clone, a new laptop, a `brew` that has not been run yet. Refusing to let that
# person commit teaches them to pass `--no-verify`, and a hook that people
# habitually bypass protects nothing. So locally: print how to install it and
# get out of the way.
#
# In continuous integration the opposite is true. CI is the gate that branch
# protection actually enforces, and a gate that silently passes because a tool
# was missing is worse than no gate — it reports green while checking nothing.
# So when CI=true: a missing SwiftLint is a hard failure.
#
# EXIT CODES
#   0  lint clean, or the tool is absent on a developer machine
#   1  a lint violation, or the tool is absent in continuous integration

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

cd -- "$REPO_ROOT"

if ! command -v swiftlint >/dev/null 2>&1; then
  if [[ "${CI:-}" == "true" ]]; then
    cat <<'EOF' >&2
check-lint.sh: swiftlint is not installed on this runner, and CI=true.

  The lint gate is one of the four checks branch protection relies on. A run
  that skipped it would report green while checking nothing, so this is a hard
  failure rather than a warning.

  Add a step that installs SwiftLint before this one.
EOF
    exit 1
  fi

  cat <<'EOF'
check-lint.sh: swiftlint is not installed — the lint gate did NOT run.

  Install it and this check starts working:

      brew install swiftlint

  Continuous integration always runs it, so a violation will be caught before
  anything merges. This is a local convenience, not a licence to skip it.
EOF
  exit 0
fi

echo "check-lint.sh: swiftlint $(swiftlint version) --strict"
# --strict promotes every warning to an error. `.swiftlint.yml` at the
# repository root selects the rules and the paths.
swiftlint lint --strict --quiet
echo "check-lint.sh: OK — no lint violations."
