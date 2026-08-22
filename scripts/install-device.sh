#!/usr/bin/env bash
#
# Build a signed ZenTomato and install it on a connected iPhone.
#
# WHY THIS IS A SCRIPT AND NOT A MAKEFILE RECIPE
# It has to find a device, decide whether that device is usable, and explain
# clearly when it is not. Every one of those failures has a specific fix the
# person running it needs to be told, and a Makefile recipe that can only say
# "Error 1" is how a five-second problem becomes a twenty-minute one.
#
# WHAT IT NEEDS
#   1. DEVELOPMENT_TEAM in Config/Secrets.xcconfig — your Apple Developer team.
#   2. An iPhone plugged in, unlocked, and trusting this Mac.
#   3. Developer Mode on: Settings > Privacy & Security > Developer Mode.
#      The phone restarts the first time this is switched on.
#
# Simulator builds need none of this, which is why `make test` works on a
# machine with no Apple developer account at all.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PROJECT="ZenTomato.xcodeproj"
SCHEME="ZenTomato"
DERIVED_DATA="DerivedData"
SECRETS="Config/Secrets.xcconfig"

die() { printf 'install-device.sh: %s\n' "$1" >&2; shift; for l in "$@"; do printf '                   %s\n' "$l" >&2; done; exit 1; }

# --- 1 · a signing team ----------------------------------------------------
team=""
if [[ -f "$SECRETS" ]]; then
  team="$(sed -n 's|^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*||p' "$SECRETS" | tail -1 | tr -d '[:space:]')"
fi
if [[ -z "$team" ]]; then
  die "DEVELOPMENT_TEAM is not set — a device build must be signed." \
      "" \
      "  cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig" \
      "" \
      "then put your ten-character Apple Developer Team ID in it. Find it at" \
      "https://developer.apple.com/account under Membership details, or run:" \
      "  security find-identity -v -p codesigning"
fi

# --- 2 · a usable iPhone ---------------------------------------------------
# devicectl reports every paired device, including ones that are not currently
# reachable, so "found" and "usable" are different questions and are asked
# separately below.
devices_json="$(mktemp -t zt-devices)"
trap 'rm -f "$devices_json"' EXIT
xcrun devicectl list devices --json-output "$devices_json" >/dev/null 2>&1 || true

# `set -e` would abort with NO MESSAGE if python were missing or died before
# printing, because `read` returns non-zero at EOF — which is exactly the silent
# "Error 1" this script exists to prevent. So the status is captured and checked
# rather than left to the shell.
device_line=""
if ! device_line="$(python3 - "$devices_json" <<'PYEOF'
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    devices = []
for d in devices:
    hardware = d.get("hardwareProperties", {})
    if "iPhone" in (hardware.get("marketingName") or ""):
        properties = d.get("deviceProperties", {})
        # The name is printed with non-breaking spaces so that a phone called
        # "Marty's iPhone" stays ONE whitespace-delimited field and does not
        # shift the OS version into the wrong variable. Undone below.
        print(hardware.get("udid", ""),
              (properties.get("name") or "iPhone").replace(" ", "\u00a0"),
              properties.get("osVersionNumber", "?"))
        break
else:
    print("", "", "")
PYEOF
)"; then
  die "could not read the list of attached devices." \
      "" \
      "This needs python3, which ships with the Xcode command line tools:" \
      "  xcode-select --install"
fi

read -r udid name os <<<"$device_line" || true

if [[ -z "${udid:-}" ]]; then
  die "no iPhone is paired with this Mac." \
      "" \
      "Plug the phone in with a cable, unlock it, and tap Trust when it asks." \
      "Then run this again."
fi

printf 'install-device.sh: %s — iOS %s\n' "${name//$' '/ }" "$os"

# --- 3 · build -------------------------------------------------------------
# -allowProvisioningUpdates lets Xcode create and refresh the signing profile
# without a trip through the developer portal.
printf 'install-device.sh: building…\n'
build_log="$(mktemp -t zt-build)"
trap 'rm -f "$devices_json" "$build_log"' EXIT

if ! xcodebuild build \
  -project "$PROJECT" -scheme "$SCHEME" \
  -destination "id=${udid}" \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates >"$build_log" 2>&1
then
  # The two failures worth naming, because neither says what to do about it.
  if grep -q 'developer disk image could not be mounted' "$build_log"; then
    die "the phone is paired but not ready for development." \
        "" \
        "Almost always this means Developer Mode is off. On the phone:" \
        "  Settings > Privacy & Security > Developer Mode > on" \
        "The phone restarts. Unlock it afterwards and run this again." \
        "" \
        "If Developer Mode is already on, unplug and replug the cable — the" \
        "phone must be unlocked when it connects for the disk image to mount."
  fi
  if grep -qi 'no profiles for\|requires a development team\|failed to register bundle identifier' "$build_log"; then
    # The team ID is not secret, but it is a value read out of the private
    # xcconfig and nothing else in this repository prints one. Kept out.
    die "signing failed." \
        "" \
        "Check that DEVELOPMENT_TEAM in Config/Secrets.xcconfig is right, and" \
        "that the bundle identifier com.martingleason.ZenTomato is free to use." \
        "" \
        "Last lines of the build log:" \
        "$(tail -15 "$build_log")"
  fi
  die "the build failed." "" "$(tail -25 "$build_log")"
fi

app="$(find "$DERIVED_DATA/Build/Products" -maxdepth 2 -name 'ZenTomato.app' -path '*iphoneos*' | head -1)"
[[ -n "$app" ]] || die "the build succeeded but produced no .app bundle." "" "$(tail -15 "$build_log")"

# --- 4 · install -----------------------------------------------------------
printf 'install-device.sh: installing %s…\n' "$app"
xcrun devicectl device install app --device "$udid" "$app"

printf '\ninstall-device.sh: installed. Open ZenTomato on the phone.\n'
