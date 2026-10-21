# Workspaces

Create a workspace in the same desktop window and switch away and back while retaining the workspace and its session. The separate `workspace-focus` journey verifies keyboard input restoration for Chat View and the shell.

## Sub-features

- `workspace-create`: add one in-process workspace with a real CMD session.
- `workspace-switch`: return to the first stored workspace.
- `workspace-return`: cycle back to the new workspace and confirm its saved identity and active state.
- `workspace-focus`: leave and return with Alt+Right / Alt+Left, then type into the remembered Chat View typing box or shell without clicking.

## How to get to it (user POV)

- In single-window mode press Ctrl+N, or use the new-workspace pill (Alt+N).
- Alt+1 selects Starred; Alt+2 through Alt+9 select the first eight stored workspaces.
- Alt+Left / Alt+Right cycle workspaces; Alt+J / Alt+K also cycle outside an Inbox context.
- Workspace pills are mouse entry points. Ctrl+K `Open Workspace` opens stored workspaces; `Sort Workspaces` orders pills. These are alternative paths, not exercised here.
- Agents use `zsb workspace-list` to discover workspace, group and host names, then `zsb session-open --workspace <name> --group <name> --host <reported host> --tmux <session> --name <title>` to open a background tmux tab without switching the active workspace or tab. See [Session open](session-open.md) for that separate CLI journey and its SSH boundary.

## Driving it with control.ps1

Preconditions:

- Baseline Doctor passes in single-window mode with the first stored workspace active and a real CMD session.
- The fresh instance has room for another workspace; no browser pane owns Alt+Right.

- **Dispatch.** Run `gh workflow run verify.yml -f feature=workspaces`; Windows runs `control.ps1 -Feature workspaces`.
- **Create.** Capture the baseline and press Ctrl+N. The saved workspace count must increase by exactly one. `created.png` shows the new workspace and its CMD tab; remember its active workspace index.
- **Switch away.** Press Alt+2. The saved active workspace must be the first stored workspace, index zero.
- **Return.** Press Alt+Right. The saved active workspace must equal the newly created workspace, not Starred or a different window.
- **Proof.** Inspect `before.png`, `created.png`, `after.png`, the timestamped keys in `actions.json`, and `data/roaming/ZigShell/session.json`. `result.json` records before/after workspace counts, returned active index and window title.

### Keyboard focus regression journey

Dispatch `gh workflow run verify.yml -f feature=workspace-focus`; Windows selects `control.ps1 -Feature workspace-focus`. Pull requests run this alongside the unchanged appearance journey.

- Wait for workspace 1's CMD session to be saved. Use Ctrl+K `per tab` to select per-session Chat View, then Alt+C if that session's Chat View is off. Wait for the saved enabled state and the owned frame's visible native Edit child. Restore and foreground the frame, wait for that exact Edit HWND to have focus, then type `before-` and require its exact value before switching. All waits have timeouts; CMD supports this without Claude or an account.
- Create workspace 2 with Ctrl+N, return with Alt+2, then switch away with Alt+Right and back with Alt+Left.
- Without clicking or issuing another focus command, type `workspace-focus-chat`. Read the original Edit control's UI Automation ValuePattern and require exactly `before-workspace-focus-chat`, the same focused HWND, the same selected session and saved workspace focus `chat`.
- Press Alt+C to return to the shell. Type `echo workspace-focus-shell` without Enter, switch away and back with Alt+Right / Alt+Left, then append redirection to the isolated `workspace-focus-shell.txt` and press Enter without clicking.
- Require that previously absent file to contain exactly `workspace-focus-shell`, the same selected session and saved workspace focus `shell`. The harness never writes the marker or session state.
- Require `workspace-focus chat PASS` and `workspace-focus shell PASS` in the job log. A missing text value, file, focus target or selected session fails the job; inspect `before.png`, `action.png`, `chat-returned.png`, `after.png`, `actions.json`, `result.json` and the retained data.

This journey covers local CMD and Chat View typing focus, not account sync, agents, SSH or browser focus. The Zig workspace regression also covers persisted focus round trips; this desktop journey does not relaunch the app.

## Gotchas

- Without single-window mode Ctrl+N opens another app window instead; that is a different journey and is not covered here.
- Starred occupies Alt+1, so Alt+2 is the first stored workspace.
- A focused docked browser uses Alt+Right for browser navigation. The baseline deliberately has no browser; do not pretend that a browser back/forward action switched workspaces.
- Snoozing, waking, remote-session bring-back and workspace sorting need separate real prerequisites and are not verified by create/switch/return.
