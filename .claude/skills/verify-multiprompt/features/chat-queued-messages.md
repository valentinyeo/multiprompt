# Queued messages tray

Source files: src/chat_queue.zig, src/chat_queue_view.zig, src/chat_echo.zig, src/chat_send.zig, src/chat_render.zig, src/chat_composer.zig, src/chat_history_reader.py, src/app_state.zig, src/main.zig, tools/chat-history-reader-test.py, tools/chat-delivery.test.js, .github/workflows/chat-queued-messages.yml, .claude/skills/verify-multiprompt/features/chat-queued-messages.md

CI workflow: chat-queued-messages.yml

## Sub-features

- A chat with at least one message waiting to send docks a compact card in the space directly above the message box. The card reads **Queued Messages**, a count badge, the muted line **Sends after agent finishes working**, and a chevron on the right.
- Each waiting message gets one row: its text on a single shortened line, then Send now, Edit and Delete.
- Send now moves that message ahead of the rest and dispatches it, even when it was already first. A busy stream host is interrupted by reopening the same native conversation; Codex steers its active turn and Pi uses a steering prompt. A message the host took but has not read yet stays waiting on the host, so Send now recovers that host, re-queues the same message under a new attempt and dispatches it once, without duplicating it. Edit pulls the text back into the message box and takes the message out of the queue, including a message the host took but has not read: the host is recovered and the message cancelled before its text returns. Delete cancels the message without sending it.
- The chevron collapses the tray to its header row and expands it again. A queue that drains to zero removes the tray and gives its space back to the transcript. Queued messages never also paint as transcript echo bubbles, including after reload or while the tray is collapsed. Once accepted they leave the tray and appear once in normal history. Messages that already failed keep their existing in-bubble **Not sent** treatment; the tray never adds a status line under a message bubble.

## How to get to it (user POV)

Send a message to a chat whose agent is still working. The message waits, and the tray appears above the message box. Click the chevron to collapse it, the arrow to send early, the pencil to edit, or the bin to delete. Nothing else has to be open.

## Driving it with GitHub CI

This surface is proved by `.github/workflows/chat-queued-messages.yml` on GitHub Linux; it is not a Windows desktop journey:

```sh
gh workflow run chat-queued-messages.yml --ref <branch>
```

1. `zig test src/chat_queue.zig` runs the tray model, single-line shortening, six-row cap, header-only collapse, docked-above-the-composer geometry, the Send now / Edit / Delete / chevron hit boxes and the one-refresh handoff a finished queue action leaves for the outbox timer.
2. `python3 tools/chat-history-reader-test.py MUBO_594_QueuedMessageActionsTest MUBO_601_UnacknowledgedSendTest -v` lists queued messages from the shared store and proves edit in place, cancel-and-hand-back, delete, send-now promotion, Send now and Edit on an unacknowledged hosted send, and the idempotent repeat of each.
3. `zig test src/chat_echo.zig` and `node --test tools/chat-delivery.test.js tools/scoped-pr-checks.test.js` prove queue-only visibility, stable retry IDs, confirmed local deletion and reload behavior. Source guards check comments, file sizes, runtime fingerprints, timers, the PR title and commit identities.
4. It writes `summary.json` into the `chat-queued-messages` artifact, naming the head revision, the exit code and both checks. The PR verifier reads that file as this feature's CI receipt.

Observable proof: the tests exit 0, the run's head revision matches the pull request head, and the artifact's `summary.json` names the same revision. The painted card and clicks need the paired Windows transcript journeys below.

### Windows desktop pairing

The tray is painted into the transcript window and handled before transcript selection, so these existing journeys cover the change surface and must stay green: `feature=chat-still` (exact newest-message rectangle while the tray is absent), `feature=chat-delivery` (queued, busy and steer cases) and `feature=chat-send-latency`. They do not yet press the tray buttons; that driver path stays UNREACHABLE until a `verify.yml` recipe seeds a busy host chat, waits for the tray, and clicks Send now, Edit and Delete.

## Gotchas

- The tray height is subtracted from the transcript bottom inside `chatViewLayout`, so the messages above it never paint behind the card. Any new element in that strip must reserve its own height the same way, or it will overlap the New messages pill.
- The outbox entry, not a second copy of the text, is the source of truth. A message leaves the tray when its outbox state stops being `queued`, which is also what makes the tray disappear on its own.
- Edit and Delete reuse the existing dismiss path, so a queue that the shared store already dispatched cancels exactly like the message menu's Cancel item. Behaviour on a terminal-backed chat is unchanged.
- A row leaves the tray only while the store still calls it `queued`. A hosted chat writes the row to its agent at once, so the store's state is `sent` with no receipt; Send now and Edit treat exactly that state as still waiting. Send now recovers the host and re-queues the row before dispatch, and Edit recovers the host and cancels it. A row the host accepted or started is no longer waiting and both actions leave it alone.
- The new shared-store operations are additive on message protocol 1. Older Desktop and Android clients never send them and keep working untouched.

### MUBO-601 recovery and compatibility

A hosted stream send without acknowledgement fails after 60 seconds. If stdout has also stopped for that interval, the host reopens the same native conversation without automatically repeating the message. Explicit Retry stops the old writer before creating a new attempt on the same shared message ID. Late acceptance may still confirm a timed-out attempt before retry; accepted messages cannot be retried or deleted as unsent. Delete persists cancellation before the outbox removes the row, and late receipts cannot revive it.

Desktop ticket: https://app.hypertask.ai/detail/project-13734/601. Paired Android ticket: https://app.hypertask.ai/detail/project-13734/602. Message protocol remains 1; old Desktop and Android clients retain the same row and event shapes, and benefit from hosted timeouts, retry and dismissal fixes. Android client changes and live phone proof remain owned by MUBO-602. Synthetic host tests do not claim live Antigravity or Android proof.
