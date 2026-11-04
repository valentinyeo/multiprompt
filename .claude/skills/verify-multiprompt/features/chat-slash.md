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

Retain screenshots, raw controls, acknowledgements, resulting mode, executable identity, actions and zero-process cleanup together. This journey is independent of the structured-question card journey.

## Gotchas

Two saved remote tabs and one transcript round are seeded once before launch. The app-supplied reader runs the real host mode handler. Only SSH, host ownership and agent control transport are stand-ins. No shared session, credentials or paid agent is used. This verifies native routing and host controls, not a real agent session.
