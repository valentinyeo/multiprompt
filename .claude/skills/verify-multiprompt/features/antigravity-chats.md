# Antigravity chats

Source files: src/session.zig, src/json_reader.zig, src/vps.zig, src/agent_host.zig, src/capacity.zig, src/archive.zig, src/notifications.zig, src/shell_poll.zig, src/workspaces.zig, src/chat_mention.zig, src/chat_transcript.zig, src/command_palette.zig, src/shortcuts.zig, tools/fixtures/SOFT-3050/*, tools/verify-chat-delivery/boundary.py, tools/verify-chat-delivery/antigravity-chats.ps1, tools/chat-antigravity-proof.cjs, tools/pi-codex-continuity.py

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

The journey fails unless the tab actions menu opens from a real right-click on the app-reported tab row and selects 7176; the switch attempt during the held reply is recorded `status=busy reason=chat_busy` while the Antigravity config and session id stay unchanged; the switch back leaves one row with the same name, every earlier message and both Switch AI dividers in the Claude history and in the conversation copied through Ctrl+K Select All and Ctrl+C after the real renderer has loaded it; the switch leaves one row with the same name; the handed-over history still holds the earlier message; the Antigravity fixture receives both the handover and the new message, its reply reaches the switched chat, and the new session tab opens in Chat View named Antigravity with `host start antigravity` in its launch command. It also fails unless the app's own poll cache lists `agy-pane` with agent `8`: that value comes only from `tmuxAgentFromPaneCommand` reading the `agy` pane command, so a pane command that falls through to `0` leaves the journey red.

Inspect `antigravity-chat-before.png`, `antigravity-switch-palette.png`, `antigravity-tab-menu-switch.png`, `antigravity-switch-while-replying.png`, `antigravity-switched-chat.png`, `antigravity-switch-back-claude.png`, `antigravity-new-session-palette.png`, `antigravity-new-session.png`, `antigravity/host/` config and history files, `antigravity/session-after-switch.json`, `antigravity/session-after-switch-back.json`, `antigravity/session-new-session.json`, `antigravity/tab-menu.json`, `antigravity/switch-while-replying.json`, `antigravity/switch-back.json`, `antigravity/claude-back-config.json`, `antigravity/claude-back-history.jsonl`, `antigravity/agy-pane-agent.json`, `actions.json`, `doctor.json`, `build.json`, `cleanup.json`, and the stand-in `agy-agent.jsonl`, `agy-received.jsonl`, `antigravity-hold.jsonl` and `antigravity-switch.jsonl`.

`result.json` carries one line per case: `antigravity-chats`, `switch-back-to-claude`, `tab-menu-switch-ai` and `switch-while-replying`. Its `cleanup` field records what the owned job stopped and what scratch was removed. The notice that refuses a switch during a reply is painted in the app header, so only `antigravity-switch-while-replying.png` shows its exact wording; the same refusal is written as text in `switch-while-replying.json` and `antigravity-switch.jsonl`.

### Pi Codex plan proof first

Run `gh workflow run chat-auto-switch.yml --ref <branch> -f real_pi_codex=true`. Its optional `real-pi-codex` job runs only on public GitHub-hosted Ubuntu. The normal recorded auto-switch journey remains unchanged and still runs independently.

The real job reuses the existing `CODEX_AUTH_JSON` plan secret inside the runner. It creates no key, login, account or SSH access. An absent, unsupported or soon-expiring OAuth session fails before a model call; the job never refreshes it or chooses an API-key substitute. Only the runner consumes the existing secret; no secret value enters the model transcript or retained artifact. Pi and Codex client versions and the real valentin-mode skill source are pinned in the workflow.

The production host creates a disposable Pi chat on `openai-codex/gpt-6.1-sol`. A real reply remembers a fresh marker. `/valentin-mode` must cause an actual skill-file read in that Pi session, followed by a real reply recalling the marker. The production Switch AI request moves the same chat to the real Codex connector and back to Pi. Pi's existing model-selection request selects Codex Sol again, with its real acknowledgement and native model-tagged reply required. Earlier records must remain byte prefixes of their original files, and every original user/assistant history row must remain in order. The saved face, login, tmux address and working directory must remain unchanged; automatic fallback stays off. A final continued reply and owned-host cleanup are required.

Inspect `real-pi-codex/summary.json` for the exact HEAD, actual prompts/replies, model/catalog evidence, native transcript hashes, both switches, skill-read assertion and owned cleanup. Missing credentials, unavailable skill checkout, provider errors or failed recall leave the job red. This is real reader/provider proof, not Windows keyboard, visible-history, AgY, DeepSeek or deployment proof. The desktop journey and its copied/rendered-history assertions remain mandatory. Returning to Pi currently starts its normal default before the model-selection request; the proof does not replace that with a test-only model override.

### Real-provider continuity proof

The fixture journey above does not satisfy this proof. Run only on a public GitHub-hosted Windows runner with the real branch executable and approved, existing provider access. Missing access blocks the run; do not copy credentials from a developer machine or substitute another model. Do not use an owner or orchestrator chat.

1. Record the branch HEAD, executable hash, Doctor result, provider versions, `agy models`, and Pi's model catalog. Require `gemini-4-neon-medium`, `opencode-go/deepseek-v4.1-flash`, and `openai-codex/gpt-6.1-sol`. Catalog presence alone does not prove working access.
2. Create one disposable named Pi chat using the real app. Turn off **Chat View: Auto-switch AI when a plan runs out** for this chat so a quota error cannot send it to another provider. Select DeepSeek Flash in Pi's model picker. Send a new random continuity marker and ask the model to remember it. Keep the resulting user and assistant records unchanged.
3. Send `/valentin-mode` through the composer. Require evidence that the installed skill loaded, not merely that the model repeated its name. Send another message and require a reply that recalls the continuity marker without putting the marker in that message.
4. Use Ctrl+K **Switch AI to Antigravity**. Require the real `agy` process to select `gemini-4-neon-medium`. The same chat must retain its name, picture, workspace, order, address, and all previous messages. Require a continued reply recalling the marker, then repeat `/valentin-mode` and send another message.
5. Switch the same chat to Pi with Ctrl+K. Select `openai-codex/gpt-6.1-sol` with Pi's model picker. Require the real Pi model-change acknowledgement, a continued reply recalling the marker, `/valentin-mode` loading, and another successful message.
6. In that Pi session, select `opencode-go/deepseek-v4.1-flash` again. Require a continued reply and the same Pi session identity. Switch to Antigravity again, continue the conversation, then switch back to Pi and select Codex Sol again. Require a reply after each transition.
7. Copy the complete displayed conversation before and after every transition. Independently compare the ordered original user and assistant messages, allowing only appended messages and Switch AI dividers. Retain the original provider transcript files and record their hashes before and after. A file can grow; no original record can disappear or change.
8. Retain screenshots, genuine input actions, model acknowledgements, process arguments, provider transcript identities, copied conversation, and isolated-profile state privately. Publish only sanitized proof. Require owned-process cleanup and an independent verifier from another model family at the same current-base HEAD before merge.

Antigravity launches default to the catalog-confirmed `gemini-4-neon-medium`. An explicit `--model` remains unchanged. The launch does not choose a substitute model when Neon is unavailable. Pi DeepSeek and Pi Codex use the same Pi connector with different provider/model selections; they are not separate Switch AI provider identities. A Switch AI handover supplies recent context, not the full retained transcript, so visible-history preservation and model recall need separate assertions.

## Gotchas

The Antigravity provider is a repository fixture, not the real CLI: replies are synthetic, no model quality, billing or live Antigravity account is verified. The Claude side of a switch back is served by the same fixture host store, so it proves the app, host store, config and history behaviour, not waking a real Claude process. The new Antigravity session is spawned through the SSH stand-in, so its console and agent transport are stand-ins too; the tab, its Chat View and the routed launch command are real app behaviour.
