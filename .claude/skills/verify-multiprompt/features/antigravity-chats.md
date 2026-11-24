# Antigravity chats

Source files: src/vps.zig, src/agent_host.zig, src/capacity.zig, src/archive.zig, src/notifications.zig, src/shell_poll.zig, src/workspaces.zig, src/chat_mention.zig, src/chat_transcript.zig, src/command_palette.zig, src/shortcuts.zig, tools/fixtures/SOFT-3050/*, tools/verify-chat-delivery/boundary.py, tools/verify-chat-delivery/antigravity-chats.ps1, tools/chat-antigravity-proof.cjs

## Sub-features

- Start a new chat on Antigravity from Ctrl+K and land in its Chat View.
- Switch an existing Claude chat to Antigravity and keep its row, name and readable history.
- Send a message after the switch and read the reply that comes back under the same chat.
- Switch the same chat back to Claude and keep the rows, name and history.
- Reach Switch AI from the chat tab's right-click menu, not only Ctrl+K.
- Ask for a switch while the chat is still replying: it is refused and the reason is shown.
- Read a server tmux pane whose command is `agy` as an Antigravity session in the app's tmux list.

## How to get to it (user POV)

Ctrl+K, type **new antigravity sessions**, then choose the row with Up/Down and Enter. The new tab opens in Chat View on Antigravity.

In a live Claude chat, Ctrl+K, type **switch ai to antigravity**, then choose the row with Up/Down and Enter. The chat keeps its sidebar row, name, photo and address; earlier messages stay above a Switch AI divider, and the next message is answered by the new provider. Right-click the chat row, type **switch ai to claude**, and the tab actions menu offers the same Switch AI rows; the same chat moves back to Claude with every earlier row kept under a second divider. Asking for a switch while the chat shows a reply still being written is refused: the header shows **Switch AI: wait for this reply to finish** and the chat stays where it is.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=antigravity-chats` on the branch, without a release tag. `control.ps1` runs the chat-delivery driver and the job uploads `verify-antigravity-chats`.

One saved tmux tab and the stand-in remote shell are seeded before launch; only SSH is replaced. The stand-in answers the app's tmux inventory with the capacity line and one extra pane, `agy-pane`, whose `pane_current_command` is `agy`, so the app reads a real `agy` pane on its own poll. The app supplies its embedded reader unchanged and the fixture serves that reader's production host store in an isolated home, so the first message and its reply run through the real host store with no live Claude process. `agy.exe` is a repository fixture that speaks the Antigravity stream-json protocol; the runner has no real Antigravity CLI. The fixture serves the Claude side of a switch from the same host store and records the target start in `antigravity-claude-start.jsonl`, so a switch back is proved without a live Claude process.

The journey sends one message in the Claude chat, switches with Ctrl+K to Antigravity, opens the tab's right-click menu and selects **Switch AI to Claude** there (target 7176, so the chat-view copy 7050 cannot stand in), sends a second message while the fixture holds the reply open, tries Ctrl+K **switch ai to claude** against that held reply, releases the reply, switches back to Claude with Ctrl+K, then starts a new Antigravity session from Ctrl+K. Each Ctrl+K step reads the highlighted row's target id from the palette log (5109 for New Antigravity Sessions, 7053 for Switch AI to Antigravity, 7050 for Switch AI to Claude), so a look-alike row cannot stand in.

The journey fails unless the tab actions menu opens from a real right-click on the app-reported tab row and selects 7176; the switch attempt during the held reply is recorded `status=busy reason=chat_busy` while the Antigravity config and session id stay unchanged; the switch back leaves one row with the same name, every earlier message and both Switch AI dividers in the Claude history; the switch leaves one row with the same name; the handed-over history still holds the earlier message; the Antigravity fixture receives both the handover and the new message, its reply reaches the switched chat, and the new session tab opens in Chat View named Antigravity with `host start antigravity` in its launch command. It also fails unless the app's own poll cache lists `agy-pane` with agent `8`: that value comes only from `tmuxAgentFromPaneCommand` reading the `agy` pane command, so a pane command that falls through to `0` leaves the journey red.

Inspect `antigravity-chat-before.png`, `antigravity-switch-palette.png`, `antigravity-tab-menu-switch.png`, `antigravity-switch-while-replying.png`, `antigravity-switched-chat.png`, `antigravity-switch-back-claude.png`, `antigravity-new-session-palette.png`, `antigravity-new-session.png`, `antigravity/host/` config and history files, `antigravity/session-after-switch.json`, `antigravity/session-after-switch-back.json`, `antigravity/session-new-session.json`, `antigravity/tab-menu.json`, `antigravity/switch-while-replying.json`, `antigravity/switch-back.json`, `antigravity/claude-back-config.json`, `antigravity/claude-back-history.jsonl`, `antigravity/agy-pane-agent.json`, `actions.json`, `doctor.json`, `build.json`, `cleanup.json`, and the stand-in `agy-agent.jsonl`, `agy-received.jsonl`, `antigravity-hold.jsonl` and `antigravity-switch.jsonl`.

`result.json` carries one line per case: `antigravity-chats`, `switch-back-to-claude`, `tab-menu-switch-ai` and `switch-while-replying`. Its `cleanup` field records what the owned job stopped and what scratch was removed. The notice that refuses a switch during a reply is painted in the app header, so only `antigravity-switch-while-replying.png` shows its exact wording; the same refusal is written as text in `switch-while-replying.json` and `antigravity-switch.jsonl`.

## Gotchas

The Antigravity provider is a repository fixture, not the real CLI: replies are synthetic, no model quality, billing or live Antigravity account is verified. The Claude side of a switch back is served by the same fixture host store, so it proves the app, host store, config and history behaviour, not waking a real Claude process. The new Antigravity session is spawned through the SSH stand-in, so its console and agent transport are stand-ins too; the tab, its Chat View and the routed launch command are real app behaviour.
