# Server shell release proof

Source files: src/clipboard.zig, src/native_session.zig, src/terminal_window.c, src/session.zig, src/shell_poll.zig, src/command_palette.zig, src/mp_shell.py, .claude/skills/verify-multiprompt/control-feature-server-shell-tabs.ps1, .claude/skills/verify-multiprompt/server-shell-release-setup.ps1, .claude/skills/verify-multiprompt/server-shell-release-cleanup.ps1, .claude/skills/verify-multiprompt/server-shell-release-fixture.py

## Sub-features

- SOFT-3001: select a line and copy it with Ctrl+C and with Ctrl+Shift+C, paste with Ctrl+V and with Ctrl+Shift+V, wheel back past 100 lines of output, and interrupt a running command with Ctrl+C and no selection.
- SOFT-3002: a saved tmux tab restored at launch attaches the same remote session and accepts real keyboard input.
- SOFT-3007: the console fills the tab after open and after a window resize, on a plain server shell tab and on a tmux-attached tab.

## How to get to it (user POV)

Open a server shell with Ctrl+K Open shell on VPS 1, and also start the app with a saved tab on a live tmux session. In each tab select a line and press Ctrl+C, then press Ctrl+Shift+C, paste a command with Ctrl+V and with Ctrl+Shift+V, print 200 numbered lines and wheel back through them, interrupt a running command with Ctrl+C, and resize the window.

## Driving it with control.ps1

```sh
gh workflow run verify.yml --ref <journey-branch> -f feature=server-shell-tabs -f tag=v0.28.<n>
gh workflow run verify.yml --ref <journey-branch-with-the-fix> -f feature=server-shell-tabs
```

Dispatch `server-shell-tabs` directly: the workflow installs the runner-owned WSL server and ffmpeg for this feature, and the journey owns its own setup, evidence in `shell-release/` and cleanup. It records the whole run to `journey.mp4` with ffmpeg gdigrab and takes a screenshot before and after every step. Pass `tag` to drive the published release. Without a tag the CI builds the dispatched branch, so merge the fix into the journey branch to drive that app source.

The journey seeds one saved tab on the fixture `proof-shell` tmux session, then drives the restored tab and a plain server shell opened through Ctrl+K. Each tab runs the same eight steps and records them independently in `journey-steps.json` and `result.json`. Every step uses real keyboard and mouse input; remote receipts come from the runner-owned WSL Linux server over real OpenSSH.

Copy is checked by clearing the screen, printing a single token line, drag-selecting that line and requiring the clipboard to equal the token exactly. Paste sets the clipboard to an `echo` command, requires the prompt row to include that command through the same surface the screenshots show (`MPTerminal` prompt-line copy or conhost UI Automation document text), presses Enter with shell focus, and requires the file the pasted command writes. The wheel step prints 200 numbered lines, reads the visible text through Ctrl+C, wheels up 40 notches and requires the lowest visible line number to drop by at least 100. Layout requires the console to cover at least 80% of the tab height and 50% of the width, after open and after the window grows. The restore step requires a visible terminal on the saved `proof-shell` tab and a real remote receipt written through that tab.

## Gotchas

- Each wait uses a short deadline and writes the failing step name, screenshot and UI Automation dump to `result.json`. Remote receipts use bounded SSH waits so the driver never blocks inside a condition.
- The scroll step reads visible text through the product's own Ctrl+C copy path. When copy is broken the step fails and reports that the wheel could not be measured.
- SOFT-3003 is not part of this journey. On v0.28.1893 Ctrl+K Open shell on VPS 1 opened `/home/mpverify` instead of the chat folder; that is tracked outside this proof.
- Only the paid provider is deterministic. SSH, tmux, shell processes, clipboard, wheel scroll, signals and layout are real and runner-owned. No user machine, credentials or shared VPS is involved.
- A released run and an `app_revision` run are two dispatches, so the same video shows the failure on the release and the fix on the revert branch.
