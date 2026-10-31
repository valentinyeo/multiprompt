---
type: Architecture
title: App-owned agent session host
description: How the runtime owns a Claude session over stream-json instead of typing into a terminal.
tags:
  - architecture
  - chat
updated: 2026-10-31
---

# App-owned agent session host (IGSH-1266)

The app owns one agent session per chat and speaks the agent CLI's structured
protocol. Nothing is typed into a terminal. This page is the contract between the
server runtime and every client.

## Data shape

- One chat is one agent session id (`provider` plus `sid`).
- At most one host process per chat.
- At most one owner per chat at a time: the host (app) or a terminal (`claude --resume`).
- The store stays the source of truth for messages; the host only adds a delivery
  transport. `shared_messages`, `message_attempts` and `message_events` keep their shape.

## State directory

`~/.local/state/multiprompt/agent-host/`, owner-only (`0700`), files `0600`:

| File | Meaning |
| --- | --- |
| `<key>.config.json` | Per-chat switch and options. Absent means off. |
| `<key>.owner.lock` | `flock` lock file. Holding it is being the owner. |
| `<key>.owner.json` | Who holds the lock: `host` or `terminal`, plus pid and start time. |
| `<key>.state.json` | Host state: session id, written message ids, accepted flags, last events. |
| `<key>.backoff` | Per-chat retry backoff: next try time and current delay. |
| `<key>.events.log` | One line per lifecycle event, useful when a chat misbehaves. |
| `<key>.stderr.log` | The host process's own stderr. |

`<key>` is the first 32 hex characters of `sha256(provider + ":" + sid)`.

The delivery socket is `$TMPDIR/mp-agent-host-<uid>/<key>.sock`, owner-only. Its path stays
under the 108-character limit a Unix socket path has, whatever the home directory looks like.

## Per-chat switch (default off)

- No config file, or `enabled` not `true`: the terminal path is unchanged.
- The file also carries `command` (the agent executable, default `["claude"]`), `args`
  (extra CLI arguments), `tmux` (the chat's tmux name) and `cwd`.
- Tests point `command` at a fake executable.
- Codex and Pi keep their own paths until their adapters exist.

## Host lifecycle

- **start**: takes `<key>.owner.lock` with `flock LOCK_EX|LOCK_NB`. Held by anyone else
  means refuse (`status=busy`), never wait. Then writes `owner.json`, binds the socket,
  and spawns the agent CLI.
- The agent CLI runs as
  `claude --print --input-format stream-json --output-format stream-json --verbose`
  plus `--resume <sid>` when the session transcript exists, otherwise `--session-id <sid>`.
- **deliver**: a client connects to `<key>.sock`, writes one JSON line, reads one JSON line.
  Request: `{"op":"deliver","id":<message id>,"attempt":<attempt>,"epoch":<epoch>,"text":<text>}`.
  Reply: `{"status":"sent"|"duplicate"|"busy"|"refused"|"error","reason":<reason>}`.
- **receipt**: before the write the host claims the attempt row through the existing
  `attempt_prepare` with binding
  `{"v":1,"mode":"stream_json_user_line","host":<pid>,"session":<sid>}`. After a successful
  stdin write and flush it records the message id in `state.json` and calls `attempt_finish(sent)`.
- **idle stop**: no in-flight message and no delivery request for 300 s. The host closes
  stdin, waits up to 5 s, kills, unlinks the socket, removes `owner.json`, releases the lock.
- **crash restart**: the next delivery request finds no socket, starts a host (which takes
  the stale lock), and retries once. Repeated requests for an id already written in the same
  epoch answer `duplicate` and write nothing.
- **handover**: `host stop` or `host handover` ends the host and releases the lock, so a
  terminal may `claude --resume <sid>`. `owner.json` records `terminal` until the app takes
  the chat back with `host start`, which clears that record.

## A message becomes one stream-json line

One JSON object per line on the host's stdin, UTF-8, newline-terminated:

```json
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"<message text>"}]}}
```

- The text is passed through unchanged; JSON escaping handles newlines and quotes.
- The host keeps the stdin pipe open between messages. Closing it ends the process.
- The host writes one message at a time. It writes the next only after the turn ends.

## Events that decide delivery state

Recorded from Claude Code 2.1.316, one throwaway session (`--session-id <new uuid>`),
one user line `reply with the word ok`:

| Order | Event | Meaning for the host |
| --- | --- | --- |
| 1 | `{"type":"system","subtype":"hook_started"}` / `hook_response` | Startup hooks. No message meaning. |
| 2 | `{"type":"system","subtype":"init","session_id":...}` | CLI ready; session id confirmed. |
| 3 | `{"type":"system","subtype":"commands_changed"}` | Skill list. Ignore. |
| 4 | `{"type":"assistant","message":{"id":...,"content":[{"type":"thinking"}...]}}` | **Message accepted**: the CLI has taken the line and started the turn. |
| 5 | `{"type":"assistant","message":{"id":...,"content":[{"type":"text","text":"ok"}]}}` | Same turn, more chunks of the same message id. |
| 6 | `{"type":"rate_limit_event"}` | Usage notice. Ignore. |
| 7 | `{"type":"result","subtype":"success","stop_reason":"end_turn","session_id":...,"usage":...,"total_cost_usd":...}` | **Turn done**. The host may write the next line. |

- Accepted means the first `assistant` event after the write, and the host applies one
  `accepted` fact for that message id and attempt (store state `accepted`, which the client
  shows as delivered).
- Turn done means the `result` event. The host clears the in-flight message and accepts the
  next delivery request.
- The CLI does not echo the user line on stdout. Ordering is what identifies the accepted
  message, and the host allows one in-flight message per chat, so the mapping is exact.
- stderr and exit status are only used for `not_sent` before the write.

## Runtime entry points

Run from the selected runtime file (`src/chat_history_reader.py`):

```
python3 <reader> host start <provider> <sid> [--tmux NAME]
python3 <reader> host stop <provider> <sid>
python3 <reader> host status <provider> <sid>
python3 <reader> host enable <provider> <sid> [--tmux NAME]
python3 <reader> host disable <provider> <sid>
python3 <reader> host handover <provider> <sid>
```

- `status` prints one JSON object: enabled, owner, pid, session id, in-flight message,
  written count, last event type, next backoff.
- Only `claude` is accepted today; other providers are refused.
- Each command prints one JSON object. The host process exits `1` when another owner holds the
  lock, `2` for an unsupported provider, `3` when the chat is switched off, `4` when it cannot
  start the agent; `host start` reports those as `owner_busy`, `unsupported_provider`,
  `host_disabled` or `host_error`.

## Delivery integration

- `message_dispatch` checks the per-chat switch and lock ownership before the connector.
- Owned chat: flip the row to `sent`, claim the attempt, hand it to the host, return.
  Acceptance arrives later from the host process, through the same fact application the
  connectors use, so clients need no new event types.
- Not owned, switched off, or not Claude: the existing connector path runs unchanged.
- Host unavailable, busy or timed out: the row returns to `queued` (same attempt, so a later
  retry is a `duplicate`, not a second send) and the per-chat backoff grows 250 ms, 500 ms,
  1 s, 2 s, 4 s, 8 s, 16 s, 30 s. Success clears it.
- One chat's error never blocks another chat: the message worker is per chat, and the
  backoff file is per chat.

## Limits

- One host per chat; no parallel agents inside one chat.
- Permission prompts have no channel in print mode. The host passes the mode the config
  gives it (`--permission-mode`), and anything that would still prompt is denied.
- Editor and interactive-session state belongs to the agent CLI, not the app.
- A crash between the stdin write and the accepted event leaves the message `sent` until the
  attempt deadline expires, after which the client may show it as failed and the user decides
  whether to send again.
