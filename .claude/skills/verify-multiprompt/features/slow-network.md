# Slow network

## Sub-features

- Ten real Ctrl+1/Ctrl+2 session switches between two saved remote sessions while the app's SSH path carries a 2 s one-way TCP delay (about 4 s round trip).
- Eight real keystrokes into the native Chat View composer on the selected remote session under the same delay.
- Each action records the longest message-pump wait measured with `SendMessageTimeout(WM_NULL)` and the Windows `IsHungAppWindow` state.
- Pass requires the app window to answer every pump within 500 ms, report no not-responding state, complete every switch and show every typed character.

This journey answers SOFT-3066 and SOFT-3067: slow internet to the remote session hosts must never freeze the window. The older pre-fix release is the red control: run the same journey with `-f tag=<release before the fix>` and expect a stall over 500 ms.

## How to get to it (user POV)

Two remote tmux tabs are open. Press Ctrl+1 and Ctrl+2 and keep typing in the Chat View composer (Alt+C) while the link to the server answers in seconds. The sidebar, tabs and composer must keep responding immediately.

## Driving it with control.ps1

Dispatch on GitHub Windows only, against a published release or the branch build:

```sh
gh workflow run verify.yml --ref <branch> -f feature=slow-network -f tag=v0.28.1878
gh workflow run verify.yml --ref <branch> -f feature=slow-network
gh run list --workflow verify.yml --event workflow_dispatch --limit 5 --json databaseId,headSha,displayTag,url
gh run watch <id> --interval 60
gh run download <id> -n verify-slow-network -D /tmp/verify-slow-network-<id>
```

The harness seeds two saved stand-in tmux tabs, starts `.claude/skills/verify-multiprompt/slow-network.py` as a local TCP proxy, and points the app's `ssh-path.txt` at the existing launcher, which now runs that proxy client instead of the boundary directly. Every chunk in both directions is held 2000 ms before reaching `tools/verify-chat-delivery/boundary.py`, so the app talks over a genuinely delayed TCP socket while the remote host stays the repository's SSH/tmux stand-in. The seed writes only the saved-tab file and the boundary's own fixture state; no app state setter, no synthetic transcript injection into the app.

`control-feature-slow-network.ps1` then opens Chat View with Alt+C, drives ten Ctrl+1/Ctrl+2 switches and eight typed characters, and stores `slow-network-timings.json` with each action's worst pump wait, sample count and hung state. `before.png`, `slow-network-chat-view.png`, `slow-network-switch.png`, `slow-network-typing.png` and `after.png` show the real desktop while the delay is active.

## Gotchas

- The delay is real TCP latency at the app's SSH boundary, not a physical internet path. A real VPS, credentials, tmux server and Claude are not used; the host side is the same synthetic boundary as the other remote journeys.
- The proxy adds delay only. It does not cap bandwidth, so the journey proves a 2 s latency budget, not a 50 kbit/s one.
- A launch, missing second session or build failure is not a slow-network red. Require a completed setup before reading a stall as the bug.
- `slow-network-timings.json` and `result.json` are written before the pass/fail throw, so the pre-fix red run still keeps its measurements.
