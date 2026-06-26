---
description: "Show the current Cortex Cloud connection (org, plan) or whether the token was revoked. Usage: /cortex-status"
---

# /cortex-status — Cortex Cloud connection status

Calls `GET /v1/me` with the stored device token and reports one of three states:

- **not connected** — no local credentials (run `/cortex-login`).
- **connected** — shows the org and plan.
- **expired/revoked** — the token no longer works (the kill switch fired or it
  aged out); run `/cortex-login` to reconnect.

## Run it

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/cortex-status.sh"
```

Relay the status plainly to the user.
