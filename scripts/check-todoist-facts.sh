#!/bin/bash
#
# check-todoist-facts.sh — settle three claims about Todoist's API against a
# real account, because none of them is settled by reading.
#
# WHY THIS EXISTS
# F3b and D22 turn on three behaviours that the documentation does not state and
# that community reports disagree about. Each was flagged by a researcher as
# NOT TESTED, and each changes the design if it goes the other way:
#
#   1. Does `GET /projects/{id}` still resolve a project AFTER it is archived?
#      If yes, an archived project keeps a readable name and the mirror only
#      needs a second endpoint. If no, archiving is as destructive as deleting
#      for our purposes and the name snapshot carries far more weight.
#
#   2. Does incremental sync report a removed project as a TOMBSTONE
#      (`is_deleted: true`), or does it simply stop mentioning it?
#      A tombstone lets the mirror mark a project gone and keep its last known
#      name. Silent omission means the mirror can only ever notice by absence,
#      which needs a "seen this pass?" sweep instead.
#
#   3. Do old all-numeric task IDs still resolve on API v1?
#      If they do not, an ID stored before the migration is a dangling key and
#      the name snapshot is the only durable record of what a block was for.
#
# THIS SCRIPT IS READ-ONLY. It issues GETs and one `POST /sync`, which is Sync's
# read operation and carries no `commands` array. It creates nothing, completes
# nothing, deletes nothing. It is a diagnostic tool and is not part of the app:
# `scripts/` is deliberately outside the reach of check-todoist-writes.sh, and
# nothing here may be taken as licence to add an endpoint to the app's allowlist.
#
# YOUR TOKEN NEVER TOUCHES THE DISK.
# It is read from TODOIST_TOKEN if set, otherwise prompted for silently. It is
# never echoed, never written to a file, never placed in a command line where
# `ps` could read it, and never included in this script's output. The sync token
# IS written to a temp file between phases — that is a pagination cursor, not a
# credential.
#
# USAGE
#   scripts/check-todoist-facts.sh              # claims 1 and 3, plus sync phase 1
#   scripts/check-todoist-facts.sh --phase2     # claim 2, after you change something
#   scripts/check-todoist-facts.sh --task-id ID # also test one specific legacy ID
#
# EXIT CODES
#   0  every claim that could be tested was tested
#   1  a request failed in a way that stops the check
#   2  usage or configuration failure

set -uo pipefail

readonly API="https://api.todoist.com/api/v1"
readonly STATE="${TMPDIR:-/tmp}/zentomato-todoist-sync-token"

legacy_task_id=""
phase2=false

while [ $# -gt 0 ]; do
  case "$1" in
    --phase2) phase2=true; shift ;;
    --task-id) legacy_task_id="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -z "${TODOIST_TOKEN:-}" ]; then
  printf 'Todoist API token (input hidden): ' >&2
  read -rs TODOIST_TOKEN
  printf '\n' >&2
fi
if [ -z "${TODOIST_TOKEN}" ]; then
  echo "check-todoist-facts.sh: no token given." >&2
  exit 2
fi

# Every request goes through here so the token appears in exactly one place and
# is passed via a header file on stdin rather than argv, where `ps` would show it.
api_get() {
  curl -sS --max-time 20 -H @<(printf 'Authorization: Bearer %s\n' "${TODOIST_TOKEN}") \
    -w '\n%{http_code}' "$@"
}

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
verdict() { printf '  VERDICT: %s\n' "$1"; }

json() { python3 -c "$1" 2>/dev/null; }

# ---------------------------------------------------------------------------
if [ "${phase2}" = false ]; then

say "CLAIM 1 — does an archived project still resolve by id?"

archived_body="$(api_get "${API}/projects/archived?limit=200")"
archived_code="$(printf '%s' "${archived_body}" | tail -n1)"
archived_json="$(printf '%s' "${archived_body}" | sed '$d')"

if [ "${archived_code}" != "200" ]; then
  echo "  GET /projects/archived returned HTTP ${archived_code}" >&2
  echo "  (401 means the token was rejected; nothing else was attempted.)" >&2
  exit 1
fi

archived_count="$(printf '%s' "${archived_json}" | json '
import json,sys
d=json.load(sys.stdin)
print(len(d.get("results",[])))')"

echo "  GET /projects/archived → HTTP 200, ${archived_count:-0} archived project(s)."

if [ "${archived_count:-0}" = "0" ]; then
  verdict "UNTESTED — you have no archived projects."
  echo "  To settle this: archive any throwaway project in Todoist, then re-run."
else
  first_id="$(printf '%s' "${archived_json}" | json '
import json,sys
d=json.load(sys.stdin)
print(d["results"][0]["id"])')"
  first_name="$(printf '%s' "${archived_json}" | json '
import json,sys
d=json.load(sys.stdin)
print(d["results"][0].get("name",""))')"
  echo "  Testing archived project \"${first_name}\"."

  single="$(api_get "${API}/projects/${first_id}")"
  single_code="$(printf '%s' "${single}" | tail -n1)"
  single_json="$(printf '%s' "${single}" | sed '$d')"
  echo "  GET /projects/{id} → HTTP ${single_code}"

  if [ "${single_code}" = "200" ]; then
    name="$(printf '%s' "${single_json}" | json '
import json,sys
print(json.load(sys.stdin).get("name",""))')"
    flag="$(printf '%s' "${single_json}" | json '
import json,sys
print(json.load(sys.stdin).get("is_archived","absent"))')"
    verdict "RESOLVES. name=\"${name}\" is_archived=${flag}"
    echo "  → A live lookup can label an archived project. The mirror must read"
    echo "    BOTH /projects and /projects/archived or it will lose the name."
  else
    verdict "DOES NOT RESOLVE (HTTP ${single_code})."
    echo "  → Archiving is as destructive as deleting for labelling purposes."
    echo "    The name snapshot becomes the only record. Weigh D22 accordingly."
  fi
fi

# ---------------------------------------------------------------------------
say "CLAIM 3 — do old all-numeric task ids still resolve?"

tasks_body="$(api_get "${API}/tasks?limit=200")"
tasks_code="$(printf '%s' "${tasks_body}" | tail -n1)"
tasks_json="$(printf '%s' "${tasks_body}" | sed '$d')"

if [ "${tasks_code}" = "200" ]; then
  printf '%s' "${tasks_json}" | json '
import json,sys
d=json.load(sys.stdin); rows=d.get("results",[])
numeric=[t["id"] for t in rows if str(t["id"]).isdigit()]
alnum=[t["id"] for t in rows if not str(t["id"]).isdigit()]
print(f"  {len(rows)} active task(s): {len(alnum)} alphanumeric id(s), {len(numeric)} all-numeric id(s).")
if numeric:
    print(f"  An all-numeric id is still live on this account, e.g. {numeric[0]}")
    print("  VERDICT: MIXED ID FORMATS IN USE — an id column must not assume one shape.")
else:
    print("  VERDICT: every active id is alphanumeric.")
    print("  This does not prove old ids are dead, only that none is in active use.")
    print("  Re-run with --task-id <old numeric id> if you have one recorded.")'
else
  echo "  GET /tasks → HTTP ${tasks_code}" >&2
fi

if [ -n "${legacy_task_id}" ]; then
  echo "  Testing supplied id ${legacy_task_id}:"
  one="$(api_get "${API}/tasks/${legacy_task_id}")"
  one_code="$(printf '%s' "${one}" | tail -n1)"
  echo "  GET /tasks/{id} → HTTP ${one_code}"
  if [ "${one_code}" = "200" ]; then
    verdict "LEGACY ID RESOLVES — old ids are still keys."
  else
    verdict "LEGACY ID DOES NOT RESOLVE — a stored id can dangle. Keep the snapshot."
  fi
fi

# ---------------------------------------------------------------------------
say "CLAIM 2 — phase 1: taking a sync token"

sync1="$(curl -sS --max-time 20 \
  -H @<(printf 'Authorization: Bearer %s\n' "${TODOIST_TOKEN}") \
  -d 'sync_token=*' -d 'resource_types=["projects"]' \
  -w '\n%{http_code}' "${API}/sync")"
sync1_code="$(printf '%s' "${sync1}" | tail -n1)"
sync1_json="$(printf '%s' "${sync1}" | sed '$d')"

if [ "${sync1_code}" != "200" ]; then
  echo "  POST /sync → HTTP ${sync1_code}. Cannot test tombstones." >&2
  exit 1
fi

printf '%s' "${sync1_json}" | json '
import json,sys
d=json.load(sys.stdin); p=d.get("projects",[])
deleted=[x for x in p if x.get("is_deleted")]
print(f"  Full sync returned {len(p)} project(s); {len(deleted)} already flagged is_deleted.")'

printf '%s' "${sync1_json}" | json '
import json,sys
print(json.load(sys.stdin).get("sync_token",""))' > "${STATE}"
chmod 600 "${STATE}"
echo "  Sync token saved to ${STATE} (a cursor, not a credential)."
echo
echo "  NOW DO THIS, then re-run with --phase2:"
echo "    1. Create a throwaway project in Todoist, e.g. \"zt-tombstone-test\"."
echo "    2. Re-run this script (phase 1) to take a fresh token AFTER creating it."
echo "    3. Delete that project."
echo "    4. scripts/check-todoist-facts.sh --phase2"

# ---------------------------------------------------------------------------
else

say "CLAIM 2 — phase 2: what does sync say about what changed?"

if [ ! -f "${STATE}" ]; then
  echo "  No stored sync token at ${STATE}. Run phase 1 first." >&2
  exit 2
fi
stored="$(cat "${STATE}")"

sync2="$(curl -sS --max-time 20 \
  -H @<(printf 'Authorization: Bearer %s\n' "${TODOIST_TOKEN}") \
  --data-urlencode "sync_token=${stored}" -d 'resource_types=["projects"]' \
  -w '\n%{http_code}' "${API}/sync")"
sync2_code="$(printf '%s' "${sync2}" | tail -n1)"
sync2_json="$(printf '%s' "${sync2}" | sed '$d')"

echo "  POST /sync (incremental) → HTTP ${sync2_code}"
if [ "${sync2_code}" != "200" ]; then exit 1; fi

printf '%s' "${sync2_json}" | json '
import json,sys
d=json.load(sys.stdin); p=d.get("projects",[])
print(f"  {len(p)} project(s) in the delta.")
for x in p:
    print(f"    - {x.get(\"name\",\"?\")}  id={x.get(\"id\")}  is_deleted={x.get(\"is_deleted\",\"absent\")}  is_archived={x.get(\"is_archived\",\"absent\")}")
tomb=[x for x in p if x.get("is_deleted")]
print()
if tomb:
    print("  VERDICT: TOMBSTONES ARE RETURNED.")
    print("  → The mirror can mark a project gone and KEEP its last known name.")
    print("    A deleted project can still be labelled in the export.")
elif p:
    print("  VERDICT: changes returned, but NO is_deleted tombstone among them.")
    print("  → If you deleted a project, sync reported it by silence.")
    print("    The mirror needs a seen-this-pass sweep, and a deleted project")
    print("    loses its name unless the snapshot holds it. This strengthens D22.")
else:
    print("  VERDICT: empty delta — nothing changed since the stored token.")
    print("  → Make the change described in phase 1, then re-run --phase2.")'

fi

say "Done. Nothing was created, modified or deleted by this script."
