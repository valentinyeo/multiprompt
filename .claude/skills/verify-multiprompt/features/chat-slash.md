# Live chat commands

Source files: src/chat*, src/terminal*, src/chat_markdown*.zig, src/chat_connectors/*, src/tmux*, src/message*, src/chat_history_reader.py, src/mp_complete.py, tools/agent-notifications/mp_complete.py, tools/verify-chat-delivery/*, src/main.zig, build.zig, build.zig.zon, src/command_palette.zig, src/shortcuts.zig, .claude/skills/verify-multiprompt/chat-slash.ps1

## Sub-features

/plan and /permissions open the existing mode picker. Plan, Ask and Accept edits apply to the originating live chat. Unsupported terminal commands explain their limits without entering the outbox. Pi /model opens its provider model picker. In an Antigravity chat /model opens that chat's model and effort rows in the Plus menu, while its own slash skills and unsupported commands still send to the agent. Claude and Codex chats still show the coming-soon notice.

## How to get to it (user POV)

Type /plan or /permissions in live chat. Press Enter, then choose a mode. Ctrl+K also lists the modes. In Claude and Codex chats, /model, /resume and /rewind keep the draft editable and show a plain notice; an Antigravity chat opens its model and effort rows instead of sending /model on. Pi /login opens provider authentication. The Plus menu also offers Bypass; the existing journey does not cover every Pi/provider path.

## Driving it with control.ps1

Dispatch the GitHub Windows journey:

```sh
gh workflow run verify.yml --ref igsh-1522-live-chat-slash -f feature=chat-slash
```

The journey first opens a saved host-0 tab whose reported folder belongs to the other server account. It types `/verify-owner` and accepts it with Tab. The isolated SSH boundary serves that skill only as the tab's account on its original server. Retain `completion-owner.jsonl`, `slash-owner-catalog.png` and `slash-owner-accepted.png`. On master, the request uses the login account and the skill cannot be accepted.

The journey then selects the same isolated live chat and types all five commands through the real composer. It captures every typed command, each picker and each notice. Choosing Plan, Ask and Accept edits must produce exactly three host controls for that chat, in order. No slash command may enter the ordinary outbox.

Retain screenshots, raw controls, acknowledgements, resulting mode, executable identity, actions and zero-process cleanup together. This journey is independent of the structured-question card journey.

## Gotchas

Two saved remote tabs and one transcript round are seeded once before launch. The app-supplied reader runs the real host mode handler. Only SSH, host ownership and agent control transport are stand-ins. No shared session, credentials or paid agent is used. This verifies native routing and host controls, not a real agent session.
