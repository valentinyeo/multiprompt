# Workspace browser profiles

## Sub-features

- Six stable workspace IDs launch six distinct isolated Edge roots.
- Every root has a completion marker and Local State before the pane becomes live.
- Six real browser processes coexist while switching parks and restores panes.
- Returning to the first workspace preserves its ID and does not create another root.
- A fresh installation never creates or mutates the shared migration seeds.

## User entry points

Alt+A opens a pane; Ctrl+K Open Browser Pane is the palette entry. Ctrl+N creates
another workspace in single-window mode. Alt+2 returns to the first workspace.
The launch header notice shows the workspace profile token for manual bookmarks.

## Driving recipe

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=browser-workspaces`.
The fresh offline app needs the runner's installed Microsoft Edge. Through real
keyboard input, create six workspaces and open each pane. Independently hash the
persisted stable IDs, read completion markers and Local State from their roots,
require the app's live-pane publication, and inspect real Chromium command lines.
Return to the first workspace and require the same ID and exactly six roots.
Inspect before/action/after, workspace-0 through workspace-5 screenshots,
workspace-browser-processes.json, saved session.json and result.json.

## Gotchas

This journey does not install an extension or seed browser settings. It verifies
real pane/profile coexistence, not native messaging, remote tmux, cookies/login
behavior, bookmark editing, seeded migration, engine switching or mode round trips.
Those require their own prerequisites; executable bridge/migration tests cover
the transport and byte-isolation regressions separately. It uses only the owned
job's fresh desktop processes, never a user's browser. Six Edge processes may
need up to a minute each to become visible on the hosted desktop.
