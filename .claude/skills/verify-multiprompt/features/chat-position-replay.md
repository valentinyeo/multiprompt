# Real-server long-chat console replay

Source files: src/chat*, src/main.zig, build.zig, build.zig.zon, src/console.zig, src/focus.zig, src/window_layout.zig, tools/verify-server-chat/*, tools/verify-chat-delivery/*frame-probe*, tools/verify-chat-delivery/native-console*, tools/verify-chat-delivery/position-replay*, .claude/skills/verify-multiprompt/drive.ps1, .claude/skills/verify-multiprompt/seed-profile.py

## Sub-features

- PR 1072's working Windows OpenSSH to WSL2 OpenSSH/tmux journey, with its production host, reader and connectors.
- One real server conversation containing all 2,400 messages from PR 1070's `source_rows` generator, including images, tables and code. Other workspaces are not exercised by this journey.
- The initial server history is paged. Focus its owned transcript and press Home to load older pages until native copied text proves all 1,200 questions and 1,200 answers reached Chat View. Press End to restore the newest messages before observation starts.
- Idle with the long chat open, scroll into older history, then Alt+Tab away and back through a separate owned peer window. Repeat while reading old history.
- The original server send, `/clear` and after-clear cases, exact server receipts, per-job key restrictions and cleanup remain unchanged.

## How to get to it (user POV)

Open the saved server tab with Ctrl+1 and Chat View with Alt+C. Read its long conversation. Switch to another application and back with Alt+Tab. Scroll into older messages and repeat.

## Driving it with control.ps1

Select `feature=chat-position-replay` in `verify.yml`. It selects the real `server-chat` driver, installs the read-only paint probe, and starts native window observation before the app launches. It does not use the synthetic SSH or hosted-delivery stand-ins. Only the paid Claude process remains deterministic, as documented by [server-chat](server-chat.md).

A separate positive control must catch a real native child console. It cannot establish the app's failing-master repro. The server driver owns the only desktop video recorder at 30 fps. Keep the video, `windows/windows.tsv`, console screenshots, every paint, `position-phases.json`, `position-replay.json`, `native-console.json`, native transcript copy and server receipts.

The window observer records opening and shutdown too. `allFlashes` retains every overlap. A qualifying `flashes` entry must occur in a loaded-long-chat observation phase and identify the latest completed, nonblank paint for that same conversation. Opening-only overlap, stale content, a fixture timeout or the positive control cannot establish this bug.

Done when master exposes a native console over painted long-chat content on this real-server journey and the unchanged journey passes on the app fix. Inspect the event, corresponding paint and desktop video before editing app code. Head must also pass the original server receipts, paint-position checks, cleanup, and `chat-view-everywhere`.

## Gotchas

WSL2, SSH key handling, provider startup and SQLite locking belong to the existing server harness. Do not replace them with fake SSH, a shared VPS or production credentials. The runner is 1920x1080. The peer is an ordinary window in the driver process, not a manufactured console flash. Alt+Tab must genuinely return to the app without a focus-repair call. Recording overhead is not a latency benchmark. No app fix is claimed until failing-master and passing-head evidence exists.
