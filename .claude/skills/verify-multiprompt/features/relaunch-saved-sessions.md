# Relaunch saved sessions

The release gate for one failure class: a bug that only shows when the app starts again on real saved sessions (IGSH-890 listed every starred session twice and kept adding more; every check had only started the app once on an empty profile).

## Sub-features

- `seeded-state`: the first launch starts on a saved Starred workspace with three groups (Hypertask, Software Factory, inne), two workspaces, 14 live sessions and 6 cached copies of live sessions that have no tmux identity.
- `launch-1`, `launch-2`, `launch-3`: after each launch every live session is published exactly once, nothing unsaved is published, the saved file holds exactly the 14 live sessions with no copies, all three group headers are saved, and exactly one session is selected.
- `view-round-trip`: before each quit the journey opens the home view (Alt+2) and Starred (Alt+1) and repeats the same counts.
- `selection-kept`: the session selected when the app quits is the one selected after relaunch, still in Starred.
- `occupied-ports`: launches 2 and 3 run with every notification port held by a fixture socket, as on a laptop where earlier console children still own them.

## How to get to it (user POV)

- Alt+S favorites a session, Ctrl+K → `Move to Group` groups it, Alt+1 opens Starred, Alt+2 returns home.
- Close Multiprompt and open it again, three times in a row.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml -f feature=relaunch-saved-sessions` (or `--ref <branch>`). It also runs in the full matrix on every master push, and `tools/auto-release-admit.sh` tags a commit only when `verify (relaunch-saved-sessions)` of that exact commit's push run succeeded.

1. The driver writes `seed-session.json` into the private `roaming/ZigShell/session.json` before the first launch. This is the only journey that seeds the saved file (Valentin, 2026-10-26, IGSH-900: "ok run it", approving a release gate that seeds a realistic saved state). Sessions are CMD tabs named `Relaunch 01` to `Relaunch 14` plus six `tmux` records named like live sessions with no `tmux_session`, the shape IGSH-890 left behind.
2. Launch with `--single-window` and the restore path on. Wait for all 14 names in the published Inbox, then require no name twice, no unsaved name, and the saved file at exactly 14 tabs with all three group names.
3. Repeat the counts in the home view and in Starred, then close the owned window normally (WM_CLOSE) and clean its job.
4. Occupy every port of `src/notify_ports.zig` with owned loopback sockets, relaunch the same executable and private data directory, and repeat steps 2 and 3. Relaunch once more.
5. `result.json` names feature `relaunch-saved-sessions` with `launches: 3`; evidence is `seed-session.json`, `launch-N.inbox.json`, `launch-N.session.json`, `relaunch-launches.json` and screenshots per launch.

## Gotchas

- Red control: `origin/master` before the IGSH-890 fix publishes the cached copies, so step 2 fails with `sessions listed twice in the sidebar` or the relaunch never finishes restoring. The red and green run links are on the IGSH-900 ticket.
- The journey adds no app startup limit, timeout or blocking state; its waits live in the GitHub script only.
- Remote tmux reconnection, account sync and browser panes stay outside it. A missing, cancelled or red result for this job blocks the release; other journeys keep their own auto-revert path.
- Cancelled runs count as missing: a newer master push cancels the older commit's Verify run, so only commits whose run finished can be tagged.
