# Real-size chat

Source files: src/chat*, src/terminal*, src/markdown*, src/claude*, src/tmux*, src/message*, src/main.zig, build.zig, build.zig.zon, tools/chat-history-reader.py, tools/verify-chat-delivery/*, .claude/skills/verify-multiprompt/seed-profile.py, .claude/skills/verify-multiprompt/seed-profile.ps1, .claude/skills/verify-multiprompt/drive.ps1
Verify on: push, pull_request

## Sub-features

- A repeatable, public-safe profile has 64 saved sessions across eight workspaces, eight 2,400-message chats, tables, fenced code, and embedded synthetic PNG images.
- A long server chat opens through the production reader and archive.
- Real composer input reaches production message dispatch. A partial reply and the completed reply reach the native transcript through eight live deltas.

## How to get to it (user POV)

Open a saved server chat, read its history, type a message, and watch its reply arrive.

## Driving it with control.ps1

`click-through.yml` requires this journey when chat or fixture sources change and calls the shared `verify.yml` batch. Do not dispatch an additional run while its automatic run is pending.

The workflow calls `drive.ps1 chat-and-composer chat-real-size` with the executable identity and evidence arguments from the shared skill. It records `journey.mp4` and delegates to the existing console-backed SSH and provider boundary.

Require `result.json` status `passed`, the 64-session manifest, `working-live/loaded-copied.txt` containing `Synthetic chat 00 answer 1199`, and separate partial and completed transcript copies. The partial copy must not contain `Streaming segment 7.`; the completed copy must contain it. Require zero remaining owned processes and removed scratch state in `cleanup.json`. Inspect `real-size-loaded.png`, `real-size-streaming.png`, `real-size-completed.png`, and the video in `verify-chat-real-size` after cleanup.

## Gotchas

The ordinary journey's selected tabs remain unchanged. The fixture adds eight saved, non-restoring workspaces to its real profile; it does not launch 64 consoles. This dedicated journey loads one long conversation into the real native renderer. The other fixture conversations are available for session-switch reproductions.

SSH and the AI provider are synthetic. Production parsing, history storage, dispatch, subscriptions, rendering, keyboard input, and cleanup run for real. This does not prove account login, a real remote server, provider quality, every image's painted appearance, or the absence of the separately tracked chat-jump bug.
