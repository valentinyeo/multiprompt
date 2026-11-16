# Terminal replies never fill the message box

## Sub-features

Device-attribute, cursor-position and OSC replies in the pane input are removed whole by the production embedded reader. Raw ESC and caret-escaped replies leave an empty message box. Brackets typed by a person remain exactly `[]` in the reader draft and native message box.

## How to get to it (user POV)

Select a saved terminal session, open Chat View, and type `[]`.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=chat-terminal-replies` on GitHub Windows. This focused extension of the chat-delivery harness uses its isolated saved tab, synthetic transcript and fake tmux boundary. It injects five terminal replies into the shell input box, observes the unmodified production reader's returned draft, checks the native message box through WM_GETTEXT, then checks literal brackets in the reader draft and types them through real keyboard input.

Inspect `terminal-replies-empty.png`, `terminal-replies-typed.png`, `terminal-replies/stand-in/terminal-drafts.jsonl`, `observation.json`, Doctor and cleanup in `verify-chat-terminal-replies`. Run the same harness with `app_revision=<base SHA>` to require the old reader to fail reply removal rather than startup or focus.

## Gotchas

The stand-in supplies terminal replies, not a live Windows Terminal or remote agent. The observer records the real reader's input and return value without changing either. Arbitrary shell text is intentionally not imported into Chat View. This journey proves clean reader drafts, an empty native message box and literal typed brackets, not arbitrary draft restoration, message delivery or real SSH. Message delivery has inherited failures tracked by PR #1060 and remains outside this draft-cleanup journey.
