# Relaunch and update

Restore saved work after reopening and install a verified update without losing sessions.

Journeys: session-restore, safe-updates
Release paths: src/startup.zig, src/update*, src/release_signing_public_key.txt, src/main.zig, build.zig

## Sub-features
- `restore` reopens saved sessions, workspace selection, and views.
- `reattach` reconnects the active remote tab.
- `update` stages and verifies an update, restarts, or rolls back on failure.

## How to get to it (user POV)
- Reopen the app or Ctrl+K Restart Multi Bot; Ctrl+Shift+R reattaches a remote tab; Ctrl+K Restart to update applies a ready update; the visible update prompt is another entry point.

## Driving it with drive.ps1
Preconditions: fresh hosted Windows desktop, matching executable/hash/version, isolated app data, and the selected legacy recipe’s prerequisites.
- Migration pending for this feature. Run `gh workflow run verify.yml --ref <branch> -f feature=session-restore`. [Session restore](session-restore.md) relaunches the owned isolated app; [safe updates](safe-updates.md) uses signed local fixtures on GitHub Windows.
- Require saved unique session names, workspace, and view after relaunch, screenshots before/after, executable provenance, selected-recipe checks, and zero remaining owned processes. Only the selected journey is covered. Download `verify-session-restore` after cleanup. This legacy workflow route does not yet use the video driver; see [inventory](../inventory.md).

## Gotchas
- Never restart the user’s app. The signed-fixture update journey is not proof of the public release feed, and remote transport stand-ins are not live SSH.
