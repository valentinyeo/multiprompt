# Inbox

Open the session list across workspaces, change a session's read/unread state, and return to the workspace.

## Sub-features

- `inbox-open`: show the Inbox for the owned app instance.
- `inbox-unread`: toggle the selected session's blue-dot state through the list.
- `inbox-return`: close the Inbox without closing the session.
- `inbox-mute`: mute a tab through Ctrl+K, prove it leaves Inbox but stays in the workspace, then unmute it and prove it is listed again.

## How to get to it (user POV)

- Click the sidebar Inbox button or press Ctrl+Shift+I to toggle Inbox. This journey uses Ctrl+Shift+I.
- Alt+I opens Inbox and selects All; pressing it inside returns to All.
- Ctrl+K `Inbox: Frequent` opens the Frequent split, a distinct entry path not covered by this journey.
- In Inbox, j/k or arrow navigation selects sessions; Tab/h/l changes splits; Ctrl+F or `/` searches; `u` toggles read/unread; Enter opens a session; q/Esc closes Inbox.

## Driving it with control.ps1

Preconditions:

- Baseline Doctor passes; the isolated instance publishes its one initial CMD session.
- Inbox has a visible selected session, with no active search or unread-only filter hiding it.

- **Dispatch.** Run `gh workflow run verify.yml -f feature=inbox`; Windows runs `control.ps1 -Feature inbox`.
- **Open.** Press Ctrl+Shift+I. Require the actual window title to start `Inbox - ` then press Alt+I to select All and capture `action.png`, showing the list before the mutation.
- **Toggle.** Read the session's current attention value, then press the real `u` key. Require the published session attention value to change. Capture `after.png` while Inbox is visible.
- **Return.** Press Esc. The actual window title must no longer start `Inbox - `. Capture `returned.png` with the usable workspace restored.
- **Mute.** After `returned.png`, record the published `shells[0].sid` from Read-Inbox and require it to be listed and match the active saved tab. Record the saved tab count. Press Ctrl+K, type `mute tab`, then Enter. Require Read-Session to save `muted: true` on the same active tab and Read-Inbox to publish a valid list without that sid.
- **Muted Inbox.** Press Ctrl+Shift+I, require the `Inbox - ` title, then press Alt+I for All. Capture `muted.png`, showing Inbox without the session. Record `inbox-muted-hidden` in `result.json` with the sid, `listed=false`, and the title.
- **Muted return.** Press Esc and require Inbox to close. Require the same session to remain in Read-Session with the same tab count as before muting. Capture `muted-returned.png`, showing the muted tab still in its workspace.
- **Unmute.** Press Ctrl+K, type `unmute tab`, then Enter. Require the same sid to reappear in Read-Inbox and record `inbox-unmuted-listed` with the sid and `listed=true`.
- **Proof.** Inspect `action.png`, `after.png`, and `returned.png` for the selected session, blue dot, and workspace return; inspect `muted.png` and `muted-returned.png` for Inbox absence and tab survival. `result.json` records attention before/after, the mute/unmute checks, and Inbox window titles. `data/roaming/ZigShell/inbox-default.json` and `session.json` are app-published side effects, not harness-created fixtures.

## Gotchas

- An empty or filtered-out list cannot exercise a read/unread toggle. Treat that as a failed precondition, not success opening an empty overlay.
- Unread-only is a global transient filter; it is not the same thing as one session's blue dot.
- A muted session never appears in Inbox whatever it does (new output, done, waiting), on every device; it stays in its workspace tab, and the mute is saved and synced through the account layout.
- `u` must reach Inbox, not a CMD prompt or search field.
- This baseline proves a local session and window-state transition, not cross-process aggregation, every split, archive/undo or remote-session discovery.
