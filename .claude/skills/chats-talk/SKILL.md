---
name: chats-talk
description: List the live Multiprompt chats by name and send a message into another live chat. Use only when Valentin asks you to tell, ask or notify another chat.
---

# Talk to another live chat

Use this only when Valentin asks you to contact another chat. Never message a chat on your own, and never message real people.

```sh
mp-send list
mp-send read "<chat name>"
mp-send --to "<chat name>" "<message>"
```

- `mp-send list` (also `mp-sessions`) lists live chats of every AI, Claude, Codex, Pi, hax and Cursor, with name, state, terminal session and folder. Add `--json` for machine output.
- `mp-send read` prints the last answer of a Claude, Codex or Pi chat.
- A chat takes at most 6 messages a minute and you send at most 12 a minute. Past that, `mp-send` exits 5. Wait.
- `--to` ignores case, accepts a unique prefix and stops on two matches. The `@Name{session}` text from the @ pill works as is.
- The receiver sees `From <your chat name>:` before your text. Outside a chat, add `--from NAME`.
- A busy chat takes the message when its turn ends.
- Missing commands: run `tools/install-mp-talk.sh` from the Multiprompt checkout.

Details: `openwiki/operations/chats-talk.md`.
