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
dev_mode_ok=0

# THE PLATFORM LIST IS NOT THE TEST, AND ASSERTING IT WAS A BUG.
#
# This script first demanded that the platform list contain "watchOS". It does
# not, even on a working setup: Xcode's managed profile for a watch app is
# labelled `iOS xrOS visionOS` because a companion watch app is provisioned under
# the iOS profile type. Once the real fix landed — an explicit App ID for
# com.martingleason.ZenTomato.watchkitapp, with the watch registered — this
# script would still have called it broken.
#
# A check that fails on a working configuration is worse than no check: it is
# read once, disbelieved, and then ignored when it is right.
#
# What actually decides whether the watch app can install is the App ID and the
# device list, both checked below.
app_id="$(/usr/libexec/PlistBuddy -c "Print :Entitlements:application-identifier" "${decoded}" 2>/dev/null)"
echo "  App ID    : ${app_id}"

case "${app_id}" in
  *com.martingleason.ZenTomato.watchkitapp)
    echo "  OK — an explicit App ID for the watch app."
    ;;
  *\*)
    echo "  WARN — a wildcard App ID. It can install, but cannot carry a"
    echo "         capability, which is why MusicKit is unentitled (see O14)."
    ;;
  *)
    echo "  FAIL — this profile is for ${app_id}, not the watch app."
    failed=1
    ;;
esac

# Asked once, before anything needs it. devicectl will not write JSON to a pipe,
# so it gets a real file.
devices_json="$(mktemp -t zt-devices)"
trap 'rm -f "${decoded}" "${devices_json}"' EXIT
xcrun devicectl list devices -j "${devices_json}" >/dev/null 2>&1

say "Developer Mode, as the devices actually report it"
dev_mode="$(python3 -c "
import json,sys
try: d=json.load(open('${devices_json}'))
except Exception: sys.exit()
for x in d.get('result',{}).get('devices',[]):
    hw=x.get('hardwareProperties',{}); dp=x.get('deviceProperties',{})
    n=hw.get('marketingName','?')
    if 'Watch' in n or 'iPhone' in n:
        print(f\"  {n:<24} developer mode: {dp.get('developerModeStatus','unknown')}\")
" 2>/dev/null)"
if [ -n "${dev_mode}" ]; then
  printf '%s\n' "${dev_mode}"
  if printf '%s' "${dev_mode}" | grep -q "developer mode: enabled"; then
    dev_mode_ok=1
  fi
else
  echo "  (no devices reachable — connect the iPhone)"
fi

say "Is the paired watch in its device list?"
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
  if [ "${dev_mode_ok}" -eq 0 ]; then
    cat <<'NEXT'

FIRST: turn on Developer Mode ON THE WATCH — everything else waits on it.
    Watch > Settings > Privacy & Security > Developer Mode > on
  The watch restarts; unlock it and confirm the prompt.

NEXT
  else
    cat <<'NEXT'

Developer Mode is already on, so that is not what is stopping this.

NEXT
  fi

  cat <<NEXT
WHAT IS LEFT — it needs the developer account, so it is yours; see docs/chores/C8.md.

  THE WATCH IS NOT REGISTERED AS A DEVELOPMENT DEVICE. Developer Mode makes a
  watch WILLING to run development builds; registering it is what makes a profile
  able to name it, and they are separate things. xcodebuild cannot do the second
  from here, because a watch is never a build destination — it is reachable only
  through the iPhone it is paired to.

  The most reliable route, which does not depend on Xcode noticing the watch:

    1. developer.apple.com > Certificates, Identifiers & Profiles > Devices > +
       Platform : watchOS
       Device ID: ${watch_udid}
       Name     : anything

    2. While you are there (this is O14, the other half of the same fault):
       Identifiers > + > App IDs, explicit, for
         com.martingleason.ZenTomato               with MusicKit enabled
         com.martingleason.ZenTomato.watchkitapp
       The app is currently signed with the team wildcard KH6NBQRZBY.*, which
       cannot carry a capability — which is why every launch logs
       ICError -7013 "Client is not entitled to access account store".

    3. make generate && open ZenTomato.xcodeproj, iPhone CONNECTED BY CABLE.
       Xcode > Settings > Accounts > Download Manual Profiles.
       Both targets > Signing & Capabilities: confirm the Team and let Xcode
       regenerate. It should now choose the explicit App IDs.

    4. make device
    5. scripts/check-watch-provisioning.sh

  If the watch app still does not appear after a successful check:
    iPhone > Watch app > scroll to Available Apps > ZenTomato > Install.

NEXT
  exit 1
fi

say "The watch app should install. If it still does not appear:"
echo "  iPhone > Watch app > scroll to Available Apps > ZenTomato > Install."
echo "  A development build often needs that nudge rather than arriving on its own."
exit 0
