#!/bin/bash
# cortex-logout.sh — revoke this device's token server-side (POST /auth/logout,
# which flips api_tokens.revoked + primes the Redis revoked:{tid} kill switch) and
# delete the local credentials. Best-effort: even if the server is unreachable we
# still remove the local token so the machine is disconnected.
set -uo pipefail

CRED_FILE="${HOME}/.cortex/credentials.json"

if [ ! -f "$CRED_FILE" ]; then
  echo "cortex-logout: not logged in."
  exit 0
fi

if command -v python3 >/dev/null 2>&1; then
  token="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("access_token",""))' "$CRED_FILE" 2>/dev/null)"
  base="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("base_url",""))' "$CRED_FILE" 2>/dev/null)"
  if [ -n "${token:-}" ] && [ -n "${base:-}" ] && command -v curl >/dev/null 2>&1; then
    curl -fsS -m 10 -X POST "${base%/}/auth/logout" \
      -H "authorization: Bearer ${token}" >/dev/null 2>&1 \
      && echo "cortex-logout: token revoked on Cortex Cloud." \
      || echo "cortex-logout: could not reach Cortex Cloud (removing local token anyway)."
  fi
fi

rm -f "$CRED_FILE"
echo "cortex-logout: disconnected (local credentials removed)."
