# Favorites groups

Verify on: push

Group the same session independently in its home workspace and Favorites (Alt+1), using the existing group palette.

## Sub-features

- Home grouping retains the session's home workspace.
- Favorites grouping creates a separate membership without replacing the home group.
- Returning home preserves both saved memberships.
- A muted starred session stays in Favorites, in its Favorites group (IGSH-719).
- Cached sidebar previews never become duplicate sessions when notification ports are occupied (IGSH-890).

## How to get to it (user POV)

- Alt+S stars the active session; Alt+1 opens Favorites and Alt+2 returns to the first stored workspace.
- Ctrl+K, search `move to group`, Enter, search `new group`, Enter creates a group in the current workspace. Existing group menus, headers, rename, collapse, color and drag remain the same; no new commands or shortcuts are needed.

## Driving it with control.ps1

Preconditions: baseline Doctor passes on a fresh single-window instance with its initial unstarred CMD session in the first stored workspace. All input is real keyboard input; saved files are read-only evidence.

- Dispatch `gh workflow run verify.yml -f feature=favorites-groups`; Windows selects `control.ps1 -Feature favorites-groups`.
- Press Alt+S and wait for the original tab's `favorite: true` in app-written `session.json`.
- Ctrl+K `move to group`, Enter, `new group`, Enter. Identify a newly saved group H and wait for the original tab's `group_id` to equal H. Escape closes any inline rename without typing a custom name.
- Press Alt+1 and repeat the same palette sequence. Require one new group F, distinct from H, with the tab's `starred_group_id` equal to F and `group_id` still H. Missing fields or unchanged membership fail the bounded wait; old releases cannot pass or skip this check.
- Capture `starred-grouped.png` and `session-starred-grouped.json`, then press Alt+2. Require the initial tab and home workspace active, `favorite: true`, `group_id: H` and `starred_group_id: F` unchanged.
- Ctrl+K `new cmd`, Enter, so the Inbox keeps one unmuted session for Doctor. Alt+1 selects the starred tab; Ctrl+K `mute tab`, Enter; require `muted: true` saved. Press Alt+2, then Alt+1; require `starred_view: true` with the starred tab selected, `starred_group_id: F` and `muted: true`. Capture `starred-muted.png` and `session-starred-muted.json`. A release that hides muted sessions from Favorites leaves nothing selected and fails this wait.
- Inspect `before.png`, `action.png`, `starred-grouped.png`, `starred-muted.png`, `after.png`, `actions.json`, both saved-state snapshots and `result.json`. The result records both exact persisted field names and IDs.

- IGSH-890 continues after the muted-starred check: normally close the owned app, stop its owned descendants, and occupy every production notification port with fixture TCP listeners. Restart the same executable/profile, require both the `no free notify port` diagnostic and completed `launch step=browser`, then switch Home/Favorites four times with a fresh Inbox refresh each time. The saved tab count must stay unchanged, every CMD tab must have a real PID, and the selected favorite must keep its Favorites group. Restart again while the fixture still owns the ports; retain `favorites-no-duplicates.png`, four refresh snapshots and `favorites-no-duplicates.json`. Fixture sockets close in `finally`. This is isolated GitHub Windows only, not a user's desktop.

- IGSH-1185 pins through the existing palette in Starred, requires `starred_pinned_top` without the home `pinned_top`, captures `starred-pins-before.png` and `starred-pins-after.png`, checks the same state after both restarts in `starred-pins-restarted.png`, then unpins into the unchanged group and captures `starred-pins-unpinned.png`.

## Gotchas

- Groups use their real default saved names. This journey does not type into an inline rename editor or seed JSON.
- Group memberships are local to this device; account layout sync is unchanged and does not sync groups across devices.
- This journey covers local CMD membership independence, not remote windows, all group context actions or relaunch persistence.
- Static contract checks are not proof of a passed Windows journey; GitHub must run the real desktop verification.
