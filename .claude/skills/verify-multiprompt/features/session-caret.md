# Session caret

Source files: src/terminal_window.c, src/terminal_window.h, src/session_caret.zig, src/main.zig, build.zig, build.zig.zon, .claude/skills/verify-multiprompt/control-feature-session-caret.ps1, .claude/skills/verify-multiprompt/control-native.cs

Verify on: push, pull_request

## Sub-features

- A CMD session caret blinks while typing in the console.
- After another app steals focus, returning to Multiprompt restores a visible blinking caret in the console.
- Chat View typing shows a visible non-zero caret after Alt+C and after focus return.

## How to get to it (user POV)

- Open a local CMD session and type in the console; the caret should blink.
- Alt+Tab away and back; the caret should blink again.
- Press Alt+C for Chat View, type in the composer, Alt+Tab away and back; the caret should still be visible.

## Driving it with control.ps1

- Dispatch `verify.yml` with `feature=session-caret` on the branch, or use its PR matrix entry.
- Launch the isolated offline CMD instance. Doctor must pass.
- Type `abc` in the console through real keys. Sample `GetGUIThreadInfo` caret rectangles twice 500ms apart on the owned window thread; the two rectangles must differ, proving blink motion.
- Start Notepad, bring the owned app back with `BringToForeground`, then require a non-zero caret rectangle in the console again.
- Press Alt+C, require composer focus, type `abc`, sample a non-zero caret rectangle on the composer.
- Retain caret JSON, screenshots, and `result.json`. Cleanup must leave zero app processes.

## Gotchas

- Caret blink is disabled when Windows reports `GetCaretBlinkTime` as `0xFFFFFFFF`; the journey skips blink-difference checks in that environment.
- Hosted MPTerminal tabs use `mp_terminal_window_repair_caret` instead of a raw `ShowCaret` on conhost children.
- This map is an executable recipe, not a claim of a completed Windows run. Inspect hosted artifacts before reporting live verification.