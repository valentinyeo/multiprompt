# Session restore

Reopen the workspace and local CMD session that was selected, after a normal close or a killed process.

## Sub-features

- `normal-close-selection`: the middle of three named CMD sessions returns selected after WM_CLOSE and relaunch.
- `process-kill-selection`: a different selected session returns after Stop-Process and relaunch.
- `workspace-selection`: both relaunches return to the same non-initial workspace, identified by its saved workspace ID.

## How to get to it (user POV)

- Ctrl+N creates a workspace with its initial CMD session.
- Ctrl+K, type `new cmd`, Enter creates another local CMD session; F2 renames the active session.
- Ctrl+K, type the unique session name, Enter selects that exact session. Ctrl+1 through Ctrl+9 instead use visible row order, which automatic sorting can change.
- Close the app window normally, or end its process, then open Multiprompt again.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml -f feature=session-restore` for the exact revision under review. This map describes the journey, not a Windows journey result.

1. Launch the real executable in the baseline isolated profile with `--single-window`, without `--no-window-restore`. Keep this private data directory for all three launches in the job. Never seed or modify app settings, session files or launch snapshots.
2. Wait for startup restoration, then Ctrl+N creates a distinct workspace and its first CMD session. Use the existing palette keyboard path twice to add two CMD sessions. Rename the three sessions `Restore first`, `Restore middle`, and `Restore last` using F2, Ctrl+A, typed text and Enter. Require each unique CMD name in the app's saved session.
3. Ctrl+K, type `Restore middle`, Enter selects the middle-created session by its unique name. Read the app-published `inbox-default.json`: resolve `active_shell_id` against `shells[].sid` and require the selected name and workspace. Independently require the saved selection and workspace ID to agree. Capture `action.png`.
4. Doctor verifies the owned PID and HWND. Send WM_CLOSE through that process's CloseMainWindow, require normal exit, stop only the old owned job's remaining children, then relaunch the same executable and private data directory. Require newly owned published state after the restore phase, the middle session selected and the same workspace ID. Retain normal-close before/after Inbox and session JSON and `normal-close-after.png`.
5. Ctrl+K, type `Restore first`, Enter selects a different named session; wait for the app's published and persisted selection to agree. Stop only the Doctor-verified app PID using Stop-Process, require exit, clean its owned job's descendants and relaunch with the unchanged private data directory. Require the first session selected, all three named sessions still published and the same workspace ID. Retain process-kill before/after state and `after.png`.
6. `result.json` must name feature `session-restore` and contain both `normal-close-selection` and `process-kill-selection` before status can be `passed`. Standard Doctor, action trace, screenshots, per-launch stdout/stderr, exit/job accounting and final cleanup evidence remain required.

## Gotchas

- Session shell IDs can be reassigned during restoration. Resolve the published active ID to the unique user-created name; do not assume the previous process's ID survives a relaunch.
- Startup's painted launch snapshot is not proof of completed restoration. The driver requires the new HWND in published state and the new launch's restore/browser phase before checking selection.
- Only this job's private directory is reused. No shared desktop, credentials, synthetic sessions or test-only setters are used.
- Waits are inside the GitHub verification script only. This journey adds no app startup limits, timeouts or blocking behavior.
- This local CMD journey does not verify remote transport reconnection, account synchronization, browser panes or multiple top-level windows.
