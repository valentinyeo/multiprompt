# Server shell input

Source files: src/clipboard.zig, src/native_session.zig, src/main.zig, src/terminal_window.c, tools/verify-chat-delivery/boundary.py, tools/server-shell-input.test.js, .claude/skills/verify-multiprompt/server-shell-input.ps1, .claude/skills/verify-multiprompt/control.ps1, .claude/skills/verify-multiprompt/control-library.ps1, .claude/skills/verify-multiprompt/control-native.cs

Verify on: pull_request

## Sub-features

- Ctrl+C with a text selection copies to the clipboard.
- Ctrl+C with no selection sends an interrupt to the running remote command.
- Mouse wheel scrolls back through earlier server shell output.

## How to get to it (user POV)

Open a VPS shell tab with the shared server connection on, print a long transcript, wheel up, select a line and press Ctrl+C, then press Ctrl+C again with nothing selected while a long command is running.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=server-shell-input` on the candidate revision. The harness enables the shared server connection, opens one VPS tab, and replaces only the production SSH transport with the existing verify boundary. The boundary paints the seeded transcript into the first frame: 200 numbered scrollback lines, a fixed marker line, then one interruptible line. The driver waits for the boundary frame, clicks the native MPTerminal child to give it keyboard focus, drag-selects the whole pane and requires Ctrl+C to put the marker and the visible scrollback numbers on the clipboard, types a blocking command and interrupts it with a second Ctrl+C that the boundary records, then wheel-scrolls the pane and requires the copied scrollback numbers to move to older lines. Screenshots, clipboard text and the interrupt receipt are required.

## Gotchas

- SSH is simulated; scroll, copy, and interrupt routing use the production native terminal and keyboard hook, not a live server.
- UNREACHABLE for tmux mouse-mode copy mode until a hosted tmux session with mouse reporting is wired into this boundary.
