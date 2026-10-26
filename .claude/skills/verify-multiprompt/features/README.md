# Multiprompt desktop verification map

Read the matching feature before dispatching. [Recent changes coverage](../coverage.md) lists ticket gaps and this pass's run results. Each file uses four sections: sub-features, user entry points, driving recipe and gotchas. Baseline file stems are `verify.yml`'s `feature` input; the SSH maps below use the separate reconnect workflow.

## Baseline preconditions

- Only a fresh GitHub `windows-latest` desktop; never launch locally or on a user's computer.
- A real branch build or checksum-verified release executable with matching embedded version.
- Empty isolated APPDATA, LOCALAPPDATA, USERPROFILE and HOME, one single-window instance and an initialized CMD tab. The harness must see the owned `ZigShell` HWND through UI Automation.
- Documented `MULTIPROMPT_NO_LOGIN=1` offline mode. Account login, device approval, sync, real AI agents, SSH/tmux and browser integration are not verified by this baseline.
- Read-only Doctor passes before input. Never seed session JSON, set app settings directly or reuse a shared desktop.

## Driving conventions

Dispatch `gh workflow run verify.yml -f feature=<stem>`, identify the matching revision/event, run `gh run watch <id> --interval 60`, then `gh run download <id>`. Development branches use `--ref <branch>`; the PR trigger runs appearance, chat-dictation, workspace-focus, favorites-groups, browser-pane-stuck, browser-pane-locked, group-rail, pane-layout, chat-view-everywhere, chat-focus, status-card, palette-order, browser-own-profile and remind-me; `tab-names` runs on request. See [SKILL.md](../SKILL.md) for the exact Windows helper invocation and release selection.

Every baseline recipe below is implemented by `control.ps1 -Feature <stem>` with the remaining identity/evidence arguments supplied by the workflow. Named keys mean actual SendInput key down/up events, not posted app messages. Query text is typed through the same input path. Search plus arrow navigation is necessary because the app paints its own palette rows. Browser-pane-locked targets an ownership-checked empty browser strip with real mouse input; workspace-focus also clicks workspace pills.

## Proof and failure reporting

Require `result.json` status `passed`, a successful cleanup, before/action/after screenshots you have inspected, action trace, and the feature-specific saved-file or window-state assertions. The artifact is `verify-<stem>`. Side effects come from the app or the real console command; the harness only reads them. Evidence survives scratch cleanup under `evidence/` in the runner and in the downloaded artifact.

A passing selected journey does not cover all listed entry points or every sub-feature of Multiprompt. Record the exact entry path actually exercised. Missing shells, inaccessible windows, unmatched selections and missing saved values fail; do not replace them with mocks or skip them. Map entries below describe runnable journeys, not a historical claim that each has already passed.

## Diagnostic verification

- [Remote switch speed](../diagnostics/remote-switch-speed.md): dedicated Windows baseline/candidate workflow, 20 session switches and 20 workspace switches, 2,000 rendered messages, native paint gaps, one-core CPU, and two-second recovery.

- [Account servers](../diagnostics/account-hosts.md): deterministic Test-workflow Worker and production desktop-sync regression; the offline desktop harness has no account-service stub.

- [Chat sync audit](../diagnostics/chat-sync-audit.md): a dedicated `feature=chat-sync-audit` job runs the real audit renderer and synthetic diagnostic fixtures on GitHub Linux. This is not a desktop journey and makes no UI or live-session claim.

## Features

- [Inline working dots](chat-working.md): screenshot pixels prove three animated dots in the next reply slot and their disappearance after the reply.

- [Chat dictation](chat-dictation.md): Ctrl+D, all three stop methods, visible microphone state, immediate native draft insertion and typing while listening, with recorded audio and offline provider-response replay.
- [Every session message](chat-full-history.md): all 50 messages on open and restart, with a pre-fix origin/master red control.

- [Messages only](chat-messages-only.md): a tool-heavy assistant turn retains all transcript data but paints no tool rows or empty space; the identical Windows journey must reject the pinned pre-fix commit 42cecfd3.

- [Safe updates](safe-updates.md): dedicated signed local-release swap journey, including responsive sign-in, consecutive app/bridge updates and rollback; uses the update driver rather than baseline offline sessions.
- [Chat tables](chat-tables.md): format a real console table and retain it across a tab switch.
- [Skill pills](chat-skill-pill.md): known skills stand out in the composer and sent history on dark and light themes; ordinary messages and unknown slash text stay plain.
- [Chat composer text](chat-composer-text.md): real typed message-box text is measured with system smoothing OFF; native production-painter evidence spans three UI scales and three DPIs, with v0.28.858 as the live red control.
- [Chat code font](chat-code-font.md): a real console fenced code block draws Nordwand Mono cells 2 pt smaller than before, the app logs the selected code face, and the branch painter proves overflowing diff rows stay smooth on DirectWrite.
- [Browser emulation](browser-emulation.md): drive the real native zsb CLI and unpacked extension in isolated Chrome for Testing; prove mobile viewport, UA and touch across navigation and restore desktop with off. This is an extension journey, not embedded-pane verification.
- [Chat first paint](chat-first-paint.md): quit with Chat View and a docked browser pane open, relaunch, and require the transcript, message box and composer card to keep one position from the first painted frame until restore finishes.
- [Relaunch saved sessions](relaunch-saved-sessions.md): the release gate. A seeded Starred workspace of 14 live sessions and 6 cached copies is launched and quit three times, the last two with every notification port occupied; each session must appear once and the selected chat must stay.
- [Session restore](session-restore.md): reopen the selected workspace and CMD session after both normal close and process kill, using only app-created state.
- [Remind Me](remind-me.md): press Ctrl+H on a tmux session, require the hour and evening preset rows in the app log, then Esc without choosing one.
- [Tab names](tab-names.md): a seeded state of three unflagged tab names in one folder, reordered, then launch, close, kill and close again; every name and the order must hold for 45 seconds after each start, with v0.28.893 as the red control. Seeds `session.json` once; see its boundary.
- [Palette order](palette-order.md): open an empty Ctrl+K with a seeded usage history file; require the Most used band, group headers, the removed per-tab row and renamed commands.
- [Sessions](sessions.md): create a local CMD tab through Ctrl+K, rename it, run a command and check its file.
- [Group headlines](group-rail.md): plain left-aligned group headlines with no fill, rail or chevron, and a headline click that hides and restores its sessions.
- [Favorites groups](favorites-groups.md): group a starred session independently in Favorites and its home workspace using the existing palette.
- [Workspaces](workspaces.md): create an in-process workspace, switch away and return without losing it.
- [Session open](session-open.md): discover workspaces/groups and create a named background tmux tab through the real agent bridge; prove repeat no-op and unchanged selection, and require failed SSH status with its logged exit code; successful remote attachment remains outside verification.
- [Workspace focus](workspace-focus.md): restore Chat View typing and shell input after keyboard workspace switches.
- [Inbox](inbox.md): open the cross-workspace list, change a session's unread state and return.
- [Command palette](command-palette.md): search and execute UI Size actions, prove persistence and reset.
- [Status card](status-card.md): measure the one-line sidebar status card on all three pages after real Ctrl+Shift+G presses and capture its hover view; fail outside 20 to 30 px.
- [Title bar](title-bar.md): native caption glyph identity and app-black caption-facing masks with mismatched Chrome themes at real 100%, 125% and 150% monitor scaling.
- [Pane layout](pane-layout.md): preserve pane geometry and Alt+Q input routing without focus rings; compare exact margin pixels and screenshots across themes against a pinned pre-fix control.
- [Browser corners](browser-corners.md): twenty mixed activations retain all four rounded corner masks, measured from pixels and real window stacking.
- [Browser pane locked](browser-pane-locked.md): real strip dragging, Win+Up and double-click cannot move or maximize the docked browser.
- [Browser switch speed](browser-switch-speed.md) (on demand only): compare 20 Ctrl+Tab switches without panes against 20 with warm docked browsers and five freshly frozen returns in console and Chat View; fail above a 50 ms median gap.
- [Chat switch speed](chat-switch-speed.md) (on demand only): 20 Ctrl+N switches across five seeded remote Claude sessions in Chat View with the browser pane closed and open; fail above a 150 ms median click-to-chat-shown time or any 100 ms window hang.
- [Own browser profile](browser-own-profile.md): a workspace listed in `browser-own-profile.txt` opens its pane in its own empty Chrome profile and pipe, while other workspaces keep the shared profile untouched, including after restart.
- [Browser pane stuck](browser-pane-stuck.md): close and reopen panes, then keep a docked pane visible past the opening deadline without an extension.
- [Chat delivery](chat-delivery.md): real-keyboard composer delivery through the production tmux host channel to a console-backed remote-shell stand-in, with busy, grey-suggestion and steer cases; not real Claude or a real server. This verify.yml journey explicitly seeds isolated saved tabs like verify-reconnect.
- [Chat View everywhere](chat-view-everywhere.md): one-time bulk actions on every tab, independent pinned/unpinned toggles, removed command queries and restart persistence through real input.
- [Chat focus](chat-focus.md): restart typing and Alt+Q/Alt+M recovery from Find and transcript interaction without a browser pane.
- [Composer buttons](composer-buttons.md): one-line and six-line working drafts retain equally round, bottom-aligned attach, microphone and Send controls.
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
