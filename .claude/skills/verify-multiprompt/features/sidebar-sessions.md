# Sidebar sessions

Open, name, group, pin, reorder, archive, and delete sessions without losing their saved chat history.

Journeys: sessions, session-actions, session-tabs
Release paths: src/sidebar.zig, src/session*.zig, src/rename.zig, src/archive*.zig, src/favorites*.zig, src/main.zig, src/app_state.zig, build.zig

## Sub-features
- `open-select` opens a session and preserves its chosen server, folder, and view.
- `organize` names, favorites, pins, groups, and reorders sessions.
- `archive-delete-restore` distinguishes saved history from a running agent.

## How to get to it (user POV)
- Click a sidebar row or plus; Ctrl+T; Ctrl+Tab or Ctrl+1…9; F2; Alt+S; drag rows; right-click a tab or group; Ctrl+K All Sessions, Delete session, or New terminal.

## Driving it with drive.ps1
Preconditions: fresh hosted Windows desktop, matching executable/hash/version, isolated app data, and the selected legacy recipe’s prerequisites.
- Migration pending for this feature. Run `gh workflow run verify.yml --ref <branch> -f feature=sessions`. [Sessions](sessions.md), [session actions](session-actions.md), and [session tabs](session-tabs.md) enumerate exact inputs and saved-tab assertions.
- Require selected shell identity, the selected recipe’s saved-tab assertions, screenshots, and actual owned-process closure for deletion. Only the selected journey is covered. Download `verify-sessions` after cleanup. This legacy workflow route does not yet use the video driver; see [inventory](../inventory.md).

## Gotchas
- Remote creation needs a configured host and repo. The sessions journey replaces SSH at its documented boundary, not a live agent.
