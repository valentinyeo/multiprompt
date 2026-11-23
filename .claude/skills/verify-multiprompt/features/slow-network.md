# Slow network

## Sub-features

- Ten real Ctrl+Tab session switches between two saved remote sessions while the app's SSH path carries a 2 s one-way TCP delay (about 4 s round trip).
- Eight real keystrokes into the native Chat View composer on the selected remote session under the same delay.
- Archive of the selected remote chat under the same delay, driven through the Ctrl+K palette.
- First open of a hosted chat after the app's chat transport helper for that host was killed: the helper's `{"ready":true}` reply has to cross the 2 s one-way delay in each direction, so the ready handshake costs about 4 s.
- Each action records the longest message-pump wait measured with `SendMessageTimeout(WM_NULL)` and the Windows `IsHungAppWindow` state.
- Pass requires the app window to answer every pump within 500 ms, report no not-responding state, complete every switch and show every typed character.

This journey answers SOFT-3066 and SOFT-3067: slow internet to the remote session hosts must never freeze the window. Run it against a pre-fix release with `-f tag=<release before the fix>` to compare.

## Why the two extra steps exist

The first version of this journey switched tabs and typed, and both v0.28.1849 (without the fixes) and v0.28.1878 (with them) passed with a worst pump of 8 and 9 ms. Switching and typing never reach the frozen code: the freeze needs a window-thread call that runs while the shared chat transport is starting or while a remote kill is in flight.

- SOFT-3066 (PR 1213): `chat_transport.open` ran the helper handshake inline, waiting for `{"ready":true}` while holding the host mutex, and `chatHistoryPersistent` could run on the GUI thread. The journey now kills the app's transport helper for the host, then opens the hosted chat for the first time. The helper's ready reply crosses a delayed TCP socket, so the old code holds the window for the round trip.
- SOFT-3067 (PR 1214): archiving a remote chat ran the remote `tmux kill-session` on the window thread. The journey archives the selected remote chat through the palette under the same delay.

Both steps measure the pump exactly like the switch and typing steps, so the pre-fix red run keeps its numbers.

Measured on 2026-11-23, one dispatch per release, same branch head 8c40796d1:

| Step | v0.28.1849 (before) | v0.28.1890 (after) |
| --- | --- | --- |
| Archive the selected remote chat (Ctrl+K) | 5001 ms, not responding | 1 ms |
| First open after the transport helper was killed | 1 ms | 1 ms |
| Ten Ctrl+Tab switches, worst | 6 ms | 5 ms |
| Eight composer keystrokes, worst | 7 ms | 8 ms |

The archive step reproduces SOFT-3067 and the after build clears it. The helper-down first open did not stall on v0.28.1849: the helper it kills is booted again off the window thread even in the pre-fix build, so the ready handshake never lands on the window thread from this action. Runs [45142127724](https://github.com/valentinyeo/multiprompt/actions/runs/45142127724) and [45142183920](https://github.com/valentinyeo/multiprompt/actions/runs/45142183920).

## How to get to it (user POV)

Two remote tmux tabs are open. Press Ctrl+Tab to switch and keep typing in the Chat View composer (Alt+C) while the link to the server answers in seconds. Then use Ctrl+K to archive a chat, and open a chat whose transport is still starting. The sidebar, tabs and composer must keep responding immediately.

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

`control-feature-slow-network.ps1` then opens Chat View with Alt+C, drives ten Ctrl+Tab switches, eight typed characters, the palette archive and the helper-down first open, and stores `slow-network-timings.json` with each action's worst pump wait, sample count and hung state. `slow-network-timings.json` also records how many transport helpers were killed and the ready round trip that applies. `before.png`, `slow-network-chat-view.png`, `slow-network-switch.png`, `slow-network-typing.png`, `slow-network-archive.png`, `slow-network-first-open.png` and `after.png` show the real desktop while the delay is active.

## Gotchas

- The delay is real TCP latency at the app's SSH boundary, not a physical internet path. A real VPS, credentials, tmux server and Claude are not used; the host side is the same synthetic boundary as the other remote journeys.
- The proxy adds delay only. It does not cap bandwidth, so the journey proves a 2 s latency budget, not a 50 kbit/s one.
- A launch, missing second session or build failure is not a slow-network red. Require a completed setup before reading a stall as the bug.
- The helper-down step kills the app's own `ssh.exe` children whose command line carries `python3 -u -c`, and nothing else. The app boots them again on the next fetch, which is why the step can wait for Chat View to repaint.
- The stand-in SSH boundary answers `96` to an unknown remote command, so the archive step may keep its tab on a pre-fix build. The step records `archiveClosed` and judges the stall, not the tab count.
- `slow-network-timings.json` and `result.json` are written before the pass/fail throw, so the pre-fix red run still keeps its measurements.
