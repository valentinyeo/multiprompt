# Automatic AI switch

Source files: src/chat_auto_switch.zig, src/chat_history_reader.py, tools/chat-auto-switch-journey.py, tools/fixtures/SOFT-2469/*, .github/workflows/chat-auto-switch.yml
CI workflow: chat-auto-switch.yml

## Sub-features

- `plan-out-match`: each provider's recorded usage-limit event is recognised by that provider's predicate only, so an ordinary sentence holding the words "usage limit" never counts.
- `switch-on-plan-out`: a chat that runs out of plan moves to the next AI on the saved order, keeps its address and chat name, and shows the automatic switch divider above the carried conversation.
- `fallback-order`: a used-up AI is skipped, so the chat lands on the next AI that still has a plan, and Antigravity is the last AI in that default order.
- `antigravity-plan-out`: a chat whose own AI is Antigravity moves on when Antigravity reports resource exhaustion, the same way the other AIs do.
- `toggle-off-keeps-chat`: with the automatic switch off, a recorded usage limit starts nothing, moves nothing and posts no notice; toggling back on restores the default.
- `all-plans-empty`: when every AI in the order is used up the chat stays where it is and the app says no plan is left anywhere.

## How to get to it (user POV)

With the automatic AI switch on, a chat reaches its provider's plan limit. The chat continues on the next AI in the saved order, the transcript shows the usual history with the divider `Switched AI automatically: Claude ran out of plan` above the carried messages, and the composer keeps the chat you were in. Three-dots chat menu, Auto-switch AI turns the behaviour off, and the same limit then leaves the chat on the AI it is already on.

## Driving it with GitHub CI

Dispatch on GitHub, never on a server or a desktop:

```sh
gh workflow run chat-auto-switch.yml --ref <branch>
```

The Linux job loads `src/chat_history_reader.py` the same way the app does, reads the recorded events from `tools/fixtures/SOFT-2469/`, and feeds them through the production `host_agent_event` turn path of a seeded chat with a queued message. Only the provider CLI start is replaced: the stand-in records the target AI and runs the production `host_auto_switch_run` and `host_switch_ai` bodies against an isolated home and message store. Toggle state is changed through the production `set_auto_switch` request.

Require every check in `journey.json` and `summary.json` to pass, the divider and earlier messages in `switched-history.jsonl`, and `revision.txt` to match the pull request head. `summary.json` is the artifact root file the pull request verifier reads for a `CI workflow:` receipt. The artifact is `chat-auto-switch`; `journey.log` carries the same check list.

The PR selector owns these files through `CI workflow:`, so changing `src/chat_auto_switch.zig`, the switch reader or the recorded fixtures requires this workflow on the exact head.

## Gotchas

This is a reader-level replay of the real event and switch path, not a Windows desktop journey: it claims no screenshots, no keyboard input and no live provider. It does not start Claude, Codex or Pi, and it does not open the app window, so a Chat View paint of the divider stays outside this proof.

The fixtures are recorded provider events, not live transcripts. Refreshing a fixture changes `coverage.json` in the switch AI formal skill, which is the review gate for the detection the model relies on.

`src/chat_auto_switch.zig` only sends the `set_auto_switch` request and posts the reply notice; the switch itself lives in the reader. The journey drives the saved setting through the production request, so a broken Zig row still needs the desktop journey for the chat menu.
