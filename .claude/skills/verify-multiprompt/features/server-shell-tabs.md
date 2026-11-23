# Server shell tabs

Source files: src/session.zig, src/json_reader.zig, src/shell_poll.zig, src/main.zig, src/command_palette.zig, src/browser_bridge.zig, src/mp_shell.py, tools/verify-chat-delivery/boundary.py, .claude/skills/verify-multiprompt/control-feature-server-shell-tabs.ps1, .claude/skills/verify-multiprompt/control.ps1

## Sub-features

- SOFT-3002: a saved tmux row with no session name stays a server tab through launch and a normal quit and relaunch, and Ctrl+K Reopen server shell attaches a detached session on that tab's server.
- SOFT-3003: the desktop opens a plain VPS shell tab on the chat's server, placed below the chat tab, running the chat's folder first.

Ctrl+C copy and interrupt in a shell tab is [Server shell input](server-shell-input.md), not this journey.

## How to get to it (user POV)

Open a server tab that ran tmux without a known session name, quit Multiprompt and start it again; the tab is still there. Then close it and run Ctrl+K Reopen server shell to attach a detached session on that server. From a chat on the server, run `mp-shell open --folder <chat folder>`; a VPS shell tab opens below the chat tab on that server, in that folder.

## Driving it with control.ps1

```sh
gh workflow run verify.yml --ref <branch> -f feature=server-shell-tabs -f tag=v0.28.<n>
```

The journey seeds two tabs on one stand-in host once before launch: a `tmux` row with `tmux_host` and no `tmux_session`, which the fix keeps, and a plain VPS shell. It requires both tabs after launch, a live transport for the plain shell, a normal quit and relaunch of the verified executable in the same isolated profile, both tabs back, a fresh transport and a keystroke receipt in the restored shell, then deletes the plain shell with Ctrl+Shift+W and uses the real Ctrl+K Reopen server shell rows to attach the one detached session the boundary serves. It finishes with a real `shell-open` bridge call carrying the chat host, the anchor tab and the chat folder, and requires the new plain shell tab below its anchor on the same host with a live transport.

Require `result.json` status `passed`, `before.png`, `server-shell-after-restart.png`, `action.png`, `server-shell-chat-tab.png`, `after.png`, and a zero-process cleanup.

## Gotchas

- Only SSH and tmux are stand-ins. No credentials, real server or agent turn are used, so the chat's own `mp-shell` call is not executed from an agent; `tools/mp-shell-test.py` proves mp-shell turns the chat folder into the `--run` prefix this journey sends to the same bridge verb.
- The boundary serves one detached session, so the Reopen list has a single row.
- `used` must be non-zero on the seeded row: a tmux row without a session name and without a saved use time is still dropped by design.
