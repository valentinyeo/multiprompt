# Chat switch-back replay

## Sub-features

- Switching away from a live host chat and back resumes its live subscription at the last seen event.
- Switching back does not replay the chat history page by page.
- Switching back does not redraw old turns in the transcript.

## How to get to it (user POV)

Open two saved remote tabs that are host chats, open Chat View in both, then switch from the first to the second and back.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=chat-switch-replay`. The workflow selects the existing chat-delivery driver. Inspect the `switch-replay` evidence: `observation.json`, `switch-return-chat-live.log`, `stand-in/switch-host.jsonl`, the `switch-a-before`, `switch-b`, `switch-a-replaying` and `switch-a-after` screenshots, `result.json` and `cleanup.json`.

The stand-in reader seeds each chat's host event store with long history through the production reader functions: chat A holds 400 complete turns (1200 events), chat B holds 3. The journey selects A and waits until its live subscription has delivered the full history, presses Ctrl+2 to switch to B, waits for B's subscription, presses Ctrl+1 to switch back to A and then samples the transcript pixels for nine seconds.

The checker reads only what happened after the switch back. It requires the `[chat-live] start` line for A to carry the last seen event number, at most one `[chat-live] page` line and at most one `[chat-live] draw` line for A, a reader subscription that starts at that same event number and no replay pages pushed by the reader. A run that restarts the stream from zero fails with the cursor, page and draw counts in one message. The number of distinct transcript states seen while sampling is recorded as evidence.

The remote shell and the agent host are stand-ins. The app, Chat View, live stream, reader subscriptions, event store, window loop and painter are real. No credentials or paid provider are used.

## Gotchas

The reader pushes one page per subscription every second on Windows, so the nine second window covers a five page replay. Hosted results are recorded in the pull request that ships the fix, not here. A passing portable checker test is not a hosted desktop result; require the Windows artifact.
