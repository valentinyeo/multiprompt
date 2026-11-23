# Server shell release proof

Source files: src/clipboard.zig, src/native_session.zig, src/terminal_window.c, src/session.zig, src/shell_poll.zig, src/command_palette.zig, src/mp_shell.py, .claude/skills/verify-multiprompt/control-feature-server-shell-tabs.ps1, .claude/skills/verify-multiprompt/server-shell-release-setup.ps1, .claude/skills/verify-multiprompt/server-shell-release-cleanup.ps1, .claude/skills/verify-multiprompt/server-shell-release-fixture.py

## Sub-features

- SOFT-3001: exact clipboard text from a selected terminal character while the same remote command keeps running, followed by Ctrl+C without selection interrupting that command.
- SOFT-3002: normal quit and restart restores an attached server tab; Close tab followed by Ctrl+K Reopen server shell reattaches the identical tmux session, pane and shell process.
- SOFT-3003: from the real server chat, Ctrl+K Open shell on VPS 1 opens a shell on that server in the chat's non-default folder. A wrong folder fails rather than substituting a direct bridge call.

## How to get to it (user POV)

Select text in a running shell and press Ctrl+C, then press it again with no selection. Quit with a server shell tab open, restart, close that tab through Ctrl+K Close tab, then use Reopen server shell to choose the same session. Select the server chat, open Chat View with Alt+C, and use Ctrl+K Open shell on VPS 1.

## Driving it with control.ps1

```sh
gh workflow run verify.yml --ref <branch> -f feature=server-chat -f tag=v0.28.<n>
```

Use one dispatch. A tagged `server-chat` run first reuses the existing real-server chat journey in its own PowerShell process, then extends it with these shell checks in `shell-release/`. The existing server-chat setup owns the WSL2 server, OpenSSH keys, real tmux and deterministic paid-provider substitute. No workflow changes are required. Do not dispatch `server-shell-tabs` alone because it needs the `server-chat` WSL installation.

The fixture adds a real shell session and places the chat provider in `/home/mpverify/shell-proof-folder`. Before launch only, it seeds one saved server chat. Ctrl+K Reopen server shell opens the detached proof session as a fresh tab before the copy check. Every subsequent action uses real keyboard or mouse input. Remote reads retain stdout, stderr and exit codes. A Python command writes an atomic heartbeat and an interrupt receipt. The first terminal cell contains `S`; a drag within that cell selects it and the clipboard must equal exactly `S`. Remote PTY width can lag the actual native grid and must not define selection length.

Restart uses the same `Restart-SessionRestore` helper as the SOFT-3039 journey on `soft-3053-release-proof`. Remote tmux session ID, pane ID and shell PID must remain identical, and typed commands must produce new remote receipts after restart and reopen. The current Close tab alias resolves to Archive chat (`7110`), not the old close target `6232`. The proof requires the remote session to remain alive and detached after that real action; if it does not, the close/reopen case fails. Ctrl+Shift+W deletes the remote session and is not used.

Inspect `shell-release/SOFT-3001-result.json`, `SOFT-3002-result.json`, `SOFT-3003-result.json`, exact clipboard/expected text, heartbeat and interrupt receipts, restart/reopen identities, chat folder state, and the corresponding `SOFT-*.png` screenshots. Each case records failures independently. Runner keys are removed before scratch evidence is copied; WSL is stopped during cleanup.

## Gotchas

- SOFT-3003 itself ships `mp-shell open` for server agents. Source and the shortcut table have no chat-specific folder-preserving open-shell row. The nearest real palette row is Open shell on VPS 1 (`2003`); its actual folder is measured, not assumed. This journey does not claim it proves the separate agent command.
- Only the paid provider is deterministic. SSH, tmux, shell processes, signals, clipboard and server folders are real and runner-owned. No user machine, credentials or shared VPS is involved.
- Shell copy/scroll geometry comes from the existing server-shell-input journey. This release proof adds the exact-selection and running-process checks it did not assert.
