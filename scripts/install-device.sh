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
# A SIMULATOR IS NOT A DEVICE, AND `devicectl list devices` LISTS BOTH.
# This picked the first entry whose marketing name contained "iPhone" and broke,
# so on a Mac with an iPhone simulator it chose the simulator — built for
# `Debug-iphonesimulator` and then died with "the build succeeded but produced no
# .app bundle", which names the symptom and not the cause. It cost the owner a
# device check.
#
# `transportType == "sameMachine"` is what separates them. `hardwareProperties`
# has no usable flag: `isSimulated` is ABSENT on every entry, simulator and phone
# alike, so a truthiness test on it selects nothing and a falsiness test selects
# everything.
def physical_iphones(devices):
    for d in devices:
        hardware = d.get("hardwareProperties", {})
        connection = d.get("connectionProperties", {})
        if connection.get("transportType") == "sameMachine":
            continue
        if "iPhone" in (hardware.get("marketingName") or ""):
            yield d


candidates = list(physical_iphones(devices))
if candidates:
    # Prefer one the Mac can currently reach, but do not require it: a phone that
    # is merely paired still builds, and step 4 gives a specific error if the
    # install itself cannot reach it.
    candidates.sort(
        key=lambda d: d.get("connectionProperties", {}).get("tunnelState") != "connected")
    chosen = candidates[0]
    hardware = chosen.get("hardwareProperties", {})
    properties = chosen.get("deviceProperties", {})
    # The name is printed with non-breaking spaces so that a phone called
    # "Marty's iPhone" stays ONE whitespace-delimited field and does not
    # shift the OS version into the wrong variable. Undone below.
    print(hardware.get("udid", ""),
          (properties.get("name") or "iPhone").replace(" ", "\u00a0"),
          properties.get("osVersionNumber", "?"))
else:
    # Say WHICH failure it is. "No iPhone" and "only simulators" have different
    # fixes, and the previous version could report neither because it never knew
    # the difference.
    simulated = sum(
        1 for d in devices
        if d.get("connectionProperties", {}).get("transportType") == "sameMachine"
        and "iPhone" in (d.get("hardwareProperties", {}).get("marketingName") or ""))
    # `NONE` AND NOT THREE EMPTY FIELDS. `read -r udid name os note` strips leading
    # whitespace, so printing `"" "" "" note` put the NOTE into `udid`, the empty
    # check passed, and the build ran with `-destination id=simulators=2`. An
    # explicit sentinel cannot collapse.
    print("NONE", "-", "-", f"simulators={simulated}")
PYEOF
)"; then
  die "could not read the list of attached devices." \
      "" \
      "This needs python3, which ships with the Xcode command line tools:" \
      "  xcode-select --install"
fi

read -r udid name os note <<<"$device_line" || true

if [[ -z "${udid:-}" || "${udid}" == "NONE" ]]; then
  if [[ "${note:-}" == simulators=* && "${note#simulators=}" != "0" ]]; then
    die "no PHYSICAL iPhone is paired with this Mac — only ${note#simulators=} simulator(s)." \
        "" \
        "A simulator cannot be the target of a device build, and choosing one is" \
        "how this script used to fail with 'the build succeeded but produced no" \
        ".app bundle'." \
        "" \
        "Plug the phone in with a cable, unlock it, and tap Trust when it asks." \
        "For a simulator build instead:  make test"
  fi
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

# A FRESH BUILD NUMBER ON EVERY DEVICE INSTALL, AND WHY IT IS NOT OPTIONAL.
#
# devicectl replaces the phone app whatever its version says. The WATCH app does
# not arrive that way: iOS carries it across from the phone itself, and it
# compares versions first. Every build until now was 0.1.0 (1), so after the very
# first install iOS concluded there was nothing new and left the old watch app in
# place — which is why an icon fix, correctly built and correctly embedded, never
# reached the wrist. Nothing reported it; there is nothing to report.
#
# The timestamp is passed as a build setting rather than written into
# project.yml, so the repository keeps one honest version and does not collect a
# commit per install. Release builds are unaffected.
build_number="$(date +%Y%m%d%H%M)"
printf 'install-device.sh: build %s\n' "$build_number"

if ! xcodebuild build \
  -project "$PROJECT" -scheme "$SCHEME" \
  -destination "id=${udid}" \
  -derivedDataPath "$DERIVED_DATA" \
  CURRENT_PROJECT_VERSION="$build_number" \
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
  if grep -qi 'No Accounts: Add a new account' "$build_log"; then
    die "Xcode has no Apple ID signed in, so it cannot create a signing profile." \\
        "" \\
        "Xcode > Settings > Accounts > + > Apple ID" \\
        "" \\
        "This is only needed if no usable provisioning profile already exists." \\
        "Check first — a wildcard profile covers every bundle id on its team:" \\
        "  ls ~/Library/Developer/Xcode/UserData/Provisioning\\ Profiles/"
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

  # THE PRODUCT NAME IS NOT HARDCODED, AND `C26` IS WHY.
  # `CFBundleName` still expands to the target name `ZenTomato` while the app shows
  # as ZenPom, and the fix is `PRODUCT_NAME: ZenPom` in project.yml — which renames
  # the BUNDLE ON DISK from ZenTomato.app to ZenPom.app. Three scripts named that
  # file literally, so the rename would have broken them all, and
  # install-device.sh's failure would have read "the build succeeded but produced
  # no .app bundle" — the exact misleading message `C38` was just fixed to stop
  # printing. A path that must change when a build setting changes is a path that
  # should be discovered, not typed.
  app="$(find "$DERIVED_DATA/Build/Products" -maxdepth 2 -name '*.app' -path '*iphoneos*' | head -1)"
[[ -n "$app" ]] || die "the build succeeded but produced no .app bundle." "" "$(tail -15 "$build_log")"

# --- 4 · install -----------------------------------------------------------
printf 'install-device.sh: installing %s…\n' "$app"
xcrun devicectl device install app --device "$udid" "$app"

printf '\ninstall-device.sh: installed. Open ZenTomato on the phone.\n'
