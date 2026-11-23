# Release proof

One dispatch proves three fixed tickets on a published release build: the second account's slash menu, saved server shell tabs after a restart, and a console caret that keeps blinking.

Source files: src/chat_composer.zig, src/console.zig, src/session.zig, src/native_session.zig, src/focus.zig, src/session_caret.zig, src/terminal_window.c, .claude/skills/verify-multiprompt/control-feature-release-proof.ps1, tools/verify-chat-delivery/boundary.py

## Sub-features

- SOFT-3053: a chat whose folder belongs to the second server account lists that account's own slash commands.
- SOFT-3039: two saved server shell tabs reattach to their saved tmux sessions after a normal quit and a real relaunch, and each restored console accepts keyboard input.
- SOFT-3046: a focused console caret keeps toggling over five seconds, before and after switching sessions and back.

## How to get to it (user POV)

- Open the chat of a session that belongs to the second account, press `/` in the message box and pick one of that account's skills with Tab.
- Open two server shell tabs, quit Multiprompt and start it again; both tabs should show their same remote sessions and take typing.
- Focus a console and watch the caret blink; switch to another session and back, and it should still blink.

## Driving it with control.ps1

```sh
gh workflow run verify.yml --ref <branch> -f feature=release-proof -f tag=v0.28.<n>
```

The journey seeds two isolated saved tmux tabs once before launch, one reporting `/home/inne` as its folder, and points the app's SSH path at the verification boundary. It selects the second-account chat, types `/verify-owner` through real keys, waits for the boundary to record the completion request as the inne owner, and requires Tab to accept the account's own row. It then focuses the first tab's native terminal, samples the caret pixels at 10 fps for five seconds, switches sessions with Ctrl+2 and back with Ctrl+1, and samples again. Both samples must keep toggling, and a magnified frame strip is written next to the frames.

Before restarting it switches the boundary to its plain server shell mode, shows the second tab's console, quits through WM_CLOSE, and relaunches the same verified executable in the same isolated profile. Both tabs must come back with their saved tmux session names, two fresh transports must name both sessions, and Ctrl+C in each restored console must reach its transport.

Require `result.json` status `passed`, `owner-slash-menu.png` with the open menu, `server-shell-after-restart.png`, both `caret-strip-*.png` strips, `completion-owner.jsonl`, the transport and input receipts, and a zero-process cleanup.

## Gotchas

- Only SSH, tmux and agent transport are stand-ins. No credentials, shared session or paid agent are used; the second account is the boundary's seeded owner of `/home/inne`, not a real login.
- `interrupt.json` is a single receipt file, so the journey reads it immediately after each tab's Ctrl+C to attribute the input to that tab.
- Caret blink is skipped only when Windows reports `GetCaretBlinkTime` as `0xFFFFFFFF`; the hosted runner normally blinks.
- This map is an executable recipe, not a claim of a completed Windows run. Inspect the artifacts before reporting live verification.
