# Saved terminal binding

## Sub-features

- A bare SSH tab adopts a confirmed named terminal session.
- Missing status text never erases the confirmed identity.
- Five normal close/reopen cycles attach to that same name and host.
- No reopen emits a bare login or creates another remote session.
- Reusing the same name with another server generation is refused before attachment.

## How to get to it (user POV)

Open an SSH tab, attach an existing terminal session, then close and reopen Multiprompt.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=tmux-binding` on the exact candidate revision.
The fixture seeds one bare SSH tab with no terminal binding before launch. Its isolated SSH boundary displays an existing session named `workspace` with a stock status row. The driver resolves the existing named terminal through the public `pane-info` request, which adopts without respawning. Alt+S persists it through the real favorite action. No app setter or saved terminal binding is injected.
The boundary then removes only the status row. Observe four real name-poll events while requiring the saved identity to remain intact. No app setting or timer is injected.
Normally close and reopen the owned app five times, reusing only its private profile. Each cycle must retain the exact name and host, emit exactly one additional attach command and no additional bare login, and keep the boundary's one-session registry unchanged. Save screenshots and session JSON for every cycle.
The real SSH probe must learn and persist the server-start/PID/session-ID tuple. Every reopened SSH command must check that saved generation atomically and attach by immutable session ID. After five successful reopens, replace only the boundary generation under the same name while the owned app is closed. Reopen again: require an explicit refusal receipt, no sixth attach, and the original saved identity unchanged.
`binding-proof.json` records all five cycles, before/after counts and the name-reuse refusal. `binding-commands.jsonl` retains exact attach receipts. The normal Doctor, foreground, hash, process-tree and cleanup rules remain required.

## Gotchas

- SSH is an explicitly simulated remote boundary, not a live server or real Claude. Detection, persistence, command generation, restart and native rendering are the production Windows app.
- A missing screen status bar, failed console capture or temporary plain prompt cannot prove that a remote session died.
- Run this identical journey before the fix: the saved identity disappears after three missing-status polls. Do not retry or mask that assertion.
