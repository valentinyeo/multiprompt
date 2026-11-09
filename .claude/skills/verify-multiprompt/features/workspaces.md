# Workspaces

Read the current workspace name above the sessions. Click the name to open the workspace card, select another named workspace, or create a workspace. The workspaces journey verifies native clicks and screenshots in every theme, including AMOLED. The separate `workspace-focus` journey verifies keyboard input restoration for Chat View and the shell.

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
- **Identity regression.** Before creating another workspace, toggle Single-window mode off and back on through real Ctrl+K commands. Require the home workspace identity to equal the current window identity (`default`). This reproduces IGSH-1774 without writing settings or forging clicks. After creating another workspace, the existing first-workspace click must return to this same-ID home slot and close the menu; Alt+2 and Alt+3 must still switch between both slots.
- **Create.** Press Ctrl+N and require exactly one new saved workspace and CMD session.
- **Switch.** Click the workspace name even with the numbered switcher hidden. Click the first workspace row, then reopen and click the new workspace. Require the saved identities and active workspace after both clicks.
- **Themes.** Capture the header and open card in dark, Multiprompt, light, AMOLED, mid, edge grey and system themes. Check native card fill and dismiss with Escape without switching.
- **Compact geometry.** Require 28px rows, 6px panel insets and a 7px divider gap: height is `19 + rowCount * 28` at the journey’s 100% scale. Zero/unknown counts are blank; current rows use semibold names without ticks.
- **Keyboard.** Exercise Up/Down and Enter to select the first workspace, then return by mouse. Inspect `workspace-keyboard-selected.png`. Escape is checked in every theme. Scrolling and divider hit boundaries retain executable Zig coverage.
- **Theme limitation.** Graphite 2 is not shipped. Record it unavailable; Edge Grey screenshots are separately labelled, never substitutes.
- **New workspace.** Click the card's New workspace row. Require exactly one additional workspace and a closed card.
- **Archive and restore.** Select a created workspace through Ctrl+K Archive workspace, require its saved snapshot and archived registry flag, and require its removal from the stored strip, compact card, normal Open workspace list and published Inbox. Restore it through Archived workspaces and require the original workspace identity, session names and kinds. This uses real local CMD sessions, not a remote provider. Inspect `archive-*.png`, `archive-snapshot.json` and `archive-restored.session.json`.
- **Delete.** After the existing create/switch checks, rename two synthetic workspaces to Workspace 9 and CEO Runners. Delete Workspace 9 with two real mouse clicks on its filtered Ctrl+K delete row; delete CEO Runners with two Enter presses. Require both saved workspace identities and registry entries to disappear, and their actual CMD process IDs to exit. This does not delete any user workspace or prove the user's original registry state.
- **Refusal.** Select the `default` Main identity in Delete workspace. Require the existing native dialog to remain visible beyond six seconds, then dismiss it explicitly. Inspect `workspace-delete-main-refused.png`, `workspace-delete-main-still-visible.png`, the two named before/after deletion pairs, saved sessions, and the attempt/result debug lines. The isolated base slot may be displayed as Other; the protected `default` identity is unchanged.
- **Routing regression.** The hosted Zig harness in `tools/workspace-delete.test.js` executes production routing with missing, current and stale registry host labels. A real local slot must close in all three cases; a refused local slot must neither report success nor lose its registry entry. Main, the containing-window identity and another window's hosted slot remain protected. The native journey exercises real process closure and UI input, not stale-host metadata injection.
- **Proof.** Inspect `workspace-first.png`, `workspace-created.png`, `workspace-<theme>-header.png`, `workspace-<theme>-card.png`, `after.png`, saved session files, actions and `result.json`. These are real native windows on GitHub, never the user's desktop.

### Keyboard focus regression journey

Dispatch `gh workflow run verify.yml -f feature=workspace-focus`; Windows selects `control.ps1 -Feature workspace-focus`. Pull requests run this alongside the unchanged appearance journey.

- Show the default-hidden workspace switcher through Ctrl+K before any pill click; wait for saved visibility, expanded sidebar and the default unsnoozed layout.
- Follow the [complete workspace-focus step and bounded-readiness table](workspace-focus.md#driving-it-with-controlps1). It enumerates setup, keyboard and pill returns in both Chat View and the console, no-click text assertions, staged commands and cleanup.
- Require all four `workspace-focus ... PASS` outcomes and a passed `result.json`. Every transition waits for the selected saved session, matching view and actual input surface, not just the active workspace index.
- Inspect `pills-ready.png`, `action.png`, `chat-returned.png`, `after.png`, timestamped `actions.json`, saved state and debug logs. Readiness readers and Type-Text never click a composer or set focus; Press still calls SetForegroundWindow before every chord, including workspace returns and Enter. This does not prove unassisted foreground restoration.

This journey covers local CMD and Chat View typing focus, not account sync, agents, SSH or browser focus. The Zig workspace regression also covers persisted focus round trips; this desktop journey does not relaunch the app.

## Gotchas

- Without single-window mode Ctrl+N opens another app window instead; that is a different journey and is not covered here.
- Starred occupies Alt+1, so Alt+2 is the first stored workspace. It has independent session groups through the existing group actions; [Favorites groups](favorites-groups.md) verifies that grouping there leaves the home group intact.
- A focused docked browser uses Alt+Right for browser navigation. The baseline deliberately has no browser; do not pretend that a browser back/forward action switched workspaces.
- Snoozing, waking, remote-session bring-back and workspace sorting need separate real prerequisites and are not verified by create/switch/return.
