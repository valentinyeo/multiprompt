# Inbox

Open the session list across workspaces, change a session's read/unread state, and return to the workspace.

## Sub-features

- `inbox-open`: show the Inbox for the owned app instance.
- `inbox-unread`: toggle the selected session's blue-dot state through the list.
- `inbox-return`: close the Inbox without closing the session.

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
- **Proof.** Inspect the screenshots for the selected session and blue dot. `result.json` records attention before/after and the Inbox window title. `data/roaming/ZigShell/inbox-default.json` is the app-published side effect, not a harness-created fixture.

## Gotchas

- An empty or filtered-out list cannot exercise a read/unread toggle. Treat that as a failed precondition, not success opening an empty overlay.
- Unread-only is a global transient filter; it is not the same thing as one session's blue dot.
- A muted session never appears in Inbox whatever it does (new output, done, waiting), on every device; it stays in its workspace tab, and the mute is saved and synced through the account layout.
- `u` must reach Inbox, not a CMD prompt or search field.
- This baseline proves a local session and window-state transition, not cross-process aggregation, every split, archive/undo or remote-session discovery.
