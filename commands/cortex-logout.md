---
description: "Disconnect this machine from Cortex Cloud — revokes the device token and removes local credentials. Usage: /cortex-logout"
---

# /cortex-logout — Disconnect from Cortex Cloud

Revokes this machine's device token on Cortex Cloud (`POST /auth/logout`, which
flips the token's `revoked` flag and primes the server-side kill switch so its next
request is rejected) and deletes the local `~/.cortex/credentials.json`.

Best-effort by design: if Cortex Cloud is unreachable, the local credentials are
still removed so the machine is disconnected either way.

## Run it

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/cortex-logout.sh"
```

Report whether the token was revoked server-side and confirm the local credentials
were removed.
