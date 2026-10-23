# Chat delivery

## Sub-features

- `busy-send`: a message typed in the real Chat View composer reaches an agent buffer as exactly that text followed by Enter within 15 seconds while the scripted agent remains busy (`esc to interrupt`).
- `idle-suggestion`: the same path delivers only the typed message, not the nonempty grey suggestion following Claude's `❯` prompt glyph.
- `steer-chord`: Ctrl+X then Ctrl+S submits the composer text, then the channel sends the native `C-x C-s` after the text and Enter.

## How to get to it (user POV)

Select an existing remote tmux tab with Ctrl+1. Press Alt+C to open Chat View, type a message in its composer and press Enter. To ask Claude to take a queued message immediately, type in the composer and press Ctrl+X then Ctrl+S instead of Enter.

## Driving it with control.ps1

Dispatch on GitHub Windows only:

```sh
gh workflow run verify.yml --ref ceo/IGSH-595 -f feature=chat-delivery -f tag=v0.28.811
gh workflow run verify.yml --ref ceo/IGSH-595 -f feature=chat-delivery -f tag=v0.28.821
gh workflow run verify.yml --ref ceo/IGSH-595 -f feature=chat-delivery
```

After merge, omit `--ref` to dispatch the default branch. Verify the exact harness SHA and release tag in `build.json`; watch with `gh run watch <id> --interval 60`, then download `verify-chat-delivery`. Release runs use the checksum-verified published app and embedded version; Zig compiles only the remote-shell launcher. Branch runs also build the app. The workflow installs Python 3.12 for the supplied remote reader.

`control.ps1 -Feature chat-delivery` delegates to `tools/verify-chat-delivery/drive.ps1`. Each case gets a separate unique RUNNER_TEMP profile, a saved tmux tab seeded exactly through the reconnect harness's `session.json` mechanism, and the production `ssh-path.txt` override. This explicit exception to baseline empty-session rules replaces only the remote-shell system boundary. The console-backed stand-in renders a Claude-like busy or idle screen, with a dark-grey suggestion on the actual prompt row for idle. Fake `tmux capture-pane` returns the same characters without colour escapes, as ordinary capture-pane does. The state file belongs solely to the stand-in; it is never an app-state setter.

The app starts its own persistent host channel, supplies its embedded `chat_history_reader.py` over stdin, and sends ordinary JSON requests. The boundary launches Python with that supplied command and unmodified stdin, not a substitute reader from the checkout. The real app composer, outbox, channel and reader issue literal `tmux send-keys`, Enter and `send_queued` operations. Fake tmux independently logs every raw send-keys argv and wall-clock timestamp to `agent-buffer.jsonl`; it does not know the expected message text.

Doctor checks the original process, executable path/hash/version, owned visible ZigShell HWND through UI Automation, published tmux shell and foreground composer focus. Only real SendInput keyboard events select the tab, open Chat View, type and submit. Every case runs even if a previous one fails. Cases use separate app lifetimes so 811's blocked outbox cannot contaminate later cases. A complete 15-second observation window catches extra writes as well as missing or delayed delivery.

Require root `result.json` status `passed` and all three `{name, passed, detail}` entries passed. The independent Node evidence checker requires exact raw writes and ordering, the matching fake capture/console screens, the supplied persistent-reader bootstrap, Doctor identity, valid screenshots, and successful owned-job cleanup. `before.png`, `after.png`, and `<case>-before/action/after/final.png` show the real desktop. Root `agent-buffer.jsonl`, `invocations.jsonl`, `debug.log`, `actions.json` and `cleanup.json` accompany each case's raw stand-in logs, reader stderr, observation, Doctor, saved session and process-tree accounting. Missing evidence fails; it is never a skipped pass. Cleanup stops only each case's owned kernel job, requires zero active processes, preserves evidence and removes its profile.

The expected regression comparison is 811 failing busy-send and idle-suggestion at its pre-channel gate, versus master/821 delivering immediately; master/821 must also pass steer-chord. A release launch or infrastructure error is not a demonstrated regression. Inspect screenshots and buffer evidence from the first paired runs before making any runtime claim.

## Gotchas

- `agentBoundary` honestly records: stand-in remote shell + fake tmux + scripted agent screen, not real Claude or a real server. This proves that real Chat View input reaches the production tmux-channel system boundary, not that Claude consumes it, generates a response, or persists a real conversation.
- No real SSH networking, authentication, server, Claude process, transcript discovery, transcript settlement or remote rendering is verified. No credentials, synthetic transcript files, account data or test-only app setters are supplied.
- The launcher preserves an attached console for screen reads and uses `CREATE_NO_WINDOW` when no console is attached, including SSH probes with non-pipe stdout. Child startup uses `SW_SHOWNOACTIVATE`. Foreground acquisition uses the same Alt/thread-attachment routine as the other journeys; each Press retries it if foreground was lost, then still refuses keyboard input unless the owned app is foreground.
- The app's screen read for 811's outbox gate is the attached console, not a reader `screen` opcode. The stand-in mirrors fake capture-pane characters into that console so the old busy and nonblank-input checks remain exercised. The production reader separately calls capture-pane while sending.
- The known local direct-input gap is not covered: the local console route still rejects a prompt row holding a suggestion, even on master/821. This journey deliberately exercises remote tmux channel delivery, the route relevant to the reported remote Claude sessions.
- Multiline paste-buffer, slash commands, real transcript confirmation, local console paste, permission prompts and other entry points remain outside these three cases. Branch/release runs have not passed merely because source contracts pass locally.
