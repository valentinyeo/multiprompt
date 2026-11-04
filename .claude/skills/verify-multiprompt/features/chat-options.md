# Chat options

## Sub-features

Only a pending structured question creates answer cards. Claude Code supplies AskUserQuestion; Codex supplies request_user_input. Ordinary numbered and bulleted replies stay text. Cards preserve the question, header, option label and description. Single choices send the corresponding provider selection. Multiple choices remain selectable until Submit. Other focuses the existing composer for a typed answer. Finished tool calls remove the cards.

## How to get to it (user POV)

For a terminal session, open Chat View with Alt+C. Live chats already show Chat View. Click a choice, or select several choices and Submit. Choose Other to type an answer.

In a live chat, type /plan or /permissions and send it. Choose a mode in the small palette. The same mode choices appear in Ctrl+K. Unsupported terminal commands stay editable and show a plain notice.

Verification:

The chat-options journey uses the real transcript reader and app against an owned SSH boundary. A plain three-question list must have no cards. AskUserQuestion fixtures must display the exact question and choices in AMOLED. Real card clicks must deliver Orange, then both Desktop and Phone, then a typed Purple through Other. Screenshots and provider-side answer receipts are saved together.

## Driving it with control.ps1

Run `.claude/skills/verify-multiprompt/control.ps1` through the GitHub Windows verify workflow:

```sh
gh workflow run verify.yml --ref ceo/IGSH-1063 -f feature=chat-options
gh workflow run verify.yml --ref master -f feature=chat-options -f tag=vX.Y.Z
```

Retain the workflow run, exact build hash, provider answer receipts and AMOLED screenshots together.

The journey then selects an isolated live chat and types /plan, /permissions, /model, /resume and /rewind through the real composer. It saves a screenshot for every command. Plan and permissions open the existing palette. Choosing Plan, Ask and Accept edits must produce exactly three set_permission_mode controls for that live chat, in order, and no slash-command outbox messages. /model shows the allowed coming-soon notice until its dedicated picker is available; /resume and /rewind show unavailable notices and keep their drafts editable.

The slash boundary runs the app-supplied reader and the real host mode handler. Only host ownership and the agent control transport are stand-ins. Raw controls, acknowledgements, resulting mode, input actions, screenshots, executable identity and owned-process cleanup remain in the artifact. This proves native routing and host controls, not a real paid agent session.

## Gotchas

The provider console is scripted. No Claude, Codex or other paid provider is called. The reader regression suite separately covers request_user_input and completed/sidechain/ordinary-text negatives. A released build runs through the same journey; the desktop update offer is verified separately.
