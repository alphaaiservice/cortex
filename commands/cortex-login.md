---
description: "Connect this machine to Cortex Cloud via secure OAuth device login (no password in the terminal). Usage: /cortex-login [cloud-url]"
---

# /cortex-login — Connect to Cortex Cloud

Logs this machine into **Cortex Cloud** using the OAuth 2.0 **Device Authorization
Grant** (RFC 8628) — the same "open a URL, type a code" flow as `gh auth login` or
`aws sso`. No password is ever typed in the terminal.

`$ARGUMENTS` (optional) overrides the Cortex Cloud base URL (default
`https://cloud.cortex.alphaai.com`). You can also set `CORTEX_CLOUD_URL`.

## What happens

1. The plugin calls `POST /auth/device` and shows you a short **user code** and a
   **verification URL** (`…/activate`).
2. You open that URL in your browser, sign in to the dashboard, and enter the code.
3. The plugin polls `POST /auth/token` (honoring the server's `interval` and
   `slow_down`) until you approve, then writes the device token to
   `~/.cortex/credentials.json` with `chmod 600`.

The raw token only ever lives on your disk — Cortex Cloud stores just its sha256
hash. Telemetry and premium features stay off until you connect; nothing here is
required to use the plugin locally.

## Run it

Execute the device-grant flow (this will print a code and wait for approval):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/cortex-login.sh" $ARGUMENTS
```

When it prints the code, tell the user — clearly — to open the verification URL and
enter the user code, then wait. On success report that the machine is connected; on
timeout or an expired/denied code, tell them to run `/cortex-login` again. Use
`/cortex-status` to check the connection later and `/cortex-logout` to disconnect.
