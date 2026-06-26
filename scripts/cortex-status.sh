#!/bin/bash
# cortex-status.sh — show the current Cortex Cloud connection by calling
# GET /v1/me with the stored device token. Distinguishes "not connected",
# "connected", and "token expired/revoked" (the kill switch having fired).
set -uo pipefail

CRED_FILE="${HOME}/.cortex/credentials.json"

if [ ! -f "$CRED_FILE" ]; then
  echo "Cortex Cloud: not connected. Run /cortex-login to connect."
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "cortex-status: 'python3' is required."; exit 1; }
command -v curl    >/dev/null 2>&1 || { echo "cortex-status: 'curl' is required.";    exit 1; }

token="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("access_token",""))' "$CRED_FILE" 2>/dev/null)"
base="$(python3  -c 'import json,sys;print(json.load(open(sys.argv[1])).get("base_url",""))'      "$CRED_FILE" 2>/dev/null)"
base="${base%/}"

body_file="$(mktemp "${TMPDIR:-/tmp}/cortex_me.XXXXXX")"
trap 'rm -f "$body_file"' EXIT

status="$(curl -sS -m 10 -o "$body_file" -w '%{http_code}' \
            "${base}/v1/me" -H "authorization: Bearer ${token}" 2>/dev/null)" || status="000"

case "$status" in
  200)
    python3 - "$body_file" <<'PY'
import sys, json
with open(sys.argv[1]) as _f:
    m = json.load(_f)
print("Cortex Cloud: connected ✓")
print(f"  org:   {m.get('org_name') or m.get('org_id')}")
print(f"  plan:  {m.get('plan')}")
role = m.get("role")
if role:
    print(f"  role:  {role}")
PY
    ;;
  401)
    echo "Cortex Cloud: token expired or revoked. Run /cortex-login to reconnect."
    ;;
  *)
    echo "Cortex Cloud: connected, but the service is unreachable right now (HTTP ${status})."
    ;;
esac
