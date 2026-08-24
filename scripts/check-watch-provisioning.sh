#!/bin/bash
#
# check-watch-provisioning.sh — say whether the watch app can actually install.
#
# WHY THIS EXISTS
# On 2026-08-24 the watch app was built, embedded and signed correctly, installed
# with the phone app, and never appeared on the wrist. Nothing reported an error:
# iOS installs the container app and silently declines the watch app when the
# watch app's provisioning does not cover the watch. Four separate checks of the
# bundle all looked healthy, because the bundle WAS healthy.
#
# The fault was one level up, in the provisioning profile, and it is invisible
# from the app itself. This script looks there.
#
# WHAT MUST BE TRUE, and all three are checked below:
#   1. The embedded watch app carries its own provisioning profile.
#   2. That profile's Platform list includes watchOS. An iOS profile cannot
#      authorise a watchOS app, however correctly the app is signed.
#   3. The paired Apple Watch's UDID appears in the profile's device list.
#
# READ-ONLY. It decodes profiles already on disk and asks the connected devices
# for their identifiers. It builds nothing, installs nothing and signs nothing.
#
# EXIT CODES
#   0  the watch app should install
#   1  it cannot install, and the reason is printed
#   2  a usage failure, or nothing built to inspect

set -uo pipefail

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly APP="${REPO_ROOT}/DerivedData/Build/Products/Debug-iphoneos/ZenTomato.app"
readonly WATCH_APP="${APP}/Watch/ZenTomatoWatch.app"

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

if [ ! -d "${WATCH_APP}" ]; then
  echo "check-watch-provisioning.sh: no built watch app at" >&2
  echo "  ${WATCH_APP}" >&2
  echo "Run 'make device' first — and note the folder matters: a bare xcodebuild" >&2
  echo "without -derivedDataPath writes somewhere else entirely." >&2
  exit 2
fi

profile="${WATCH_APP}/embedded.mobileprovision"
if [ ! -f "${profile}" ]; then
  echo "FAIL — the watch app carries no provisioning profile at all." >&2
  exit 1
fi

decoded="$(mktemp -t zt-wp)"
trap 'rm -f "${decoded}"' EXIT
security cms -D -i "${profile}" > "${decoded}" 2>/dev/null

name="$(/usr/libexec/PlistBuddy -c "Print :Name" "${decoded}" 2>/dev/null)"
platforms="$(/usr/libexec/PlistBuddy -c "Print :Platform" "${decoded}" 2>/dev/null | tr -d ' ' | tr '\n' ' ')"

say "The profile the watch app is signed with"
echo "  name      : ${name}"
echo "  platforms : ${platforms}"

failed=0

if printf '%s' "${platforms}" | grep -qi "watchOS"; then
  echo "  OK — it is a watchOS profile."
else
  echo "  FAIL — this profile does not cover watchOS."
  echo "         An iOS profile cannot authorise a watchOS app, however correctly"
  echo "         the app itself is signed. This is the usual cause."
  failed=1
fi

say "Is the paired watch in its device list?"
# devicectl will not write JSON to a pipe; it needs a real file.
devices_json="$(mktemp -t zt-devices)"
trap 'rm -f "${decoded}" "${devices_json}"' EXIT
xcrun devicectl list devices -j "${devices_json}" >/dev/null 2>&1
watch_udid="$(python3 -c "
import json,sys
try: d=json.load(open('${devices_json}'))
except Exception: sys.exit()
for x in d.get('result',{}).get('devices',[]):
    p=x.get('hardwareProperties',{})
    if 'Watch' in str(p.get('marketingName','')): print(p.get('udid','')); break
")"

if [ -z "${watch_udid}" ]; then
  echo "  No Apple Watch found. Pair one, or connect the iPhone it is paired to."
  failed=1
else
  echo "  watch UDID: ${watch_udid}"
  if /usr/libexec/PlistBuddy -c "Print :ProvisionedDevices" "${decoded}" 2>/dev/null \
    | grep -qi "${watch_udid}"; then
    echo "  OK — the watch is provisioned."
  else
    echo "  FAIL — the watch is NOT in this profile's device list."
    echo "         iOS will install the phone app and silently skip the watch app."
    failed=1
  fi
fi

if [ "${failed}" -ne 0 ]; then
  cat <<'NEXT'

WHAT TO DO — it needs the developer account, so it is yours rather than the agent's:

  1. make generate && open ZenTomato.xcodeproj
  2. Keep the iPhone connected and the Watch on your wrist and unlocked.
  3. Xcode > Window > Devices and Simulators — the watch should appear under the
     iPhone. If it does not, unlock both and wait; the watch is only reachable
     through its paired phone.
  4. Select the ZenTomatoWatch target > Signing & Capabilities, and confirm the
     Team. Xcode registers the watch and creates a watchOS profile at that point.
  5. make device
  6. scripts/check-watch-provisioning.sh   (this script, again)

NEXT
  exit 1
fi

say "The watch app should install. If it still does not appear:"
echo "  iPhone > Watch app > scroll to Available Apps > ZenTomato > Install."
echo "  A development build often needs that nudge rather than arriving on its own."
exit 0
