# Workspaces

Create a workspace in the same desktop window and switch away and back while retaining the workspace and its session.

## Sub-features

- `workspace-create`: add one in-process workspace with a real CMD session.
- `workspace-switch`: return to the first stored workspace.
- `workspace-return`: cycle back to the new workspace and confirm its saved identity and active state.

## How to get to it (user POV)

- In single-window mode press Ctrl+N, or use the new-workspace pill (Alt+N).
- Alt+1 selects Starred; Alt+2 through Alt+9 select the first eight stored workspaces.
- Alt+Left / Alt+Right cycle workspaces; Alt+J / Alt+K also cycle outside an Inbox context.
- Workspace pills are mouse entry points. Ctrl+K `Open Workspace` opens stored workspaces; `Sort Workspaces` orders pills. These are alternative paths, not exercised here.

## Driving it with control.ps1

Preconditions:

- Baseline Doctor passes in single-window mode with the first stored workspace active and a real CMD session.
- The fresh instance has room for another workspace; no browser pane owns Alt+Right.

- **Dispatch.** Run `gh workflow run verify.yml -f feature=workspaces`; Windows runs `control.ps1 -Feature workspaces`.
- **Create.** Capture the baseline and press Ctrl+N. The saved workspace count must increase by exactly one. `created.png` shows the new workspace and its CMD tab; remember its active workspace index.
- **Switch away.** Press Alt+2. The saved active workspace must be the first stored workspace, index zero.
- **Return.** Press Alt+Right. The saved active workspace must equal the newly created workspace, not Starred or a different window.
- **Proof.** Inspect `before.png`, `created.png`, `after.png`, the timestamped keys in `actions.json`, and `data/roaming/ZigShell/session.json`. `result.json` records before/after workspace counts, returned active index and window title.

## Gotchas

- Without single-window mode Ctrl+N opens another app window instead; that is a different journey and is not covered here.
- Starred occupies Alt+1, so Alt+2 is the first stored workspace.
- A focused docked browser uses Alt+Right for browser navigation. The baseline deliberately has no browser; do not pretend that a browser back/forward action switched workspaces.
- Snoozing, waking, remote-session bring-back and workspace sorting need separate real prerequisites and are not verified by create/switch/return.
