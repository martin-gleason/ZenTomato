#!/bin/bash
#
# Compile the configuration that actually ships, and fail on a warning in our
# own code.
#
# WHY THIS EXISTS
# Until C12, nothing in this repository ever built Release. `make build`, `make
# test` and every CI run compiled Debug for the simulator. The binary a person
# would install is built with `-O` and whole-module optimisation, and those are
# not the same compiler run.
#
# The first time Release was built by hand it produced two data-race warnings
# nobody had seen — in a project whose stated standard is strict concurrency —
# and an attempt to annotate them away CRASHED the Swift 6.3.3 compiler while
# emitting a reabstraction thunk under `-O`. A crash that Debug cannot reproduce
# is precisely the class of thing a Debug-only gate cannot catch.
#
# WHY WARNINGS FAIL IT
# A warning in the shipping configuration that nobody ever compiles is a warning
# that accumulates. Treating it as a failure is the only thing that keeps the
# count at zero, and zero is where it is today.
#
# Only warnings from files inside this repository count. SDK and toolchain
# warnings are not ours to fix and would make the gate unmeetable, which is how
# a gate gets deleted rather than satisfied.
set -euo pipefail

cd "$(dirname "$0")/.."

log="${TMPDIR:-/tmp}/zentomato-release-build.log"

echo "check-release-build.sh: compiling Release for a device…"

# Unsigned: this checks that the code COMPILES as it ships, which is a different
# question from whether this machine holds a distribution certificate. CI has no
# certificate and must still be able to run this.
if ! xcodebuild build \
  -project ZenTomato.xcodeproj \
  -scheme ZenTomato \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath DerivedData-release \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  > "$log" 2>&1; then
  echo "check-release-build.sh: FAIL — Release did not compile."
  echo
  grep -E "error:|Command SwiftCompile failed|While emitting" "$log" | sort -u | head -20
  echo
  echo "  Full log: $log"
  exit 1
fi

# Warnings whose path is inside this checkout. `$PWD` rather than a fixed string
# so the check works from any clone location.
ours=$(grep -E "^${PWD}/.*\.swift:[0-9]+:[0-9]+: warning:" "$log" | sort -u || true)

if [ -n "$ours" ]; then
  echo "check-release-build.sh: FAIL — the shipping configuration has warnings."
  echo
  echo "$ours" | sed "s|${PWD}/||"
  echo
  echo "  These do not appear in a Debug build. Fix them, or say in the commit"
  echo "  message why the shipping binary should carry one."
  exit 1
fi

echo "check-release-build.sh: OK — Release compiles with no warnings of ours."
