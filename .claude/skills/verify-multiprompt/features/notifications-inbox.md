# Notifications and Inbox

Triage unread or working sessions across workspaces, mark them read, archive them, and return to the chosen chat.

Journeys: inbox, remind-me
Release paths: src/inbox*.zig, src/notification*.zig, src/alert*.zig, src/attention*.zig, src/remind*.zig, src/main.zig, build.zig

## Sub-features
- `attention` shows unread and working sessions across workspaces.
- `triage` filters, navigates, opens, marks, archives, and restores rows.
- `remind` hides a tmux-backed session until a chosen time.

## How to get to it (user POV)
- Click the sidebar Inbox button; Ctrl+Shift+I toggles; Alt+I opens All; Ctrl+F or / filters; j/k and Enter open rows; u marks unread; e archives and z undoes; Ctrl+H or Alt+H opens Remind Me for a tmux-backed tab.

## Driving it with drive.ps1
Preconditions: fresh hosted Windows desktop, matching executable/hash/version, isolated app data, and the selected legacy recipe’s prerequisites.
- The shared wrapper accepts these Journeys; automatic workflow migration remains partial. Run `gh workflow run verify.yml --ref <branch> -f feature=inbox`. [Inbox](inbox.md) and [Remind Me](remind-me.md) specify actual keyboard steps and published shell-state assertions.
- Require chosen row identity, read/unread or reminder state from app-written files, visible Inbox screenshots, and the named result checks. Only the selected journey is covered. Download `verify-inbox` after cleanup. This legacy workflow route does not yet use the video driver; see [inventory](../inventory.md).

The recipes distinguish existing focused journeys from unreachable complete paths. UNREACHABLE names the missing data, endpoint, build mode or driver action; it never means the product passed.

### snooze: Reminders and workspace snooze

Select a Part B tmux chat. Open Remind Me by Ctrl+H, Alt+H and the palette, choose a short due time, then reopen it through Reminders. Snooze a disposable workspace; wake it through its named Workspace: Wake row. Exercise Bring Back All Sessions after hiding its recorded sessions.

Observable proof: The exact selected identity hides, its host continues, and it returns at the chosen time or explicit wake. Saved deadline and screenshots agree; wake selects the right workspace and creates no duplicate tab.

Journey: remind-me opens and cancels the picker only. UNREACHABLE for due-time/wake proof until the driver chooses a preset or typed time, observes the actual deadline and uses Part B's still-running host.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_REMINDERS_MENU_OFFSET` | Ctrl+K, search for **reminders**. Follow `snooze` above. |
| `SEARCH_REMINDER_ROW_OFFSET` | Open **Reminders**, then select the snoozed session name. Follow `snooze` above. |
| `SEARCH_REMIND_ME_OFFSET` | Ctrl+K, search for **remind me**. Follow `snooze` above. |
| `SEARCH_REMIND_PRESET_OFFSET` | Open **Remind Me** on a tmux tab, then select the displayed hour/evening preset or enter a time. Follow `snooze` above. |
| `SEARCH_WS_BRINGBACK_OFFSET` | Ctrl+K, type **bring back**, then select the matching action with Up/Down and Enter. Follow `snooze` above. |
| `SEARCH_WS_SNOOZED_OFFSET` | Ctrl+K, type **snoozed**, then select the matching action with Up/Down and Enter. Follow `snooze` above. |
| `SEARCH_WS_SNOOZED_ROW_OFFSET` | Open **Workspace: Snoozed**, then select **Workspace: Wake <name>**. Follow `snooze` above. |
| `SEARCH_WS_SNOOZE_OFFSET` | Ctrl+K, type **snooze**, then select the matching action with Up/Down and Enter. Follow `snooze` above. |

### inbox: Inbox navigation and triage

Open the sidebar envelope, Ctrl+Shift+I and Alt+I. Filter with Ctrl+F or slash; move with j/k, top/bottom and number keys. Change workspace split with Tab/h/l. Mark a row unread, enable unread-only, archive it and undo. Enter opens the chosen session; q or Escape closes without changing the draft.

Observable proof: App-published row IDs and selected workspace agree with visible filtering and ordering. Read/unread changes only the chosen row; undo restores it. Returning retains the exact draft and selected chat.

Journey: inbox, inbox-order, inbox-space, favorites-groups. UNREACHABLE for cross-window aggregation until a second owned named instance is launched and health-checked; a single offline instance cannot prove that boundary.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_FREQUENT_FIRST_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_GOINBOX_OFFSET` | Ctrl+K, type **go to inbox**, then select the matching action with Up/Down and Enter. Follow `inbox` above. |
| `SEARCH_INBOX_EXCLUDE_OFFSET` | Ctrl+K, search for **Inbox: Never Show This Session / Show This Session Again**. Follow `inbox` above. |
| `SEARCH_INBOX_FREQUENT_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_NEXTUNREAD_OFFSET` | Ctrl+K, search for **next unread session**. Follow `inbox` above. |
| `SEARCH_SHOW_ALL_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_SHOW_FREQUENT_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_STARRED_OFFSET` | Ctrl+K, type **starred**, then select the matching action with Up/Down and Enter. Follow `inbox` above. |
| `SEARCH_TABCTX_INBOX_EXCLUDE` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_TABCTX_UNREAD` | Right-click the intended tab, then choose **Mark unread**. Follow `inbox` above. |
| `SEARCH_UNREADONLY_OFFSET` | Ctrl+K, type **unread only**, then select the matching action with Up/Down and Enter. Follow `inbox` above. |

### attention: Activity and notifications

Start real output in an inactive Part B tmux session and then stop it. Send a real notification to the owned app's listener. Observe working/unread state and open that session; toggle mute and Inbox exclusion separately and repeat.

Observable proof: Working indicator follows actual output, unread appears on the inactive tab and clears on opening. Muting and excluding affect only their documented notification/Inbox surfaces. Record listener address, received payload, tab identity and native pixels.

UNREACHABLE until Part B publishes actual activity/title/notification events and the driver controls a real sender. A manually toggled unread bit or synthetic notify fixture does not prove the full hook-to-desktop path.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_INSTALLHOOK_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |

## Gotchas
- Offline unread toggles do not prove TCP notifications, real remote attention events, or cross-device sync. Never manufacture a notification then claim real delivery.
