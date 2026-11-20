# All sessions states and servers

## Sub-features

- Summary of running sessions, servers with running sessions and archived sessions.
- Server chips with independent running counts and memory totals, including a server with no attached window.
- All, Running, No window and Archived tabs with filtered counts.
- Row state, workspace, server and memory.
- S toggles the selected row's server; the palette command filters to the active chat's server.
- Existing navigation, search, open, mark, clear, close confirmation, cancel and archive actions.

## How to get to it (user POV)

Use Ctrl+K, Show all sessions. Click a server chip or a state tab. Press S for the selected row's server. Ctrl+K, All sessions filter server is the other server-filter entry. Ctrl+F searches; J/K move; H/L change tabs; W, A and U select Waiting, Archived and No window. Space marks, X asks to close unattached sessions, Enter opens or confirms, and Q/Esc dismisses.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=all-sessions`, or let `pr-verifier.yml` select this map for changes to the All sessions overlay. The shared control driver runs `control-feature-all-sessions.ps1` with Doctor, genuine keyboard/mouse input, screenshots and owned-job cleanup.

Seed three saved remote tabs once, across two servers and two workspaces, plus one archived identity on a third server. The SSH boundary returns five live sessions and distinct memory values. It maintains end-request receipts outside app state. This is synthetic SSH, not real servers or providers. The driver never writes the app's computed counts, filters or archive after launch.

Require these Done-when checks in head `result.json`:

1. `summary`: `before.png` and `before.txt` show 3 running on 2 servers and 1 archived.
2. `server-chips`: host 0 has 2 running and 224 MB, host 1 has 0 running and 512 MB, and host 2 has 1 running and 256 MB. Click host 2 and click again; require 1 then 6 visible rows.
3. `state-tabs`: All has 6 rows, Running 3, No window 2 and Archived 1. Click tabs and use A; inspect the paired screenshots and painter receipts.
4. `row-fields`: `all-tab.png` and `all-tab.txt` show Running, No window and Archived, both workspace labels, each server and each distinct memory value. Archived memory is empty, not a live allocation.
5. `server-key`: S reduces the selected host 0 list to 3 rows and a second S restores all 6.
6. `server-palette`: close with Q, then use Ctrl+K, All sessions filter server. Require the active Second chat's host 2 and its one row.
7. `existing-actions`: drive J/K, H/L, W, U, Space, Clear marks, X/Esc, Ctrl+F, Enter, and hover Archive. Require canceled close to leave the synthetic session alive; require the app-written archive to retain spare's host and session, with an independent SSH end receipt. Mark the remaining unattached session, click Close marked, confirm, and require its independent end receipt. The final screenshot has 3 running and 2 archived; Esc dismisses.

Painter receipts describe the actual frame and clickable rectangles, not injected app state. Read them with screenshots, `actions.json`, `doctor.json`, the saved archive and SSH invocation/end files under `data/`. A receipt alone is not a visual verdict. The identical head harness may run on the base executable; a base without these state tabs or receipts must fail rather than silently skip.

## Gotchas

The older sessions map tests repository picking and local CMD creation. Session-actions tests sidebar menus and deletion. Command-palette tests size and unrelated commands. None of those maps proves this overlay. Select this map for All sessions state/count changes.

The failed PR 1038 run 43720263296 had every journey canceled before a runner started. GitHub annotations say the run was canceled by the repository owner. Missing head/base evidence in that run was not a selector or artifact-name mismatch. Do not cancel the replacement run before it uploads `verify-all-sessions`.

This journey does not verify account sync, Android, real remote agents or archived provider resume. Independent screenshot review is still required for design A.
