# Switch a whole workspace to another AI

Source files: src/workspace_switch_ai.zig, tools/mb.mjs, tools/verify-chat-delivery/boundary.py, tools/verify-chat-delivery/workspace-switch-host.py, tools/verify-chat-delivery/workspace-switch.ps1, tools/workspace-switch-ai-proof.mjs, tools/verify-workspace-switch-ai/*, src/browser_bridge.zig, src/chat_history_reader.py, .claude/skills/verify-multiprompt/features/workspace-switch-ai.md

Verify on: push

## Sub-features

- `palette-switch-workspace`: Ctrl+K offers `Workspace: Switch every chat to Claude`, `...to Codex` and `...to Antigravity`, and one Enter moves every live agent chat of the active workspace to that AI, one at a time, keeping each chat's name, address and earlier messages.
- `history-kept`: each switched chat renders its earlier messages plus the `Switched AI: Claude to Codex` divider, and switching back adds the `Switched AI: Codex to Claude` divider, so the visible conversation and the saved session agree.
- `saved-state`: after the switch the saved session records the new agent for every tab and the new chat identity the server replied with.
- `antigravity-refused`: Antigravity is still refused by the host with `unsupported_provider`, so every chat stays where it is and the app paints `Workspace switch to Antigravity not finished: ... refused`.
- `mb-verb`: `node tools/mb.mjs workspace switch-ai <workspace> codex` lists the workspace through the real `zsb` command line, switches every chat individually and reports `ok`, `status complete` and the identities it switched.

## How to get to it (user POV)

Open a workspace that holds at least two live agent chats. Press Ctrl+K, type `switch all chats codex`, press Enter. Each chat moves to Codex in turn and keeps its earlier conversation. Repeat with `switch all chats claude` to move them back. An agent can do the same without the window from the command line: `mb workspace switch-ai <workspace> codex`.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=workspace-switch-ai` on GitHub Windows. The workflow selects the chat-delivery driver and uploads `verify-workspace-switch-ai`.

The saved tab, remote shell, tmux and provider CLI are fixture boundaries. Two saved Claude chats with history are seeded in one workspace, `ws-chat-one` and `ws-chat-two`, by the hosted stand-in in `boundary.py`; the production reader, `host_switch_ai`, the message store, `src/workspace_switch_ai.zig`, the `zsb` lane and the real desktop window are unchanged. Only the provider CLI start is replaced, exactly as `chat-auto-switch.yml` does on Linux.

1. Require both saved chats to load on Claude and copy each rendered conversation, which must hold its earlier question and reply.
2. Press Ctrl+K, type `switch all chats antigravity`, Enter. Require two `switch-reply` rows with `status refused` and `reason unsupported_provider`, the painted notice, and both chats still saved on Claude with their original identities.
3. Press Ctrl+K, type `switch all chats codex`, Enter. Require two `switched` replies, two Codex provider starts, the saved session holding the agent number and identity of every reply, and each copied conversation holding its earlier messages plus `Switched AI: Claude to Codex`.
4. Press Ctrl+K, type `switch all chats claude`, Enter, and require the same for Claude with `Switched AI: Codex to Claude`.
5. Read the app-owned loopback port, then run `node tools/mb.mjs workspace switch-ai "Verify workspace" codex --json` through a `zsb` wrapper that runs the shipped `src/mp_zsb.sh`. Require exit 0, `ok true`, `status complete`, `switched 2`, the saved identities equal to the reported ones, and the same visible conversations and Codex divider.
6. Inspect `verify-workspace-switch-ai`: `journey.mp4`, `result.json`, `workspace-switch/` with `observation.json`, `workspace-switch.json`, `workspace-switch-mb.txt`, the `*-copied.txt` conversations, `stand-in/workspace-switch.jsonl`, `session-chat.json`, and the screenshots `workspace-switch-before.png`, `workspace-switch-antigravity-refused.png`, `workspace-switch-codex.png`, `workspace-switch-claude.png` and `workspace-switch-mb.png`.

## Gotchas

The stand-in is not a real Codex or Claude process: the provider CLI start is replaced and no token, bill or model quality is exercised. The saved chats are seeded in the real session file; the reader keeps the production handover, divider, message store and identity rules.

- `mb` needs a `python3` executable for the shipped `zsb` script, so the driver links one beside `python.exe` before the verb runs.
- The Antigravity refusal is the server's current `HOST_SWITCH_TARGETS`; adding Antigravity (PR 1216) turns this journey red on purpose, and that step then moves to a real switch.
- The workspace must be saved in single-window mode, because that is the only mode the app restores workspace names from.
