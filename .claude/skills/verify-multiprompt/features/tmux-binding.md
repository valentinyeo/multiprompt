# Saved terminal binding

## Sub-features

- A bare SSH tab adopts a confirmed named terminal session.
- Missing status text never erases the confirmed identity.
- Five normal close/reopen cycles attach to that same name and host.
- No reopen emits a bare login or creates another remote session.

## How to get to it

Open an SSH tab, attach an existing terminal session, then close and reopen Multiprompt.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=tmux-binding` on the exact candidate revision.
The fixture seeds one bare SSH tab before launch. Its isolated SSH boundary displays an existing session named `verify-binding` with a stock status row. The real app must detect and save its name and second-host identity.
The boundary then removes only the status row. Observe four real name-poll events while requiring the saved identity to remain intact. No app setting or timer is injected.
Normally close and reopen the owned app five times, reusing only its private profile. Each cycle must retain the exact name and host, emit exactly one additional attach command and no additional bare login, and keep the boundary's one-session registry unchanged. Save screenshots and session JSON for every cycle.
`binding-proof.json` records all five cycles and before/after counts. `binding-commands.jsonl` retains exact attach receipts. The normal Doctor, foreground, hash, process-tree and cleanup rules remain required.

## Gotchas

- SSH is an explicitly simulated remote boundary, not a live server or real Claude. Detection, persistence, command generation, restart and native rendering are the production Windows app.
- A missing screen status bar, failed console capture or temporary plain prompt cannot prove that a remote session died.
- Run this identical journey before the fix: the saved identity disappears after three missing-status polls. Do not retry or mask that assertion.
