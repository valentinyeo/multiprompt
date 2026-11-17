# Workspaces and rooms

Organize sessions by workspace and coordinate several agents in a Room.

Journeys: workspaces, workspace-focus

## Sub-features
- `workspace` creates, switches, stars, snoozes, and archives session collections.
- `restore` brings archived workspaces and their sessions back.
- `room` creates, opens, and edits a shared multi-agent conversation.

## How to get to it (user POV)
- Click the workspace name/card; Ctrl+N or Alt+N creates; Alt+1 opens Starred; Alt+2…9 selects stored workspaces; Alt+Left/Right cycles; Ctrl+Shift+N or Ctrl+K New room creates a Room; search its name or Edit room.

## Driving it with drive.ps1
Preconditions: single-window mode, fresh hosted Windows desktop, matching executable/hash/version, isolated app data, and the selected legacy recipe’s prerequisites.
- Migration pending for this feature. Run `gh workflow run verify.yml --ref <branch> -f feature=workspaces`. [Workspaces](workspaces.md) drives creation, switching, archive/restore and deletion; [workspace focus](workspace-focus.md) checks typing after returning.
- Require stable saved workspace IDs and session membership, card screenshots, and restored typing. Rooms require visible member replies in a separately authenticated live pass. Only the selected journey is covered. Download `verify-workspaces` after cleanup. This legacy workflow route does not yet use the video driver; see [inventory](../inventory.md).

## Gotchas
- Offline CMD workspace proof does not cover Rooms, sync, or remote agents. Room reply checks are [diagnostic](../diagnostics/room-reply-grouping.md), not a completed desktop journey.
