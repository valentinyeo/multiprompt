# Multiprompt desktop verification map

Read the matching feature before dispatching. Each file uses four sections: sub-features, user entry points, driving recipe and gotchas. Baseline file stems are `verify.yml`'s `feature` input; the SSH maps below use the separate reconnect workflow.

## Baseline preconditions

- Only a fresh GitHub `windows-latest` desktop; never launch locally or on a user's computer.
- A real branch build or checksum-verified release executable with matching embedded version.
- Empty isolated APPDATA, LOCALAPPDATA, USERPROFILE and HOME, one single-window instance and an initialized CMD tab. The harness must see the owned `ZigShell` HWND through UI Automation.
- Documented `MULTIPROMPT_NO_LOGIN=1` offline mode. Account login, device approval, sync, real AI agents, SSH/tmux and browser integration are not verified by this baseline.
- Read-only Doctor passes before input. Never seed session JSON, set app settings directly or reuse a shared desktop.

## Driving conventions

Dispatch `gh workflow run verify.yml -f feature=<stem>`, identify the matching revision/event, run `gh run watch <id> --interval 60`, then `gh run download <id>`. Development branches use `--ref <branch>`; a new workflow can first run through the PR trigger, defaulting to appearance. See [SKILL.md](../SKILL.md) for the exact Windows helper invocation and release selection.

Every baseline recipe below is implemented by `control.ps1 -Feature <stem>` with the remaining identity/evidence arguments supplied by the workflow. Named keys mean actual SendInput key down/up events, not posted app messages. Query text is typed through the same input path. Search plus arrow navigation is necessary because the app paints its own palette rows. The browser-pane-locked journey alone targets an ownership-checked empty browser strip with real mouse input.

## Proof and failure reporting

Require `result.json` status `passed`, a successful cleanup, before/action/after screenshots you have inspected, action trace, and the feature-specific saved-file or window-state assertions. The artifact is `verify-<stem>`. Side effects come from the app or the real console command; the harness only reads them. Evidence survives scratch cleanup under `evidence/` in the runner and in the downloaded artifact.

A passing selected journey does not cover all listed entry points or every sub-feature of Multiprompt. Record the exact entry path actually exercised. Missing shells, inaccessible windows, unmatched selections and missing saved values fail; do not replace them with mocks or skip them. Map entries below describe runnable journeys, not a historical claim that each has already passed.

## Diagnostic verification

- [Chat sync audit](../diagnostics/chat-sync-audit.md): a dedicated `feature=chat-sync-audit` job runs the real audit renderer and synthetic diagnostic fixtures on GitHub Linux. This is not a desktop journey and makes no UI or live-session claim.

## Features

- [Safe updates](safe-updates.md): dedicated signed local-release swap journey, including responsive sign-in, consecutive app/bridge updates and rollback; uses the update driver rather than baseline offline sessions.
- [Chat tables](chat-tables.md): format a real console table and retain it across a tab switch.
- [Browser emulation](browser-emulation.md): drive the real native zsb CLI and unpacked extension in isolated Chrome for Testing; prove mobile viewport, UA and touch across navigation and restore desktop with off. This is an extension journey, not embedded-pane verification.
- [Session restore](session-restore.md): reopen the selected workspace and CMD session after both normal close and process kill, using only app-created state.
- [Sessions](sessions.md): create a local CMD tab through Ctrl+K, rename it, run a command and check its file.
- [Favorites groups](favorites-groups.md): group a starred session independently in Favorites and its home workspace using the existing palette.
- [Workspaces](workspaces.md): create an in-process workspace, switch away and return without losing it.
- [Session open](session-open.md): discover workspaces/groups and create a named background tmux tab through the real agent bridge; prove repeat no-op and unchanged selection, with failed SSH explicitly outside remote verification.
- [Workspace focus](workspace-focus.md): restore Chat View typing and shell input after keyboard workspace switches.
- [Inbox](inbox.md): open the cross-workspace list, change a session's unread state and return.
- [Command palette](command-palette.md): search and execute UI Size actions, prove persistence and reset.
- [Pane layout](pane-layout.md): keep the console focus border continuous, the pane gap clear and the gray group line separate from the first session icon.
- [Browser pane locked](browser-pane-locked.md): real strip dragging, Win+Up and double-click cannot move or maximize the docked browser.
- [Browser pane stuck](browser-pane-stuck.md): close and reopen panes, then keep a docked pane visible past the opening deadline without an extension.
- [Chat View](chat-view.md): open, close and reopen the native transcript through Alt+C; pair the real desktop evidence with a separate synthetic-envelope Windows painter image, without claiming live agent delivery.
- [Appearance](appearance.md): choose Dark then Light through Themes and prove visible and saved changes.

The five baseline UI areas are sessions, workspace organization, Inbox, command palette and globally persisted appearance. Session open additionally covers local agent-bridge requests and saved background tabs, with observed failed SSH recorded as a boundary. Successful remote/AI/browser journeys still need their real prerequisites and are not verified by this map; the browser recovery journey deliberately has no extension attached.

### SSH reconnect maps

- [SSH tab reconnect](ssh-tab-reconnect.md): background transport loss without layout/focus disruption; case A.
- [Ended remote session](ended-remote-session.md): confirmed missing tmux session stops retries and shows Session ended; case B.
- [Saved remote workspace](saved-remote-workspace.md): two seeded remote tabs restore to a usable workspace; launch/Doctor.

These maps use `.github/workflows/verify-reconnect.yml` and `tools/verify-reconnect/`, not `control.ps1` or `verify.yml`'s feature input. Read the shared skill's Drive section for dispatch, stand-in boundary, artifacts and cleanup. Only SSH is replaced; native app layout, focus, reconnect and ended-session state run for real on GitHub Windows.

## Code interview anchors

- Primary surface, normal build and offline mode: `README.md`, `CONTRIBUTING.md`.
- Keyboard routing and shortcut labels: `src/shortcuts.zig`, `openwiki/operations/keyboard-shortcuts.md`, `src/focus.zig`.
- Startup flags and versioned title: `src/startup.zig:108`, `src/startup.zig:310`; initial shell and readiness: `src/main.zig:8017`.
- Palette query matching and actions: `src/command_palette.zig:1672`, `src/command_palette.zig:2071`, `src/command_palette.zig:3788`; displayed labels: `src/sidebar.zig:3563`, `src/sidebar.zig:3895`.
- Theme persistence and user action: `src/themes.zig:232`, `src/main.zig:6301`.
- Session persistence and workspace actions: `src/session.zig:96`, `src/session.zig:659`, `src/workspaces.zig:3041`, `src/rename.zig`.
- Inbox window state, saved published attention and user toggle: `src/inbox.zig:240`, `src/inbox.zig:1358`, `src/inbox.zig:1670`.

Keep these implementation anchors here, not in the user-facing recipes. Refresh them when the source moves.
