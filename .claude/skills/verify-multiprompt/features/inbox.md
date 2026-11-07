# Inbox

Open the session list across workspaces, change a session's read/unread state, and return to the workspace.

## Sub-features

- `inbox-open`: show the Inbox for the owned app instance.
- `inbox-unread`: toggle the selected session's blue-dot state through the list.
- `inbox-return`: close the Inbox without closing the session.
- `inbox-chat-navigation` (IGSH-1771): open Chat View before Inbox, move up and down six times in Light and AMOLED, require the owned transcript window to stay hidden, and restore that same chat when Inbox closes. Retain `inbox-chat-<theme>-navigation.png` and `inbox-chat-<theme>-returned.png`. This offline journey verifies window layering, not live account sync.
- `inbox-button`: hide the sidebar button while Inbox is open and restore it on return.
- `inbox-mute`: mute a tab through Ctrl+K, prove it leaves Inbox but stays in the workspace, then unmute it and prove it is listed again.

## How to get to it (user POV)

- Click the sidebar Inbox button to open Inbox. The button is hidden while Inbox is open and returns on close. Ctrl+Shift+I still toggles Inbox.
- Alt+I opens Inbox and selects All; pressing it inside returns to All.
- Ctrl+K `Inbox: Frequent` opens the Frequent split, a distinct entry path not covered by this journey.
- In Inbox, j/k or arrow navigation selects sessions; Tab/h/l changes splits; Ctrl+F or `/` searches; `u` toggles read/unread; Enter opens a session; q/Esc closes Inbox.

## Driving it with control.ps1

Preconditions:

- Baseline Doctor passes; the isolated instance publishes its one initial CMD session.
- Inbox has a visible selected session, with no active search or unread-only filter hiding it.

- **Dispatch.** Run `gh workflow run verify.yml -f feature=inbox`; Windows runs `control.ps1 -Feature inbox`.
- **Open.** Press Ctrl+Shift+I. Require published `inbox_active` to be true (or the legacy `Inbox - ` title) then press Alt+I to select All and capture `action.png`, showing the list before the mutation.
- **Toggle.** Read the session's current attention value, then press the real `u` key. Require the published session attention value to change. Capture `after.png` while Inbox is visible.
- **Return.** Press Esc. Require published `inbox_active` to be false (or the legacy title to leave `Inbox - `). Capture `returned.png` with the usable workspace restored.
- **Mute.** After `returned.png`, press Ctrl+K, type `new cmd`, then Enter, and require two saved tabs and two published Inbox sessions, so the Inbox is never empty while one is muted. Record the second tab's `shell_id` as the sid and require it to be listed and match the active saved tab. Record the saved tab count. Press Ctrl+K, type `mute tab`, then Enter. Require Read-Session to save `muted: true` on the same active tab and Read-Inbox to publish a valid list without that sid.
- **Muted Inbox.** Press Ctrl+Shift+I, require published `inbox_active` (or the legacy `Inbox - ` title), then press Alt+I for All. Capture `muted.png`, showing Inbox without the session. Record `inbox-muted-hidden` in `result.json` with the sid, `listed=false`, and the title.
- **Muted return.** Press Esc and require Inbox to close. Require the same session to remain in Read-Session with the same tab count as before muting. Capture `muted-returned.png`, showing the muted tab still in its workspace.
- **Unmute.** Press Ctrl+K, type `unmute tab`, then Enter. Require the same sid to reappear in Read-Inbox and record `inbox-unmuted-listed` with the sid and `listed=true`.
- **Button.** After unmuting, show the workspace strip through Ctrl+K `workspace switcher` if it is hidden, then require the app to save `hide_pills: false`. This restores the ordinary sidebar button precondition without writing settings. Select Light and AMOLED through the Themes palette. For each, capture `inbox-button-<theme>-closed.png` and `inbox-button-<theme>-open.png`. Check the former button region is blank while open and the sidebar glyph is visible while closed. Click the former region, close Inbox, click the restored sidebar button, and capture `inbox-button-<theme>-returned.png`. Require published `inbox_active` transitions. Pixel coordinates use the app-published sidebar width, UI scale, window DPI and native frame offsets.
- **Proof.** Inspect `action.png`, `after.png`, and `returned.png` for the selected session, blue dot, and workspace return; inspect `muted.png` and `muted-returned.png` for Inbox absence and tab survival. Inspect both button states in each theme. `result.json` records pixel counts and transitions alongside attention and mute/unmute checks. Graphite 2 is not a shipped theme, so it is recorded as unavailable rather than substituted. `data/roaming/ZigShell/inbox-default.json` and `session.json` are app-published side effects, not harness-created fixtures. [Windows run 41888148376](https://github.com/valentinyeo/multiprompt/actions/runs/41888148376) passed on c092547a, with both theme states inspected, open pixels 0, closed pixels 133, restored-button clicks and zero remaining owned processes. The same driver rejected [released v0.28.1459](https://github.com/valentinyeo/multiprompt/actions/runs/41855325465), which retained 133 button pixels while Inbox was open.

## Gotchas

- An empty or filtered-out list cannot exercise a read/unread toggle. Treat that as a failed precondition, not success opening an empty overlay.
- Unread-only is a global transient filter; it is not the same thing as one session's blue dot.
- A muted session never appears in Inbox whatever it does (new output, done, waiting), on every device; it stays in its workspace tab, and the mute is saved and synced through the account layout.
- `u` must reach Inbox, not a CMD prompt or search field.
- This baseline proves a local session and window-state transition, not cross-process aggregation, every split, archive/undo or remote-session discovery.
