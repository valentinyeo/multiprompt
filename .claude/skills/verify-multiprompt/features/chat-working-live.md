# Hosted live working dots

Source files: src/chat*, src/terminal*, src/chat_markdown*.zig, src/chat_connectors/*, src/tmux*, src/message*, src/chat_history_reader.py, tools/verify-chat-delivery/*, src/main.zig, build.zig, build.zig.zon, src/command_palette.zig, src/shortcuts.zig, tools/verify-chat-delivery/working-live.ps1

## Sub-features

- Real composer Enter to three painted dots within 1000 ms.
- Dots animate after the subscribed live turn starts.
- Dots remain with a visible live reply before turn end.
- Two real follow-up messages stay queued while the dots animate.
- A server chat with completed live events and unchanged history stays still for five seconds, with zero layouts and at most one transcript paint between counter samples.
- Reading an older message stays still while at least six reply deltas arrive below the viewport. Message identity, source offset, screen Y and cropped message pixels must remain unchanged for five seconds. Actual paint and layout deltas remain in `steady-position.json`.

## How to get to it (user POV)

Open the saved remote tab, open Chat View, type a message and press Enter.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=chat-working-live` on a branch build. The idle and streaming checks require the app's position and paint-counter diagnostics. The workflow selects the existing chat-delivery driver. It runs two isolated app profiles. `working-live` retains the original send-to-dots timing and animation gates with short history. `steady-live` uses an idle terminal, known long history, idle counters and reading-time streaming checks. Scrolling to expose the reply in this second case is not a send-latency measurement. Inspect both evidence directories, particularly timestamped BMP transcript captures, `timing.json`, `actions.json`, `stand-in/working-host.jsonl`, `doctor.json`, `result.json` and `cleanup.json`. The checker requires the production message store's queued event, matching dispatch, subscription pushes, a timely screenshot, animation after the turn-start push, the copied reply, reply pixels alongside working dots, and animated dots after two real follow-up messages queue. Capture end times use a monotonic stopwatch started before SendInput; filesystem writes and image analysis are not counted as capture time.

The remote shell and provider are stand-ins. The provider stand-in runs production message dispatch in a thread, substitutes host ownership and delivery, and writes production host events through the app-supplied reader's event store. The existing Windows notification polling fallback delivers the real subscription pages. In `steady-live`, before sending, it seeds 50 known paragraphs through the production host archive and emits a seed turn-ended event. This leaves a nonzero live revision during the idle observation without duplicate live rows. The dispatched turn sends growing text deltas but deliberately no turn-ended event, so the reply must retain dots while the turn remains active. The journey then submits two real follow-up messages, requires both queued records from the production message store, and checks that the dots still animate. No credentials or paid provider are used. The app, composer, outbox, message store, subscription, window loop and painter are real.

Recorded hosted proof: https://github.com/valentinyeo/multiprompt/actions/runs/42368960296 passed on `f6fefa003`. Downloaded `verify-chat-delivery/result.json` reports `passed`; both cleanup records report zero remaining owned processes and removed scratch directories. This is the simulated-provider boundary above, not a real provider acceptance claim.

The `Verify steady chat` workflow runs this same driver against the instrumented pre-idle-fix app at `596e3261` and the candidate. Its baseline artifact is `verify-chat-delivery-596e3261e9e77ce193ab7addbfd3001892242331`; the candidate artifact is `verify-chat-delivery`. During the idle window, the stand-in appends blank JSONL lines every half-second. The file cursor advances but no message changes. At least six such refreshes must occur inside the measured window. The baseline must fail the idle layout or paint assertion, not setup. The workflow's counter job rejects an unexpectedly quiet baseline and requires the candidate's full checker to pass. The driver creates empty isolated host directories before concurrent readers start, then uses production archive and event APIs to fill them.

## Gotchas

The driver requires an already-running subscribed turn with visible dots before Enter. Its Enter-to-dots assertion proves continued visibility within the bound, not idle-to-working onset caused by that send.


This is not proof of a real provider, real SSH, provider startup or the normal external message-worker process. Timing includes the actual hosted runner and stand-in transport, not production network or provider latency. A passing portable checker test is not a hosted desktop result. Require the Windows artifact and inspect the screenshots; no pass is claimed until that run succeeds.
