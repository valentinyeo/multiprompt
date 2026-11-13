# Native AI usage telemetry

The collector for multiprompt's native Combined and Today's AI cards runs inside
`multibot.exe`. It does not host HTTP, render a dashboard, add a tray icon,
start a second process, or require Node.js.

Build it with:

```powershell
zig build
```

One background worker thread runs the collector only while the usage meter is
wanted: while the usage card is hovered or after the sidebar card has been
switched in this session. The UI thread only sets that wanted flag and signals the worker. It never
waits on a fetch and has no polling timer for this. The worker exits when the
meter is no longer wanted and when the app closes. The pure start and stop
decision and the poll interval policy live in `src/usage_worker_plan.zig`.

The named mutex `Local\MultipromptUsageTelemetry` keeps one worker alive across
all workspace windows, and a legacy helper from an older version blocks a new
worker the same way. Setting the named event
`Local\MultipromptUsageTelemetryRefresh` requests an immediate refresh without
bypassing Claude's provider cooldown; the reconnect script does this after a
verified sign-in. On update, `--relaunch-after` stops legacy
`multiprompt-telemetry*.exe` processes from the same executable directory.

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
