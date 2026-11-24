# Permission requests

A chat that runs Claude Code in auto mode stops before a step that its safety classifier
will not wave through, and waits for a yes. Multiprompt finds those open requests from the
server side and, in part 1, shows them: the tab's Waiting mark and `Ctrl+K → Permission
requests`. Answering them is MUBO-282 part 2. Multiprompt Android reads the same rows
(MUBO-283).

## Fields

Each open request is one row with these keys. This is the shape the desktop app, `mb`,
and Multiprompt Android read, so keep the names when a client is behind.

| Key | Type | Meaning |
| --- | --- | --- |
| `chat` | string | chat id the tab uses |
| `title` | string | chat title, or the id when untitled |
| `host` | string | server the chat runs on |
| `tool` | string | tool the blocked step wants, `Bash`, `Edit`, `Write` |
| `toolUseId` | string | the `tool_use` id; the answer goes to this step |
| `detail` | string | the command, description or path, private text included |
| `mode` | string | `auto`, `default` or `acceptEdits` |
| `why` | string | one plain sentence saying why it was blocked |
| `askedAt` | string | transcript timestamp of the blocked step |

Rows are newest first by `askedAt`.

## Where it comes from

The server helper reads the chat's Claude Code transcript, the same file the history
reader already follows, at `~/.claude/projects/<folder>/<session>.jsonl`:

- `{"type":"permission-mode","permissionMode":"auto"}` is auto mode. `auto` is a real
  value, written on that record and on every assistant and user record. A
  `bypassPermissions` chat never asks and never lists.
- The blocked step is an assistant record whose `message.content[]` has
  `type: "tool_use"` with an `id`, `name` and `input`. While the prompt is open nothing
  else is written, so "open" means that `tool_use` has no `tool_result` yet.
- The answer closes it: a `{"type":"user"}` record whose `message.content[]` holds a
  `tool_result` for that `tool_use_id`, with `permissionDecision` beside it. A refusal
  from the person carries `toolDenialKind: "user-rejected"`.
- A step the auto mode classifier refuses outright is a `tool_result` with
  `toolDenialKind: "automode-blocked"` and `permissionDecision` `reasonType: "classifier"`,
  `reasonCode: "classifier:auto-mode"`, plus a `classifierCategory`. Nothing waits after
  that: the step is closed, so it is not an open request. `blockedRequests` reports it for
  the history, and the `why` names the category in plain words.
- A closed step means a `PermissionRequest` hook event was answered or refused, or the
  classifier refused it.

Claude Code's `PermissionRequest` hook fires at the same moment with `tool_name`,
`tool_input` and `permission_mode`. It is not in the transcript, so the transcript is what
a server can read at any time. Real snapshots live in `tools/fixtures/MUBO-282/`, and the
fixture README names the source version and the record shapes.

## Reading them

The status row the Chat View already polls now carries `permission_request` when a chat has
one open, so the desktop reads it without a second file walk. `src/chat_transcript.zig`
parses it into the chat status, and `src/chat_permission_requests.zig` turns open requests
into palette rows in plain words, newest first.

The tab shows the Waiting mark (`needs_attention`, source `permission`) while a request is
open. The mark clears when the answer closes the step, or when the request disappears from
the transcript. `Ctrl+K → Permission requests` lists the same rows across every chat and
Enter opens that chat. There is no new element around the messages.

- `tools/permission-requests.mjs`: `openRequests(chats)` and `blockedRequests(chats)`,
  each row shaped as above; `describeRequest(row)` for the one-line wording.
- `mb permission-requests [--dir ~/.claude/projects] [--json]`: lists open requests from
  local transcripts, newest first. Running it twice prints the same rows.

## Answers

Part 1 is read only. Part 2 adds approve and decline: approve sends the same answer the
console prompt expects, decline sends the refusal, and both land as the `tool_result`
row above.
