# Workspaces and rooms

Organize sessions by workspace and coordinate several agents in a Room.

Journeys: workspaces, workspace-focus
Release paths: src/workspace*.zig, src/room*, src/groups*.zig, src/main.zig, build.zig

## Sub-features
- `workspace` creates, switches, aggregates favorite sessions in Starred, snoozes, and archives session collections.
- `restore` brings archived workspaces and their sessions back.
- `room` creates, opens, and edits a shared multi-agent conversation.

## How to get to it (user POV)
- Click the workspace name/card; Ctrl+N or Alt+N creates; Alt+1 opens Starred; Alt+2…9 selects stored workspaces; Alt+Left/Right cycles; Ctrl+Shift+N or Ctrl+K New room creates a Room; search its name or Edit room.

## Driving it with drive.ps1
Preconditions: single-window mode, fresh hosted Windows desktop, matching executable/hash/version, isolated app data, and the selected legacy recipe’s prerequisites.
- The shared wrapper accepts these Journeys; automatic workflow migration remains partial. Run `gh workflow run verify.yml --ref <branch> -f feature=workspaces`. [Workspaces](workspaces.md) drives creation, switching, archive/restore and deletion; [workspace focus](workspace-focus.md) checks typing after returning.
- Require stable saved workspace IDs and session membership, card screenshots, and restored typing. The [rooms journey](rooms.md) supplies a runner-owned authenticated account and two deterministic live member agents. Only the selected journey is covered. Download `verify-workspaces` after cleanup. This legacy workflow route does not yet use the video driver; see [inventory](../inventory.md).

The recipes distinguish existing focused journeys from unreachable complete paths. UNREACHABLE names the missing data, endpoint, build mode or driver action; it never means the product passed.

### workspace: Workspace lifecycle

Create and rename a workspace; choose its folder and color. Select a different stored workspace, then return through the name card, Alt+2..9 and Alt+Left/Right. Archive it, restore it from Archived workspaces, then delete the disposable archived workspace with the second Enter confirmation.

Observable proof: Saved workspace ID, folder, color and tab membership match each screenshot. Return restores its selected chat and exact draft. Archive keeps server sessions. Other remains reachable and cannot be archived away.

Journey: workspaces, workspace-focus, sessions. UNREACHABLE for cross-device folder/archive propagation until two authenticated disposable devices are available; Part B alone is insufficient.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_CLOSEWIN_OFFSET` | Ctrl+K, search for **archive workspace**. Follow `workspace` above. |
| `SEARCH_CREATEWS_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_PICK_REPO_BACK_OFFSET` | Open the named submenu, then choose **back**. Follow `workspace` above. |
| `SEARCH_PICK_REPO_OFFSET` | Ctrl+K, type **pick repo**, then select the matching action with Up/Down and Enter. Follow `workspace` above. |
| `SEARCH_PICK_REPO_ROW_OFFSET` | Open **Pick repo** or **Set workspace folder**, then select the displayed folder and its host. Follow `workspace` above. |
| `SEARCH_RENAMEWIN_OFFSET` | Ctrl+K, search for **rename workspace**. Follow `workspace` above. |
| `SEARCH_SET_FOLDER_OFFSET` | Ctrl+K, type **set workspace folder**, then select the matching action with Up/Down and Enter. Follow `workspace` above. |
| `SEARCH_TABCTX_MOVE_NEW_WS` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_TABCTX_WSMOVE` | Right-click the intended tab, then choose **Move to workspace**. Follow `workspace` above. |
| `SEARCH_WORKSPACES_MENU_OFFSET` | Ctrl+K, search for **open workspace**. Follow `workspace` above. |
| `SEARCH_WORKSPACE_ARCHIVED_MENU_OFFSET` | Ctrl+K, search for **archived workspaces**. Follow `workspace` above. |
| `SEARCH_WORKSPACE_BACK_OFFSET` | Open the named submenu, then choose **Back from workspace list**. Follow `workspace` above. |
| `SEARCH_WORKSPACE_COLOR_OFFSET` | Ctrl+K, type **workspace color**, then select the matching action with Up/Down and Enter. Follow `workspace` above. |
| `SEARCH_WORKSPACE_DELETE_MENU_OFFSET` | Ctrl+K, search for **delete workspace**. Follow `workspace` above. |
| `SEARCH_WORKSPACE_DELETE_OFFSET` | Open **Delete workspace**, then select the disposable archived workspace name and confirm a second time. Follow `workspace` above. |
| `SEARCH_NEWWIN_OFFSET` | Ctrl+K, search for **new workspace window**, to open the workspace in its own top-level window. Follow `workspace` above. |
| `SEARCH_WORKSPACE_OFFSET` | Open Ctrl+K **Open workspace**, then select the displayed workspace name. Follow `workspace` above. |
| `SEARCH_WSMOVE_NEW_OFFSET` | Ctrl+K, search for **move to new workspace**. Follow `workspace` above. |
| `SEARCH_WSMOVE_MENU_OFFSET` | Ctrl+K, search for **move to workspace**. Follow `workspace` above. |
| `SEARCH_WSMOVE_OFFSET` | Choose **Move to workspace**, then select its destination name. Follow `workspace` above. |
| `SEARCH_WSSORT_MENU_OFFSET` | Ctrl+K, search for **sort workspaces**. Follow `workspace` above. |
| `SEARCH_WSSORT_OFFSET` | Open **Sort workspaces**, then choose the displayed sort mode. Follow `workspace` above. |

### room: Rooms

In a release or Rooms-enabled verification build, use Ctrl+Shift+N or Ctrl+K New room. Choose members, create and open the room by name, send a message, then Edit room to rename and change members. Reopen and inspect both agents' replies.

Observable proof: The room keeps one ID and the selected members; replies are attributed once to the right agent. Editing preserves earlier history and prevents private per-chat actions from leaking into a room.

Run `feature=rooms` for the desktop gate in [Rooms](rooms.md), including fresh creation, closed-chat membership and away/restart recovery. Release builds enable Rooms; non-release verification builds need `-Drooms-preview=true`. The room-reply-grouping diagnostic alone is not desktop proof.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_ROOM_ROW_OFFSET` | In a Rooms preview build, search Ctrl+K for the room's name. Follow `room` above. |
| `room.edit_room_target` | In the Rooms preview build, Ctrl+K, choose **Edit room**. Follow `room` above. |
| `room.new_room_target` | In the Rooms preview build, Ctrl+K, choose **New room**. Follow `room` above. |

## Gotchas
- The member catalog comes from the host, including unopened chats. Account names override server session names by host and tmux identity; closing a tab keeps its known name for the current account. The create path logs dialog opening, deferred discovery, each request kind, bridge spawn, reply counts and failures to `debug.log`. A missing failure line alone does not prove that the bridge never ran.
- Offline CMD workspace proof does not cover Rooms, sync, or remote agents. Room reply checks are [diagnostic](../diagnostics/room-reply-grouping.md), not a completed desktop journey.
- A chat that was already running when the app published its room helper loads that helper from the published runtime, so a send does not need the chat restarted. A host that still reports no room features is running an older helper; restart that chat.
