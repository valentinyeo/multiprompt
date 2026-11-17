# Relaunch and update

Restore saved work after reopening and install a verified update without losing sessions.

Journeys: session-restore, safe-updates

## Sub-features
- `restore` reopens saved sessions, workspace selection, and views.
- `reattach` reconnects the active remote tab.
- `update` stages and verifies an update, restarts, or rolls back on failure.

## How to get to it (user POV)
- Reopen the app or Ctrl+K Restart Multi Bot; Ctrl+Shift+R reattaches a remote tab; Ctrl+K Restart to update applies a ready update; the visible update prompt is another entry point.

## Driving it with drive.ps1
Preconditions: fresh hosted Windows desktop, matching executable/hash/version, isolated app data, and the selected legacy recipe’s prerequisites.
- The shared wrapper accepts these Journeys; automatic workflow migration remains partial. Run `gh workflow run verify.yml --ref <branch> -f feature=session-restore`. [Session restore](session-restore.md) relaunches the owned isolated app; [safe updates](safe-updates.md) uses signed local fixtures on GitHub Windows.
- Require saved unique session names, workspace, and view after relaunch, screenshots before/after, executable provenance, selected-recipe checks, and zero remaining owned processes. Only the selected journey is covered. Download `verify-session-restore` after cleanup. This legacy workflow route does not yet use the video driver; see [inventory](../inventory.md).

The recipes distinguish existing focused journeys from unreachable complete paths. UNREACHABLE names the missing data, endpoint, build mode or driver action; it never means the product passed.

### restore: Restore, instances and reconnect

Launch an owned --name instance, create and select two tabs, close normally and reopen its profile. Repeat after killing only its owned job. Reconnect a Part B remote tab, then reopen while transport is down. Keep a second differently named instance separate.

Observable proof: Each instance uses its own session-{name}.json and title. Tab IDs, names, order, workspace and selection survive; reconnect changes neither foreground typing nor layout. An ended remote session stops retrying and offers the documented recovery path.

Journey: session-restore, relaunch-saved-sessions, ssh-tab-reconnect, ended-remote-session, saved-remote-workspace. UNREACHABLE for real reconnect and named-instance isolation until Part B and a two-owned-instance driver are available; reconnect stand-ins prove only app state handling.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_RECONNECT_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_SHARED_SERVER_CONNECTION_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_SINGLEWIN_OFFSET` | Ctrl+K, search for **single-window mode**. Follow `restore` above. |
| `SEARCH_TABCTX_RECONNECT` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |

### update: Quit, update and diagnostics

Use disposable profiles only. Open Changelog and Crash Reports; request Restart Multi Bot. With a signed staged fixture update, use Restart to update, then test rollback after a failed candidate. Quit keeps server agents alive. Trigger Debug crash now only on the isolated app whose evidence is already copied.

Observable proof: Saved tabs survive; the relaunched executable hash/version matches the signed candidate or rollback target. Quit/restart never ends a Part B agent. Crash evidence remains after owned cleanup. A downloaded file or success log alone is not update proof.

Journey: safe-updates, whats-new, session-restore. UNREACHABLE for public-feed authenticity and crash/report-folder buttons until the signed public feed and native folder/crash assertions are supplied. The local signed release fixture is explicitly narrower.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_CHANGELOG_OFFSET` | Ctrl+K, search for **changelog**. Follow `update` above. |
| `SEARCH_CRASH_NOW_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_CRASH_REPORTS_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_QUIT_OFFSET` | Ctrl+K, search for **quit multi bot**. Follow `update` above. |
| `SEARCH_RESTART_OFFSET` | Ctrl+K, search for **restart multi bot**. Follow `update` above. |
| `SEARCH_UPDATE_OFFSET` | Ctrl+K, type **restart to update**, then select the matching action with Up/Down and Enter. Follow `update` above. |

## Gotchas
- Never restart the user’s app. The signed-fixture update journey is not proof of the public release feed, and remote transport stand-ins are not live SSH.
