# Chat options

## Sub-features

Only a pending structured question creates answer cards. Claude Code supplies AskUserQuestion; Codex supplies request_user_input. Ordinary numbered and bulleted replies stay text. Cards preserve the question, header, option label and description. Single choices send the corresponding provider selection. Multiple choices remain selectable until Submit. Other focuses the existing composer for a typed answer. Finished tool calls remove the cards.

## How to get to it

Open Chat View with Alt+C on a connected session awaiting a structured question. Click a choice, or select several choices and Submit. Choose Other to type an answer.

## Verification

The chat-options journey uses the real transcript reader and app against an owned SSH boundary. A plain three-question list must have no cards. AskUserQuestion fixtures must display the exact question and choices in AMOLED. Real card clicks must deliver Orange, then both Desktop and Phone, then a typed Purple through Other. Screenshots and provider-side answer receipts are saved together.

The provider console is scripted. No Claude, Codex or other paid provider is called. The reader regression suite separately covers request_user_input and completed/sidechain/ordinary-text negatives. A released build runs through the same journey; the desktop update offer is verified separately.

## Driving it with control.ps1

Run `.claude/skills/verify-multiprompt/control.ps1` through the GitHub Windows verify workflow:

```sh
gh workflow run verify.yml --ref ceo/IGSH-1063 -f feature=chat-options
gh workflow run verify.yml --ref master -f feature=chat-options -f tag=vX.Y.Z
```

Retain the workflow run, exact build hash, provider answer receipts and AMOLED screenshots together.
