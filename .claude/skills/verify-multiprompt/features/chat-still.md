# A chat stays still

Verify on: pull_request

## Sub-features

- From the first nonempty painted frame, the newest visible message keeps its exact screen rectangle.
- No scrolling, tolerance, warm-up frame, settle delay or baseline reset is permitted after that frame.
- Observe at least two seconds without input, then at least two seconds overlapping a streaming reply.
- A missing anchored message, blank repaint, dirty layout or first-paint width mismatch fails immediately.
- The message selected in the first frame remains the reference throughout idle, streaming and settlement. A new reply does not replace it. Only a deliberate scroll-to-bottom may start a different viewing position; this journey never scrolls.

## How to get to it (user POV)

Switch from one Chat View session to another long session with Ctrl+2. Leave it alone while the agent replies.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=chat-still` and download `verify-chat-still`.

The existing remote boundary seeds five saved Chat View tabs and 400 question/answer rounds per transcript before launch. No app cache or layout state is written. The initial tab must actually render, then the observer starts before the genuine Ctrl+2 input switches to the second chat.

`tools/chat-still/observer.cs` samples on each DWM composition frame. Native `WM_PAINT` emits complete, unthrottled visible message rectangles only under `MULTIPROMPT_CHAT_STILL_PROOF=1` and `ZIGSHELL_DEBUG=1`. The observer consumes every completed native paint between samples too, so a one-paint displacement that returns before the next sample still fails. Each display sample converts the retained message rectangle through the live transcript HWND's screen origin. Each paint must already have a clean layout at the actual client width. The final message in the first visible frame becomes the fixed identity; later rows cannot silently replace it.

The observer keeps one identity and one baseline continuously across both phases; it never resets them at streaming start. After 2,100 ms idle and a real `events_subscribe`, it releases the synthetic provider. The boundary calls the production `host_event`, `message_events_page` and `events_push` paths with 30 increasing `text.delta` snapshots over three seconds, then `text.done` and a matching final provider JSONL record. The observer continues for 4,200 ms after streaming starts, including at least one second after the canonical history write. The journey requires at least ten emitted chunks and ten subscription-pushed deltas overlapping observation, at least two native paints and two different laid-out content heights. Each phase needs at least 30 display-frame samples. Missing prerequisites fail rather than skip. The host thread belongs to the app-owned remote boundary and dies with its verified process tree.

Inspect `chat-still-idle.json`, `chat-still-streaming.json`, the chunk receipt, raw debug log, before/action/after screenshots, Doctor and owned-process cleanup. Samples retain all four screen edges, identity, time, layout width and dirty state. The exact rectangle comparison uses zero pixel tolerance. `observer.test.ps1` proves rejection of a one-pixel change in each edge, dirty first paint, wrong width, disappearing identity and a blank repaint.

Chat-related source changes force this journey into the PR verifier's selection ahead of optional journeys. The path-filtered Chat stillness workflow also runs it independently of the picker and the arithmetic check.

## Gotchas

This is the real native Windows UI on a GitHub-hosted runner, with only remote SSH/tmux/provider input replaced. It does not verify real network timing, a signed-in agent, GPU scanout or undrawn pending outbox bubbles. The read-only diagnostic reports the production message bounds; screenshots remain necessary to review actual pixels. DWM sampling plus every native paint covers rendered position changes, not an absolute proof of every display driver.

The observation after the canonical write covers the settlement window, but does not independently prove that every written record was consumed. The first PR adds the diagnostic, so an older master executable cannot emit it. Do not report that missing instrumentation as a demonstrated product movement. Formal failures against unmodified master are separate findings. Never warm the target, wait for movement to stop, loosen the comparison or switch to the newest arriving reply to get a green result.
