---
type: Reference
title: Keyboard shortcuts
description: Full keyboard shortcut list; the Full list is generated from the F1 overlay by node tools/shortcuts-doc.mjs.
tags:
  - shortcuts
  - keyboard
updated: 2026-10-03
---

# Keyboard shortcuts

Source of truth for the F1 overlay is `SHORTCUT_ROWS` in `src/shortcuts.zig`. The Full list below is generated from it by `node tools/shortcuts-doc.mjs`. Every new user-facing function ships with a shortcut (when sensible), a Ctrl+K entry, and an F1 row; regenerate the Full list after changing those rows.

- Ctrl+Shift+Space: Inside multiprompt, start/stop dictation. From another app, bring multiprompt to the front (global hotkey).
- Ctrl+Shift+S: Screenshot the active browser-pane tab, upload it, and insert its link followed by exactly one space. Works from multiprompt, Chat View, and the focused docked Chrome/Edge pane through the native hook and bridge, independently of Chrome's shortcut binding. Ctrl+K has `Browser: Screenshot → Chat View / Shell`; F1 lists the chord. In Chat View the composer receives focus with the caret after the space, including extension-menu screenshots and Ctrl+V image attachments. An inactive target receives the link without changing tabs or stealing focus; another foreground application and modal editors keep their focus.
- Chrome extension screenshot shortcuts: extension 1.0.62 suggests Ctrl+Shift+S and retains Alt+Shift+S. Both commands and the extension context menu use the same capture/upload/paste transaction. Chrome can leave a conflicting suggested key unbound, and unpacked reloads preserve old bindings: assign it manually at `chrome://extensions/shortcuts` if needed. The app-owned Ctrl+Shift+S path still works while a bound multiprompt pane or the app is foreground; this is not a global shortcut for unrelated Chrome windows.
- + button / Ctrl+V in Chat View: The round + at the left of the composer opens a picker for any file, including png, jpg, jpeg, gif or webp images; Ctrl+V with a picture on the clipboard does the same. Drop files onto the composer or chat, or copy files in Explorer and paste with Ctrl+V. Up to 10 images attach one after another in their original order. Other files (up to 10, at most 200 MB each) are copied over the session's ssh to `~/.multiprompt/uploads/<session>/` on the server, and their server path is inserted at the caret; only server sessions can receive files. Your original files are kept. The image is uploaded to screencast2 (same upload as Ctrl+Shift+S, 10 MB limit) and its link is inserted at the caret with the caret placed after it. Ctrl+K has `Chat View: Attach File`. Image links in any message (https links ending in .png, .jpg, .jpeg, .gif or .webp, or screencast2.com/<id>.png) show as a rounded thumbnail under the text, up to 320 px wide; click one to open it in the browser pane. Thumbnails are cached in `%APPDATA%\ZigShell\imgcache`.
- Ctrl+Shift+D in Chat View: Copy the latest nonempty code block without its fence markers. Ctrl+K has `Chat View: Copy Latest Code Block`; each code panel also has a one-click Copy button that highlights on hover. Keywords, strings, numbers and comments use light/dark-aware colors. This chord is free elsewhere and never consumes Ctrl+Alt/AltGr; existing Ctrl+Shift+C still copies a console selection.
- Drag in Chat View: Select transcript text with the mouse, double-click a word, or triple-click a message; dragging above or below the viewport auto-scrolls. The selection spans messages and is highlighted behind the characters.
- Ctrl+C in Chat View: Copy the current transcript selection (CRLF breaks, messages separated by a blank line). Without a selection this is unchanged. Right-click opens Copy, Select All, and Copy Message. Copying returns focus to the composer. Ctrl+K also has `Chat View: Copy Selection`.
- Ctrl+A in Chat View: Select all transcript text while the transcript has focus; the composer keeps its own Ctrl+A. Esc clears the selection. Ctrl+K also has `Chat View: Select All Text`.
- Chat View message styles: Alt+C automatically shows your messages in right-aligned tinted bubbles and full-width replies with a small Claude/Codex avatar. Recorded times include their timezone; screen-copy history never invents timestamps. There is no extra switch or shortcut.
- Chat View formatting: Alt+C reads the exact Claude or Codex conversation through the existing remote helper, including headings, emphasis, lists, tables, links and inline code. Missing identity, missing files or an older/unavailable helper keep the screen-copy fallback. No new shortcut or palette action is needed; the existing Alt+C and Chat View toggle enable it automatically.
- `/` in Chat View: Suggest Claude or Codex commands and skills. Up/Down selects, Tab or Enter inserts without sending, and Esc closes the list.
- `$` in a Codex Chat View: Suggest Codex skills; press Enter again to send after inserting.
- Ctrl+/ in Chat View: Browse all available commands and skills. Ctrl+K also has `Chat View: Insert Command or Skill...`.
- Alt+C: Toggle Chat View on/off for the active tab, current tab only. Works from every focus state — terminal, the chat composer, the transcript, or a focused docked browser pane (exits browser focus first). Esc no longer closes Chat View; it only closes an overlay (Ctrl+K/F1/Inbox) opened on top of it. Also a Ctrl+K entry that toggles the same way. Page Up / Page Down scroll the conversation while the cursor stays in the typing box (once the box has grown past five lines and shows its own scroll bar, they scroll the box instead).
- Chat View mode: Ctrl+K "Chat View: On Everywhere" / "Chat View: Per Tab" / "Chat View: Off Everywhere" (the active one is tagged `current`, saved in the session file). "On Everywhere": every tab opens in Chat View. "Per Tab" (default): Alt+C turns Chat View on or off for the tab you are on and each tab remembers it. "Off Everywhere": Chat View never shows; Alt+C only shows the notice "Chat View is off everywhere (Ctrl+K to change)", and choosing it leaves Chat View on all tabs at once.
- Ctrl+K → "Chat View: Send Queued Messages Now" / "Chat View: Clear Offline Queue": no dedicated shortcut. When Chat View sends into a stalled ssh/tmux link, or the write/Enter fails, the message is queued per tab (FIFO, max 20) instead of being lost and the composer clears. The queue persists across restart in `%APPDATA%\ZigShell\chat-outbox.json` and flushes one at a time once the link is back and the agent is idle at its `❯` input prompt; background tabs flush when their console is idle and the send route does not need focus. "Send Queued Messages Now" flushes immediately (still waits for the idle prompt); "Clear Offline Queue" drops the active tab's queue and reports how many were dropped. Closing a tab drops its queue. Disconnected `.tmux` tabs also auto-reattach on a 5s/10s/20s/30s backoff while Windows reports internet; plain VPS tabs stay manual (Ctrl+Shift+R) because a fresh plain shell would lose the remote session's live state.
- Ctrl+K → `Chat View: Reset this chat`: also in the right-click tab palette and F1 overview; no dedicated shortcut. Clears every local queued, pending and sent bubble for that tab, deletes its disk chat cache and reloads the transcript from scratch. Keeps your unsent composer text, sends nothing and leaves the terminal/agent session running. Automatic cleanup removes exact normalized copies anywhere in user transcript history even if recorded before the send time; Sent bubbles expire after ten minutes once a successful full transcript load completed after the send. On upgrade, the old version-1 local outbox is discarded (including offline queues); new version-2 queues still persist across restarts.
- Chat View send status: every Enter shows the message immediately at the bottom of the transcript as your own bubble with a small status line — `◷ Sending…` while the terminal write/Enter verify runs, `◷ Waiting for connection` while queued offline, and a red `Not sent · click to retry` if the verify gives up (click the bubble to re-queue it). Once the real message appears in the transcript the echo is replaced by the real bubble and that message's time gets a subtle `✓✓ Read` mark. If Claude takes the message out of its input box but queues it (it is still working), the bubble stays as `✓ Sent · queued in Claude · click to send now`; clicking it, or Ctrl+K → "Chat View: Send Claude's Queued Message Now", sends Ctrl+X Ctrl+S so Claude takes it immediately. Unconfirmed sends survive a restart as Not sent. Ctrl+K → "Chat View: Retry Unsent Messages" re-sends this tab's Not-sent messages in order; "Chat View: Discard Unsent Messages" drops them. No dedicated shortcut.
- Alt+V: Toggle Voice Mode. Works in the terminal and in Chat View; it no longer opens Chat View for you. If the tab is already showing Chat View it keeps using it, otherwise it runs right in the terminal, sending what you say straight to the shell. The mic stays on while Voice Mode is on, so speak over the agent to stop it and send your words after a short pause. One press during speech stops the voice only; a second press turns Voice Mode off. Voice Mode turns itself off after 10 quiet minutes. While it's on, its state (listening/speaking/waiting) shows in the window title bar when the terminal is on screen, or in the Chat View header when that's open. Communications capture may make audio from other apps quieter while it is on.
- Ctrl+K → "Voice: Always Listening On/Off": Always listening is on by default. Turn it off to return to the old taking-turns behavior; the choice is saved in the session.
- Ctrl+K → "Voice Speed: 1x / 1.25x / 1.4x / 1.5x": how fast Voice Mode talks. Default 1.25x. Takes effect on the next reply, no restart needed.
- Ctrl+K → "Update: Relaunch": no dedicated shortcut. When a session installs a new build over the exe you launched from, a small card "vX is ready" with a Relaunch button appears at the bottom left of the sidebar (above the TODAY'S AI card); the x hides it until the next version. The same action is Ctrl+K "Update: Relaunch to vX" (typing "update" shows "no update ready" when nothing is installed). Relaunch saves your session, closes every workspace window gracefully, stops the old telemetry and bridge, and reopens multiprompt maximized on the new version.
- Alt+R: Read the agent's last reply aloud again, right now. Works whether Voice Mode is on or off, and whether or not Chat View is open. With Voice Mode off, it's a one-shot: nothing else changes afterward. Also a Ctrl+K entry, "Voice: Read Last Reply".
- Alt+[ / Alt+]: Read the previous / next agent reply aloud. Previous stops at the oldest, next stops at the newest; Alt+R resets to the newest. Works with Voice Mode and Chat View on or off. Chat View scrolls to and marks the spoken reply while speaking. Also Ctrl+K entries, "Voice: Read Previous Reply" and "Voice: Read Next Reply".
- Ctrl+V / Ctrl+Shift+V: Paste Windows clipboard into focused shell (works in tmux/SSH)
- Ctrl+Shift+C: Copy current console selection to clipboard (if any)
- Ctrl+Click: Open URL under cursor in default browser (works in cmd/tmux/SSH)
- Ctrl+O: Scan visible shell buffer for URLs, pick one from overlay, open in browser
- Ctrl+Shift+K: Open the multiprompt Ctrl+K command palette from any foreground multiprompt surface, including the focused Chrome/Edge browser pane and Chat View. The browser does not receive this chord; Ctrl+K alone still goes to the website when the browser is focused.
- Ctrl+K → **Account: Sign Out**: clear this device's DPAPI login, attempt server revocation, and immediately lock the full window. Offline sign-out is local only; revoke the device from another signed-in device when back online.
- Ctrl+K → **Account: Devices**: list device names/IDs; Yes revokes the displayed device, No advances, Cancel closes. Revoking this device signs it out.
- Ctrl+K → **Sync: Pull Now**: fetch the account layout now (or send pending local edits first), reconcile workspaces/names/order and synchronized tmux tabs without killing remote tmux. Local-only tabs and unsynchronized attachments are retained.
- Ctrl+K opens with your last 5 sessions: with nothing typed, the palette leads with the 5 sessions you viewed most recently across every workspace, newest first, each with its workspace name. The first row is the session you just left, so Ctrl+K then Enter still hops back. Snoozed workspaces and filed-away (hidden) tabs are left out, and the tab you are on is not listed.
- Ctrl+K: Quick switcher — search/switch tabs + spawn new shells by name. Also exposes **"Open sessions in this folder"** (search "folder"/"sessions"/"repo"): when a VPS/tmux tab is focused, bulk-attaches every *other* tmux session on the **same host** whose cwd is under the focused session's folder (prefix match on `#{session_path}`). Requires the VPS list source to emit the path — the inline fallback already sends `-F '#{session_name}|#{session_activity}|#{session_path}'`; for `~/.local/bin/tmux-list.sh` append `|#{session_path}` to its `-F` format (4th field after ram; client parser detects path by leading `/`, ram by all-digits, so it tolerates 2–4 fields). Until a host emits the path, the entry just won't match there.
- Alt+T: New workspace tmux tab in its configured or inferred remote folder. A workspace-scoped `commands.json` default with `alt_t` (for example `"claude"`) starts that program in the folder after shell startup; without it, the new tab is a neutral shell. The sidebar '+ New tab' button and Ctrl+T outside browser focus use the same path.
- Ctrl+T: New workspace tmux tab outside browser focus, same as Alt+T and '+ New tab'. In a focused docked browser, Ctrl+T and Ctrl+K go to the browser; Ctrl+Shift+K opens the multiprompt palette.
- Ctrl+Shift+1: New CMD tab
- Ctrl+Shift+2: New TMUX tab
- Ctrl+Shift+3: New VPS Remote host 1 tab
- Ctrl+Shift+4: New VPS Remote host 2 tab
- Ctrl+Shift+5: New PowerShell tab
- Ctrl+Shift+F: Toggle full-width ("fullscreen") for the active shell — fills the content pane instead of the centered column. Also a Ctrl+K entry ("Toggle Full-Width").
- Ctrl+Shift+R: Reconnect/reattach the active SSH/tmux tab (recovers a dropped/black session by respawning ssh + reattaching the tmux session). Also a right-click tab menu item ("Reconnect"). No-op on cmd/pwsh tabs.
- Ctrl+Shift+E: Archive the active tmux tab (press TWICE within 2.5s — the thread band shows the confirm prompt). Kills the remote tmux session (frees VPS RAM), saves {name, tmux session, host, Claude session id, cwd} to archive.json, closes the tab. Resurrect via Ctrl+K: type the archived name -> '\u21A9 <name>' row recreates the tmux session and relaunches `claude --resume <sid>` (or --continue without a stored id). The Claude session id arrives via the SESSION: hook broadcast (v0.28.247). Also available as Ctrl+K 'Archive Session' and in the right-click tab menu (explicit pick = confirmed, no double-press; v0.28.249)
- Ctrl+Shift+B: Cycle sidebar: open -> collapsed -> hidden (0px focus mode) -> open. Ctrl+K 'Sidebar: Expand/Collapse/Hide' jump to a state directly
- Ctrl+Shift+O: Toggle the docked Edge browser pane for the active tab (v0.28.264 — owner-docked top-level borderless Edge, per session; console reflows left, pane docks right). Also Ctrl+K 'Browser: Open URL...' and 'Insert browser-control instructions' (pastes the `zsb` usage guide into the shell). Drive the pane from the session via the `zsb` CLI (on each shell's PATH) or browser-cli/Playwriter. NOTE: the Edge extension + native-messaging host load from the `zigshell-browser-pane` repo folder — keep it; deleting it breaks browser CONTROL (the pane still docks). Windows-only; no VPS path yet
- **Browser-focus escape hatches (v0.28.293):** while the docked Edge pane has FOCUS (the Ctrl+Shift+M isolation state where all keys go to Edge natively), a small set of one-press Alt combos still reach ZigShell — Edge ignores the Alt namespace, so claiming them costs no native browser shortcut. **Alt+I** = jump to Inbox (no Ctrl+Shift+M dance first), **Alt+1..9** = switch workspace (1 is Starred; 2-9 are the first eight stored workspaces), **Alt+J / Alt+K** = cycle workspace (the workspace ones are single-window-mode only, mirroring the shell-focused binds). Everything else still passes to Edge (Alt+Left/Right stay browser back/forward). Mnemonic: Ctrl = Edge, Alt = ZigShell. Implemented in the `keyboardHookProc` browser-focus passthrough block; F1 overview lists the three rows
- Alt+S: Favorite or unfavorite this session. Starred tabs show a small yellow dot and keep it after restart, tmux adoption, or moving tabs. Ctrl+K has `Favorite: Toggle` with its current on/off state; right-click a tab for `Favorite` / `Unfavorite`. Alt+Shift+S still reaches the browser extension.
- Alt+P: Keep the active tab awake — exempts its docked browser pane from freezing/hibernation (v0.28.635). Also Ctrl+K "Keep Tab Awake: On/Off" and the right-click tab menu. Sidebar shows a pin glyph on awake tabs and "z" on frozen/hibernated panes. See [pane hibernation](../browser/pane-hibernation.md)
- Ctrl+K → "Hibernate Browser Panes Now": immediately sleep every hidden, unpinned browser pane (v0.28.635)
- Ctrl+K → "Crash Reports: Open Folder": opens `%APPDATA%\ZigShell\crashes` in Explorer. After a crash the app writes `crash-<yyyymmdd-hhmmss>.txt` (version, exception, offset for the .pdb, tab count, Chat View, debug-log tail) plus a small `.dmp`, keeps the newest 10, and reopens itself with a one-line notice (not when 4 crashes happen within 15 minutes; repeat crashes wait 5 s, then 30 s, before reopening). Resolve a report with `node tools/crash-report.js <crash.txt> --exe multiprompt.exe`. Dev builds also have Ctrl+K "Debug: Crash Now" (type "crash now") to test the recorder.
- Ctrl+K → "Power Saver: Auto / Always / Off": when background timers, VPS polling and hidden tabs slow down (Auto = on battery or Energy Saver). Deep idle applies in every mode.
- Ctrl+K → "Token Ladder: Auto / Burn Claude / Burn Codex": picks which AI plan to use up now. Auto lets the Token Ladder decide; the active choice is tagged "current". The usage panel at the bottom of the sidebar shows the result in its top line ("BURN CLAUDE | auto") and lists the plans the ladder watches.
- Ctrl+K → "Token Ladder: Open Dashboard": opens the ladder's usage page in the browser pane.
- Ctrl+K -> "Inbox: Never Show This Session" / "Inbox: Show This Session Again" (also right-click a tab): permanently exclude or restore that tab in the cross-workspace Inbox, its needs-reply counts, and the inbox button badge. The sidebar blue dot, spinner, and ETA remain unchanged. No dedicated shortcut: Alt+I opens Inbox, Alt+E files a tab temporarily, Alt+U marks it unread, and Ctrl+Shift+U toggles unread-only; an additional modifier chord for this infrequent setting would compete with shell/browser shortcuts.
- Sidebar inbox button (in the workspace strip): Click to toggle the cross-workspace Inbox. The button shows the local needs-reply count across workspaces and stays clickable to close the Inbox. Alt+I opens the Inbox or selects the ALL split; Ctrl+Shift+I toggles the Inbox too. The `★ Favorites` split immediately after ALL shows starred sessions from every window, in the same order and row style as ALL. The Frequent split comes first, before All and Favorites. It shows sessions you sent input to in the last 24 hours, plus watch-only sessions you explicitly selected and kept in front for ten focused seconds at least three times in six hours. Switches alone, attention stepping, Inbox step-jumps, automatic focus and old usage history do not qualify. Qualifying input determines order, otherwise the newest look does; newest appears at the bottom. The selected split survives migration.
- Alt+J / Alt+K: Jump to the next / previous Inbox session from Chat View, the terminal, or the docked browser. Outside an Inbox context, cycle workspaces including Starred. The old Ctrl+Shift+J/K aliases are retired.
- Ctrl+Shift+T: Reopen last closed tab
- Ctrl+Shift+U: Toggle the GLOBAL unread-only filter (sidebar + inbox, one state, v0.28.227): sidebar shows only blue-dot tabs + the active tab (UNREAD ONLY badge replaces the Ctrl+T hint); inbox filters rows/splits as before. Not persisted. Tab cycling and Ctrl+1-9 skip filtered tabs. Jump-to-next-unread lives on via Alt+J/K and the Ctrl+K "Next unread" row / Ctrl+K+Enter
- Ctrl+Shift+Up / Ctrl+Shift+Down: Move active tab up/down (blocked at group boundary). When sidebar auto-sort is on, first materializes the displayed order and switches Tab Order to Manual
- Mouse drag between PINNED / RECENTS: dropping a session on either section heading, any session in that section, or a section's group header pins/unpins it while preserving Inbox auto-sort
- Ctrl+G: Toggle active tab's group collapsed/expanded (no-op if ungrouped)
- Ctrl+K → "UI Size: Increase/Decrease/Reset": chrome zoom 80..150% in 10% steps (v0.28.246) — scales ALL UI fonts (one type scale; thread band follows the theme) + tab/inbox/palette row heights; persisted as ui_scale; separate from the shell font zoom below by design (shell zoom changes the terminal grid)
- Ctrl+Plus / Ctrl+Minus / Ctrl+0: Console font bigger / smaller / reset (global override, all tabs, persisted; reset returns to the Windows console default; AltGr-safe). Also Ctrl+K "Font Size: Increase/Decrease/Reset". Fonts are PINNED across monitors (v0.28.238) — no DPI scaling, by user decision. While Chat View (Alt+C) is active, these same keys size Chat View's text instead (transcript + composer, code blocks scale with it; range 10..28pt, default 14, persisted separately from the console font)
- Ctrl+Tab / Ctrl+Shift+Tab: Next/previous tab
- Ctrl+1-9: Switch to tab 1-9
- Ctrl+Shift+Y: Snooze the current workspace (single-window mode). Pick This evening, Tomorrow morning, In 3 days, This weekend, Next week, Someday, or Custom in the same Remind Me picker as a tab. It closes local tabs, keeps remote tmux sessions running, and hides the workspace until its wake time. Ctrl+K "Workspace: Snoozed..." wakes it early and switches to it; right-click a visible workspace pill to snooze that pill. Ctrl+Shift+Y is free; Ctrl+Shift+H already snoozes one tab, Alt+Y is unclaimed but lacks the Ctrl+Shift pattern and could interfere with browser input, and Ctrl+Alt combinations are reserved for AltGr on US-International keyboards. Separate-window workspaces remain available; workspace snooze applies to in-process single-window workspaces.
- Ctrl+K "Workspace: Wake <name>": one row for every snoozed workspace, listed from the live snooze flags (not only from reminders.json). It wakes the workspace now and switches to it. No dedicated shortcut. The snooze flag is also saved with the workspace in the session file, so a lost wake marker is rebuilt at the next start and the workspace stays reachable.
- Ctrl+K "Workspace: Bring Back All Sessions": no dedicated shortcut. For the active workspace it reopens, as tabs in that workspace, every tmux session recorded for it (written when the workspace is snoozed, plus its snooze snapshot) that is still running on a VPS and not open as a tab anywhere. Sessions already open are never duplicated.
- Alt+1..9: Switch in-process workspace (single-window mode): 1 is Starred, and 2-9 are the first eight stored workspaces. Held Alt chains — Alt+1, 2, 3 without re-pressing (focus defers until Alt release so the synthetic-Alt trick can't cancel the held key)
- Alt+Left / Alt+Right: Cycle prev/next workspace (hold Alt, tap arrows; auto-repeat works). Both Alt shortcuts exit the inbox first if it's open. EXCEPTION (v0.28.286): while the docked browser pane is FOCUSED, Alt+Left/Right = browser back/forward instead (the Alt+Shift chord from .285 was dropped - too alien); shell focus always keeps workspace cycling
- Alt+J / Alt+K: Cycle next/prev workspace including Starred outside an Inbox context (vim order; hold Alt, tap J/K — same as Alt+arrows)
- Alt+Space: Open the window's system menu (move/size/minimize/maximize/close — e.g. Alt+Space, x = maximize). The menu appears on Alt RELEASE (v0.28.239 — deferred so the foreground claim can't race the held Alt; holding Alt keeps it pending). Hook retargets it to the main window because focus usually sits on the conhost child
- Win+Left/Right/Up/Down: Snap left/right half, maximize, restore/minimize — retargeted to the main window because focus sits on the conhost child. Pressing Left/Right when already snapped to that edge hops to the adjacent monitor's opposite half (native cycle semantics)
- Win+Shift+Left/Right: Move the window to the adjacent monitor, preserving maximized state (v0.28.235 — natively these targeted the conhost child and did nothing)
- Ctrl+K → "Sort Workspaces": drag rows by their ≡ handle (or Ctrl+Up/Down) to reorder the workspace pills; Enter switches to a pill; order persists (registry + session + inbox)
- Ctrl+N: New ZigShell window (single-window mode: new in-process workspace)
- Ctrl+W: Close the active tab/session (both modes; reverted in v0.28.219 — .215's workspace-close granularity was wrong). Workspace close = Ctrl+K 'Close Workspace' (non-destructive, reopenable via Open Workspace); app close = Ctrl+K 'Quit ZigShell'
- F1: Open the in-app keyboard-shortcuts overview overlay (Esc/F1/click to close; ↑↓ or j/k to scroll). Also a Ctrl+K entry ("Keyboard Shortcuts"). **When adding/removing a shortcut, update `SHORTCUT_ROWS` in `src/shortcuts.zig` and run `node tools/shortcuts-doc.mjs` to regenerate the Full list.**
- F2: Rename active tab
- Double-click tab: Rename tab
- Right-click tab: Open the Ctrl+K palette in TAB-CONTEXT mode (v0.28.240 — the native menu is gone): Reconnect (remote tabs), Archive Session (tmux tabs, v0.28.249, one-pick = confirmed), Favorite/Unfavorite (Alt+S), Mute/Unmute, Keep Alive (cmd/pwsh), Move to Workspace… (links into the wsmove submenu, targets the right-clicked tab), group commands (add to new/existing group, remove, new tab in group), Clear tab selection. Actions target the CLICKED tab (captured by shell_id), not the active one; with a Ctrl+click selection the selection-wide variants show and moves apply to the whole set. Esc closes; Backspace on empty query = back to the normal palette.
- No dedicated shortcut — Session ETA: when an agent hook reports a time estimate for the in-flight request, the sidebar row shows a countdown ("12m", "1h 20m", amber "+4m" once overdue) and a thin progress line, Chat View's header shows "ETA 12m, done about 14:27", and Inbox rows show the same countdown. No hook wired up yet -> nothing shows. Ctrl+K → "ETA Countdown Numbers: On/Off" and "ETA Progress Line: On/Off" toggle each independently (both default on); Ctrl+K → "Estimate Accuracy" opens a read-only summary of how each agent's estimates compare to actual time taken, computed from `%APPDATA%\ZigShell\eta-log.jsonl`. Esc closes.

## Sync

Opening multiprompt is locked until device login is validated and the initial server layout is fetched. **Sign in** or **Enter** opens the default system browser for Cloudflare Access email one-time-code login. No console, pane or workspace UI is restored before success. No vault password is required by the optional layout service; encrypted-vault foundations are separate future work.

<!-- SHORTCUT_ROWS:START -->

## Full list

### Tabs

| Keys | Action |
| --- | --- |
| Alt+S | Favorite or unfavorite this session |
| Ctrl+Tab / Ctrl+Shift+Tab | Next / previous tab |
| Ctrl+1 ... 9 | Switch to tab 1-9 |
| Ctrl+W | Close active tab / session |
| Ctrl+Shift+W | Close active session completely (tmux kill + tab close) |
| Ctrl+Shift+U | Toggle unread-only filter (sidebar + inbox) |
| Alt+U | Mark active session unread / restore blue dot |
| Ctrl+K -&gt; Show Frequent split | Show or hide Frequent; synced across your account |
| Ctrl+K -&gt; Frequent as first tab | Put Frequent first or immediately after Favorites; synced across your account |
| Ctrl+K -&gt; Show Favorites split | Show or hide Favorites; synced across your account |
| Ctrl+K -&gt; Show All split | Show or hide All; All stays visible if every split is hidden |
| Ctrl+K -&gt; Inbox: Frequent | Sessions you use or repeatedly watch across devices, newest at the bottom |
| Ctrl+K -&gt; Inbox: Never Show This Session | Toggle permanent Inbox exclusion for this tab (also right-click tab) |
| Alt+J / Alt+K | Next / previous Inbox session, or workspace (including Starred) outside Inbox context |
| Ctrl+Shift+Up / Down | Move active tab up / down |
| Ctrl+G | Collapse / expand tab group |
| Alt+; / Ctrl+; | Use snippets |
| Ctrl+K -&gt; Create Snippet | Save a named paste block |
| Delete twice in snippets | Delete the selected saved snippet |
| F2 / double-click | Rename tab or selected Inbox session |

### Workspaces (single-window)

| Keys | Action |
| --- | --- |
| Alt+1 | Go to Starred workspace |
| Alt+1 ... 9 | Switch workspace: 1 is Starred, 2-9 are stored workspaces |
| Ctrl+Shift+Y | Snooze this workspace until a chosen time |
| Ctrl+K -&gt; Workspace: Wake &lt;name&gt; | Wake a snoozed workspace now and switch to it |
| Ctrl+K -&gt; Workspace: Bring Back All Sessions | Reopen every recorded tmux session of this workspace |
| Alt+Left / Alt+Right | Cycle prev / next workspace |
| Ctrl+N / Alt+N pill | New workspace |

### Inbox (Alt+I)

| Keys | Action |
| --- | --- |
| Sidebar inbox button | Click or Ctrl+Shift+I to toggle; Alt+I opens / selects All |
| Ctrl+F or / | Reduce Inbox to matching sessions |
| j/k or Alt+J/K  gg/G  1-9 | Move / top / bottom / jump row |
| Tab / h / l | Switch workspace split |
| e or Alt+E / z or Alt+Z / u | Archive / undo archive / toggle read-unread |
| Ctrl+Shift+U | Toggle unread-only filter (global) |
| Alt+I (inside) | Jump back to ALL split |
| q / Esc | Close Inbox |

### View

| Keys | Action |
| --- | --- |
| Ctrl+Shift+F | Toggle full-width (fullscreen) |
| Ctrl+Shift+B | Cycle sidebar: open / collapsed / hidden |
| multiprompt-browser sidebar | Reveal the sidebar from a shell |
| Ctrl+K Thread Title | [DEV] Subject header above the console (toggle) |
| Ctrl++ / Ctrl+- / Ctrl+0 | Terminal font only (Chat View text size when Chat View is active) |
| Ctrl+K UI Size | App/sidebar only, layered over native monitor DPI |
| Ctrl+Shift+R | Reconnect active SSH/tmux tab |
| Ctrl+K -&gt; All Sessions | Open session overview (w = Waiting, a = Archived, u = unattached) |
| Ctrl+F in All Sessions | Reduce the list to matching sessions |
| Alt+E | Move active tab to Waiting until it gets a blue dot |
| Alt+Z | Undo the most recent move to Waiting |
| Ctrl+K -&gt; Restore Waiting | Restore waiting live sessions in this workspace |
| Alt+X | Archive tmux session; close non-tmux tab (press twice; also on inbox rows) |
| Ctrl+Shift+Space / Enter | Start/stop dictation; Enter is stop-only while recording |

### Spawn / Windows

| Keys | Action |
| --- | --- |
| Ctrl+Shift+1 ... 5 | New CMD / TMUX / VPS / PowerShell |
| Ctrl+N | New multiprompt window |
| Ctrl+Shift+T | Reopen last closed tab |
| Alt+Space | Window menu (move/size/min/max) |
| Win+Arrows | Snap / maximize / minimize (edge-snapped Left/Right hops monitors) |
| Win+Shift+Left/Right | Move window to the adjacent monitor |

### Palette / Actions

| Keys | Action |
| --- | --- |
| Ctrl+K | Open command palette; it opens with your last 5 sessions |
| Ctrl+K -&gt; Account: Sign Out | Forget this device login and lock multiprompt |
| Ctrl+K -&gt; Account: Approve devices | Approve or deny a new device reaching your servers |
| Ctrl+K -&gt; Account: Devices | List account devices and revoke a device |
| Ctrl+K -&gt; Sync: Pull Now | Reconcile server workspaces and synchronized tmux tabs |
| Ctrl+Shift+K | Open command palette from any multiprompt surface, including browser |
| Ctrl+K → Reconnect Claude: Primary / Secondary | Force sign-in one telemetry profile in its own terminal |
| Ctrl+K → Power Saver: Auto / Always / Off | Choose when background timers, VPS polling, and idle tabs slow down to save power |
| Ctrl+Shift+G | Cycle Combined, VPS, and Today's AI telemetry cards |
| Alt+T | New workspace tmux tab (optional configured program) |
| Ctrl+K Remind Me | Snooze active tmux/Claude tab via quick presets (or type a time) |
| Alt+H | Remind Me: hide local tab, keep tmux running, return when due |
| Ctrl+K Reminders | View / restore snoozed sessions |
| Ctrl+V (in Ctrl+K) | Paste into the palette search |
| Browser pane focused | Ctrl+C / Ctrl+V / Ctrl+K pass through to the page |
| Ctrl+K Lock Session | Protect the active session from every close / archive path |
| Drag tab onto a group | Move it there without changing pin or lock state |
| Drag tab: PINNED / RECENTS | Change its order inside the group or ungrouped list |
| Click tier heading | Collapse / expand ungrouped PINNED or RECENTS |
| Right-click group / Ctrl+K | Group: new tab, rename, color, collapse / expand, move workspace, ungroup, close all tabs |
| Right-click tab | Tab actions palette (lock / pin / reconnect / mute / close / move / group) |
| Ctrl+F in Chat View | Chat View: Find in conversation; Enter / F3 next, Shift+Enter / Shift+F3 previous, Esc closes |
| Double-click empty space | Switch between Chat View and the shell (without selecting text) |
| Alt+C | Toggle formatted Chat View for this tab; screen copy remains the fallback |
| + button / Ctrl+V in Chat View | Attach files and images: pick, drop, or paste; images become links, other files go to the server session and their path goes in at the caret (Ctrl+K Chat View: Attach File) |
| Right-click message → Reply / Ctrl+K "Chat View: Reply to latest agent message" | Quote a message above your reply; click × or press Esc with an empty composer to cancel |
| Ctrl+K "Chat View: Open or fold all tool steps" | Open every tool step's details, or fold them all; click one tool line to toggle it |
| Ctrl+K "Chat View: Toggle todo list" | Show or hide this tab's agent todo list below the model and context header; also click the header |
| Ctrl+Shift+D in Chat View | Copy latest code block (also its Copy button or Ctrl+K) |
| Drag in Chat View | Select text; double-click a word, triple-click a message; drag past the edge to auto-scroll |
| Ctrl+C in Chat View | Copy the selection (right-click also has Copy / Select All / Copy Message) |
| Ctrl+A in Chat View | Select all transcript text (transcript focus; composer keeps its own Ctrl+A) |
| / in Chat View | Suggest Claude or Codex commands and skills; Up/Down, Tab or Enter inserts, Esc closes |
| $ in Chat View (Codex) | Suggest Codex skills |
| Ctrl+/ in Chat View | Browse commands and skills for this session |
| Ctrl+K "Chat View: ..." | Chat View mode: On Everywhere (every tab opens in Chat View), Per Tab (Alt+C per tab, default), or Off Everywhere (Chat View never shows, Alt+C does nothing) |
| Ctrl+K "Chat View: Send Queued Messages Now" | Flush offline-queued Chat View messages for this tab now (waits for the agent prompt) |
| Alt+Y in Chat View / Ctrl+K "Chat View: Allow" | Answer the live permission prompt: allow |
| Alt+O in Chat View / Ctrl+K "Chat View: Always allow" | Answer the live permission prompt: always allow |
| Alt+D in Chat View / Ctrl+K "Chat View: Deny" | Answer the live permission prompt: deny |
| Esc (Chat View, while working) / Stop button / Ctrl+K "Chat View: Stop the agent" | Send Esc to the agent to stop its current run |
| Ctrl+K "Chat View: Reset this chat" / right-click tab | Clear local bubbles and cache; reload history, keep unsent composer text |
| Ctrl+K "Chat View: Clear Offline Queue" | Drop this tab's queued offline Chat View messages |
| Ctrl+K "Chat View: Retry Unsent Messages" | Re-send this tab's Not-sent Chat View messages in order |
| Ctrl+K "Chat View: Discard Unsent Messages" | Drop this tab's Not-sent Chat View messages |
| Ctrl+K "Chat View: Send Claude's Queued Message Now" | A message marked 'queued in Claude' waits until Claude finishes; this sends it now (same as clicking the bubble or Ctrl+X Ctrl+S in the terminal) |
| Ctrl+K → Token Ladder: Auto / Burn Claude / Burn Codex | Choose which AI plan to use up now (shown at the top of the usage panel); Auto lets the ladder decide |
| Ctrl+K → Token Ladder: Open Dashboard | Open the Token Ladder page with every plan's usage and reset clock in the browser pane |
| Alt+V | Voice Mode on/off; talk over the agent, or press once to stop its voice and again to turn it off; works in the terminal and in Chat View |
| Ctrl+K Voice: Always Listening On/Off | Keep the mic on to talk over replies, or return to taking turns |
| Ctrl+K "Voice Speed: ..." | How fast Voice Mode talks: 1x, 1.25x (default), 1.4x or 1.5x |
| Alt+R | Read the agent's last reply aloud again, right now, even with Voice Mode off |
| Alt+[ / Alt+] | Read previous / next agent reply aloud; Chat View follows the spoken reply |
| Alt+W | Open a URL in a new pane tab and focus the browser |
| Alt+A | Toggle the Edge browser pane for this tab |
| Alt+Shift+A | Retry a browser pane that could not connect (Ctrl+K: Retry Browser Pane) |
| Ctrl+Shift+S | Screenshot browser tab, paste link + space, focus Chat View composer or shell |
| Ctrl+Shift+X | Insert current browser tab URL (or most recent) + space at the Chat View caret; never send |
| Ctrl+Shift+L / Ctrl+L | Focus browser address bar |
| Alt+Q | Jump between shell and browser pane |
| Ctrl+K → Browser engine | Switch every pane between dedicated Edge and dedicated Chrome profiles |
| Ctrl+K → Browser mode | Toggle pane between native browser chrome (tabs+omnibox) and custom URL bar |
| Alt+Left / Alt+Right (browser focus) | Browser back / forward |
| Alt+I (browser focus) | Open Inbox |
| Alt+1..9 (browser focus) | Switch workspace: 1 is Starred, 2-9 are stored workspaces |
| Alt+J / Alt+K (browser focus) | Next / previous Inbox session, or workspace (including Starred) outside Inbox context |
| URL bar ‹ / › | Browser back / forward |
| Ctrl+K Auto-suspend | Toggle idle browser pane suspension |
| Alt+P | Keep this tab's browser pane awake (exempt from freeze/hibernate) |
| Ctrl+K → Crash Reports: Open Folder | Open the folder with crash reports saved after a crash (the app also reopens itself) |
| Ctrl+K → Hibernate Browser Panes Now | Immediately hibernate every parked, unpinned browser pane |
| Ctrl+K → Close All Browser Panes | Close browser panes in every workspace and keep their saved URLs |
| Ctrl+K → Insert browser-control instructions | Paste the multiprompt-browser guide into the active shell |
| URL bar (click strip above pane) | Type a URL and press Enter to navigate the docked pane |
| Ctrl+Click URL in shell | Open link in the docked browser pane (was: default browser) |
| Ctrl+K -&gt; Changelog | what changed in each version |
| (agent-reported) Session ETA countdown | Sidebar row shows time left + a progress line; toggle either from Ctrl+K → ETA Countdown Numbers / ETA Progress Line |
| Ctrl+K → Estimate Accuracy | See how each agent's time estimates compare to how long tasks actually took |
| Ctrl+K → Restart multiprompt | Save session and relaunch the app |
| Ctrl+K → Update: Relaunch | Relaunch onto the installed new version (same as the sidebar card) |
| F1 | This shortcuts overview |

### Clipboard

| Keys | Action |
| --- | --- |
| Ctrl+V / Ctrl+Shift+V | Paste into the focused shell |
| Ctrl+C / Ctrl+Shift+C | Copy selection / send interrupt |
| Ctrl+Click | Open URL under cursor |

<!-- SHORTCUT_ROWS:END -->

### Chat View status and todos

The header shows the latest model, context left, and completed todo count when available, for example `Opus 5.5 · 62% context left · 3 of 7 done`.
Click the header or use Ctrl+K → `Chat View: Toggle todo list` to expand or collapse the active tab's list.
Completed items use ✓, the current item uses ▸, and pending items use ○.
The list scrolls independently when long; transcript scrolling and selection remain below it.
The toggle stays per tab. No extra keyboard chord is reserved: use the existing Ctrl+K command search.
