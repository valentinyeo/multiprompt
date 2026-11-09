# Remove a stuck Not sent message

A message that is stuck as Not sent from an old session can be removed with Remove.

## Sub-features

- `remove-old-session`: Up selects the Not sent message and Delete removes it for good.

## How to get to it (user POV)

- Open a chat with a Not sent message. Press Up to select it, then Delete, or right-click it and choose Remove.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml -f feature=chat-not-sent-remove`, or run the Click-through journeys workflow. The recipe is `control-feature-chat-not-sent-remove.ps1`.

Seeding boundary: the harness writes `session.json` and `chat-outbox.json` once before launch. The tab has a fixed chat id. The outbox holds one message already marked sent under a session id the tab no longer has. This is the state left after a helper agent rebinds a chat, and it cannot be reached by typing. Both files are copied to `seed-session.json` and `seed-outbox.json`.

1. Launch with `--single-window` and require the message in the outbox file.
2. Alt+C to open Chat View.
3. Up to select the message, Delete to remove it, up to three attempts.
4. Require the message gone from `chat-outbox.json`.
5. Retain `outbox-before.json`, `outbox-after.json`, `action.png`, `selected.png` and `after.png`.

## Gotchas

- Before the fix for IGSH-1859 Remove asks the host and shows "Could not remove yet. Try again"; the message stays and the journey fails at the removal wait.
- The status text is painted, so the proof is the saved outbox file plus screenshots.
