#!/bin/bash
#
# check-musickit-entitlement.sh — is the app signed with an App ID that can carry MusicKit?
#
# WHY THIS EXISTS
# The app has been signed with the team wildcard KH6NBQRZBY.* since F1. A wildcard App ID
# cannot carry a capability, so there is no MusicKit entitlement, so MusicSubscription.current
# can never succeed — and every launch logs ICError -7013 "Client is not entitled to access
# account store". That is not noise; it is the literal answer.
#
# Nothing about it is visible from the app: playback works, because playing the local library
# needs no entitlement. Only the subscription check fails, and it fails softly into
# "couldn't be checked". So the fault has to be looked for where it lives, which is here.
#
# READ-ONLY. It decodes what is already built and signs nothing.
#
# EXIT CODES
#   0  the app carries a MusicKit entitlement under an explicit App ID
#   1  it does not, and the reason is printed
#   2  nothing built to inspect

set -uo pipefail

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly APP="${REPO_ROOT}/DerivedData/Build/Products/Debug-iphoneos/ZenTomato.app"

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

if [ ! -d "${APP}" ]; then
  echo "check-musickit-entitlement.sh: nothing built at" >&2
  echo "  ${APP}" >&2
  echo "Run 'make device' first — and note a bare xcodebuild without -derivedDataPath" >&2
  echo "writes somewhere else entirely." >&2
  exit 2
fi

entitlements="$(codesign -d --entitlements - --xml "${APP}" 2>/dev/null \
  | plutil -convert xml1 -o - - 2>/dev/null)"

say "What the built app is actually entitled to"
printf '%s' "${entitlements}" | grep -E "<key>" | sed 's/.*<key>/  /; s|</key>||'

failed=0

# THE PROFILE'S App ID, NOT THE APP'S ENTITLEMENT — and the difference is the whole trap.
#
# The app's `application-identifier` entitlement always reads as the specific bundle id, even
# when the profile that granted it is a wildcard: a wildcard profile signs any bundle id under
# the team and stamps the real one into the app. So reading the entitlement and calling it
# "explicit" is exactly the mistake that made this fault hard to see in the first place.
#
# The profile is where the capability lives, so the profile is what gets read.
decoded="$(mktemp -t zt-pp)"
trap 'rm -f "${decoded}"' EXIT
security cms -D -i "${APP}/embedded.mobileprovision" > "${decoded}" 2>/dev/null
profile_name="$(/usr/libexec/PlistBuddy -c "Print :Name" "${decoded}" 2>/dev/null)"
profile_id="$(/usr/libexec/PlistBuddy -c "Print :Entitlements:application-identifier" "${decoded}" 2>/dev/null)"

say "The profile it was signed with"
echo "  name   : ${profile_name}"
echo "  App ID : ${profile_id}"
case "${profile_id}" in
  *\*)
    echo "  FAIL — a wildcard profile. It can sign this app, which is why everything builds,"
    echo "         but it cannot grant a capability — so MusicKit is missing below, and every"
    echo "         launch logs ICError -7013 as a direct consequence."
    failed=1
    ;;
  *com.martingleason.ZenTomato)
    echo "  OK — an explicit App ID, which is what can carry MusicKit."
    ;;
  *)
    echo "  UNEXPECTED — this profile is for ${profile_id}, not this app."
    failed=1
    ;;
esac

say "MusicKit"
if printf '%s' "${entitlements}" | grep -q "com.apple.developer.musickit"; then
  echo "  OK — the entitlement is present."
else
  echo "  FAIL — no com.apple.developer.musickit entitlement."
  echo "         MusicSubscription.current cannot succeed, so the music row will always"
  echo "         read 'couldn't be checked'. Playback is unaffected."
  failed=1
fi

if [ "${failed}" -ne 0 ]; then
  cat <<'NEXT'

WHAT TO DO — it needs the developer account, so it is yours; see docs/chores/C11.md.

  1. developer.apple.com > Identifiers > + > App IDs > App
       Bundle ID  : EXPLICIT, com.martingleason.ZenTomato
       Capability : MusicKit
  2. Xcode > Settings > Accounts > Download Manual Profiles.
  3. Both targets > Signing & Capabilities: confirm the Team.
  4. make device, then run this again.

  IF NOTHING CHANGES, Xcode is preferring a cached wildcard profile. Delete the stale one
  from ~/Library/Developer/Xcode/UserData/Provisioning Profiles/ and download again — that
  is what unstuck the watch profile in C8, and it presents identically: a successful build
  that changes nothing.

NEXT
  exit 1
fi

say "Signed under an explicit App ID, with MusicKit. Nothing further needed here."
exit 0
