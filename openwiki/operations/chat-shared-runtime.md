# Shared chat runtime

- Desktop and Android send the complete canonical reader.
- The outer loader selects the inner reader.
- Selection happens before requests.
- Imports never install a runtime.
- The full-file hash identifies the client artifact.
- The inner-source hash identifies the selected runtime.

## Selection

- Each Unix user has a private runtime.
- Its directory is `~/.multiprompt-runtime`.
- `active.json` contains `protocol`, `generation`, and `sha256`.
- Protocol 1 starts at generation 1.
- Every inner-source edit increments `RUNTIME_GENERATION`.
- Generations increase monotonically.
- A lock serializes selection.
- Readers use owner-only permissions.
- Each reader is stored as `<sha256>.py`.
- Publishing syncs a temporary file.
- An atomic rename publishes it.
- Older launchers select the installed newer reader.
- Equal generations with a different hash replace the stale selection with this
  client's own source, so one missing bump cannot wedge every client.
- Unsafe, corrupt or malformed selections still fail closed.
- Unsafe files and corrupt readers fail closed.

## Requests

- Send this `--serve` request:

```json
{"id":1,"op":"engine_info"}
```

- It returns:

```json
{"id":1,"engine_info":{"protocol":1,"generation":1,"sha256":"..."}}
```

- Live history requests must send `follow: true`.
- This resolves the live session before saved IDs.
- Existing history responses remain unchanged.
- Watch and one-shot calls use selected source.
- Owner and held-worker calls also use it.
- Runtime errors return history error frames.
- They never execute older code instead.

## Hosted chats and other tools

- A hosted chat's tmux session carries `@mp_host_sid` while a host runs on it.
- The host clears that option when it stops, and a move to the terminal clears
  it too, so a tool reading it never types into a hosted pane's shell.
- Read it with `tmux show-options -t <session> -v @mp_host_sid`.
- A tool with that id sends through the reader, never into the pane:
  `python3 <runtime>/reader.py host send claude <sid> <text>`.
- `host send` submits through the shared store and dispatches to the host, so
  the message gets an id and a receipt like any message from the desktop.
- `--tmux <session>` overrides the chat the host is bound to.

## Workspace accounts and startup failures

New chats use the account owning their workspace folder.
The folder must be inside that account's home.
Other folders keep the server's login account.
The server must allow password-free account switching.
Only the agent switches accounts.
The host and message store keep their account.
Agent commands use the workspace account's login environment.
They never inherit the host account's credentials.

A failed startup shows one chat line.
It does not keep restarting the agent.
Changing the chat configuration permits another startup attempt.
Existing message requests and live events remain compatible.
Ctrl+T, Alt+T, and the existing palette action remain unchanged.

## Limits

- Older launchers still run their embedded reader.
- Those launchers predate this loader.
- Existing processes continue until they exit.
- Selection cannot stop those processes.
- Recovery cursors remain independent of selection.
- Immediate cutover is not promised.
- Old and new process ordering is not promised.
- Android must migrate its embedded canonical file.
- Verify both clients before closing paired work.
