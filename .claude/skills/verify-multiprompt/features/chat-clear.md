# Clear a server chat

Journeys: server-chat

## Sub-features

- Clear the current Claude context without changing the chat's address.
- Hide earlier messages, including after reloading, without deleting their transcripts.
- Send a new message once and show its reply without `Not sent`.

## How to get to it (user POV)

In a server chat, type `/clear` into the message box and press Enter. Do not substitute Reset this chat or Fresh start.

## Driving it with drive.ps1

Use `feature=server-chat` through `verify.yml` on GitHub Windows. The [server chat recipe](server-chat.md) owns the isolated SSH/tmux host and deterministic provider.

1. Open the seeded chat and send a message normally.
2. Type `/clear`, dismiss completion with Escape, and press Enter.
3. Require a new host context and zero provider prompts containing `/clear`.
4. Copy the visible transcript and require no messages. Run Resync chat through Ctrl+K, then require it to remain empty.
5. Send a new unique message. Require one provider receipt, its visible reply, no old messages and no `Not sent`.

Inspect `open.png`, `clear.png`, `clear-reloaded.png`, `after-clear.png`, copied text, server snapshots and `journey.mp4`. Require all four result cases, Doctor and cleanup to pass.

## Gotchas

The host, reader, message store and Windows UI are production code. Only the paid Claude process is replaced. A new provider conversation is proven; Claude's internal context handling is not. Busy clears retain the command and show a header explanation. Ordinary terminal chats and commands with arguments still use the existing send path.
