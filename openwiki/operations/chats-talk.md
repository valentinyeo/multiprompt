# Chats talk to each other

Agent sessions on the server, Claude, Codex, Pi, hax or Cursor, can list the live chats by the name shown in the desktop app, read a chat's last answer and put a message into another live chat. Every chat gets the same tool: `mp-send` has `list`, `read` and `--to`. Use it only when Valentin asks.

## Install

Run `tools/install-mp-talk.sh` from a checkout. It copies `mp_send.py` and `mp_sessions.py` to `~/.local/share/multiprompt-talk/` and writes the `mp-send` and `mp-sessions` wrappers into `~/.local/bin`. Run it again after a release to update.

## List chats

```sh
mp-send list
mp-send list --json
mp-sessions
```

Each row has the name, AI, state (`busy` while a turn runs, otherwise `idle`), terminal session, session id and folder. A chat counts as live when its host process runs and its terminal session exists. A chat whose name has not been published yet shows `(no name yet)` and can still be reached by its terminal session.

## Read the last answer

```sh
mp-send read "Pi Helper"
```

Prints the newest assistant answer of a Claude, Codex or Pi chat. Names match as for `--to`. A chat with no answer yet exits 3. hax and Cursor chats can be listed and messaged but not read.

## Send a message

```sh
mp-send --to "Multi Bot Opus Lead" "Can you check the release build?"
mp-send --to "multi bot" --wait "short prefix works when it is unique"
mp-send --to "@Multi Bot Opus Lead{live-308b1fc}" "mention form from the @ pill"
```

- Matching ignores case. An exact name wins, then a unique prefix. Two matches stop with an error that lists them.
- `{live-...}` is the terminal session the @ pill appends. It is an exact key and needs no name.
- The text sent starts with `From <your chat name>:`. The sender is found from `MULTIPROMPT_TAB`, then `TMUX_PANE`. Outside a chat, pass `--from NAME`.
- A busy chat queues the message and takes it when its turn ends. `--wait` waits for acceptance. `--json` prints machine output.
- Sending to your own chat is refused.
- Loop cap: one chat takes at most 6 messages from other chats in a minute, and one sender sends at most 12 in a minute. Past a cap `mp-send` prints `slow down` and exits 5.

The old form `mp-send <provider> <sid> "text" --tmux <session>` still works.

## Where names come from

The desktop publishes each live chat's tab name to the server through the reader (`chat_names` request). The reader merges them into `~/.local/state/multiprompt/chat-names.json`, keyed by terminal session. The desktop sends the list when tabs, names or workspaces change. Until a desktop with this feature has connected, chats show without names.
