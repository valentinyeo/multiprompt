# Contributing

Use Zig 0.16. Build on Windows with `zig build`, or use `zig build dev` for a separate development executable and session file. On Linux, cross-build with `zig build -Dtarget=x86_64-windows-gnu`. Window hosting, focus, DPI, clipboard, and browser behavior need interactive Windows testing.

## Checks

On Windows, run `zig build test` with Node.js, Python, and PowerShell installed. Portable Linux checks are collected by:

```sh
python3 tools/public_audit.py --verify
```

Set `ZIG` to your Zig executable if it is not on PATH. This runs a Windows cross-build, standalone portable Zig tests, Node regression tests, Python tests, and the worker tests. Service and documentation dependencies use `npm ci` in their respective directories. To build the documentation, run `npm run build` in `docs-site/` (Node.js 22.12 or newer).

Before submitting a change, run `zig fmt --check build.zig src/*.zig` and secret scans:

```sh
gitleaks dir .
trufflehog filesystem . --no-update --fail
```

Keep personal runtime data, credentials, screenshots of real sessions, and build artifacts out of commits. Changes to shortcuts should update the F1 table and [shortcut reference](openwiki/operations/keyboard-shortcuts.md). Browser extension and native bridge versions must match.

## Remote shells

The three built-in host slots use SSH config aliases `remote-1`, `remote-2`, and `remote-3`. Configure them in your own SSH config, for example:

```sshconfig
Host remote-1
    HostName host.example.com
    User user
    IdentityFile ~/.ssh/id_ed25519
```

Host indices 0, 1, and 2 refer to those aliases. No remote server is supplied. Optional tmux helpers are in `tools/`; notification adapters in `tools/agent-notifications/` integrate coding tools with activity indicators. Install only the integrations you use and review their configuration first.

The optional Token Ladder integration reads `~/.local/state/token-ladder/status.json` on the second configured remote host and requires a separately installed `token-ladder` command. Without it, no ladder data is available.

The optional encrypted-vault OIDC client has example defaults. Supply your own `clientId`, `authorizationEndpoint`, `tokenEndpoint`, `redirectUri`, and `scope` in `%APPDATA%\ZigShell\sync-auth.json` to enable it. Do not supply a client secret.

For notification audio, set `MULTIPROMPT_NOTIFY_SOUND` to your own MP3 file path and enable Notification Sounds in Ctrl+K. No sound file or user-specific path is bundled.
