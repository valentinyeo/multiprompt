# Architecture

multiprompt is a Zig Win32 organizer, not a terminal emulator. `src/main.zig` manages native console windows, workspaces, overlays, keyboard routing, and JSON persistence. Chat View reads supported conversation histories while the original shell process remains alive.

The optional browser pane is a native Chrome or Edge window owned and positioned by the main frame. Separate browser profiles isolate it from normal browser windows and installed web apps. `extension/bridge.js` executes exact-window commands; `src/bridge.zig` connects the CLI and native messaging channels. See [routing](../browser/routing-state-machine.md) and [pane lifecycle](../../docs/browser-pane-lifecycle.md).

Runtime files live under `%APPDATA%\ZigShell` for compatibility. Stable and development binaries use separate session files. Never publish personal runtime files, conversation caches, or authentication state.

Portable modules implement layout reconciliation, session identity, chat parsing, and cryptographic protocols independently of Win32. The optional [worker](../../service/README.md) provides device enrollment and revision-based layout sync. Notification adapters supply activity and completion events; their installation is optional.
