# Permission requests

Source files: src/chat_permission_requests.zig, src/chat_transcript.zig, src/chat_session.zig, src/attention_rules.zig, src/sidebar.zig, src/command_palette.zig, src/palette_text.zig, src/main.zig, src/shortcuts.zig, src/app_state.zig, src/chat_history_reader.py, tools/permission-requests.mjs, tools/mb.mjs, tools/fixtures/MUBO-282/*, .claude/skills/verify-multiprompt/control-feature-permission-requests.ps1

## Sub-features

A chat whose Claude Code auto mode safety check waits for a yes carries the open request in the status row the Chat View already polls. The tab shows the Waiting mark while it is open and drops it when the answer closes the step. `Ctrl+K -> Permission requests` lists every open request across chats, newest first, each row saying in plain words what the chat wants to do and why it waits. `mb permission-requests` prints the same rows from the local transcripts, and running it twice prints the same output. Answering is MUBO-282 part 2.

## How to get to it (user POV)

Press Ctrl+K and type `permission requests`. The row opens a sub-list whose first row is Back. With an open request the rows below it name the chat, the step and the reason, newest first; Enter on a row opens that chat.

## Driving it with control.ps1

Dispatch `feature=permission-requests` on the branch. The run opens the empty palette, types the query, reads the `[palette] rows` and `[palette] ready` traces, requires the entry id to be present, presses Enter, and requires the sub-list to open with the Back row first, then leaves through Back. Snapshots are captured before, at the entry, in the list, and after.

## Gotchas

A fresh isolated profile has no chats, so this journey proves the entry, the list opening and the Back row, not a populated request row. Populated rows come from the reader, which `tools/chat-history-reader-test.py` checks against the snapshotted auto mode transcripts in `tools/fixtures/MUBO-282/`; a live stalled chat needs the seeded real chat prerequisite owned by Part B (SOFT-2567). The Waiting mark is driven only once such a chat exists. Approve and decline are out of scope here; they belong to MUBO-282 part 2.
