# Notifications and Inbox

Triage unread or working sessions across workspaces, mark them read, archive them, and return to the chosen chat.

Journeys: inbox, remind-me

## Sub-features
- `attention` shows unread and working sessions across workspaces.
- `triage` filters, navigates, opens, marks, archives, and restores rows.
- `remind` hides a tmux-backed session until a chosen time.

## How to get to it (user POV)
- Click the sidebar Inbox button; Ctrl+Shift+I toggles; Alt+I opens All; Ctrl+F or / filters; j/k and Enter open rows; u marks unread; e archives and z undoes; Ctrl+H or Alt+H opens Remind Me for a tmux-backed tab.

## Driving it with drive.ps1
Preconditions: fresh hosted Windows desktop, matching executable/hash/version, isolated app data, and the selected legacy recipe’s prerequisites.
- Migration pending for this feature. Run `gh workflow run verify.yml --ref <branch> -f feature=inbox`. [Inbox](inbox.md) and [Remind Me](remind-me.md) specify actual keyboard steps and published shell-state assertions.
- Require chosen row identity, read/unread or reminder state from app-written files, visible Inbox screenshots, and the named result checks. Only the selected journey is covered. Download `verify-inbox` after cleanup. This legacy workflow route does not yet use the video driver; see [inventory](../inventory.md).

## Gotchas
- Offline unread toggles do not prove TCP notifications, real remote attention events, or cross-device sync. Never manufacture a notification then claim real delivery.
