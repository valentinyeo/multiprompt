# Restarted chat tab kind

Source files: src/mp_sessions.py, src/mp_send.py, src/mp_helper.py, src/mp_fresh.py, src/mp_zsb.sh, src/mp_shell.py, tools/mp-sessions, tools/verify-session-restart/*, tools/verify-server-chat/*, tools/vps-multiprompt-browser.sh, .claude/skills/verify-multiprompt/control.ps1

Verify on: push, pull_request

## Sub-features

- `hosted-chat-reply`: a hosted chat lives in a named workspace and group; the composer sends one message and the Chat View shows the real server reply.
- `mp-sessions-close-restart`: `mp-sessions close` then `mp-sessions restart` on the runner stub bring the same chat back with Chat View on (`cv=true`), not a plain server shell tab, in the same workspace and group.
- `app-restart-reply`: closing and relaunching the desktop app keeps that chat tab kind and placement; a second message still receives a visible reply.

## How to get to it (user POV)

On a server where session commands are installed, create or reuse a chat in a workspace and group, talk to it in Chat View, run `mp-sessions close` on its name, then `mp-sessions restart`, then quit and reopen Multiprompt and send again.

## Driving it with control.ps1

Preconditions: GitHub `windows-latest`, WSL2 Ubuntu with OpenSSH, tmux and Python, Windows OpenSSH, the branch or a tagged release executable, and the runner-owned server stub from `server-chat`. Shared server connection stays enabled so Linux `mp-sessions` reaches the desktop through the production zsb relay.

`control.ps1 -Feature session-restart` delegates to `tools/verify-session-restart/drive.ps1`. It starts the same Linux host as `server-chat`, uses the app-published `~/.multiprompt-runtime/mp-sessions` for the `mpverify` user, launches the app with shared server connection, creates a named workspace and group through the real palette, runs `mp-sessions start`, sends and copies one reply through Chat View, captures `before-restart.png`, runs `mp-sessions close` and `mp-sessions restart`, asserts the saved tab is still a chat tab in that workspace and group, captures `after-mp-sessions-restart.png`, relaunches the owned app window and asserts again plus `after-app-restart.png`, then sends a second message with `after-restart.png`.

Require `result.json` status `passed`, all three named cases passed, `before-restart.png`, `after-mp-sessions-restart.png`, `after-app-restart.png`, and `after-restart.png` with copied transcript text for both sends. PR selection maps edits to `src/mp_sessions.py`, `src/mp_send.py`, `src/mp_helper.py`, `src/mp_fresh.py`, and `tools/mp-sessions` here.

## Gotchas

This journey proves tab kind and placement after session commands and an app restart, not paid-provider context, account sync or Android. It uses the deterministic server-chat provider, not a live Claude process. A passing run on an older release is evidence only; report pass or fail honestly when dispatching `-f tag=v<version>`. If `mp-sessions restart` opens a shell tab (`cv=false`), the journey fails at the saved-session assertion by design.