# Every session message

## Sub-features

- A long session opens with all 50 known user/assistant messages in order, not just its recent tail.
- The same 50 messages remain available after a normal owned-app restart with the same profile and app-written cache.
- All 24 tool blocks reach layout but remain invisible under the existing messages-only policy.
- Chat View shows a thin scrollbar and, once scrolled up, a round down-arrow button; one wheel notch moves at least as far as a browser notch, and one click on the button returns to the newest message.

## How to get to it (user POV)

Select the session with Ctrl+1 and open Chat View with Alt+C. No scroll-to-load action is needed. Ctrl+K, `chat view select all`, followed by Ctrl+C copies the complete conversation.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref ceo/IGSH-815 -f feature=chat-full-history` and download `verify-chat-full-history`.

The existing delivery boundary creates its own ordinary Claude transcript: two initial messages, then 24 user/assistant pairs interleaved with large synthetic tool results. The source exceeds the reader's tail window. The harness seeds only its documented isolated remote tab and agent boundary, never the app's message cache.

On open, Ctrl+0 requires the production renderer to lay out 74 blocks. Ownership-checked visible transcript identity followed by genuine Ctrl+K, `chat view select all`, Enter and Ctrl+C must copy all 50 messages exactly once in source order. Capture the visible transcript after this assertion; no scroll input may repair a failing open. Close the owned app normally, stop its owned descendants, restart the identical executable/profile, and repeat the identical count, copy and screenshot assertions.

`tools/chat-full-history-proof.mjs` independently compares the copied text against the retained source transcript, checks both measured stages, build/Doctor identity and zero-process cleanup. Inspect the open/restart screenshots, copied text, debug log, `result.json`, `cleanup.json`, and the cache retained before restart.

The red run must execute this journey with the app source unchanged from origin/master at fada2dbdb0e7892e92d0ae3244a548804b41b249. An `IGSH-815 incomplete session at open` failure with successful Doctor/cleanup is the expected red, not build or launch failure. Run the same journey on the fixed branch for green and record both run URLs in the PR.

## Gotchas

This is a synthetic Claude/SSH/tmux boundary on GitHub's free Windows runner, not a signed-in live agent. Production transcript discovery, Python reader, history/cache, native layout, selection/copy and app restart are real. No desktop, build or test runs on the VPS. Existing driver condition observations are reused; no new timing constants, page limits or row caps are introduced.

## Retained refresh performance (IGSH-1100)

Run `gh workflow run verify.yml --ref <branch> -f feature=chat-delivery -f chat_retention_proof=true`.
The retention journey preserves 2,000 messages through 200 arrivals, a source replacement, and an empty refresh. Every copied stage must remain complete, ordered, and unique. Every measured arrival, including the source replacement, remains below the existing 100 ms limit; repeated cached switches remain below 150 ms. Inspect `retention.json`, `full-history/retention-arrival.log`, and the before/after screenshots.

The production-history regression in `tools/chat-transcript-history.test.js` requires unchanged layout prefixes to survive replacement and same-length edited text to invalidate reuse. The last mutable message remains outside the reused prefix.
