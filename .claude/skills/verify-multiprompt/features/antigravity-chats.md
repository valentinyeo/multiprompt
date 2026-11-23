# Antigravity chats

Source files: src/agent_host.zig, src/capacity.zig, src/archive.zig, src/notifications.zig, src/shell_poll.zig, src/workspaces.zig, src/chat_mention.zig, src/chat_transcript.zig, src/command_palette.zig, src/shortcuts.zig, tools/fixtures/SOFT-3050/*, tools/verify-chat-delivery/boundary.py, tools/verify-chat-delivery/antigravity-chats.ps1, tools/chat-antigravity-proof.cjs

## Sub-features

- Start a new chat on Antigravity from Ctrl+K and land in its Chat View.
- Switch an existing Claude chat to Antigravity and keep its row, name and readable history.
- Send a message after the switch and read the reply that comes back under the same chat.

## How to get to it (user POV)

Ctrl+K, type **new antigravity sessions**, then choose the row with Up/Down and Enter. The new tab opens in Chat View on Antigravity.

In a live Claude chat, Ctrl+K, type **switch ai to antigravity**, then choose the row with Up/Down and Enter. The chat keeps its sidebar row, name, photo and address; earlier messages stay above a Switch AI divider, and the next message is answered by the new provider. The right-click tab row does the same.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=antigravity-chats` on the branch, without a release tag. The workflow selects the chat-delivery driver and uploads `verify-antigravity-chats`.

One saved tmux tab and the stand-in remote shell are seeded before launch; only SSH is replaced. The app supplies its embedded reader unchanged and the fixture starts that reader's production host in an isolated home with a synthetic Python Claude process, so the first message and its reply run through the real host store. `agy.exe` is a repository fixture that speaks the Antigravity stream-json protocol; the runner has no real Antigravity CLI.

The journey sends one message in the Claude chat, switches with Ctrl+K to Antigravity, sends a second message, then starts a new Antigravity session from Ctrl+K. Each palette step reads the highlighted row's target id from the palette log (5109 for New Antigravity Sessions, 7053 for Switch AI to Antigravity), so a look-alike row cannot stand in. It fails unless the switch leaves one row with the same name, the handed-over history still holds the earlier message, the Antigravity fixture receives both the handover and the new message, its reply reaches the switched chat, and the new session tab opens in Chat View named Antigravity with `host start antigravity` in its launch command.

Inspect `antigravity-chat-before.png`, `antigravity-switch-palette.png`, `antigravity-switched-chat.png`, `antigravity-new-session-palette.png`, `antigravity-new-session.png`, `antigravity/host/` config and history files, `antigravity/session-after-switch.json`, `antigravity/session-new-session.json`, `actions.json`, `doctor.json`, `build.json`, `cleanup.json` and the stand-in `agy-agent.jsonl` and `agy-received.jsonl`.

## Gotchas

The Antigravity provider is a repository fixture, not the real CLI: replies are synthetic, no model quality, billing or live Antigravity account is verified. The new Antigravity session is spawned through the SSH stand-in, so its console and agent transport are stand-ins too; the tab, its Chat View and the routed launch command are real app behaviour.
