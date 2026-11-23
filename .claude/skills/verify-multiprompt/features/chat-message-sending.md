# Send and queue messages

Journeys: chat-delivery, chat-send-latency, chat-not-sent-remove

## Sub-features

- Send with Enter, Ctrl+Enter or Send; insert a newline with Shift+Enter; queue while busy or disconnected, retry or remove failed messages, and steer supported terminal agents.

## How to get to it (user POV)

Select a chat and type. Enter or Ctrl+Enter sends unless a command suggestion is open. The Send button sends the draft. With an empty composer, Up selects the newest message, which may be waiting; Enter opens its actions. Delete can discard unsent messages directly from the empty composer. Ctrl+K offers Send Queued Messages Now, conditional Discard Unsent Messages and searched Edit Queued Messages. Retry remains a message action; its old palette handler alone does not create a row.

## Driving it with drive.ps1

Preconditions: a healthy hosted Windows instance, matching executable/hash/version and the exact Part A/B or provider prerequisites below. The named Journeys are supporting existing routes; they do not exercise the complete path unless explicitly stated.

1. Send distinct idle messages using each entry point and one multiline message on the merged `feature=server-chat` host. Part A's real-size profile never landed.
2. While a reply is running, send three numbered messages. Require their receiving-host order, exactly one copy of each, and retained conversation identity.
3. Interrupt transport, send two more messages, remove one, reconnect and retry the other. Require no removed message at the receiver and exactly one retry.
4. In a supported terminal Claude session, test Ctrl+X then Ctrl+S steering separately. Do not claim live-host steering from a terminal stand-in.
5. Keep timestamps, native draft reads, screenshots, host receipts and zero-owned-process cleanup together.

Existing `chat-delivery` checks busy/grey/steer cases through a scripted console boundary. `chat-send-latency` and `chat-not-sent-remove` add focused native checks. Read each boundary before claiming coverage.

The recipes distinguish existing focused journeys from unreachable complete paths. UNREACHABLE names the missing data, endpoint, build mode or driver action; it never means the product passed.

### send: Send, queue, retry and remove

Follow the priority send recipe above; exercise each named queue action only on its originating tab.

Observable proof: Independent host receipts show exact order/count, removed messages never arrive and draft/newline semantics remain exact.

Journey: chat-delivery, chat-send-latency, chat-not-sent-remove. Complete real-host proof needs transport control the merged `server-chat` host does not expose to the driver; busy-queue product changes belong to SOFT-2566.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_CHAT_DISCARD_UNSENT_OFFSET` | Ctrl+K, type **discard unsent messages**, then select the matching action with Up/Down and Enter. Follow `send` above. |
| `SEARCH_CHAT_EDIT_QUEUED_OFFSET` | Ctrl+K, type **edit queued messages**, then select the matching action with Up/Down and Enter. Follow `send` above. |
| `SEARCH_CHAT_PUSH_QUEUED_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_CHAT_QUEUE_CLEAR_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_CHAT_QUEUE_SEND_OFFSET` | Ctrl+K, type **send queued messages now**, then select the matching action with Up/Down and Enter. Follow `send` above. |
| `SEARCH_CHAT_RETRY_UNSENT_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |

### Individual queue controls

- **Send Queued Messages Now:** queue two numbered messages while transport is unavailable, restore transport and choose the row. Require one receipt per message in order.
- **Edit Queued Messages:** in a supported terminal Claude chat, queue a marker, choose the row, edit the recovered prompt, then submit. Require the revised text once, not both versions.
- **Discard Unsent Messages:** create two Not sent messages, choose the row and require their removal from the native transcript and app-written outbox, with no receiving-host receipt.
- **Send again:** use a failed message's context action after restoring transport. Require exactly one retry of that message. The old Retry palette ID is not currently inserted into results.

These complete paths remain unreachable: the merged `server-chat` host gives real transport receipts but the driver does not yet cut transport or exercise these exact controls.

## Gotchas

UNREACHABLE for the complete real-server sequence until the driver can cut and restore the `server-chat` transport, read its host receipts and reach each send/retry/remove input. Busy live-host queue behavior is tracked by SOFT-2566; do not duplicate its fix.

Part A ([PR 1070](https://github.com/valentinyeo/multiprompt/pull/1070), `seed-profile.py`, `seed-profile.ps1`, the `chat-real-size` journey) was closed unmerged, so master still has no real-size seeded profile. Part B ([PR 1072](https://github.com/valentinyeo/multiprompt/pull/1072)) merged on 2026-11-18 as the runner-owned SSH/tmux [server chat](server-chat.md) journey, which runs as `feature=server-chat`; use it rather than adding another server fixture. Do not add replacement real-size fixtures here until a Part A equivalent lands.
