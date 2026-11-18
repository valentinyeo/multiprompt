# Native tab actions

Source files: src/sidebar.zig, src/command_palette.zig, src/search*, src/shortcuts.zig, src/app_state.zig, src/main.zig, build.zig, build.zig.zon, .claude/skills/verify-multiprompt/control-feature-tab-actions.ps1

Covers: palette:SEARCH_TABCTX_RENAME, palette:SEARCH_TABCTX_COPY_ID, palette:SEARCH_TABCTX_UNREAD, palette:SEARCH_TABCTX_PIN_TOP, palette:SEARCH_TABCTX_FAVORITE, palette:SEARCH_FAVORITE_OFFSET, palette:SEARCH_INBOX_EXCLUDE_OFFSET
Covers: palette:SEARCH_TABCTX_BOT_FACE, palette:SEARCH_TABCTX_BOT_COLOR, palette:SEARCH_BOT_FACE_OFFSET, palette:SEARCH_BOT_COLOR_OFFSET, palette:SEARCH_TABCTX_BACK
Covers: palette:SEARCH_GROUPMOVE_MENU_OFFSET, palette:SEARCH_GROUPMOVE_BACK_OFFSET, palette:SEARCH_GROUPMOVE_NEW_OFFSET, palette:SEARCH_GROUPMOVE_GROUP_OFFSET, palette:SEARCH_GROUPMOVE_NONE_OFFSET
Covers: palette:SEARCH_TABCTX_WSMOVE, palette:SEARCH_WORKSPACE_BACK_OFFSET, palette:SEARCH_WSMOVE_NEW_OFFSET, palette:SEARCH_WSMOVE_OFFSET
Covers: palette:SEARCH_TABCTX_ARCHIVE, palette:SEARCH_TABCTX_END_TMUX, palette:SEARCH_TABCTX_CLOSE_DISCONNECTED, palette:SEARCH_CLOSE_DISCONNECTED_OFFSET
Covers: shortcut:tabs/alt-s, shortcut:tabs/alt-u, shortcut:tabs/ctrl-k-copy-chat-id, shortcut:tabs/ctrl-k-delete-session, shortcut:tabs/ctrl-shift-w
Covers: shortcut:palette-actions/ctrl-k-right-click-tab-pin-to-top, shortcut:palette-actions/ctrl-k-right-click-tab-close-all-disconnected-sessions

## Sub-features

- Rename, copy identity, mark unread, pin and favorite a tab through context, global palette and keyboard routes.
- Change built-in face and color, restore Auto and cancel through Back without changing the other tab.
- Create a group, assign an existing group and remove membership. Move a tab into a new and an existing workspace.
- Close disposable local CMD tabs through Archive, Delete and Ctrl+Shift+W. Remove exited, pinned local sessions without closing a live control session.
- Restart the owned app and compare persistent identities, titles, appearance and membership.

## How to get to it (user POV)

Right-click the intended sidebar tab. The initial menu has seven actions. Type a query to reveal extended actions such as Favorite, Bot face, Bot color and Move to group. Ctrl+K applies global actions to the selected tab. F2 renames, Alt+S favorites, Alt+U marks unread and Ctrl+Shift+W deletes the current local session.

## Driving it with control.ps1

Use the automatic PR verifier's `tab-actions` GitHub Windows journey. It invokes `control.ps1 -Feature tab-actions`. Follow the existing automatic run at intervals of at least 300 seconds; do not dispatch a duplicate run.

1. Launch a fresh owned app with no saved-session fixtures. Create and name three local CMD tabs through actual input. Copy each ID through Ctrl+K so the app assigns its persistent local identity. Select each new tab through its native session action before F2; a saved active tab does not prove its console has keyboard focus. Require distinct saved IDs.
2. Keep the control CMD selected while targeting the inactive tab. Read the target's painted avatar rectangle from current app diagnostics, then ownership-check and right-click that point. Find each action by its current source-derived routing ID. Use Home and Down to scroll it into view, then ownership-check and click its freshly painted row. Require a fresh production palette-confirm receipt.
3. Rename through context, global palette and F2. Copy the active control ID globally, then copy the inactive target ID through context. Require the native clipboard to equal the corresponding saved `session:#` identity, not its title.
4. Mark unread through context, global palette and Alt+U. Require the matching published Inbox `att` field. Toggle pin through context and global palette. Toggle favorite through context, global palette and Alt+S. Toggle global Inbox exclusion twice.
5. Open Bot face and Bot color, choose Back, then select a nondefault built-in choice, Auto and another explicit choice. Require saved fields and unchanged control-tab appearance. Keep all screenshots for visual inspection.
6. Create a group, retain its app-generated name and place the peer in it. Remove the target's membership, then select the existing group again. The peer keeps the group alive. Exercise Back separately.
7. Create a destination workspace through Ctrl+N. After Copy ID, select its CMD peer through the native session action before giving it a manual name through F2, so automatic title updates cannot look like collateral edits. Use context Move to workspace and Back, then move the inactive target into a new workspace. Require the control identity and workspace to stay selected and the target's home group to clear. Visit the destination and move the target back to the existing home workspace.
8. Pin a disposable CMD, type `exit`, and require its actual process to exit while its row remains preserved. Read the fresh preservation receipt from `session-audit.log`, not `debug.log`, and retain it as `tab-actions-session-audit.log`. Run Close all disconnected sessions through context and global palette on separate victims. Require only the exited victim to disappear.
9. Close fresh victims through context Archive, context Delete, global Delete and Ctrl+Shift+W. Require the saved victim identity to disappear and its actual CMD process to exit. After each closure, type a new marker command into the surviving control CMD and require its exact output file.
10. Restart only the owned app using its existing saved profile. Compare saved layout keyed by persistent chat identity, including names, workspace/group membership, pin, favorite, face and color. Recopy the target ID and run another control-console marker.

The driver runs `tab-actions.test.cjs --evidence <evidence>` against retained app-written before/after session snapshots, Inbox state, native clipboard reads, process-exit observations, raw palette confirmations and owned screenshots. Require all forty ordered action steps, all twenty-five palette symbols and nine exact receiving console markers. Inspect screenshots, `doctor.json`, actions, final `result.json` and zero-process cleanup. A recipe count is not a hosted pass.

## Gotchas

These are real local CMD processes. No account, remote server, provider, SSH or tmux boundary is substituted. Local Archive and Delete close a local process; they do not prove remote agent termination or remote history retention. Appearance checks cover local saved choices, not synchronization to another device.

Session selection uses the persistent chat identity to find the current numeric row in the unfiltered palette. It skips section headers and requires the receiving confirmation; automatic tab-title changes cannot invalidate a typed name query because no name is typed. Injected mouse clicks do not authorize focus transfer. After the native selection, the driver uses the documented Alt+M shortcut to restore console input, then requires the exact selected console's foreground identity. Console readiness checks the saved runtime PID, owned root and native console class. Shell IDs and console-title counters allocate independently, so their numbers need not match after restart.

The saved home workspace omits the tab's `workspace` field; omission means workspace zero. Moving the active target home restores the home workspace's remembered session. Check its saved `last_shell` identity rather than expecting the moved target to remain selected. A palette refresh can reset the highlighted row between keys. The native click binds confirmation to the painted row instead of the highlight. A refresh can also invalidate a queued click. The driver clicks once more only after fresh receipts show the same query, row order and selected target with no accepted action. Both clicks require fresh row geometry from the latest same-query row list. Unrelated rows may change before the first click; the requested routing ID must still be present and freshly painted. The retry compares against the row list captured at the first click. A missing target or a changed query fails.

Retained labels without result insertion are not driven or counted. In particular, this journey does not claim legacy context mute, reconnect, keep-alive, group-new or group-remove IDs. Browser, permission, Stop, provider switching, remote launch and page actions remain separate journeys. The broad right-click-tab shortcut row is not claimed because its retained mute and reattach alternatives are absent from the current menu.
