# Multiprompt desktop verification map

Read the matching feature before dispatching `verify.yml`. Each file uses four sections: sub-features, user entry points, driving recipe and gotchas. File stems are the workflow's `feature` input.

## Baseline preconditions

- Only a fresh GitHub `windows-latest` desktop; never launch locally or on a user's computer.
- A real branch build or checksum-verified release executable with matching embedded version.
- Empty isolated APPDATA, LOCALAPPDATA, USERPROFILE and HOME, one single-window instance and an initialized CMD tab. The harness must see the owned `ZigShell` HWND through UI Automation.
- Documented `MULTIPROMPT_NO_LOGIN=1` offline mode. Account login, device approval, sync, real AI agents, SSH/tmux and browser integration are not verified by this baseline.
- Read-only Doctor passes before input. Never seed session JSON, set app settings directly or reuse a shared desktop.

## Driving conventions

Dispatch `gh workflow run verify.yml -f feature=<stem>`, identify the matching revision/event, run `gh run watch <id> --interval 60`, then `gh run download <id>`. Development branches use `--ref <branch>`; a new workflow can first run through the PR trigger, defaulting to appearance. See [SKILL.md](../SKILL.md) for the exact Windows helper invocation and release selection.

Every recipe below is implemented by `control.ps1 -Feature <stem>` with the remaining identity/evidence arguments supplied by the workflow. Named keys mean actual SendInput key down/up events, not posted app messages. Query text is typed through the same input path. Search plus arrow navigation is necessary because the app paints its own palette rows. Coordinates never target input.

## Proof and failure reporting

Require `result.json` status `passed`, a successful cleanup, before/action/after screenshots you have inspected, action trace, and the feature-specific saved-file or window-state assertions. The artifact is `verify-<stem>`. Side effects come from the app or the real console command; the harness only reads them. Evidence survives scratch cleanup under `evidence/` in the runner and in the downloaded artifact.

A passing selected journey does not cover all listed entry points or every sub-feature of Multiprompt. Record the exact entry path actually exercised. Missing shells, inaccessible windows, unmatched selections and missing saved values fail; do not replace them with mocks or skip them. Map entries below describe runnable journeys, not a historical claim that each has already passed.

## Features

- [Sessions](sessions.md): create a local CMD tab through Ctrl+K, rename it, run a command and check its file.
- [Workspaces](workspaces.md): create an in-process workspace, switch away and return without losing it.
- [Session open](session-open.md): discover workspaces/groups and create a named background tmux tab through the real agent bridge; prove repeat no-op and unchanged selection, with failed SSH explicitly outside remote verification.
- [Inbox](inbox.md): open the cross-workspace list, change a session's unread state and return.
- [Command palette](command-palette.md): search and execute UI Size actions, prove persistence and reset.
- [Browser pane stuck](browser-pane-stuck.md): close, reopen, time out and retry a browser pane without an extension connection.
- [Appearance](appearance.md): choose Dark then Light through Themes and prove visible and saved changes.

The five baseline UI areas are sessions, workspace organization, Inbox, command palette and globally persisted appearance. Session open additionally covers local agent-bridge requests and saved background tabs, with observed failed SSH recorded as a boundary. Successful remote/AI/browser journeys still need their real prerequisites and are not verified by this map; the browser recovery journey deliberately has no extension attached.

## Code interview anchors

- Primary surface, normal build and offline mode: `README.md`, `CONTRIBUTING.md`.
- Keyboard routing and shortcut labels: `src/shortcuts.zig`, `openwiki/operations/keyboard-shortcuts.md`, `src/focus.zig`.
- Startup flags and versioned title: `src/startup.zig:108`, `src/startup.zig:310`; initial shell and readiness: `src/main.zig:8017`.
- Palette query matching and actions: `src/command_palette.zig:1672`, `src/command_palette.zig:2071`, `src/command_palette.zig:3788`; displayed labels: `src/sidebar.zig:3563`, `src/sidebar.zig:3895`.
- Theme persistence and user action: `src/themes.zig:232`, `src/main.zig:6301`.
- Session persistence and workspace actions: `src/session.zig:96`, `src/session.zig:659`, `src/workspaces.zig:3041`, `src/rename.zig`.
- Inbox window state, saved published attention and user toggle: `src/inbox.zig:240`, `src/inbox.zig:1358`, `src/inbox.zig:1670`.

Keep these implementation anchors here, not in the user-facing recipes. Refresh them when the source moves.
