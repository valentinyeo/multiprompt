# Native AI usage telemetry

`multiprompt.exe --usage-telemetry` is the headless collector for multiprompt's native
Combined and Today's AI cards. It does not host HTTP, render a dashboard, add a
tray icon, or require Node.js.

Build it with:

```powershell
zig build
```

Multiprompt starts its own executable with `--usage-telemetry` before any UI,
session, workspace, single-instance or tray initialization. The named mutex
`Local\MultipromptUsageTelemetry` keeps one
collector alive across all workspace windows. Launching it again requests an
immediate refresh without bypassing Claude's provider cooldown. The app probes
that mutex rather than a process name before spawning a collector. On update,
`--relaunch-after` stops legacy `multiprompt-telemetry*.exe` processes from the
same executable directory, signals `Local\MultipromptUsageTelemetryStop`, and
waits for the collector mutex to release before launching the new app. No
separate telemetry executable is built or installed. Reconnect uses the exact
first `--usage-telemetry` argument and executable directory to stop only a
collector (including renamed images), never a workspace process.

Automatic usage polling runs every ten minutes. Claude credential expiry checks
remain independent; they read local credentials every two minutes and contact
the renewal endpoint only when needed.

Collector 1.4 uses its own User-Agent when renewing Claude credentials. Sending
the usage endpoint's `claude-code/` identifier to the token endpoint caused
HTTP 429 even when the refresh token was valid. The running collector also
notices credentials renewed by Claude Code and clears its stale auth retry.

The only shared output is the sanitized, atomically replaced file
`%APPDATA%\ZigShell\usage-telemetry.json`. Provider credentials remain in
their existing Claude, Codex, and Kimi stores. Per-machine labels and profile
paths belong in ignored `config.local.json`; copy `config.example.json` on a
new machine.
Claude accounts may set an optional `email` for login prefill; `label` is display-only.

Focused checks:

```powershell
zig build
python -m unittest .\test_kimi_usage.py
node --test ..\ai-pace-sidebar.test.js
```
