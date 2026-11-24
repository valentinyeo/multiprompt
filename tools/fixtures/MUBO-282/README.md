# Auto mode permission request fixtures

Snapshots of real Claude Code transcript records, reduced to the fields the app reads
and with every private value replaced. They are regression inputs, not history.

## Files

- `open-request.jsonl`: a chat in auto mode (`acceptEdits`) whose step waits for a yes.
  The last record is the assistant `tool_use`. No `tool_result` follows it.
- `answered-request.jsonl`: the same chat after the yes. The matching `tool_result`
  is present, so the request is closed.
- `declined-request.jsonl`: the same chat after a no. The `tool_result` carries
  `toolDenialKind: "user-rejected"`, so the request is closed too.

## Why these are the real shapes

- Claude Code writes a `{"type":"permission-mode","permissionMode":...}` record whenever
  the mode changes. `acceptEdits` is auto mode; `bypassPermissions` never asks.
- An assistant record carries `message.content[].type == "tool_use"` with `id`,
  `name` and `input`, plus the top-level `uuid`. Nothing is written while the prompt
  is open.
- The answer arrives as a `{"type":"user"}` record whose `message.content[]` holds a
  `tool_result` for that `tool_use_id`. On a refusal it also carries
  `toolUseResult: "User rejected tool use"` and `toolDenialKind: "user-rejected"`.
- Claude Code also fires the `PermissionRequest` hook for the same moment
  (`https://docs.claude.com/en/docs/claude-code/hooks`), with `tool_name`, `tool_input`
  and `permission_mode`. That event is not in the transcript, so the snapshot above is
  the state the app can read from the server at any time.

Private values (paths, branch, session ids, prompts, commands) are replaced with
`example-*` values. Keep it that way when re-snapshotting.
