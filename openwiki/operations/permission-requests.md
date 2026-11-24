# Permission requests

A chat that runs Claude Code in auto mode stops on a safety check and waits for a yes.
Multiprompt finds those open requests on the server and shows them in the tab's Waiting
mark and in `Ctrl+K → Permission requests`. Answering them is MUBO-282 part 2.

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
| `mode` | string | `acceptEdits` (auto mode) or `default` |
| `why` | string | one plain sentence saying why it was blocked |
| `askedAt` | string | transcript timestamp of the blocked step |

Rows are newest first by `askedAt`.

## Where it comes from

The server helper reads the chat's Claude Code transcript, the same file the history
reader already follows:

- `{"type":"permission-mode","permissionMode":"acceptEdits"}` is the mode. A
  `bypassPermissions` chat never asks and never lists.
- The blocked step is an assistant record whose `message.content[]` has
  `type: "tool_use"` with an `id`, `name` and `input`. Nothing more is written while
  the prompt is open.
- The answer closes it. A `{"type":"user"}` record with a `tool_result` for that
  `tool_use_id` means it is no longer open. A refusal also carries
  `toolDenialKind: "user-rejected"`.

Claude Code's `PermissionRequest` hook fires at the same moment with `tool_name` and
`tool_input`. It is not in the transcript, so the transcript is what a server can read
at any time. Real snapshots live in `tools/fixtures/MUBO-282/`.

## Answers

Part 1 is read only. Part 2 adds approve and decline: approve sends the same answer the
console prompt expects, decline sends the refusal, and both land as the `tool_result`
row above.
