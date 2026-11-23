# Server shell release proof

Source files: src/clipboard.zig, src/native_session.zig, src/terminal_window.c, src/session.zig, src/shell_poll.zig, src/command_palette.zig, src/mp_shell.py, .claude/skills/verify-multiprompt/control-feature-server-shell-tabs.ps1, .claude/skills/verify-multiprompt/server-shell-release-setup.ps1, .claude/skills/verify-multiprompt/server-shell-release-cleanup.ps1, .claude/skills/verify-multiprompt/server-shell-release-fixture.py

## Sub-features

- SOFT-3001: exact clipboard text from a selected terminal character while the same remote command keeps running, followed by Ctrl+C without selection interrupting that command.
- SOFT-3002: normal quit and restart restores an attached server tab; closing a server shell tab and then Ctrl+K Reopen server shell reattaches the identical tmux session, pane and shell process.

## How to get to it (user POV)

Open a server shell with Ctrl+K Open shell on VPS 1, attach a tmux session inside it, then select text in a running command and press Ctrl+C, then press it again with no selection. Lose that connection, close the server shell tab with Ctrl+K, choose the detached session through Ctrl+K Reopen server shell, then quit with the tab open and restart.

## Driving it with control.ps1

```sh
gh workflow run verify.yml --ref <branch> -f feature=server-chat -f tag=v0.28.<n>
```

Use one dispatch. A tagged `server-chat` run first reuses the existing real-server chat journey in its own PowerShell process, then extends it with these shell checks in `shell-release/`. The existing server-chat setup owns the WSL2 server, OpenSSH keys, real tmux and deterministic paid-provider substitute. No workflow changes are required. Do not dispatch `server-shell-tabs` alone because it needs the `server-chat` WSL installation.

The fixture adds a real detached tmux session and places the chat provider in `/home/mpverify/shell-proof-folder`. Before launch only, it seeds one saved server chat. The proof opens a plain server shell on the same host with Ctrl+K Open shell on VPS 1 (`2003`) and attaches that session by typing `tmux attach -t proof-shell` inside it. Every later action uses real keyboard or mouse input. Remote reads retain stdout, stderr and exit codes. A Python command writes an atomic heartbeat and an interrupt receipt. The first terminal cell contains `S`; a drag within that cell selects it and the clipboard must equal exactly `S`. Remote PTY width can lag the actual native grid and must not define selection length.

The tab is a plain server shell because the only row Ctrl+K offers for `close tab` is Archive chat (`7110`), and on a tab that tracks a tmux session that row kills the remote session. Before the close the proof drops the tab's own ssh transport, a real connection loss: the tmux client dies, the session stays alive and detached, and the app reconnects the tab as a plain shell. The proof records `#{session_attached}` going 1 to 0 to 1 and requires the same `#{session_id}|#{pane_id}|#{pane_pid}` before the close, after the reopen and after the restart, with a new remote receipt written after each reattach. A plain close without that loss leaves the remote client attached (run 45168790030 read `session_attached=1` for 30 s after the tab closed), so Reopen server shell has nothing to attach; that leak is a product defect outside this harness. Ctrl+Shift+W deletes the remote session and is not used.

Restart uses the same `Restart-SessionRestore` helper as the SOFT-3039 journey on `soft-3053-release-proof`. Inspect `shell-release/SOFT-3001-result.json`, `SOFT-3002-result.json`, exact clipboard/expected text, heartbeat and interrupt receipts, close/reopen and restart identities, and the corresponding `SOFT-*.png` screenshots. Each case records failures independently. Runner keys are removed before scratch evidence is copied; WSL is stopped during cleanup.

## Gotchas

- SOFT-3003 is not part of this journey. On v0.28.1893 Ctrl+K Open shell on VPS 1 (`2003`) from the real server chat opened `/home/mpverify` instead of the chat folder `/home/mpverify/shell-proof-folder`. That is a product defect and is tracked outside this proof.
- Only the paid provider is deterministic. SSH, tmux, shell processes, signals, clipboard and server folders are real and runner-owned. No user machine, credentials or shared VPS is involved.
- Shell copy/scroll geometry comes from the existing server-shell-input journey. This release proof adds the exact-selection and running-process checks it did not assert.
