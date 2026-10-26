# Chat send latency

IGSH-977: a message must be on screen in the Chat View the moment it is sent. The app used to hold the window thread for the 120 ms paste-and-Enter wait (250 ms for tmux and remote tabs) before the window could redraw, so the new message appeared late.

## Sub-features

- `bubble-first`: the sent message is drawn in the transcript within 100 ms of the send key press, for every one of 20 sends.
- `marks-only-in-log`: the app writes `[chat] send-latency id=<n> enqueue_us=<n> painted_us=<n>` only under verbose logging. The marks are a high resolution clock read at the top of `sendChatPrompt`, right after the message is added to the list, and after the transcript paint that first draws that message. They add no wait and no behavior.

## How to get to it (user POV)

Press Alt+C to open Chat View, type a message and press Enter.

## Driving it with control.ps1

- Branch: `gh workflow run verify.yml --ref ceo/IGSH-977 -f feature=chat-send-latency`. It also runs in the full matrix on every master push.
- The driver first starts a PowerShell console in the isolated CMD session with the title `claude agent` and a `❯` prompt, so the app treats it as a local coding agent at an idle prompt and sends through direct console input, the path that waits before pressing Enter. Then it opens Chat View, types `latency probe <n>` with real keyboard input and presses Enter, 20 times with 1.5 seconds between sends. After each send it waits for the new log line and for the message box to empty.
- `chat-send-latency.json` holds all 20 samples in milliseconds (`enqueueMs`, `paintedMs`), the median and the maximum. `result.json` names the check `chat-send-latency` with `over`, the number of sends slower than 100 ms. Any value above 100 ms fails the run.

## Gotchas

- Red control: the instrumentation-only commit (marks present, send still blocks before the redraw) is slow on every send because the wait runs before the paint. The red and green run links are on the IGSH-977 ticket.
- A release older than the marks has no `send-latency` lines, so a tag run fails with a missing-sample error. That is not a valid red control.
- The painted mark is taken right after the transcript is copied to the window. The desktop compositor adds at most one display frame after it.
- A plain CMD session never reaches the typing step (the app queues the message until an agent prompt is idle), so it measures about 9 ms and cannot be a red control. The tmux channel in the chat-delivery journey sends from a background job and also measures about 13 to 16 ms. Only the direct console path blocks the window thread.
