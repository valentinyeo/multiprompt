# Session tabs

Repair terminal tabs from an agent's real `zsb` TCP entry point: rename, rebind to another remote tmux session, move to another group or workspace, and close, all in the background.

## Sub-features

- `session-rename`: set a tab's manual title.
- `session-rebind`: point a tab at another tmux session and reconnect it, keeping title and group; a session another tab already uses returns `duplicate_session`.
- `session-move`: move a tab to a group, a workspace or out of its group by exact name.
- `session-close`: close one background tab.
- Refusals: the active tab is never moved or closed (`active_tab`), unknown ids return `unknown_tab`.

## How to get to it (user POV)

- An agent runs `zsb workspace-list` to read tab ids, then for example `zsb session-rename --tab 42 --name "Runner 7"`, `zsb session-rebind --tab 42 --tmux runner-9`, `zsb session-move --tab 42 --group "Ops"` or `zsb session-close --tab 42`.
- The user sees the sidebar change without the active tab, workspace or foreground window changing, and the layout is saved at once.

## Driving it with control.ps1

Preconditions are the same as [Session open](session-open.md): single-window offline mode, a live initial CMD tab, the app-owned loopback listener. SSH attachment is expected to fail.

- **Dispatch.** Run `gh workflow run verify.yml -f feature=session-tabs`.
- **Setup.** Create two groups through the palette, open `verify-1` to `verify-4` in the first group through `session-open`, and record the active tab, foreground HWND and window titles. Save `workspace-list` before.
- **Actions.** Rename `verify-1` to `Renamed One`; rebind `verify-2` to `verify-9` and require the saved tab keeps its title and group while `verify-2` disappears; require rebinding `verify-3` to the same session to be refused with `duplicate_session`; move `verify-3` to the second group; close `verify-4`. After each command require the active workspace, active tab, foreground window and titles unchanged.
- **Refusals.** Closing, moving or rebinding the active tab returns `active_tab`; an unknown tab id returns `unknown_tab`.
- **Restart.** Capture the saved layout (title, session, group name, workspace per tab), close and relaunch the app and require the identical layout.
- **Evidence.** `session-tabs-before.session.json`, `session-tabs-layout.session.json`, `session-tabs-layout.workspace-list.json`, `session-tabs-restarted.session.json`, the request and reply pair of every command, `before.png`, `action.png`, `after.png`, `restarted.png`, `result.json`.

## Gotchas

- A rebound tab cannot reach `connected` in CI because no server is supplied; the journey checks the saved layout and the reply state, not a live attachment.
- Group ids are compared by group name after the restart.
