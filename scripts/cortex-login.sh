#!/bin/bash
# cortex-login.sh — OAuth 2.0 Device Authorization Grant (RFC 8628) against
# Cortex Cloud. Mirrors the backend contract in app/api/device.py exactly:
#   POST /auth/device  -> { device_code, user_code, verification_url, interval, expires_in }
#   POST /auth/token   -> 428 authorization_pending / 429 slow_down / 400 expired|denied / 200 token
# On success the device JWT is written to ~/.cortex/credentials.json (chmod 600).
# The raw token lives ONLY on disk here; the server stores only sha256(token).
set -uo pipefail

BASE_URL="${CORTEX_CLOUD_URL:-${1:-https://cloud.cortex.alphaai.com}}"
BASE_URL="${BASE_URL%/}"  # strip trailing slash
CRED_DIR="${HOME}/.cortex"
CRED_FILE="${CRED_DIR}/credentials.json"

command -v curl >/dev/null 2>&1 || { echo "cortex-login: 'curl' is required."; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "cortex-login: 'python3' is required."; exit 1; }

# ── 1) Start the grant ───────────────────────────────────────────────────────
resp="$(curl -fsS -m 10 -X POST "${BASE_URL}/auth/device" \
          -H 'content-type: application/json' -d '{}' 2>/dev/null)" || {
  echo "cortex-login: could not reach Cortex Cloud at ${BASE_URL}."
  echo "  Set the URL with:  CORTEX_CLOUD_URL=https://your-cloud /cortex-login"
  exit 1
}

# Single parse: these fields are all whitespace-free, so word-splitting is safe.
read -r device_code user_code verification_url interval expires_in <<EOF
$(printf '%s' "$resp" | python3 -c 'import sys,json
d=json.load(sys.stdin)
print(d["device_code"], d["user_code"], d["verification_url"], d["interval"], d["expires_in"])' 2>/dev/null)
EOF

if [ -z "${user_code:-}" ] || [ -z "${device_code:-}" ]; then
  echo "cortex-login: unexpected response from /auth/device."; exit 1
fi

echo ""
echo "  Connect this machine to Cortex Cloud:"
echo "    1. Open:        ${verification_url}"
echo "    2. Enter code:  ${user_code}"
echo ""
echo "  Waiting for approval (expires in $(( expires_in / 60 )) min)…"

# ── 2) Poll /auth/token, honoring the interval + slow_down ───────────────────
deadline=$(( $(date +%s) + expires_in ))
body_file="$(mktemp "${TMPDIR:-/tmp}/cortex_token.XXXXXX")"
trap 'rm -f "$body_file"' EXIT

while [ "$(date +%s)" -lt "$deadline" ]; do
  sleep "$interval"
  status="$(printf '%s' "$device_code" \
    | python3 -c 'import sys,json;print(json.dumps({"device_code":sys.stdin.read()}))' \
    | curl -sS -m 10 -o "$body_file" -w '%{http_code}' \
        -X POST "${BASE_URL}/auth/token" -H 'content-type: application/json' -d @- 2>/dev/null)" \
    || { status="000"; }   # network blip — keep polling until the deadline

  case "$status" in
    200)
      mkdir -p "$CRED_DIR"; chmod 700 "$CRED_DIR" 2>/dev/null || true
      if BASE_URL="$BASE_URL" CRED_FILE="$CRED_FILE" \
         python3 - "$body_file" <<'PY'
import sys, json, time, os
with open(sys.argv[1]) as _f:
    t = json.load(_f)
out = {
    "access_token": t["access_token"],
    "token_type": t.get("token_type", "bearer"),
    "org_id": t.get("org_id"),
    "expires_in": t.get("expires_in"),
    "base_url": os.environ["BASE_URL"],
    "obtained_at": int(time.time()),
}
with open(os.environ["CRED_FILE"], "w") as f:
    json.dump(out, f, indent=2)
PY
      then
        chmod 600 "$CRED_FILE"
        echo "  ✓ Connected. Token saved to ${CRED_FILE} (chmod 600)."
        exit 0
      else
        echo "cortex-login: failed to write ${CRED_FILE}."; exit 1
      fi
      ;;
    428) : ;;                       # authorization_pending — keep polling
    429) sleep "$interval" ;;       # slow_down — back off an extra interval
    400)
      echo "  ✗ The code expired or was denied. Run /cortex-login to try again."
      exit 1
      ;;
    *) : ;;                          # 000/5xx transient — keep trying
  esac
done

echo "  ✗ Timed out waiting for approval. Run /cortex-login to try again."
exit 1
