# Fresh start stays live

Source files: src/chat*, src/chat_history_reader.py, tools/verify-chat-delivery/*, src/command_palette.zig, src/app_state.zig

## Sub-features

- `reloading-reply-live`: after Fresh start, the reloading reply paints in the Chat View with the normal three ticking dots, not an empty or dead transcript.
- `message-held-during-reload`: a message typed in the real composer while the reload is pending is answered busy by the chat, stays a waiting bubble, and reaches the chat exactly once after the reload ends.

## How to get to it (user POV)

Open a hosted server chat in Chat View, press Ctrl+K, choose "Chat View: Fresh start" and press Enter. While the reload is pending, type a message in the composer and press Enter.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=chat-fresh-start` on GitHub Windows. The hosted stand-in serves its saved history as the chat display and answers `fresh_start` with a pending reload that streams a reply until the driver ends it. The owned app presses the real palette row (`target=6498`). `fresh-start-live.ps1` requires a captured frame whose running dots pass `chat-working-proof.mjs`, the streaming reply in the copied rendered conversation while the reload is still pending, a message typed into the real composer that reaches the host as `deliver-held` with the outbox row still waiting (never `failed` or Not sent), and exactly one `deliver` row for that text after the reload finishes. `chat-fresh-start-live-proof.mjs` re-derives all of that from the raw journal, outbox, copied transcripts, screenshots and cleanup receipts, and requires the final copied conversation to hold the message exactly once beside the reloading reply. Evidence stays in `verify-chat-fresh-start`.

## Gotchas

The stand-in host is not a real agent or SSH server, and the Windows-side dispatch loop is the harness stand-in for the server's message worker, so this journey does not exercise the reader's 90 second stall watchdog and cannot go red for a reader-side hold that is missing. `tools/chat-history-reader-test.py` covers that hold on Linux, and its red run is the proof for a change like MUBO-452. The pixel check needs the transcript scrolled to its newest row. A release-tag run of this journey requires the tag's embedded reader to already hold messages during a fresh start.
