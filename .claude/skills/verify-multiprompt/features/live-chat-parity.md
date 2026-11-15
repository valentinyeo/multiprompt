# Live chat parity

A Claude, Pi, Cursor, or Codex live chat is one hosted session. The same steps must work for each provider. A step that passes for Claude and fails for another provider fails this check.

## Sub-features

- `start`: the app host enable and host start commands bring the chat up.
- `reply`: the chat is asked to reply with the word PARITY, and that word is in the reader transcript.
- `skills`: the slash catalog the skill pill and the slash list use lists at least one skill. A stale or loading catalog still counts when it lists skills, because the pill shows those rows. An error or an empty list fails.
- `working-start`: working state starts before the reply is shown.
- `working-end`: working state ends after the reply is shown.
- `stop`: an interrupt ends the following turn as interrupted.
- `reopen`: stopping and starting the host again still shows the prompt and the reply.
- `name`: the chat name from host status is the live chat name this run created.

## How to get to it (user POV)

Open a new live chat for Claude, then the same kind of chat for Pi, Cursor, and Codex. Send a message, use a skill, watch the working state, stop the turn, and reopen the chat. The chat name stays on the session.

## Driving it with live-chat-parity.py

This is not a Windows desktop journey. Do not add it to the desktop recipe list. GitHub runs the stand-in comparison. Real providers are manual.

### Launch

Create a throwaway directory and one `live-parity2463-<provider>-<id>` name per provider. Start each chat with the same reader commands the app uses:

```sh
python3 ~/.multiprompt-runtime/reader.py host enable <provider> <sid> --tmux <name> --cwd <folder> --permission-mode bypassPermissions
python3 ~/.multiprompt-runtime/reader.py host start <provider> <sid>
```

Claude is the only provider that receives `--permission-mode`. Codex is included because the host accepts it. The stand-in mode points those same commands at provider stand-ins and an isolated home directory.

```sh
python3 tools/live-chat-parity.py --stand-in --evidence /tmp/soft-2463-live-chat-parity
python3 tools/live-chat-parity.py --real --evidence /tmp/soft-2463-live-chat-parity
```

### Doctor

Read only. Confirm the reader file is present. For a real run, record whether `claude`, `pi`, `agent`, and `codex` are present and their version lines. Do not start a chat, send a message, or change host state. A missing provider binary is recorded and becomes a failed start later. A missing reader stops the run before any chat is created.

### Drive

For each provider, run start, reply, skills, working start, working end, stop, reopen, and name. Send `reply with the word PARITY`. Read the reader event transcript for that word. Ask the slash catalog with the same six-field request the composer sends: id, `slash`, provider, chat name, folder, and an empty field. Working start is a turn start before the reply. Working end is a turn end after it. Stop sends `HOLD` and then the host interrupt. Reopen stops and starts that same host and requires the prompt and PARITY to still be in the reader store. The chat name must still be the name this run created.

A step that passes for Claude and fails for Pi, Cursor, or Codex is a parity failure. The command exits 0 only when there is no such failure.

### Evidence

The run writes `report.json`, `table.md`, `doctor.json`, `sessions.json`, and `cleanup.json` in the evidence directory named by `--evidence`. The report has one pass or fail per step per provider and the list of parity gaps. Evidence is outside the throwaway home and outside the host state files.

### Cleanup

Disable and stop only the sessions recorded in this run, and only when the name starts with `live-parity2463-` and the host config still names that same session. Remove only that session's host files and its rows in the message store. Do not list or signal any other `live-*` session. Cleanup does not delete the evidence directory.

## Gotchas

The stand-in mode proves the comparison. It does not prove a real provider. Real mode is the proof, and it sends one short reply plus one interrupted turn per provider. Pi currently has no skills in the slash catalog, and Cursor currently fails before a normal reply. Those gaps fail the real check until their fixes land. The desktop journey list does not run this check. Never point cleanup at a chat this run did not create.
