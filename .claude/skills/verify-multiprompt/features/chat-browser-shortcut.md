# Chat tab browser shortcut

Alt+A opens the browser pane from a tab that is in Chat View. The pane shows a real browser window, never the "Browser not open" placeholder.

## Sub-features

- `alt-a-opens`: Alt+A in Chat View starts the browser and docks its window in the pane.
- `alt-a-closes`: a second Alt+A closes the pane again.

## How to get to it (user POV)

- Alt+C turns on Chat View for the active tab.
- Alt+A turns the browser on for that tab. The pane appears beside the chat.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml -f feature=chat-browser-shortcut`, or run the Click-through journeys workflow. The recipe is `control-feature-chat-browser-shortcut.ps1`.

1. Launch the real executable on an isolated profile after the isolated browser warm-up.
2. Alt+C and wait for the saved `cv` flag and the visible transcript.
3. Require the pane closed, then press Alt+A once and require a new `shortcutToggle` log line.
4. Require the pane opening or connected with a new connection id, a docked and visible pane window, and a window that is not the placeholder.
5. Alt+A again and require the pane closed.
6. Retain `chat-view.png`, `action.png`, `after.png`, `browser-pane-chat-alt-a.json` and `chat-browser-shortcut.json`.

## Gotchas

- The placeholder is painted text, not a window, so the check is that a docked browser window exists and is visible.
- Before the fix for IGSH-1860 the shortcut only set the saved flag; the journey fails at the docked window step.
- The single Alt+A is never retried, because a second press would close the pane.
