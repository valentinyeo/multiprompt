# Terminal replies never fill the message box

## Sub-features

Device-attribute, cursor-position and OSC replies in the pane input are removed whole by the production embedded reader. Raw ESC and caret-escaped replies leave an empty message box. Brackets typed by a person remain exactly `[]` and reach the agent once.

## How to get to it (user POV)

Select a saved terminal session, open Chat View, type `[]` and press Enter.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=chat-terminal-replies` on GitHub Windows. This focused extension of the chat-delivery harness uses its isolated saved tab, synthetic transcript and fake tmux boundary. It injects five terminal replies into the shell input box, observes the unmodified production reader's returned draft, checks the native message box through WM_GETTEXT, then types and sends brackets through real keyboard input.

Inspect `terminal-replies-empty.png`, `terminal-replies-typed.png`, `terminal-replies/stand-in/terminal-drafts.jsonl`, `observation.json`, the independently checked transcript enqueue, Doctor and cleanup in `verify-chat-terminal-replies`. Run the same harness with `app_revision=<base SHA>` to require the old reader to fail reply removal rather than startup or focus.

## Gotchas

The stand-in supplies terminal replies, not a live Windows Terminal or remote agent. The observer records the real reader's input and return value without changing either. Arbitrary shell text is intentionally not imported into Chat View. This journey proves clean reader drafts, an empty native message box and exact typed-bracket delivery, not arbitrary draft restoration or real SSH.
