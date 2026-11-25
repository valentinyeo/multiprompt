# Sidebar sessions

Open, name, group, pin, reorder, archive, and delete sessions without losing their saved chat history.

Journeys: sessions, session-actions, session-tabs, favorites-groups, group-rail, bot-photo
Release paths: src/sidebar.zig, src/session*.zig, src/rename.zig, src/archive*.zig, src/favorites*.zig, src/main.zig, src/app_state.zig, build.zig

## Sub-features
- `open-select` opens a session and preserves its chosen server, folder, and view.
- `organize` names, favorites, pins, groups, and reorders sessions.
- `archive-delete-restore` distinguishes saved history from a running agent.

## How to get to it (user POV)
- Click a sidebar row or plus; Ctrl+T; Ctrl+Tab or Ctrl+1…9; F2; Alt+S; drag rows; right-click a tab or group; Ctrl+K All Sessions, Delete session, or New terminal.

## Driving it with drive.ps1
Preconditions: fresh hosted Windows desktop, matching executable/hash/version, isolated app data, and the selected legacy recipe’s prerequisites.
- The shared wrapper accepts these Journeys; automatic workflow migration remains partial. Run `gh workflow run verify.yml --ref <branch> -f feature=sessions`. [Sessions](sessions.md), [session actions](session-actions.md), and [session tabs](session-tabs.md) enumerate exact inputs and saved-tab assertions.
- Require selected shell identity, the selected recipe’s saved-tab assertions, screenshots, and actual owned-process closure for deletion. Only the selected journey is covered. Download `verify-sessions` after cleanup. This legacy workflow route does not yet use the video driver; see [inventory](../inventory.md).

The recipes distinguish existing focused journeys from unreachable complete paths. UNREACHABLE names the missing data, endpoint, build mode or driver action; it never means the product passed.

### select: Select and reopen sessions

Ctrl+Shift+1..5 are alternative shell-spawn shortcuts; each non-CMD choice needs its actual installed shell or Part B SSH/tmux configuration and an independent marker command. The existing CMD journey does not certify those alternatives.

Create two CMD tabs through Ctrl+K New CMD Shell. Select each through sidebar clicks, Ctrl+Tab, Ctrl+Shift+Tab and Ctrl+1..9. Close the selected shell with exit; reopen through Ctrl+Shift+T. Repeat in Part A's many-session profile.

Observable proof: The selected tab ID and native console HWND agree. A typed echo command writes a different marker file in each shell. Only the exited tab disappears; reopening does not duplicate another identity.

Journey: sessions, session-restore. Part A is required for the many-session variant; current two-tab proof is not real-size coverage.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_NEW_OFFSET` | Search Ctrl+K for CMD, PowerShell, Bash, Git Bash, or Open shell on VPS 1/2; select the exact shell row. The old tmux host1/host2 labels are not separate current root rows. Follow `select` above. |
| `SEARCH_REOPEN_OFFSET` | Ctrl+K, search for **reopen closed tab restore undo**. Follow `select` above. |
| `SEARCH_SHELLS_MENU_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `session row` | Ctrl+K, search for **Recent or matching session**. Follow `select` above. |

### identity: Names and chat identity

Select a disposable tab. F2 renames it, then restart the owned app and compare. Clear the manual name to resume automatic naming. Copy chat ID through Ctrl+K and from a selected Inbox row; compare with the receiving host identity, not the displayed title.

Observable proof: Manual name survives incoming console-title changes and restart. Clearing it restores automatic naming. Clipboard ID belongs to the selected chat; the inactive chat stays unchanged.

Journey: sessions, tab-names, session-actions. UNREACHABLE for dynamic remote names and Copy chat ID until Part B provides title events and the driver reads the clipboard for both sidebar and Inbox targets.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_SHELL_DIAG_OFFSET` | Ctrl+K, type **copy session diagnostics**, then select the matching action with Up/Down and Enter. Follow `identity` above. |
| `SEARCH_SYNC_NAME_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_TABCTX_COPY_ID` | Right-click the intended tab, then choose **Copy chat ID**. Follow `identity` above. |
| `SEARCH_RENAME_SYNC_OFFSET` | Ctrl+K, search for **rename session**. Follow `identity` above. |
| `SEARCH_TABCTX_RENAME` | Right-click the intended tab, then choose **Rename**. Follow `identity` above. |
| `SEARCH_THREADTITLE_OFFSET` | Ctrl+K, type **thread title**, then select the matching action with Up/Down and Enter. Follow `identity` above. |

### organize: Pin, star, move and group

Create three disposable tabs and two workspaces. Toggle favorite, pin, mute and keep-alive independently. Move with keyboard and multi-select drag; move into an existing and a new group, rename/color/collapse that group, then remove membership. Repeat grouping in Starred separately from the home workspace. On a disposable remote chat, open Bot face and Bot color, pick a built-in choice, upload a small synthetic PNG, then reset to the chosen face. Require the same remote identity, saved look and circular native photo after restart; bot-photo supplies this focused image journey.

Observable proof: Saved tab IDs are unchanged; workspace, home-group and Starred-group membership match screenshots. Pin order stays manual and Recents follows the last opened or sent-to chat. Reply-only activity never moves a row under the pointer.

Journey: favorites-groups, group-rail, session-tabs. UNREACHABLE for full multi-select drag and every group action until the driver records selected IDs, executes those native drag/menu paths and compares saved order. Existing grouping proof is narrower.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_ADDFAVICON_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_BOT_COLOR_OFFSET` | Open **Bot color** or **Workspace color**, then choose a displayed color or Auto. Follow `organize` above. |
| `SEARCH_BOT_FACE_OFFSET` | Right-click the remote chat, open **Bot face**, then choose a displayed face. Follow `organize` above. |
| `SEARCH_BOT_PHOTO_RESET` | Ctrl+K, search for **Reset to show your chosen face**. Follow `organize` above. |
| `SEARCH_BOT_PHOTO_UPLOAD` | Ctrl+K, search for **Upload image**. Follow `organize` above. |
| `SEARCH_FAVORITE_OFFSET` | Ctrl+K, type **favorite**, then select the matching action with Up/Down and Enter. Follow `organize` above. |
| `SEARCH_GROUPCTX_BASE` | Right-click a real group heading, then choose New tab, Rename, Collapse/Expand, Ungroup, Close tabs, a color, or a destination workspace. Each generated row uses this group recipe. Follow `organize` above. |
| `SEARCH_GROUPMOVE_BACK_OFFSET` | Open the named submenu, then choose **Back from Move to group**. Follow `organize` above. |
| `SEARCH_GROUPMOVE_GROUP_OFFSET` | Choose **Move to group**, then select an existing group name. Follow `organize` above. |
| `SEARCH_GROUPMOVE_MENU_OFFSET` | Ctrl+K, search for **move to group**. Follow `organize` above. |
| `SEARCH_GROUPMOVE_NEW_OFFSET` | Ctrl+K, search for **new group**. Follow `organize` above. |
| `SEARCH_GROUPMOVE_NONE_OFFSET` | Ctrl+K, search for **no group**. Follow `organize` above. |
| `SEARCH_KEEPALIVE_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_MUTETAB_OFFSET` | Ctrl+K, type **mute tab** or **unmute tab**, then select the matching action with Up/Down and Enter. Follow `organize` above. |
| `SEARCH_SHOW_FAVORITES_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_TABCTX_BOT_COLOR` | Right-click the intended tab, then choose **Bot color**. Follow `organize` above. |
| `SEARCH_TABCTX_BOT_FACE` | Right-click the intended tab, then choose **Bot face**. Follow `organize` above. |
| `SEARCH_TABCTX_CLEAR_SEL` | Right-click the intended tab, then choose **clear tab selection**. Follow `organize` above. |
| `SEARCH_TABCTX_FAVORITE` | Right-click the intended tab, then choose **Favorite / unfavorite**. Follow `organize` above. |
| `SEARCH_TABCTX_GROUP_ADD_OFFSET` | Right-click the selected disposable tabs, then choose the destination group name. Follow `organize` above. |
| `SEARCH_TABCTX_GROUP_NEW` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_TABCTX_GROUP_NEW_TAB_IN` | Right-click the intended tab, then choose **new chat in this group**. Follow `organize` above. |
| `SEARCH_TABCTX_GROUP_REMOVE` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_TABCTX_KEEPALIVE` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_TABCTX_MUTE` | Right-click the intended tab, then choose **Mute Tab / Unmute Tab**. Follow `organize` above. |
| `SEARCH_PIN_TOP_OFFSET` | Ctrl+K, search for **pin tab to top**. Follow `organize` above. |
| `SEARCH_TABCTX_PIN_TOP` | Right-click the intended tab, then choose **Pin to Top / Unpin from Top**. Follow `organize` above. |
| `SEARCH_TABSORT_INBOX_OFFSET` | Ctrl+K, search for **tab order**. Follow `organize` above. |
| `SEARCH_TABSORT_MANUAL_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |

### close: Waiting, archive, remove and delete

Use only disposable Part B sessions. Move a chat to Waiting and undo it; archive and restore it. Delete a different session through its palette action and Ctrl+Shift+W. Close disconnected sessions while another session remains live. Test pin protection before group close/archive.

Observable proof: Waiting hides a row without ending its host. Archive persists identity and kills its tmux carrier; it does not pass the explicit provider-stop identity used by Delete. Do not promise a still-running carrier after archive. Delete ends the selected host once but leaves its history readable. Closing disconnected tabs keeps live identities and selection. No other agent is stopped.

Journey: session-actions; focused reconnect maps cover disconnect boundaries. UNREACHABLE for real process termination until Part B supplies independent tmux/process receipts. Stand-in end commands alone do not prove a real agent stopped.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_ARCHIVE_OFFSET` | Ctrl+K, search for **archive session**. Follow `close` above. |
| `SEARCH_CLOSE_DISCONNECTED_OFFSET` | Ctrl+K, search for **Close all disconnected sessions**. Follow `close` above. |
| `SEARCH_CLOSETAB_OFFSET` | Ctrl+K, search for **close tab**. Follow `close` above. |
| `SEARCH_END_TMUX_OFFSET` | Ctrl+K, search for **end tmux session**. Follow `close` above. |
| `SEARCH_TABCTX_ARCHIVE` | Right-click the intended tab, then choose **Archive / close session**. Follow `close` above. |
| `SEARCH_TABCTX_CLOSE_DISCONNECTED` | Right-click the intended tab, then choose **Close all disconnected sessions**. Follow `close` above. |
| `SEARCH_TABCTX_END_TMUX` | Right-click the intended tab, then choose **Delete session**. Follow `close` above. |
| `SEARCH_TABCTX_HIDE` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |

### overview: All Sessions and remote discovery

Open Ctrl+K All Sessions. Filter by text and switch Waiting, Archived and unattached states. Mark one unattached session with Space; x opens confirmation. Cancel, then repeat and confirm only the disposable marked session. Restore Waiting or disconnected sessions through their named rows.

Observable proof: The list, counts and copied chat IDs match Part B's host inventory. Cancel changes no host; confirm removes only marked targets. Restoration reuses the same ID and does not duplicate tabs.

UNREACHABLE until Part B supplies multiple live, waiting, archived and unattached identities and a native All Sessions filter/mark/confirm recipe. session-open only proves bridge requests and failed SSH, not this list.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_ARCHIVED_OFFSET` | UNREACHABLE since SOFT-2444: Ctrl+K lists active sessions only and nothing appends these rows. Use `SEARCH_ARCHIVED_VIEW_OFFSET` and the All Sessions Archived tab instead. |
| `SEARCH_ARCHIVED_VIEW_OFFSET` | Ctrl+K, search for **archived sessions**. Follow `overview` above. |
| `SEARCH_REOPEN_SERVER_SHELL_OFFSET` | On a server tab, Ctrl+K, search for **reopen server shell**, then pick one of the detached sessions it lists for that server. Attaching the same session twice is a no-op. Follow `overview` above. |
| `SEARCH_SESSION_OVERVIEW_MENU_OFFSET` | Ctrl+K, search for **show all sessions**. Follow `overview` above. |
| `SEARCH_SESSION_OVERVIEW_ROW_OFFSET` | Open **All Sessions**, filter if needed, then select the displayed session row. Follow `overview` above. |
| `SEARCH_UNARCHIVE_HIDDEN_OFFSET` | Ctrl+K, type **restore waiting**, then select the matching action with Up/Down and Enter. Follow `overview` above. |
| `SEARCH_UNARCHIVE_UNATTACHED_OFFSET` | Ctrl+K, type **restore unattached**, then select the matching action with Up/Down and Enter. Follow `overview` above. |

### Architecture feature crosswalk

Every user-facing item in `openwiki/architecture/features.md` has an owning recipe below. Architecture and footprint targets are descriptions, not measured acceptance results.

| Architecture item | Feature recipe and proof boundary |
| --- | --- |
| `architecture:Zig Win32 app` | [Select](sidebar-sessions.md#select-select-and-reopen-sessions): native owned app HWND, not a browser-rendered terminal. |
| `architecture:Left sidebar` | [Organize](sidebar-sessions.md#organize-pin-star-move-and-group): visible tab identities and ordering. |
| `architecture:Right pane` | [Select](sidebar-sessions.md#select-select-and-reopen-sessions): genuine child console HWND and marker output. |
| `architecture:No terminal rendering` | [Select](sidebar-sessions.md#select-select-and-reopen-sessions): native console output; renderer architecture is not a separate clickable feature. |
| `architecture:Drag to reorder` | [Organize](sidebar-sessions.md#organize-pin-star-move-and-group): saved order after native dragging; missing drag assertions remain unreachable. |
| `architecture:Each tab click` | [Select](sidebar-sessions.md#select-select-and-reopen-sessions): selected tab and owned visible console agree. |
| `architecture:Sidebar mini-inbox` | [Organize](sidebar-sessions.md#organize-pin-star-move-and-group) and [attention](notifications-inbox.md#attention-activity-and-notifications): Pinned/Recents, glyphs, spinner and unread behavior. |
| `architecture:Tmux adoption` | Start tmux in a plain Part B SSH tab, wait for watcher adoption, restart, then detach and wait for reversion. Require saved host/session/name and genuine attach command. UNREACHABLE until Part B supplies the real watcher, attach/detach controls and a native adoption/reversion journey; fixed waits alone are not proof. |
| `architecture:Dynamic tab naming` | [Identity](sidebar-sessions.md#identity-names-and-chat-identity): terminal title updates, sticky manual rename, clear-to-auto and restart. |
| `architecture:Activity spinner` | [Attention](notifications-inbox.md#attention-activity-and-notifications): actual output/stop events; do not confuse the sidebar spinner with the chat's three working dots. |
| `architecture:Needs-input dot` | [Attention](notifications-inbox.md#attention-activity-and-notifications): inactive-only attention and clearing on open. The historical ten-second statement needs actual activity/notification receipts, not manual unread toggling. |
| `architecture:Notifications` | [Attention](notifications-inbox.md#attention-activity-and-notifications): notify through the owned listener; do not assume fixed port 19547 is free or sufficient for all transports. |
| `architecture:Multi-instance` | [Restore](relaunch-update.md#restore-restore-instances-and-reconnect): --name titles and separate session-{name}.json; the second-owned-instance driver is a named missing prerequisite. |
| `architecture:Auto-close tabs` | [Select](sidebar-sessions.md#select-select-and-reopen-sessions): exit a real local shell and require only its tab to disappear. |
| `architecture:Cross-workspace Inbox` | [Inbox](notifications-inbox.md#inbox-inbox-navigation-and-triage): filter, split, ordering, unread/archive/undo and selected row identity. Cross-window aggregation is separately unreachable without a second owned instance. |
| `architecture:Favorites groups` | [Organize](sidebar-sessions.md#organize-pin-star-move-and-group): independent Starred/home groups, including muted favorites. |
| `architecture:Recents header` | [Organize](sidebar-sessions.md#organize-pin-star-move-and-group): ungrouped sessions below real groups, with stable activity-only ordering. |
| `architecture:Chat unread boundary` | [Read](chat-and-composer.md#read-read-find-select-and-copy): leave before tail, receive another message, reopen and require one NEW rule at the first unread ID. Read to bottom or send to clear. UNREACHABLE for real reconnect/account-resync persistence until Part B plus authenticated sync and native anchor-loss assertions are supplied; chat-messages-only has a synthetic retained-anchor case. |
| `architecture:Footprint telemetry` | [Usage](settings-appearance.md#usage-usage-eta-and-power): hover own app/descendant memory, CPU and process counts; compare footprint.json's running-version peak. Current status-card geometry proof does not validate these live totals. |
| `architecture:Close All Browser Panes` | [Browser lifecycle](browser-pane.md#browser-life-browser-lifecycle-and-agent-bridge): every owned pane closes, saved URLs remain, dedicated-profile descendants end after the grace period. |
| `architecture:Bookmarkable shell configs` | UNREACHABLE: listed as Future Features; the document supplies no shipped bookmark URL entry point or implementation to drive. Do not invent one. |
| `architecture:Tray icon for background operation` | UNREACHABLE: listed as Future Features; no shipped tray-icon entry point is established by this source pass. Window minimize is not tray support. |
| `architecture:Target Footprint` | [Usage](settings-appearance.md#usage-usage-eta-and-power) exposes actual telemetry. The document's RAM table is a design target, not measured proof or a user action. No speed or memory claim is made here. |

## Gotchas
- Remote creation needs a configured host and repo. The sessions journey replaces SSH at its documented boundary, not a live agent.
