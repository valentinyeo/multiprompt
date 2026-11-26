# Queued messages tray

Source files: src/chat_queue.zig, src/chat_queue_view.zig, src/chat_echo.zig, src/chat_send.zig, src/chat_render.zig, src/chat_composer.zig, src/chat_history_reader.py, src/app_state.zig, tools/chat-history-reader-test.py, .github/workflows/chat-queued-messages.yml, .claude/skills/verify-multiprompt/features/chat-queued-messages.md

CI workflow: chat-queued-messages.yml

## Sub-features

- A chat with at least one message waiting to send docks a compact card in the space directly above the message box. The card reads **Queued Messages**, a count badge, the muted line **Sends after agent finishes working**, and a chevron on the right.
- Each waiting message gets one row: its text on a single shortened line, then Send now, Edit and Delete.
- Send now asks the chat to take that message before the rest. Edit pulls the text back into the message box and takes the message out of the queue. Delete cancels the message without sending it.
- The chevron collapses the tray to its header row and expands it again. A queue that drains to zero removes the tray and gives its space back to the transcript. Messages that already failed keep their existing in-bubble **Not sent** treatment; the tray never adds a status line under a message bubble.

## How to get to it (user POV)

Send a message to a chat whose agent is still working. The message waits, and the tray appears above the message box. Click the chevron to collapse it, the arrow to send early, the pencil to edit, or the bin to delete. Nothing else has to be open.

## Driving it with GitHub CI

This surface is proved by `.github/workflows/chat-queued-messages.yml` on GitHub Linux; it is not a Windows desktop journey:

```sh
gh workflow run chat-queued-messages.yml --ref <branch>
```

1. `zig test src/chat_queue.zig` runs the tray model, single-line shortening, six-row cap, header-only collapse, docked-above-the-composer geometry and the Send now / Edit / Delete / chevron hit boxes.
2. `python3 tools/chat-history-reader-test.py MUBO_594_QueuedMessageActionsTest -v` lists queued messages from the shared store and proves edit in place, cancel-and-hand-back, delete, send-now promotion and the idempotent repeat of each.
3. It writes `summary.json` into the `chat-queued-messages` artifact, naming the head revision, the exit code and both checks. The PR verifier reads that file as this feature's CI receipt.

Observable proof: the tests exit 0, the run's head revision matches the pull request head, and the artifact's `summary.json` names the same revision. The painted card and clicks need the paired Windows transcript journeys below.

### Windows desktop pairing

The tray is painted into the transcript window and handled before transcript selection, so these existing journeys cover the change surface and must stay green: `feature=chat-still` (exact newest-message rectangle while the tray is absent), `feature=chat-delivery` (queued, busy and steer cases) and `feature=chat-send-latency`. They do not yet press the tray buttons; that driver path stays UNREACHABLE until a `verify.yml` recipe seeds a busy host chat, waits for the tray, and clicks Send now, Edit and Delete.

## Gotchas

- The tray height is subtracted from the transcript bottom inside `chatViewLayout`, so the messages above it never paint behind the card. Any new element in that strip must reserve its own height the same way, or it will overlap the New messages pill.
- The outbox entry, not a second copy of the text, is the source of truth. A message leaves the tray when its outbox state stops being `queued`, which is also what makes the tray disappear on its own.
- Edit and Delete reuse the existing dismiss path, so a queue that the shared store already dispatched cancels exactly like the message menu's Cancel item. Behaviour on a terminal-backed chat is unchanged.
- The new shared-store operations are additive on message protocol 1. Older Desktop and Android clients never send them and keep working untouched.
