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

- New live chats have no parking terminal or idle sleep process.
- Their saved `tmux` field is a routing name, not proof of a terminal.
- Host config stores the provider, session id, name and working directory.
- `python3 <reader> host list` lists those registered chats.
- `host connect <name>` reconnects by that registry without creating tmux.
- Desktop discovery combines the registry with existing terminal sessions.
- Headless runners stay out of desktop discovery until made visible.
- Explicit Claude terminal handoff creates a real terminal on demand.
- Older config/state pairs and physical terminal chats remain readable.
- Old and new clients keep the same request and layout fields. The selected
  runtime supplies the name lookup; Android compatibility is tracked in
  https://app.hypertask.ai/detail/project-2060/1768.

The following pane markers remain for older physical sessions:

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

## Stalled messages

Message requests run in separate, ordered lanes per chat.
Each lane admits up to 64 requests.
Up to 256 chat lanes may be active.
Excess requests receive the existing error response.
Idle lanes can be reclaimed for new chats.
Session discovery and connector calls run outside shared write transactions.

Each chat's message worker watches its oldest pending message.
After 90 seconds without progress, it releases its work locks.
The pending message becomes failed with `watchdog_timeout`.
One `worker_watchdog` log entry records the recovery.
Other chats and accepted messages remain untouched.
Recovery never automatically resends an uncertain handoff.
Explicit retry keeps the existing idempotent retry request.
The worker deadline also interrupts a hung poll or dispatch.

Protocol 1 and the stored schema remain unchanged.
The existing retry action and shortcuts remain unchanged.
A short test cannot prove a full healthy day.
That acceptance check requires post-release observation.

## Model and effort

Click the plus button left of the message box in a live Claude chat.
The plus menu lists Attach file, Model, Effort and Permission level.
Choose Model Opus, Sonnet, Haiku, or Fable.
Choose Effort Low, Medium, or High.
Choose Permission level Ask, Accept edits, Plan, or Bypass.
A check mark shows the current model, effort and permission level.
The message box shows no model or effort text.
Ctrl+K "Chat View: Plus Menu" opens the same menu from the keyboard.
Ctrl+K still lists every model, effort and permission choice.
The next message waits for the new agent.
It resumes the same conversation and keeps history.
No new keyboard shortcut is assigned.

The host accepts `set_model` and `set_effort` requests.
It reports selections through existing live events.
The `host.settings` payload includes `model`, `effort`, and `applied`.
Empty values mean the default remains unchanged.
Older clients can ignore this event and snapshot metadata.
The paired Android request needs no phone picker.

## Fresh start

Ctrl+K "Chat View: Fresh start" and the right-click tab palette use the existing live-host channel. There is no dedicated shortcut. The command-line equivalent is `python3 <reader> host fresh-start <provider> <sid>`.

Fresh start refuses a chat that is still replying or awaiting permission. The current agent writes a short handover as its reply. The host saves that reply to an owner-only handover file before stopping the agent. A failed, empty, interrupted or unsaved handover never clears context.

Only the provider-native conversation changes. The public provider/session key, registered chat name, account credentials and saved desktop layout remain unchanged. Claude and Pi start with a new native session id; Codex starts a new thread; Cursor and hax start without resuming the previous native conversation. The replacement receives only the saved handover, plus its normal startup instructions, and first acknowledges the unfinished work. Incoming messages remain queued until that acknowledgement completes. A failed read keeps messages gated; choose Fresh start again to retry.

The host keeps readable history separately from model context. Previous messages remain above a Fresh start divider. Later accepted conversation text and tool steps append to that history. Reconnecting reads the same history file without feeding it back into the agent. The existing history wire format, message protocol 1, public chat id and delivery receipts do not change. Older clients using runtime selection receive the same wire rows. Existing agents keep their selected runtime until restarted; an old host rejects the new action without clearing anything.

Desktop and Android compatibility still requires a live check on both clients before closing shared work. The action itself is desktop-only; it does not add a phone picker or change the account layout.

## Switch AI

Ctrl+K "Chat View: Switch AI to Claude", "Switch AI to Codex" and "Switch AI to Pi" and the right-click tab palette use the live-host channel. The row for the chat's current AI is hidden. There is no dedicated shortcut. The command-line equivalent is `python3 <reader> host switch-ai <provider> <sid> --to <claude|codex|pi>`.

Switch AI refuses a chat that is still replying. An idle live agent is stopped first. The host writes a handover from the saved readable history: the last messages, plus a pointer to the full history file. It starts the target AI under a new session id behind the same chat name. The new AI reads the handover before any queued message is delivered, using the Fresh start gate.

The chat keeps its tmux name, so the registered chat name, picture, sidebar place and roster entry stay the same. The agent environment names its session from that tmux name, so the session name variables stay the same too. Other chats reach it by name through the message locator, which now points at the new session. Queued messages move with it. The old session is disabled and a redirect table sends late requests, history reads and event subscriptions from the old session id to the new one. Previous messages stay above a Switch AI divider. Switching back creates another new session under the first AI.

The old AI does not write its own handover yet. The handover comes from the saved history only.

## Saved permission level

The host accepts `set_permission_mode` requests.
Ask, Accept edits and Bypass are saved with the chat, in its config and its state.
The saved level is accepted while the host is stopped, so a late pick is not lost.
A restart, a model change or a reconnect starts the agent in the saved level.
Enabling a chat again never replaces a level the user already chose.
Plan stays one-time: it lasts until the plan is settled, then the previous level returns.
In Bypass the host approves tool requests itself, including helper agents' requests.
Questions to the user and plan proposals still reach the chat.

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
