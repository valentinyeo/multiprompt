# Server shell input

Source files: src/clipboard.zig, src/native_session.zig, src/main.zig, src/terminal_window.c, src/window_layout.zig, tools/verify-chat-delivery/boundary.py, tools/server-shell-input.test.js, .claude/skills/verify-multiprompt/server-shell-input.ps1, .claude/skills/verify-multiprompt/control.ps1

Verify on: pull_request

## Sub-features

- Ctrl+C with a text selection copies to the clipboard.
- Ctrl+C with no selection sends an interrupt to the running remote command.
- Mouse wheel scrolls back through earlier server shell output.

## How to get to it (user POV)

Open a VPS shell tab with the shared server connection on, print a long transcript, wheel up, select a line and press Ctrl+C, then press Ctrl+C again with nothing selected while a long command is running.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=server-shell-input` on the candidate revision. The harness enables the shared server connection, opens one VPS tab, and replaces only the production SSH transport with the existing verify boundary. The boundary seeds scrollback lines with a fixed marker, accepts Ctrl+C as interrupt input, and keeps one selectable line on screen. The driver waits for the native terminal child, wheel-scrolls, selects the marker line, copies with Ctrl+C, starts a blocking command, and interrupts with Ctrl+C again. Clipboard text, interrupt receipts, and before/after screenshots are required.

## Gotchas

- SSH is simulated; scroll, copy, and interrupt routing use the production native terminal and keyboard hook, not a live server.
- UNREACHABLE for tmux mouse-mode copy mode until a hosted tmux session with mouse reporting is wired into this boundary.