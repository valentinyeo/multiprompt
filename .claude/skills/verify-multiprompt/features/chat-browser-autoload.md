# Chat tab browser starts by itself

Source files: src/chat*, src/terminal*, src/chat_markdown*.zig, src/chat_connectors/*, src/tmux*, src/message*, src/chat_history_reader.py, tools/verify-chat-delivery/*, src/browser*, extension/*, src/main.zig, build.zig, build.zig.zon, src/command_palette.zig, src/shortcuts.zig, .claude/skills/verify-multiprompt/control-feature-chat-browser-autoload.ps1, .github/workflows/click-through.yml

Switching to a Chat View tab whose browser slot is on starts the browser without any key press.

## Sub-features

- `switch-starts-browser`: Ctrl+Tab to the chat tab opens and docks the browser.
- `no-shortcut`: no Alt+A or other browser shortcut is pressed.

## How to get to it (user POV)

- Open a chat tab that had its browser slot on, then switch to it from another tab. The pane fills in by itself.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml -f feature=chat-browser-autoload`, or run the Click-through journeys workflow. The recipe is `control-feature-chat-browser-autoload.ps1`.

Seeding boundary: the harness writes `session.json` once before launch with a terminal tab selected first and a second tab already in Chat View with its browser slot on (`cv` and `bon`). It is copied to `seed-session.json`. Switching to a Chat View tab is the only way to reach this state without a restart.

1. Launch with `--single-window` and wait for both tabs.
2. Wait ten seconds and require no connected pane and no docked browser window; the inbox may say opening while the slot stays off-screen.
3. Press Ctrl+Tab, nothing else.
4. Require the chat tab pane opening or connected within 30 seconds, then docked and visible.
5. Require no `shortcutToggle` log line.
6. Retain `action.png`, `after.png`, `browser-pane-before-switch.json` and `chat-browser-autoload.json`.

## Gotchas

- Before the fix for IGSH-1863 the pane stays closed and the chat shows the placeholder, so the journey fails at the 30 second wait.
- The ten second idle wait lets startup settle so the launch is not blamed on a startup race.
