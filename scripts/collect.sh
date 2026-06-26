#!/bin/bash
# collect.sh — best-effort Cortex Cloud telemetry (PRD §6 Event Ingest).
#
# Reads a hook event JSON on stdin and sends/queues ONLY whitelisted metadata —
# the command/tool NAME plus an outcome flag. It NEVER sends code, prompts, file
# contents, absolute paths, or secrets (it never even reads tool_input/response).
#
# Hard contract (PRD §8): this MUST NEVER block the build. No token / offline /
# server down / 401 = a silent no-op. HTTP is bounded to a 2s timeout. The script
# always exits 0. SessionStart + PostToolUse buffer to ~/.cortex/queue.jsonl;
# Stop flushes the buffered batch to /v1/events/batch and clears the queue.
set -uo pipefail

CRED_FILE="${HOME}/.cortex/credentials.json"
QUEUE="${HOME}/.cortex/queue.jsonl"

# Telemetry is opt-in: it only runs once a machine is connected (/cortex-login).
[ -f "$CRED_FILE" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# Capture the hook payload from stdin into a temp file, so the python heredoc can
# use stdin for its own program and read the payload by path (no stdin clash).
PAYLOAD_FILE="$(mktemp "${TMPDIR:-/tmp}/cortex_evt.XXXXXX" 2>/dev/null)" || exit 0
cat > "$PAYLOAD_FILE" 2>/dev/null || true

python3 - "$PAYLOAD_FILE" "$CRED_FILE" "$QUEUE" <<'PY' >/dev/null 2>&1 || true
import sys, json, os, time, uuid, urllib.request

payload_file, cred_file, queue = sys.argv[1], sys.argv[2], sys.argv[3]
MAX_QUEUE = 500          # bound the buffer so it can't grow without limit
HTTP_TIMEOUT = 2         # never block the build


def _load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return {}


evt = _load(payload_file)
cred = _load(cred_file)
token = cred.get("access_token")
base = (cred.get("base_url") or "").rstrip("/")
if not token or not base:
    sys.exit(0)

hook = evt.get("hook_event_name") or evt.get("hookEventName") or ""


def _post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        base + path, data=data, method="POST",
        headers={"content-type": "application/json",
                 "authorization": "Bearer " + token},
    )
    try:
        urllib.request.urlopen(req, timeout=HTTP_TIMEOUT).read()
    except Exception:
        pass  # fire-and-forget: offline / down / 401 are all silent no-ops


def _append(event):
    try:
        os.makedirs(os.path.dirname(queue), exist_ok=True)
        lines = []
        if os.path.exists(queue):
            with open(queue) as f:
                lines = [ln for ln in f.read().splitlines() if ln.strip()]
        lines.append(json.dumps(event))
        with open(queue, "w") as f:
            f.write("\n".join(lines[-MAX_QUEUE:]) + "\n")
    except Exception:
        pass


now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

# Stop → flush the buffered batch (preferred path), then clear the queue.
if hook == "Stop":
    try:
        if os.path.exists(queue):
            with open(queue) as f:
                events = [json.loads(ln) for ln in f if ln.strip()]
            if events:
                _post("/v1/events/batch", {"events": events})
            open(queue, "w").close()  # clear regardless — telemetry is lossy-tolerant
    except Exception:
        pass
    sys.exit(0)

# Otherwise buffer ONE whitelisted event. Name + outcome ONLY — we deliberately
# never touch evt["tool_input"] / evt["tool_response"] (privacy contract).
if hook == "SessionStart":
    command = "session_start"
elif hook == "PostToolUse":
    command = "tool:" + str(evt.get("tool_name") or "unknown")
else:
    command = "event:" + (hook or "unknown")

_append({
    "type": "command_run",
    "command": command,
    "success": True,
    "event_id": str(uuid.uuid4()),  # client uuid → idempotent batch dedupe
    "ts": now,
})
sys.exit(0)
PY

rm -f "$PAYLOAD_FILE" 2>/dev/null || true
exit 0
