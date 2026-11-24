# Chat options

Source files: src/chat*, src/terminal*, src/chat_markdown*.zig, src/chat_connectors/*, src/tmux*, src/message*, src/chat_history_reader.py, tools/verify-chat-delivery/*, src/main.zig, build.zig, build.zig.zon, src/command_palette.zig, src/shortcuts.zig, .claude/skills/verify-multiprompt/chat-options.ps1

## Sub-features

Only a pending structured question creates answer cards. Claude Code supplies AskUserQuestion; Codex supplies request_user_input. Ordinary numbered and bulleted replies stay text. Cards preserve the question, header, option label and description. Single choices send the corresponding provider selection. Multiple choices remain selectable until Submit. Other focuses the existing composer for a typed answer. Finished tool calls remove the cards.

## How to get to it (user POV)

For a terminal session, open Chat View with Alt+C. Live chats already show Chat View. Click a choice, or select several choices and Submit. Choose Other to type an answer.

Verification:

The chat-options journey uses the real transcript reader and app against an owned SSH boundary. A plain three-question list must have no cards. AskUserQuestion fixtures must display the exact question and choices in AMOLED. Real card clicks must deliver Orange, then both Desktop and Phone, then a typed Purple through Other. Screenshots and provider-side answer receipts are saved together.

## Driving it with control.ps1

Run `.claude/skills/verify-multiprompt/control.ps1` through the GitHub Windows verify workflow:

```sh
gh workflow run verify.yml --ref ceo/IGSH-1063 -f feature=chat-options
gh workflow run verify.yml --ref master -f feature=chat-options -f tag=vX.Y.Z
```

Retain the workflow run, exact build hash, provider answer receipts and AMOLED screenshots together.

## Gotchas

The owned SSH/tmux and provider are synthetic boundaries. Structured option number keys are another user entry point, but this journey does not prove a real provider accepted the answer. Permission approval shortcuts are a separate feature.


The provider console is scripted. No Claude, Codex or other paid provider is called. The reader regression suite separately covers request_user_input and completed/sidechain/ordinary-text negatives. A released build runs through the same journey; the desktop update offer is verified separately.
