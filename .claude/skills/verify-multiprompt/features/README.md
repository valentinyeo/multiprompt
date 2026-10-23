# Multiprompt desktop verification map

Read the matching feature before dispatching. [Recent changes coverage](../coverage.md) lists ticket gaps and this pass's run results. Each file uses four sections: sub-features, user entry points, driving recipe and gotchas. Baseline file stems are `verify.yml`'s `feature` input; the SSH maps below use the separate reconnect workflow.

## Baseline preconditions

- Only a fresh GitHub `windows-latest` desktop; never launch locally or on a user's computer.
- A real branch build or checksum-verified release executable with matching embedded version.
- Empty isolated APPDATA, LOCALAPPDATA, USERPROFILE and HOME, one single-window instance and an initialized CMD tab. The harness must see the owned `ZigShell` HWND through UI Automation.
- Documented `MULTIPROMPT_NO_LOGIN=1` offline mode. Account login, device approval, sync, real AI agents, SSH/tmux and browser integration are not verified by this baseline.
- Read-only Doctor passes before input. Never seed session JSON, set app settings directly or reuse a shared desktop.

## Driving conventions

Dispatch `gh workflow run verify.yml -f feature=<stem>`, identify the matching revision/event, run `gh run watch <id> --interval 60`, then `gh run download <id>`. Development branches use `--ref <branch>`; the PR trigger runs appearance, workspace-focus, favorites-groups, browser-pane-stuck, browser-pane-locked, group-rail, pane-layout, chat-view-everywhere, status-card, palette-order and browser-own-profile. See [SKILL.md](../SKILL.md) for the exact Windows helper invocation and release selection.

Every baseline recipe below is implemented by `control.ps1 -Feature <stem>` with the remaining identity/evidence arguments supplied by the workflow. Named keys mean actual SendInput key down/up events, not posted app messages. Query text is typed through the same input path. Search plus arrow navigation is necessary because the app paints its own palette rows. Browser-pane-locked targets an ownership-checked empty browser strip with real mouse input; workspace-focus also clicks workspace pills.

## Proof and failure reporting

Require `result.json` status `passed`, a successful cleanup, before/action/after screenshots you have inspected, action trace, and the feature-specific saved-file or window-state assertions. The artifact is `verify-<stem>`. Side effects come from the app or the real console command; the harness only reads them. Evidence survives scratch cleanup under `evidence/` in the runner and in the downloaded artifact.

A passing selected journey does not cover all listed entry points or every sub-feature of Multiprompt. Record the exact entry path actually exercised. Missing shells, inaccessible windows, unmatched selections and missing saved values fail; do not replace them with mocks or skip them. Map entries below describe runnable journeys, not a historical claim that each has already passed.

## Diagnostic verification

- [Account servers](../diagnostics/account-hosts.md): deterministic Test-workflow Worker and production desktop-sync regression; the offline desktop harness has no account-service stub.

- [Chat sync audit](../diagnostics/chat-sync-audit.md): a dedicated `feature=chat-sync-audit` job runs the real audit renderer and synthetic diagnostic fixtures on GitHub Linux. This is not a desktop journey and makes no UI or live-session claim.

## Features

- [Safe updates](safe-updates.md): dedicated signed local-release swap journey, including responsive sign-in, consecutive app/bridge updates and rollback; uses the update driver rather than baseline offline sessions.
- [Chat tables](chat-tables.md): format a real console table and retain it across a tab switch.
- [Browser emulation](browser-emulation.md): drive the real native zsb CLI and unpacked extension in isolated Chrome for Testing; prove mobile viewport, UA and touch across navigation and restore desktop with off. This is an extension journey, not embedded-pane verification.
- [Session restore](session-restore.md): reopen the selected workspace and CMD session after both normal close and process kill, using only app-created state.
- [Palette order](palette-order.md): open an empty Ctrl+K with a seeded usage history file; require the Most used band, group headers, the removed per-tab row and renamed commands.
- [Sessions](sessions.md): create a local CMD tab through Ctrl+K, rename it, run a command and check its file.
- [Group rail](group-rail.md): keep both grouped selections clear of the gray rail and the space below the group free of stray rail pixels.
- [Favorites groups](favorites-groups.md): group a starred session independently in Favorites and its home workspace using the existing palette.
- [Workspaces](workspaces.md): create an in-process workspace, switch away and return without losing it.
- [Session open](session-open.md): discover workspaces/groups and create a named background tmux tab through the real agent bridge; prove repeat no-op and unchanged selection, with failed SSH explicitly outside remote verification.
- [Workspace focus](workspace-focus.md): restore Chat View typing and shell input after keyboard workspace switches.
- [Inbox](inbox.md): open the cross-workspace list, change a session's unread state and return.
- [Command palette](command-palette.md): search and execute UI Size actions, prove persistence and reset.
- [Status card](status-card.md): measure the one-line sidebar status card on all three pages after real Ctrl+Shift+G presses and capture its hover view; fail outside 20 to 30 px.
- [Pane layout](pane-layout.md): keep the console focus border continuous, the pane gap clear and the gray group line separate from the first session icon.
- [Browser pane locked](browser-pane-locked.md): real strip dragging, Win+Up and double-click cannot move or maximize the docked browser.
- [Browser switch speed](browser-switch-speed.md) (on demand only): compare 20 Ctrl+Tab switches without panes against 20 with warm docked browsers and five freshly frozen returns in console and Chat View; fail above a 50 ms median gap.
- [Own browser profile](browser-own-profile.md): a workspace listed in `browser-own-profile.txt` opens its pane in its own empty Chrome profile and pipe, while other workspaces keep the shared profile untouched, including after restart.
- [Browser pane stuck](browser-pane-stuck.md): close and reopen panes, then keep a docked pane visible past the opening deadline without an extension.
- [Chat delivery](chat-delivery.md): real-keyboard composer delivery through the production tmux host channel to a console-backed remote-shell stand-in, with busy, grey-suggestion and steer cases; not real Claude or a real server. This verify.yml journey explicitly seeds isolated saved tabs like verify-reconnect.
- [Chat View everywhere](chat-view-everywhere.md): one-time bulk actions, independent later toggles, a shell lock and restart persistence through real input.
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
- Startup flags: `parseNoWindowRestoreFlag` at `src/startup.zig:108`, `parseSingleWindowFlag` at `src/startup.zig:146`; title: `buildWindowTitle` at `src/startup.zig:308`. Initial CMD fallback: `spawnShell` at `src/main.zig:8234`; deferred readiness: `WM_DEFERRED` at `src/main.zig:1349`.
- Palette queries: `updateSearchResults` at `src/command_palette.zig:1462`, UI-size keywords: `ui_labels` at `src/command_palette.zig:3859`, theme filtering: `g_search_theme_mode` at `src/command_palette.zig:1700`; actions: `WM_APP_SEARCH_CONFIRM` at `src/main.zig:4328`, UI size: `SEARCH_UI_BIGGER_OFFSET` at `src/main.zig:4966`. Displayed labels: `UI Size: Increase` at `src/sidebar.zig:3658`, `New CMD Shell` at `src/sidebar.zig:4056`.
- Theme persistence: `saveGlobalTheme` at `src/themes.zig:232`; menu: `SEARCH_THEME_MENU_OFFSET` at `src/main.zig:6438`; apply: `SEARCH_THEME_SYSTEM_OFFSET` at `src/main.zig:6450`.
- Session persistence: `getSessionPath` at `src/session.zig:95`, `saveSessionTo` at `src/session.zig:155`, `saveSession` at `src/session.zig:797`; saved scale: `g_ui_scale` at `src/session.zig:645`; workspace data: `active_workspace` at `src/session.zig:671`. Workspace actions: `switchToWorkspace` at `src/workspaces.zig:2711`, `newWorkspace` at `src/workspaces.zig:3245`; rename: `src/rename.zig`.
- Inbox publication: `publishInboxStateNow` at `src/inbox.zig:240`; visibility: `openInbox` at `src/inbox.zig:1374`, `closeInbox` at `src/inbox.zig:1409`; unread toggle: `inboxToggleReadRow` at `src/inbox.zig:1687`, keyboard dispatch: `handleInboxKey` at `src/inbox.zig:1717`.

Keep these implementation anchors here, not in the user-facing recipes. Refresh them when the source moves.
