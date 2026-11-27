# Keyboard shortcuts

Reach the same session, workspace, chat, browser, and window actions without the mouse.

Journeys: chat-focus, workspace-focus
Release paths: src/shortcuts.zig, src/focus.zig, src/key*.zig, src/main.zig, build.zig

## Sub-features
- `reference` opens the keyboard shortcut list.
- `selection` routes session and workspace chords to the expected target.
- `surface-focus` restores chat, shell, browser, or window input.

## How to get to it (user POV)
- Open Ctrl+K Keyboard Shortcuts; use Ctrl+Tab, Ctrl+1…9, Alt+1…9, Alt+Left/Right, Ctrl+Shift+B, Ctrl+Shift+F, Alt+C, Alt+Q, Alt+M, or Win+Arrows on the appropriate surface.

## Driving it with drive.ps1
Preconditions: fresh hosted Windows desktop, matching executable/hash/version, isolated app data, and the selected legacy recipe’s prerequisites.
- The shared wrapper accepts these Journeys; automatic workflow migration remains partial. Run `gh workflow run verify.yml --ref <branch> -f feature=workspace-focus`. [Workspace focus](workspace-focus.md) and [chat focus](chat-focus.md) pair actual key chords with native draft/shell reads.
- Require the expected selected workspace/session and exact typed text after each chord, plus action/result screenshots. Only the selected journey is covered. Download `verify-workspace-focus` after cleanup. This legacy workflow route does not yet use the video driver; see [inventory](../inventory.md).

The recipes distinguish existing focused journeys from unreachable complete paths. UNREACHABLE names the missing data, endpoint, build mode or driver action; it never means the product passed.

### shortcuts: Shortcut reference and routing

Press F1 or Ctrl+K Keyboard Shortcuts. Inspect each section and dismiss. Use the exact keys in the table on the stated surface, then repeat from the owned browser where passthrough differs. Test window-menu/snap keys only on the owned app.

Observable proof: The shortcut overlay includes each SHORTCUT_ROWS heading and action. Every driven chord selects or changes its intended surface once, and typing remains correct afterward. Browser Ctrl+C/Ctrl+V/Ctrl+K stays with the page; Ctrl+Shift+K opens the app palette.

Journey: workspace-focus, chat-focus, pane-layout. UNREACHABLE for complete F1/routing proof until the desktop driver captures the overlay, scrolls every row and exercises browser passthrough; existing focus journeys cover only their named chords.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_SHORTCUTS_OFFSET` | Ctrl+K, type **keyboard shortcuts**, then select the matching action with Up/Down and Enter. Follow `shortcuts` above. |

### Every SHORTCUT_ROWS entry

Headers are verified in F1. Action rows link to the owning user-operation recipe; they do not inherit full coverage from a focus journey.

| Source section | Keys or control | Action | Feature recipe |
| --- | --- | --- | --- |
| Tabs | Tabs | F1 section heading | [shortcuts](shortcuts.md#shortcuts-shortcut-reference-and-routing) |
| Tabs | Alt+S | Favorite or unfavorite this session | [organize](sidebar-sessions.md#organize-pin-star-move-and-group) |
| Tabs | Ctrl+Tab / Ctrl+Shift+Tab | Next / previous tab | [select](sidebar-sessions.md#select-select-and-reopen-sessions) |
| Tabs | Ctrl+1 ... 9 | Open session 1-9 in this workspace, pinned first | [select](sidebar-sessions.md#select-select-and-reopen-sessions) |
| Tabs | Ctrl+Shift+W | Delete the current session; stop its agent and keep its history | [close](sidebar-sessions.md#close-waiting-archive-remove-and-delete) |
| Tabs | Ctrl+K -&gt; Delete session | Delete the current session; stop its agent and keep its history | [close](sidebar-sessions.md#close-waiting-archive-remove-and-delete) |
| Tabs | Ctrl+K -&gt; Quit multi bot | Quit the app; keep server agents and saved chats | [update](relaunch-update.md#update-quit-update-and-diagnostics) |
| Tabs | Ctrl+K -&gt; Copy chat ID | Copy the chosen chat identity | [identity](sidebar-sessions.md#identity-names-and-chat-identity) |
| Tabs | Ctrl+Shift+U | Toggle unread-only filter (sidebar + inbox) | [inbox](notifications-inbox.md#inbox-inbox-navigation-and-triage) |
| Tabs | Alt+U | Mark active session unread / restore blue dot | [inbox](notifications-inbox.md#inbox-inbox-navigation-and-triage) |
| Tabs | Ctrl+K -&gt; Inbox: Never Show This Session | Toggle permanent Inbox exclusion for this tab (also right-click tab) | [inbox](notifications-inbox.md#inbox-inbox-navigation-and-triage) |
| Tabs | Alt+J / Alt+K | Next / previous Inbox session, or workspace (including Starred) outside Inbox context | [inbox](notifications-inbox.md#inbox-inbox-navigation-and-triage) |
| Tabs | Ctrl+Shift+Up / Down | Move active tab up / down | [organize](sidebar-sessions.md#organize-pin-star-move-and-group) |
| Tabs | Ctrl+G | Collapse / expand tab group | [organize](sidebar-sessions.md#organize-pin-star-move-and-group) |
| Tabs | Alt+; / Ctrl+; | Use snippets | [snippets](snippets-commands.md#snippets-snippets-and-custom-commands) |
| Tabs | Ctrl+K -&gt; Create Snippet | Save a named paste block | [snippets](snippets-commands.md#snippets-snippets-and-custom-commands) |
| Tabs | Delete twice in snippets | Delete the selected saved snippet | [snippets](snippets-commands.md#snippets-snippets-and-custom-commands) |
| Tabs | F2 | Rename chat title, tab or selected Inbox session | [identity](sidebar-sessions.md#identity-names-and-chat-identity) |
| Workspaces (single-window) | Workspaces (single-window) | F1 section heading | [shortcuts](shortcuts.md#shortcuts-shortcut-reference-and-routing) |
| Workspaces (single-window) | Alt+1 | Go to Starred workspace | [workspace](workspaces-rooms.md#workspace-workspace-lifecycle) |
| Workspaces (single-window) | Alt+1 ... 9 | Switch workspace: 1 is Starred, 2-9 are stored workspaces | [workspace](workspaces-rooms.md#workspace-workspace-lifecycle) |
| Workspaces (single-window) | Ctrl+K -&gt; Archive workspace | Hide a workspace without deleting its server sessions | [workspace](workspaces-rooms.md#workspace-workspace-lifecycle) |
| Workspaces (single-window) | Ctrl+K -&gt; Archived workspaces | Pick an archived workspace to restore its sessions | [workspace](workspaces-rooms.md#workspace-workspace-lifecycle) |
| Workspaces (single-window) | Ctrl+K -&gt; Delete workspace | Delete an archived workspace; press Enter again to confirm | [workspace](workspaces-rooms.md#workspace-workspace-lifecycle) |
| Workspaces (single-window) | Right-click workspace pill -&gt; Archive workspace | Archive that workspace; Other stays available | [workspace](workspaces-rooms.md#workspace-workspace-lifecycle) |
| Workspaces (single-window) | Ctrl+Shift+Y | Snooze this workspace until a chosen time | [snooze](notifications-inbox.md#snooze-reminders-and-workspace-snooze) |
| Workspaces (single-window) | Ctrl+K -&gt; Workspace: Wake &lt;name&gt; | Wake a snoozed workspace now and switch to it | [snooze](notifications-inbox.md#snooze-reminders-and-workspace-snooze) |
| Workspaces (single-window) | Ctrl+K -&gt; Workspace: Bring Back All Sessions | Reopen every recorded tmux session of this workspace | [snooze](notifications-inbox.md#snooze-reminders-and-workspace-snooze) |
| Workspaces (single-window) | Ctrl+K -&gt; Workspace: Switch every chat to Antigravity (Codex, Claude) | Move every live chat in this workspace to another AI, keeping each chat's name, picture, place and readable history | [switch-ai](workspaces-rooms.md#switch-ai-switch-every-chat-in-a-workspace) |
| Workspaces (single-window) | Alt+Left / Alt+Right | Cycle prev / next workspace | [workspace](workspaces-rooms.md#workspace-workspace-lifecycle) |
| Workspaces (single-window) | Ctrl+N / Alt+N pill | New workspace | [workspace](workspaces-rooms.md#workspace-workspace-lifecycle) |
| Inbox (Alt+I) | Inbox (Alt+I) | F1 section heading | [shortcuts](shortcuts.md#shortcuts-shortcut-reference-and-routing) |
| Inbox (Alt+I) | Sidebar inbox button | Click to open; Ctrl+Shift+I toggles; Alt+I opens / selects All | [inbox](notifications-inbox.md#inbox-inbox-navigation-and-triage) |
| Inbox (Alt+I) | Ctrl+F or / | Reduce Inbox to matching sessions | [inbox](notifications-inbox.md#inbox-inbox-navigation-and-triage) |
| Inbox (Alt+I) | j/k or Alt+J/K  gg/G or Alt+G Alt+G / Alt+Shift+G  1-9 | Move / top / bottom / jump row | [inbox](notifications-inbox.md#inbox-inbox-navigation-and-triage) |
| Inbox (Alt+I) | Tab / h / l | Switch workspace split | [inbox](notifications-inbox.md#inbox-inbox-navigation-and-triage) |
| Inbox (Alt+I) | e or Alt+E / z or Alt+Z / u | Archive / undo archive / toggle read-unread | [inbox](notifications-inbox.md#inbox-inbox-navigation-and-triage) |
| Inbox (Alt+I) | Ctrl+K -&gt; Copy chat ID | Copy the chosen chat identity | [inbox](notifications-inbox.md#inbox-inbox-navigation-and-triage) |
| Inbox (Alt+I) | Ctrl+Shift+U | Toggle unread-only filter (global) | [inbox](notifications-inbox.md#inbox-inbox-navigation-and-triage) |
| Inbox (Alt+I) | Alt+I (inside) | Jump back to ALL split | [inbox](notifications-inbox.md#inbox-inbox-navigation-and-triage) |
| Inbox (Alt+I) | q / Esc | Close Inbox | [inbox](notifications-inbox.md#inbox-inbox-navigation-and-triage) |
| View | View | F1 section heading | [shortcuts](shortcuts.md#shortcuts-shortcut-reference-and-routing) |
| View | Ctrl+K -&gt; Computer: Take control / Give back | Control Computer or return to watching | [computer](computer-pane.md#computer-computer-viewing-and-control) |
| View | Ctrl+K -&gt; Computer: Retry | Retry a lost Computer connection | [computer](computer-pane.md#computer-computer-viewing-and-control) |
| View | Ctrl+Shift+F | Toggle full-width (fullscreen) | [look](settings-appearance.md#look-theme-size-and-window-layout) |
| View | Ctrl+Shift+B | Cycle sidebar: open / collapsed / hidden | [look](settings-appearance.md#look-theme-size-and-window-layout) |
| View | multiprompt-browser sidebar | Reveal the sidebar from a shell | [look](settings-appearance.md#look-theme-size-and-window-layout) |
| View | Ctrl+K Thread Title | [DEV] Subject header above the console (toggle) | [look](settings-appearance.md#look-theme-size-and-window-layout) |
| View | Ctrl++ / Ctrl+- / Ctrl+0 | Terminal font only (Chat View text size when Chat View is active) | [look](settings-appearance.md#look-theme-size-and-window-layout) |
| View | Ctrl+K UI Size | App/sidebar only, layered over native monitor DPI | [look](settings-appearance.md#look-theme-size-and-window-layout) |
| View | Ctrl+Shift+R | Reattach active SSH/tmux tab | [restore](relaunch-update.md#restore-restore-instances-and-reconnect) |
| View | Ctrl+K -&gt; New session in this group | Start a Claude session in the tab's group straight away, in the terminal | [organize](sidebar-sessions.md#organize-pin-star-move-and-group) |
| View | Ctrl+K -&gt; All Sessions | Open session overview (w = Waiting, a = Archived, u = unattached) | [overview](sidebar-sessions.md#overview-all-sessions-and-remote-discovery) |
| View | Ctrl+F in All Sessions | Reduce the list to matching sessions | [overview](sidebar-sessions.md#overview-all-sessions-and-remote-discovery) |
| View | Space in All Sessions | Mark or unmark the selected unattached session | [overview](sidebar-sessions.md#overview-all-sessions-and-remote-discovery) |
| View | x in All Sessions | Close the marked unattached sessions, or the selected one, after a confirmation | [overview](sidebar-sessions.md#overview-all-sessions-and-remote-discovery) |
| View | Alt+E | Move active tab to Waiting until it gets a blue dot | [close](sidebar-sessions.md#close-waiting-archive-remove-and-delete) |
| View | Alt+Z | Undo the most recent move to Waiting | [close](sidebar-sessions.md#close-waiting-archive-remove-and-delete) |
| View | Ctrl+K -&gt; Restore Waiting | Restore waiting live sessions in this workspace | [overview](sidebar-sessions.md#overview-all-sessions-and-remote-discovery) |
| View | Ctrl+D in Chat View | Start/stop dictation; Enter stops recording into the composer; Escape discards the recording | [voice](voice-dictation.md#voice-voice-and-dictation) |
| View | Ctrl+Shift+Space / Enter | Start/stop dictation; Enter is stop-only while recording; Escape discards the recording | [voice](voice-dictation.md#voice-voice-and-dictation) |
| Spawn / Windows | Spawn / Windows | F1 section heading | [shortcuts](shortcuts.md#shortcuts-shortcut-reference-and-routing) |
| Spawn / Windows | Ctrl+Shift+1 ... 5 | New CMD / TMUX / VPS / PowerShell | [select](sidebar-sessions.md#select-select-and-reopen-sessions) |
| Spawn / Windows | Ctrl+N | New Multi Bot window | [restore](relaunch-update.md#restore-restore-instances-and-reconnect) |
| Spawn / Windows | Ctrl+Shift+T | Reopen last closed tab | [restore](relaunch-update.md#restore-restore-instances-and-reconnect) |
| Spawn / Windows | Alt+Space | Window menu (move/size/min/max) | [look](settings-appearance.md#look-theme-size-and-window-layout) |
| Spawn / Windows | Win+Arrows | Snap / maximize / minimize (edge-snapped Left/Right hops monitors) | [look](settings-appearance.md#look-theme-size-and-window-layout) |
| Spawn / Windows | Win+Shift+Left/Right | Move window to the adjacent monitor | [look](settings-appearance.md#look-theme-size-and-window-layout) |
| Palette / Actions | Palette / Actions | F1 section heading | [shortcuts](shortcuts.md#shortcuts-shortcut-reference-and-routing) |
| Palette / Actions | Ctrl+K | Open command palette; it opens with your last 5 sessions | [palette](palette.md#palette-find-and-execute-actions) |
| Palette / Actions | Ctrl+Shift+N | Create a Room | [room](workspaces-rooms.md#room-rooms) |
| Palette / Actions | Ctrl+K -&gt; New room | Create a Room | [room](workspaces-rooms.md#room-rooms) |
| Palette / Actions | Ctrl+K -&gt; Room name | Open a Room | [room](workspaces-rooms.md#room-rooms) |
| Palette / Actions | Ctrl+K -&gt; Edit room | Edit the selected Room | [room](workspaces-rooms.md#room-rooms) |
| Palette / Actions | Ctrl+K -&gt; Account: Sign Out | Forget this device login and lock Multi Bot | [account](account-sync.md#account-account-devices-and-servers) |
| Palette / Actions | Ctrl+K -&gt; Account: Devices | List account devices and revoke a device | [account](account-sync.md#account-account-devices-and-servers) |
| Palette / Actions | Ctrl+Shift+K | Open command palette from any Multi Bot surface, including browser | [palette](palette.md#palette-find-and-execute-actions) |
| Palette / Actions | Ctrl+K → Usage: Sign In to Claude | Force sign-in one telemetry profile in its own terminal | [usage](settings-appearance.md#usage-usage-eta-and-power) |
| Palette / Actions | Ctrl+K → Power Saver | Cycle when background timers, VPS polling, and idle tabs slow down to save power: Auto, Always, Off | [usage](settings-appearance.md#usage-usage-eta-and-power) |
| Palette / Actions | Ctrl+Shift+G | Show usage, servers, and app version. Cycle collapsed cards. | [usage](settings-appearance.md#usage-usage-eta-and-power) |
| Palette / Actions | Ctrl+K -&gt; Usage and servers / collapsed status cards | Show usage, servers, and app version. Cycle collapsed cards. | [usage](settings-appearance.md#usage-usage-eta-and-power) |
| Palette / Actions | Alt+T | New workspace tmux tab, Claude by default (optional configured program) | [server](server-chats.md#server-real-server-chat-creation) |
| Palette / Actions | Ctrl+T | New Claude live chat in this workspace folder (also Alt+T outside the palette and the sidebar plus) | [server](server-chats.md#server-real-server-chat-creation) |
| Palette / Actions | Ctrl+K -&gt; New Claude session | Start a Claude live chat in this workspace folder; same as Ctrl+T and the sidebar plus | [server](server-chats.md#server-real-server-chat-creation) |
| Palette / Actions | Ctrl+K -&gt; New Codex chat | Start a Codex live chat in this workspace folder, same chat view as Claude | [server](server-chats.md#server-real-server-chat-creation) |
| Palette / Actions | Ctrl+K -&gt; New Pi chat | Start a Pi live chat in this workspace folder, same chat view as Claude | [server](server-chats.md#server-real-server-chat-creation) |
| Palette / Actions | /login in a Pi chat | Log in to a Pi provider. Pi shows its own prompts and links in the chat, and the next reply uses that login | [skills](chat-and-composer.md#skills-commands-skills-model-and-permissions) |
| Palette / Actions | Ctrl+K -&gt; Log in | Log in to a Pi provider from this Pi chat. Same as /login | [skills](chat-and-composer.md#skills-commands-skills-model-and-permissions) |
| Palette / Actions | Ctrl+K -&gt; New Cursor chat | Start a Cursor CLI live chat in this workspace folder, same chat view as Claude | [server](server-chats.md#server-real-server-chat-creation) |
| Palette / Actions | Ctrl+K -&gt; New terminal | Open a plain tmux tab in this workspace folder, no agent | [server](server-chats.md#server-real-server-chat-creation) |
| Palette / Actions | Ctrl+K -&gt; Pick repo | Choose the repo this workspace starts new tabs in, when it has no folder yet | [workspace](workspaces-rooms.md#workspace-workspace-lifecycle) |
| Palette / Actions | Ctrl+K -&gt; Set workspace folder | Declare this workspace folder from the repo list; saved for next time | [workspace](workspaces-rooms.md#workspace-workspace-lifecycle) |
| Palette / Actions | Ctrl+K Remind Me | Snooze active tmux/Claude tab via quick presets (or type a time) | [snooze](notifications-inbox.md#snooze-reminders-and-workspace-snooze) |
| Palette / Actions | Ctrl+H | Remind Me: pick In 1, 2, 3, 6 or 12 hours, This evening, Tomorrow morning or evening, and more | [snooze](notifications-inbox.md#snooze-reminders-and-workspace-snooze) |
| Palette / Actions | Alt+H | Remind Me: hide local tab, keep tmux running, return when due | [snooze](notifications-inbox.md#snooze-reminders-and-workspace-snooze) |
| Palette / Actions | Ctrl+K Reminders | View / restore snoozed sessions | [snooze](notifications-inbox.md#snooze-reminders-and-workspace-snooze) |
| Palette / Actions | Ctrl+V (in Ctrl+K) | Paste into the palette search | [palette](palette.md#palette-find-and-execute-actions) |
| Palette / Actions | Browser pane focused | Ctrl+C / Ctrl+V / Ctrl+K pass through to the page | [browser-nav](browser-pane.md#browser-nav-browser-navigation-and-focus) |
| Palette / Actions | Ctrl+K / right-click tab -&gt; Pin to Top | Pins keep sessions above other tabs. Closing unpins them. Archiving and group closing remain protected. | [organize](sidebar-sessions.md#organize-pin-star-move-and-group) |
| Palette / Actions | Ctrl+K / right-click tab -&gt; Close all disconnected sessions | Close disconnected sessions, including pinned sessions. Keep live sessions. | [close](sidebar-sessions.md#close-waiting-archive-remove-and-delete) |
| Palette / Actions | Ctrl / Shift+click tabs, then drag | Select tabs and move them together | [organize](sidebar-sessions.md#organize-pin-star-move-and-group) |
| Palette / Actions | Drag tab onto a group | Move it there without changing pin state | [organize](sidebar-sessions.md#organize-pin-star-move-and-group) |
| Palette / Actions | Drag tab: Pinned / Recents | Pinned keeps your drag order; Recents follows the chat you opened or sent to last | [organize](sidebar-sessions.md#organize-pin-star-move-and-group) |
| Palette / Actions | Click tier heading | Collapse / expand ungrouped Pinned or Recents | [organize](sidebar-sessions.md#organize-pin-star-move-and-group) |
| Palette / Actions | Right-click group / Ctrl+K | Group: new tab, rename, color, collapse / expand, move workspace, ungroup, close all tabs | [organize](sidebar-sessions.md#organize-pin-star-move-and-group) |
| Palette / Actions | Right-click tab | Tab actions palette (pin / reattach / mute / close / move / group) | [organize](sidebar-sessions.md#organize-pin-star-move-and-group) |
| Palette / Actions | Ctrl+K / right-click tab → Bot face / Bot color | Remote faces, colors and pictures sync. | [organize](sidebar-sessions.md#organize-pin-star-move-and-group) |
| Palette / Actions | Ctrl+K -&gt; Workspace color | Choose a workspace default color or Auto. Manual bot colors stay unchanged. | [workspace](workspaces-rooms.md#workspace-workspace-lifecycle) |
| Palette / Actions | Ctrl+F in Chat View | Chat View: Find in conversation; Enter / F3 next, Shift+Enter / Shift+F3 previous, Esc closes | [read](chat-and-composer.md#read-read-find-select-and-copy) |
| Palette / Actions | Shift+G twice / End / Ctrl+K "Jump to newest message" | Chat View: jump to the newest message; capital GG works only from an empty message box with two Shift+G presses within 600 ms and leaves the box empty; also the round down-arrow button above the message box that shows when you are scrolled up; Page Up / Page Down / Home scroll, the thin scrollbar on the right drags, the mouse wheel moves about 3 lines per notch | [long](long-session-chat.md#long-long-session-chat) |
| Palette / Actions | Double-click empty space | Switch between Chat View and the shell (without selecting text) | [read](chat-and-composer.md#read-read-find-select-and-copy) |
| Palette / Actions | Alt+C | Switch terminal tabs between the shell and the chat view; off for live chats, which have no terminal; also the Ctrl+K row and the tab menu for terminal tabs | [read](chat-and-composer.md#read-read-find-select-and-copy) |
| Palette / Actions | Ctrl+K -&gt; Switch to chat view / Switch to shell | Show a terminal tab as the chat view or the shell; hidden for live chats; same as Alt+C and the right-click tab menu | [read](chat-and-composer.md#read-read-find-select-and-copy) |
| Palette / Actions | + button / Ctrl+V in Chat View | Attach files and images: pick, drop, or paste; images become links, other files go to the server session and their path goes in at the caret (Ctrl+K Chat View: Attach File) | [attach](chat-and-composer.md#attach-attach-paste-and-upload) |
| Palette / Actions | Right-click Claude message / Ctrl+K reactions | Send a quoted reaction; show its badge | [quote](chat-and-composer.md#quote-quotes-reactions-and-presentation) |
| Palette / Actions | Right-click message → Reply / Ctrl+K "Chat View: Reply to latest agent message" | Quote a message. Click × to remove it. Escape cancels quotes when the draft is empty. | [quote](chat-and-composer.md#quote-quotes-reactions-and-presentation) |
| Palette / Actions | Ctrl+K "Chat View: Open or fold all tool steps" | Open every tool step's details, or fold them all; click one tool line to toggle it | [quote](chat-and-composer.md#quote-quotes-reactions-and-presentation) |
| Palette / Actions | Ctrl+K "Chat View: Toggle todo list" | Show or hide this tab's agent todo list below the title; also click the todo count | [quote](chat-and-composer.md#quote-quotes-reactions-and-presentation) |
| Palette / Actions | Ctrl+K "Chat View: Restart the AI" | Chat View: when the AI has stopped in a server chat, restart it and resume the last conversation, then send any held messages; also click "AI stopped" beside the title | [lifecycle](chat-and-composer.md#lifecycle-reset-resync-fresh-start-and-switch-ai) |
| Palette / Actions | Ctrl+Shift+D in Chat View | Copy latest code block (also its Copy button or Ctrl+K) | [read](chat-and-composer.md#read-read-find-select-and-copy) |
| Palette / Actions | Ctrl+K "Chat View: Expand table" | Open the table on screen full size over a dimmed window; also its Expand button on hover. Wheel, Shift+wheel and arrow keys scroll; Esc, the X or a click outside closes | [read](chat-and-composer.md#read-read-find-select-and-copy) |
| Palette / Actions | Double click a message | Add a thumbs up, or remove it | [quote](chat-and-composer.md#quote-quotes-reactions-and-presentation) |
| Palette / Actions | Drag in Chat View | Select text; triple-click a message; drag past the edge to auto-scroll | [read](chat-and-composer.md#read-read-find-select-and-copy) |
| Palette / Actions | Enter in the selection menu / Ctrl+K "Chat View: Add selection to chat" | Open selection actions. Enter adds text. Esc dismisses. | [read](chat-and-composer.md#read-read-find-select-and-copy) |
| Palette / Actions | Ctrl+C in Chat View | Copy selected text. Right-click for more actions. | [read](chat-and-composer.md#read-read-find-select-and-copy) |
| Palette / Actions | Ctrl+A in Chat View | Select all transcript text (transcript focus; composer keeps its own Ctrl+A) | [read](chat-and-composer.md#read-read-find-select-and-copy) |
| Palette / Actions | Ctrl+K "Chat View: Resync chat" | Chat View: reload messages from the session, repair waiting labels and keep the unsent draft without resending | [lifecycle](chat-and-composer.md#lifecycle-reset-resync-fresh-start-and-switch-ai) |
| Palette / Actions | Ctrl+K "Chat View: Fresh start" / right-click tab | Save a handover and start empty context in the same chat; keep its name, picture, address and readable history. Wait for the current reply first | [lifecycle](chat-and-composer.md#lifecycle-reset-resync-fresh-start-and-switch-ai) |
| Palette / Actions | Ctrl+K "Chat View: Switch AI to Claude" (Codex, Pi) / right-click tab | Move this chat to another AI and keep its name, picture, place, address and readable history. The new AI starts from a saved handover. Wait for the current reply first | [lifecycle](chat-and-composer.md#lifecycle-reset-resync-fresh-start-and-switch-ai) |
| Palette / Actions | Ctrl+K "Chat View: Restart this chat on the newest version" | Stop and start this chat's agent on the newest version in the background; it keeps its name and history, and a chat that is mid-reply restarts when the reply ends | [lifecycle](chat-and-composer.md#lifecycle-reset-resync-fresh-start-and-switch-ai) |
| Palette / Actions | Ctrl+K "Chat View: Restart every idle live chat" | Restart every running live chat on this server on the newest version; chats that are replying restart when their reply ends. Every live chat also restarts nightly at 04:00 local server time | [lifecycle](chat-and-composer.md#lifecycle-reset-resync-fresh-start-and-switch-ai) |
| Palette / Actions | Ctrl+K "Chat View: More Menu" | Chat View: open the round three-dot menu next to the title as one grouped panel: Approve, Stop, Terminal, Rename, History, Waiting, Remind me, Archive, the current Model, End session and Remove from list; Up/Down/Enter or the mouse choose, Esc or a click outside closes | [quote](chat-and-composer.md#quote-quotes-reactions-and-presentation) |
| Palette / Actions | Inbox icon in the chat header | Click the envelope left of the three dots to open the Inbox, same as Alt+I; a blue dot shows while Inbox items wait | [inbox](notifications-inbox.md#inbox-inbox-navigation-and-triage) |
| Palette / Actions | Up / Down / Enter in Chat View | Up in an empty message box focuses the newest message; Up/Down move between messages including waiting ones, Enter opens the right-click options, Delete cancels a waiting message, Esc or typing returns to the box | [read](chat-and-composer.md#read-read-find-select-and-copy) |
| Palette / Actions | Enter / Ctrl+Enter in Chat View | Send your message; while dictating, stops the dictation and sends it with the spoken words; Shift+Enter adds a new line; Enter inserts an open command suggestion | [send](chat-message-sending.md#send-send-queue-retry-and-remove) |
| Palette / Actions | / in Chat View | Suggest Claude or Codex commands and skills; Up/Down, Tab or Enter inserts, Esc closes | [skills](chat-and-composer.md#skills-commands-skills-model-and-permissions) |
| Palette / Actions | /plan or /permissions in live chat, or Ctrl+K -&gt; Chat View: Plus Menu | Choose Plan, Ask, Accept edits, or Bypass for this chat; /plan selects Plan first | [skills](chat-and-composer.md#skills-commands-skills-model-and-permissions) |
| Palette / Actions | Ctrl+K "Chat View: Plus Menu" | Chat View: open the plus menu left of the message box: Attach file, Model, Effort and, in a Claude chat, Permission level; Up/Down/Enter or the mouse choose, Esc or a click outside closes | [skills](chat-and-composer.md#skills-commands-skills-model-and-permissions) |
| Palette / Actions | $ in Chat View (Codex) | Suggest Codex skills | [skills](chat-and-composer.md#skills-commands-skills-model-and-permissions) |
| Palette / Actions | Ctrl+/ in Chat View | Browse commands and skills for this session | [skills](chat-and-composer.md#skills-commands-skills-model-and-permissions) |
| Palette / Actions | Ctrl+K "Chat View: On Everywhere / Off Everywhere" | Switch every session once; Alt+C and tab switches keep each session independent afterwards | [read](chat-and-composer.md#read-read-find-select-and-copy) |
| Palette / Actions | Ctrl+K "Chat View: Send Queued Messages Now" | Flush offline-queued Chat View messages for this tab now (waits for the agent prompt) | [send](chat-message-sending.md#send-send-queue-retry-and-remove) |
| Palette / Actions | Ctrl+K "Pi Model..." / /model in a Pi chat | Pick any model Pi lists for this chat; the choice applies to the next message, and the chat menu's Model row opens the same list | [skills](chat-and-composer.md#skills-commands-skills-model-and-permissions) |
| Palette / Actions | 1 or Alt+Y in Chat View / Ctrl+K "Chat View: Allow" | Approve the pending permission once | [skills](chat-and-composer.md#skills-commands-skills-model-and-permissions) |
| Palette / Actions | 2 or Alt+O in Chat View / Ctrl+K "Chat View: Always allow" | Always allow the pending permission this session | [skills](chat-and-composer.md#skills-commands-skills-model-and-permissions) |
| Palette / Actions | 3 or Alt+D in Chat View / Ctrl+K "Chat View: Deny" | Decline the pending permission | [skills](chat-and-composer.md#skills-commands-skills-model-and-permissions) |
| Palette / Actions | Esc (Chat View, while working) / Stop button / Ctrl+K "Chat View: Stop the agent" | Send Esc to the agent to stop its current run | [stop](chat-stop.md#stop-stop) |
| Palette / Actions | Ctrl+K "Chat View: Reset this chat" / right-click tab | Clear local bubbles and cache; reload history, keep unsent composer text | [lifecycle](chat-and-composer.md#lifecycle-reset-resync-fresh-start-and-switch-ai) |
| Palette / Actions | Ctrl+K "Chat View: Discard Unsent Messages" | Drop this tab's Not-sent Chat View messages | [send](chat-message-sending.md#send-send-queue-retry-and-remove) |
| Palette / Actions | Ctrl+K "Chat View: Edit Queued Messages" | Presses Claude's Up key so its queued messages come back into the prompt box, where Chat View shows and edits them too | [send](chat-message-sending.md#send-send-queue-retry-and-remove) |
| Palette / Actions | Ctrl+X then Ctrl+S in Chat View | Steers: sends the message into Claude now (Claude's Ctrl+X Ctrl+S) | [send](chat-message-sending.md#send-send-queue-retry-and-remove) |
| Palette / Actions | Ctrl+K → Token Ladder: Auto | Cycle which AI plan to use up now: Auto, Burn Claude, Burn Codex; Auto lets the ladder decide | [usage](settings-appearance.md#usage-usage-eta-and-power) |
| Palette / Actions | Ctrl+K → Token Ladder: Open Dashboard | Open the Token Ladder page with every plan's usage and reset clock in the browser pane | [usage](settings-appearance.md#usage-usage-eta-and-power) |
| Palette / Actions | Alt+V | Read replies. Press later for older. Double-press to stop. | [voice](voice-dictation.md#voice-voice-and-dictation) |
| Palette / Actions | Ctrl+K "Voice Speed" | Cycle how fast Voice Mode talks: 1x, 1.25x (default), 1.4x, 1.5x | [voice](voice-dictation.md#voice-voice-and-dictation) |
| Palette / Actions | Alt+R | Read the agent's last reply aloud again, right now, even with Voice Mode off | [voice](voice-dictation.md#voice-voice-and-dictation) |
| Palette / Actions | Alt+[ / Alt+] | Read previous / next agent reply aloud; Chat View follows the spoken reply | [voice](voice-dictation.md#voice-voice-and-dictation) |
| Palette / Actions | Alt+W | Open a URL in a new pane tab and focus the browser | [browser-nav](browser-pane.md#browser-nav-browser-navigation-and-focus) |
| Palette / Actions | Ctrl+K → Sign in to Google in this profile | Open this profile in a plain window without the control channel so Google accepts the sign-in; also offered when Google rejects the sign-in page | [browser-profile](browser-pane.md#browser-profile-browser-profiles-and-pinned-pages) |
| Palette / Actions | Alt+A | Toggle the Edge browser pane for this tab | [browser-nav](browser-pane.md#browser-nav-browser-navigation-and-focus) |
| Palette / Actions | Alt+Shift+A | Retry a browser pane that could not connect (Ctrl+K: Retry Browser Pane) | [browser-nav](browser-pane.md#browser-nav-browser-navigation-and-focus) |
| Palette / Actions | Ctrl+Shift+S | Screenshot browser tab, paste link + space, focus Chat View composer or shell | [browser-nav](browser-pane.md#browser-nav-browser-navigation-and-focus) |
| Palette / Actions | Ctrl+Shift+X | Insert current browser tab URL (or most recent) + space at the Chat View caret; never send | [browser-nav](browser-pane.md#browser-nav-browser-navigation-and-focus) |
| Palette / Actions | Ctrl+Shift+L / Ctrl+L | Focus browser address bar | [browser-nav](browser-pane.md#browser-nav-browser-navigation-and-focus) |
| Palette / Actions | Alt+Q | Jump between typing and browser pane; restore typing if no pane | [browser-nav](browser-pane.md#browser-nav-browser-navigation-and-focus) |
| Palette / Actions | Ctrl+K → Browser: Use Browser Address Bar and Tabs / Use App Address Bar | Toggle pane between native browser chrome (tabs+omnibox) and custom URL bar | [browser-nav](browser-pane.md#browser-nav-browser-navigation-and-focus) |
| Palette / Actions | Alt+Left / Alt+Right (browser focus) | Browser back / forward | [browser-nav](browser-pane.md#browser-nav-browser-navigation-and-focus) |
| Palette / Actions | Alt+I (browser focus) | Open Inbox | [inbox](notifications-inbox.md#inbox-inbox-navigation-and-triage) |
| Palette / Actions | Alt+1..9 (browser focus) | Switch workspace: 1 is Starred, 2-9 are stored workspaces | [workspace](workspaces-rooms.md#workspace-workspace-lifecycle) |
| Palette / Actions | Alt+J / Alt+K (browser focus) | Next / previous Inbox session, or workspace (including Starred) outside Inbox context | [inbox](notifications-inbox.md#inbox-inbox-navigation-and-triage) |
| Palette / Actions | URL bar ‹ / › | Browser back / forward | [browser-nav](browser-pane.md#browser-nav-browser-navigation-and-focus) |
| Palette / Actions | Ctrl+K or chat menu: Pin this page to this chat | Pin the current page to this chat | [browser-profile](browser-pane.md#browser-profile-browser-profiles-and-pinned-pages) |
| Palette / Actions | Ctrl+K or chat menu: Unpin from this chat | Remove this chat's pinned page | [browser-profile](browser-pane.md#browser-profile-browser-profiles-and-pinned-pages) |
| Palette / Actions | URL bar pin | Return to this chat's pinned page | [browser-profile](browser-pane.md#browser-profile-browser-profiles-and-pinned-pages) |
| Palette / Actions | Ctrl+K → Browser: Auto-Suspend Idle Panes | Toggle idle browser pane suspension | [browser-life](browser-pane.md#browser-life-browser-lifecycle-and-agent-bridge) |
| Palette / Actions | Alt+P | Keep this tab's browser pane awake (exempt from freeze/hibernate) | [browser-life](browser-pane.md#browser-life-browser-lifecycle-and-agent-bridge) |
| Palette / Actions | Ctrl+K -&gt; External Browser Links When Pane Off | Toggle desktop browser for HTTP(S) links when the session pane is off (default on) | [browser-nav](browser-pane.md#browser-nav-browser-navigation-and-focus) |
| Palette / Actions | Ctrl+K → Close All Browser Panes | Close browser panes in every workspace, keep their saved URLs, and stop any Google Chrome or Microsoft Edge still running on Multiprompt's dedicated browser profile | [browser-life](browser-pane.md#browser-life-browser-lifecycle-and-agent-bridge) |
| Palette / Actions | Ctrl+K → Browser: Insert Agent Instructions | Paste the multiprompt-browser guide into the active shell | [browser-life](browser-pane.md#browser-life-browser-lifecycle-and-agent-bridge) |
| Palette / Actions | URL bar (click strip above pane) | Type a URL and press Enter to navigate the docked pane | [browser-nav](browser-pane.md#browser-nav-browser-navigation-and-focus) |
| Palette / Actions | Ctrl+Click URL in shell | Open link in the docked browser pane (was: default browser) | [browser-nav](browser-pane.md#browser-nav-browser-navigation-and-focus) |
| Palette / Actions | Ctrl+, / Ctrl+K -&gt; Settings | Open Settings; Escape closes the panel | [look](settings-appearance.md#look-theme-size-and-window-layout) |
| Palette / Actions | Ctrl+K -&gt; Servers | Add, test and remove the servers Multibot signs in to with its own key | [account](account-sync.md#account-account-devices-and-servers) |
| Palette / Actions | Ctrl+K -&gt; Changelog | what changed in each version | [update](relaunch-update.md#update-quit-update-and-diagnostics) |
| Palette / Actions | (agent-reported) Session ETA countdown | Sidebar row shows time left + a progress line; toggle either from Ctrl+K → ETA Countdown Numbers / ETA Progress Line | [usage](settings-appearance.md#usage-usage-eta-and-power) |
| Palette / Actions | Ctrl+K → Estimate Accuracy | See how each agent's time estimates compare to how long tasks actually took | [usage](settings-appearance.md#usage-usage-eta-and-power) |
| Palette / Actions | Ctrl+K → Restart Multi Bot | Save session and relaunch the app | [update](relaunch-update.md#update-quit-update-and-diagnostics) |
| Palette / Actions | Ctrl+K → Restart to update | Restart when an update is ready (same as the sidebar card) | [update](relaunch-update.md#update-quit-update-and-diagnostics) |
| Palette / Actions | F1 | This shortcuts overview | [shortcuts](shortcuts.md#shortcuts-shortcut-reference-and-routing) |
| Clipboard | Clipboard | F1 section heading | [shortcuts](shortcuts.md#shortcuts-shortcut-reference-and-routing) |
| Clipboard | Ctrl+V / Ctrl+Shift+V | Paste into the focused shell | [shortcuts](shortcuts.md#shortcuts-shortcut-reference-and-routing) |
| Clipboard | Ctrl+C / Ctrl+Shift+C | Copy selection / send interrupt | [shortcuts](shortcuts.md#shortcuts-shortcut-reference-and-routing) |
| Clipboard | Ctrl+Click | Open URL under cursor | [browser-nav](browser-pane.md#browser-nav-browser-navigation-and-focus) |

### Clipboard and shell URL input

In the owned local shell, print a unique marker, select it and use Ctrl+C and Ctrl+Shift+C; independently compare clipboard text. With no selection, Ctrl+C must interrupt only the owned foreground command. Paste a multiline marker with Ctrl+V and Ctrl+Shift+V, observe exact console input, and cancel rather than accidentally executing untrusted clipboard text. Ctrl+Click a localhost URL must create the expected request in the owned browser, not send another terminal command.

Observable proof: exact clipboard and console bytes, the intended interrupted PID and owned destination request. UNREACHABLE for the full shortcut matrix until the driver exposes native console selection, clipboard reads, owned-command interruption and URL-request assertions for both copy/paste variants. Source-row presence alone is not that proof.

## Gotchas
- Browser focus can consume navigation keys. These two journeys do not prove every SHORTCUT_ROWS entry or the shortcuts overlay itself; record those as unexercised.
