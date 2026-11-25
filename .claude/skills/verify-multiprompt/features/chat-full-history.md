# Every session message

Source files: src/chat*, src/terminal*, src/chat_markdown*.zig, src/chat_connectors/*, src/tmux*, src/message*, src/chat_history_reader.py, tools/verify-chat-delivery/*, src/main.zig, build.zig, build.zig.zon, src/command_palette.zig, src/shortcuts.zig, tools/verify-chat-delivery/drive.ps1, tools/chat-full-history-proof.mjs

## Sub-features

- A long session opens with all 50 known user/assistant messages in order, not just its recent tail.
- The same 50 messages remain available after a normal owned-app restart with the same profile and app-written cache.
- All 264 tool blocks reach layout but remain invisible under the existing messages-only policy.
- The app's own reader opens on a tail frame that holds at least one user or assistant row (`chat-tail-frame-holds-message`), so no message-less frame reaches the renderer.
- Chat View shows a thin scrollbar and, once scrolled up, a round down-arrow button; one wheel notch moves at least as far as a browser notch, and one click on the button returns to the newest message.

## How to get to it (user POV)

Select the session with Ctrl+1 and open Chat View with Alt+C. No scroll-to-load action is needed. Ctrl+K, `chat view select all`, followed by Ctrl+C copies the complete conversation.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=chat-full-history` and download `verify-chat-full-history`.

The existing delivery boundary creates its own ordinary Claude transcript: two initial messages, then 24 user/assistant pairs interleaved with large synthetic tool results, then 240 further tool calls for `chat-full-history` whose results fill the newest 1.3 MB. That tail is the SOFT-2779 shape: a reader tail window that reaches back only 512 KB lands entirely inside tool output and holds no user or assistant row, so the app has to page back before any message can be drawn. The source exceeds the reader's tail window. The harness seeds only its documented isolated remote tab and agent boundary, never the app's message cache.

Before the renderer is measured, `tools/verify-chat-delivery/tail-frame.py` runs the reader the app itself published (`app-reader.py` in the harness state) against that transcript and records `full-history/tail-frame.json`. The frame must hold at least one user or assistant row; that check fails on the merge base and passes on the fix.

On open, Ctrl+0 requires the production renderer to lay out 314 blocks. Ownership-checked visible transcript identity followed by genuine Ctrl+K, `chat view select all`, Enter and Ctrl+C must copy all 50 messages exactly once in source order. Capture the visible transcript after this assertion; no scroll input may repair a failing open. Close the owned app normally, stop its owned descendants, restart the identical executable/profile, and repeat the identical count, copy and screenshot assertions.

`tools/chat-full-history-proof.mjs` independently compares the copied text against the retained source transcript, checks both measured stages, build/Doctor identity and zero-process cleanup. Inspect the open/restart screenshots, copied text, debug log, `result.json`, `cleanup.json`, and the cache retained before restart.

The red run must execute this journey with the app source unchanged from origin/master at fada2dbdb0e7892e92d0ae3244a548804b41b249. An `IGSH-815 incomplete session at open` failure with successful Doctor/cleanup is the expected red, not build or launch failure. Run the same journey on the fixed branch for green and record both run URLs in the PR.

SOFT-2779 uses this journey as its repair repro. Its red run is the current master app source built against this harness (`check-red-run` with `feature=chat-full-history`): the app's own reader returns a tail frame of tool rows only, so `chat-tail-frame-holds-message` fails with `the tail frame holds no user or assistant row`. The desktop app masks the defect by fetching older pages until a message appears, which is why the app-level checks alone do not separate base from head. The head must pass `chat-tail-frame-holds-message` and still reach `IGSH815 assistant 23` at open and keep every message after the older-page request. A run that instead fails at launch, Doctor or a missing transcript is infrastructure, not the repair repro.

### Retained refresh performance (IGSH-1100)

Run `gh workflow run verify.yml --ref <branch> -f feature=chat-delivery -f chat_retention_proof=true`.
The retention journey preserves 2,000 messages through 200 arrivals, a source replacement, and an empty refresh. Every copied stage must remain complete, ordered, and unique. Every measured arrival, including the source replacement, remains below the existing 100 ms limit; repeated cached switches remain below 150 ms. Inspect `retention.json`, `full-history/retention-arrival.log`, and the before/after screenshots.

The production-history regression in `tools/chat-transcript-history.test.js` requires unchanged layout prefixes to survive replacement and same-length edited text to invalidate reuse. The last mutable message remains outside the reused prefix.


## Gotchas

Current harness gap: the driver can wheel upward when the expected block count is absent. Such a run proves eventual completeness, not the no-scroll completeness-at-open requirement above. Do not report that requirement passed until the driver independently asserts it before scrolling. Real-size data belongs to Part A.


This is a synthetic Claude/SSH/tmux boundary on GitHub's free Windows runner, not a signed-in live agent. Production transcript discovery, Python reader, history/cache, native layout, selection/copy and app restart are real. No desktop, build or test runs on the VPS. Existing driver condition observations are reused; no new timing constants, page limits or row caps are introduced.
