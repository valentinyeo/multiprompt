# A chat stays still

Source files: src/chat*, src/app_state.zig, src/chat_layout_snapshot.zig, src/layout.zig, src/window_layout.zig, src/browser_pane.zig, src/drawing.zig, src/main.zig, build.zig, build.zig.zon, tools/chat-still/*, tools/verify-chat-still, tools/verify-chat-delivery/*, .claude/skills/verify-multiprompt/control-feature-chat*, .github/workflows/chat-still.yml

Verify on: pull_request

## Sub-features

- A reader who scrolls up keeps the newest visible message at its exact screen rectangle from the first nonempty frame after that input. A reader at bottom follows new arrivals instead, as required by MUBO-280 and verified by `chat-messages-only` and `chat-newest`.
- No scrolling, tolerance, warm-up frame, settle delay or baseline reset is permitted after that frame.
- Observe at least two seconds without input, then at least two seconds overlapping a streaming reply.
- A missing anchored message, blank repaint, dirty layout or first-paint width mismatch fails immediately.
- The message selected in the first frame remains the reference throughout idle, streaming and settlement. A new reply does not replace it. Only deliberate scrolling may start a different viewing position; this journey sends no further input after the initial wheel notch.
- The pill floats over the transcript without reserving a band, so a pill arriving never changes the transcript layout, the message rectangle or the on-screen crop.
- A pixel change anywhere in the message fails, except inside the app's own floating new-message pill. The oracle reads that pill's rectangle from the app's log and masks the whole pill; any other change, and any undeclared pill, still fails.

## How to get to it (user POV)

Switch from one Chat View session to another long session with Ctrl+2. Scroll up one wheel notch to read older messages, then leave it alone while the agent replies.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=chat-still` and download `verify-chat-still`.

The existing remote boundary seeds five saved Chat View tabs and 400 question/answer rounds per transcript before launch. No app cache or layout state is written. The initial tab must actually render. Genuine Ctrl+2 input switches to the second chat, whose probe must report a nonempty bottom frame. An ownership-checked SendInput wheel notch scrolls up. The observer consumes the log from immediately before that wheel input and keeps its first resulting frame as the continuous baseline across idle, streaming and settlement. Every observed frame must report `up=1`; a no-op wheel or accidental return to bottom fails rather than silently testing the wrong reader state.

`tools/chat-still/observer.cs` samples on each DWM composition frame. The verification build injects a read-only `WM_PAINT` measurement probe from `tools/chat-still/paint.zig`; no probe is added to shipped product code. Its original source, instrumented source and probe hashes are retained in `chat-still-instrumentation.json`, including for base comparisons. It emits complete, unthrottled visible message rectangles only under `MULTIPROMPT_CHAT_STILL_PROOF=1` and `ZIGSHELL_DEBUG=1`. Each display sample also captures actual screen pixels with `Graphics.CopyFromScreen`, compares every RGB byte inside the fixed visible message crop, and records the crop and SHA-256. A blank first crop fails; no frame is discarded to establish a later baseline. First, last and failing pixel crops are retained as PNGs. The observer consumes every completed native paint between samples too, so a one-paint displacement that returns before the next sample still fails. Each display sample converts the retained message rectangle through the live transcript HWND's screen origin. Each paint must already have a clean layout at the actual client width. The final message in the first visible frame becomes the fixed identity; later rows cannot silently replace it.

The observer keeps one identity and one baseline continuously across both phases; it never resets them at streaming start. It also reads the app's verbose `[chat] new messages count= visible= up= rect=` line, which declares where the floating new-message pill is painted in main-window client coordinates, converts that rectangle to screen coordinates and masks exactly it, widened by two pixels for the pill's painted border. The mask never grows to cover anything the app has not declared, and a declared pill outside the message crop masks nothing. The pill's 30px band is always reserved, so the crop is expected to stay put when the pill appears; a crop that moves still fails. After 2,100 ms idle and a real `events_subscribe`, it releases the synthetic provider. The boundary calls the production `host_event`, `message_events_page` and `events_push` paths with 30 increasing `text.delta` snapshots over three seconds, then `text.done` and a matching final provider JSONL record. The observer continues for 4,200 ms after streaming starts, including at least one second after the canonical history write. The journey requires at least ten emitted chunks and ten subscription-pushed deltas overlapping observation, at least two native paints and two different laid-out content heights. Each phase needs at least 30 display-frame samples. Missing prerequisites fail rather than skip. The host thread belongs to the app-owned remote boundary and dies with its verified process tree.

Inspect `chat-still-idle.json`, `chat-still-streaming.json`, the chunk receipt, raw debug log, before/action/after screenshots, Doctor and owned-process cleanup. Samples retain all four screen edges, identity, time, layout width, dirty state and the masked pill rectangle. The exact rectangle comparison uses zero pixel tolerance. `observer.test.ps1` proves rejection of a one-pixel change in each edge, dirty first paint, wrong width, disappearing identity, a blank repaint, a pixel change outside the declared pill, and acceptance of a change inside it.

Chat-related source changes force this journey into the PR verifier's selection ahead of optional journeys. The Chat stillness workflow runs the same journey nightly on master and on request, outside the picker and the arithmetic check, and it fails the night rather than the pull request.

## Gotchas

This is the real native Windows UI on a GitHub-hosted runner, with only remote SSH/tmux/provider input replaced. It does not verify real network timing, a signed-in agent, GPU scanout or undrawn pending outbox bubbles. The diagnostic supplies message identity and bounds, while the independent screen capture verifies the displayed pixels. DWM sampling plus every native paint covers rendered position changes, not an absolute proof of every display driver.

The observation after the canonical write covers the settlement window, but does not independently prove that every written record was consumed. Screen pixels are compared at every sampled DWM frame with zero RGB tolerance; only the unused alpha byte in the RGB bitmap and the pixels the app itself declares as its floating new-message pill are ignored. Animated content is outside this fixed-text fixture. Published executables have no measurement probe and are not supported by this branch-build-only journey. Both candidate and base source builds receive the identical read-only probe. Do not report missing instrumentation as demonstrated product movement. Formal failures against unmodified master are separate findings. Never warm the target, wait for movement to stop, loosen the comparison or switch to the newest arriving reply to get a green result.
