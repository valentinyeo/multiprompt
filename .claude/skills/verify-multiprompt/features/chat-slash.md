# Live chat commands

## Sub-features

/plan and /permissions open the existing mode picker. Plan, Ask and Accept edits apply to the originating live chat. Unsupported terminal commands explain their limits without entering the outbox. /model says coming soon until its dedicated picker is merged.

## How to get to it (user POV)

Type /plan or /permissions in live chat. Press Enter, then choose a mode. Ctrl+K also lists the modes. /model, /resume and /rewind keep the draft editable and show a plain notice.

## Driving it with control.ps1

Dispatch the GitHub Windows journey:

```sh
gh workflow run verify.yml --ref igsh-1522-live-chat-slash -f feature=chat-slash
```

The journey selects an isolated live chat and types all five commands through the real composer. It captures every typed command, each picker and each notice. Choosing Plan, Ask and Accept edits must produce exactly three host controls for that chat, in order. No slash command may enter the ordinary outbox.

Retain screenshots, raw controls, acknowledgements, resulting mode, executable identity, actions and zero-process cleanup together.

The same live tab then receives scripted Claude control requests through the production host event adapter, not terminal menus. Real input allows and cancels approvals, answers single/multiple/Other questions, and implements or gives feedback on plans. Each response must target its original request and tool, reach the provider stdin exactly once, and produce a continuation copied from the real transcript through Ctrl+K. Plan markdown must also appear in the copied transcript. Retain hosted request, reply and continuation JSONL alongside the native card and plan screenshots. Answers must not enter ordinary message delivery.

This covers existing desktop support referenced by the paired Android request https://app.hypertask.ai/detail/project-2060/1622 and desktop follow-up https://app.hypertask.ai/detail/project-2060/1644. It does not run Android or prove account transport.

## Gotchas

Two saved remote tabs and one transcript round are seeded once before launch. The app-supplied reader runs the real host mode handler. Only SSH, host ownership and agent control transport are stand-ins. No shared session, credentials or paid agent is used. This verifies native routing and host controls, not a real agent session.
