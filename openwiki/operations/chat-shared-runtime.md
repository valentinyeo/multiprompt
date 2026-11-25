# Shared chat runtime

- Desktop and Android send the complete canonical reader.
- The outer loader selects the inner reader.
- Selection happens before requests.
- Imports never install a runtime.
- The full-file hash identifies the client artifact.
- The hash of the inner reader, connectors and bundled tool sources identifies the selected runtime.

## Selection

- Each Unix user has a private runtime.
- Its directory is `~/.multiprompt-runtime`.
- `active.json` contains `protocol`, `generation`, and `sha256`.
- Protocol 1 and the three existing metadata fields remain unchanged.
- `RUNTIME_GENERATION` is derived from the bundle hash, not maintained by hand.
- Its integer uses bit 52 plus 52 hash bits, above legacy counters and within JSON safe-integer range.
- The full SHA-256 fingerprint, not integer ordering, decides whether a runtime differs.
- A lock serializes selection.
- Readers use owner-only permissions.
- Each reader is stored as `<sha256>.py`.
- Publishing syncs a temporary file.
- An atomic rename publishes it.
- Every tool listed in the runtime tool table is published executable.
- Its mode is set on the temporary file before the rename.
- An install removes leftover temporary files.
- Legacy integer-only launchers select the installed fingerprinted reader instead of downgrading it.
- Fingerprinted launchers replace a different selection with their own bundle.
- Hashes carry no release ordering; two different fingerprinted clients select the last bundle presented.
- Published tools carry the app version that published them, in `tools.json`.
- A bundle never moves a published tool to a copy from an older app version.
- The bundle's tools move together, so `mp-send` and `mp-sessions` stay a matched pair.
- A bundle without an app version cannot replace tools a versioned bundle published.
- A newer bundle replaces drifted tool links, so a newer client repairs an older client's copy.
- This ordering covers tools only; reader selection still takes the last bundle presented.
- Identical bundles keep the existing selection without rewriting its metadata.
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

## Saved live state (SOFT-1872)

- Generation 134 adds opt-in `events_subscribe` with `snapshot: true`.
- A cold cursor receives `result.live_snapshot` with `seq`, `events`, and `requests`.
- `events` holds the current turn, up to 96 live items, and host settings and status.
- `requests` holds only open approvals, questions, and plans.
- `plan.snapshot` supplies plan text without reopening its card.
- The client replaces live state atomically, then resumes events after `seq`.
- Legacy subscriptions keep their existing response shape.
- Older servers ignore the opt-in field and keep replaying events.
- Saved state and event cursors commit with each event.
- An upgraded store reconstructs only the latest turn and request decisions, not every past turn.

Each reader checks maintenance every minute.
A transaction keeps the last 2,000 events per chat once per UTC day, after saving current state.
Canonical messages, connector facts, and transcripts remain intact.
A pruned live cursor receives a fresh snapshot.
A pruned queue cursor receives `resync_required: true`; clients must discard the replica and fetch `message_snapshot`.
Reverting the reader generation stops future cleanup but cannot restore deleted events.

## Hosted chats and other tools

- New live chats have no parking terminal or idle sleep process.
- Their saved `tmux` field is a routing name, not proof of a terminal.
- Host config stores the provider, session id, name and working directory.
- For Claude, config `native_session` identifies the current provider conversation.
  The host updates it from each Claude `system.init` event, including resumed conversations.
- Hosted Claude transcript reads resolve config `native_session`, then the latest valid init event's session, then `sid`.
  A missing current transcript never falls back to a different conversation.
- Config `sid` remains the stable host routing id and history response id. Do not use it as the current Claude conversation id.
- Older configs gain `native_session` when the updated host receives its next init event.
  Existing history and message requests still use the stable `sid`.
  Android client coordination is tracked in https://app.hypertask.ai/detail/project-2060/2681.
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

## When a plan runs out

A live chat moves itself to the next AI when its AI reports that the plan is used up.
The host reads that from the provider's own error event: a Claude result that is an error, a Codex error notification, a Pi turn that stops with an error, or an Antigravity result that is not a success.
The predicate looks for that provider's usage-limit, rate-limit or quota wording, so ordinary reply text never triggers it.

The turn ends as failed with the reason `usage_limit`.
The fallback order is Claude, then Codex, then Pi, then Antigravity, saved with the host config as `auto_switch`.
The order travels with the chat, so a switch keeps it.
An AI that just ran out is marked empty and skipped for one hour, so a chat never ping-pongs between two empty plans.
A chat whose every AI is empty stays where it is and says so in one line.

The switch waits for the chat to be idle, then uses the existing Switch AI path in a detached process.
The old agent's config is disabled and its locator moves before the new AI starts, and the old agent is then stopped, so two AIs never work the same chat.
The unanswered user message is queued again for the new AI and delivered after the handover is read.
The divider says `Switched AI automatically: <old> ran out of plan`.

Ctrl+K "Chat View: Auto-switch AI when a plan runs out" toggles this per chat and is on by default.
There is no dedicated shortcut.
The setting is `on` in the host config and is accepted while the host is stopped.
The command-line form is `python3 <reader> host switch-ai <provider> <sid> --to <target>` with the same result; the automatic path adds no new provider or wire field.

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
