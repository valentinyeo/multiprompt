# Fresh start keeps the same Multibot chat

Source files: src/command_palette.zig, src/app_state.zig (`SEARCH_CHAT_FRESH_START_OFFSET`), src/main.zig, src/sidebar.zig, src/shortcuts.zig, src/chat_history_reader.py, tools/chat-fresh-start.test.js, tools/chat-fresh-start-proof.mjs, tools/verify-chat-delivery/fresh-start-host.py, tools/verify-chat-delivery/fresh-start-agent.py, tools/verify-chat-delivery/boundary.py, .claude/skills/verify-multiprompt/control-feature-fresh-start.ps1, .claude/skills/verify-multiprompt/control.ps1

Verify on: push

## Sub-features

- `palette-fresh-start`: Ctrl+K **Chat View: Fresh start** on a disposable hosted Claude tab completes a real handover, rotates only the native agent session and keeps the public sid, tmux name, sidebar row and saved layout `csid`.

## How to get to it (user POV)

Open a live remote chat in Chat View, exchange a couple of messages, then choose **Chat View: Fresh start** from Ctrl+K. Wait while the agent saves a handover and the chat reopens with cleared context but the same name, photo and address.

Path B (unit-tested elsewhere): in-chat `mp-fresh --handover <file>` — see `tools/mp-fresh`, `src/mp_fresh.py`, and `tools/chat-mp-fresh.test.js` (SOFT-2997).

## Driving it with control.ps1

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_CHAT_FRESH_START_OFFSET` | Ctrl+K, type **fresh start**, then select the matching action with Up/Down and Enter. Follow `palette-fresh-start` above. |

Dispatch on GitHub Windows only:

```sh
gh workflow run verify.yml --ref <branch> -f feature=fresh-start
```

The harness seeds one remote `verify-fresh-start` tab with two transcript rounds, enables production agent-host delivery through `fresh-start-host.py` and a scripted Claude process, then sends two composer messages, records `fresh-start-before.json`, runs **Chat View: Fresh start**, waits for host `fresh_start` completion (no `fresh_start` in state, new `native_session`, handover visible), and writes `fresh-start-after.json` plus `node tools/chat-fresh-start-proof.mjs`.

The scripted Claude sends its handover twice in the same turn (SOFT-2604), so the run proves one saved handover and one fresh start. After the reopen the journey sends one more composer message and requires a hosted reply, so the new chat is alive, not just reopened. Two visible handover turns, one saved file, no repeated text and one post-fresh-start reply are checked before the run can pass.

Retain before/after screenshots, `fresh-start-host.jsonl`, `agent-host` copies, `fresh-start-debug.log` and `result.json`.

## Gotchas

Only SSH/tmux and the Claude child are synthetic; composer, palette routing, session save, layout tab `csid` and agent-host files are production paths. This journey does not prove real Claude handover quality, Codex/Pi fresh start, or the in-chat `mp-fresh` path (covered by unit tests). Do not reuse a production chat row.