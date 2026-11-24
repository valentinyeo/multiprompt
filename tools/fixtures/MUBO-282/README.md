# Auto mode permission request fixtures

Snapshots of real Claude Code transcript records, reduced to the fields the app reads
and with every private value replaced. They are regression inputs, not history.

## Files

- `auto-open-request.jsonl`: an auto mode chat (`permissionMode: "auto"`) whose step waits
  for a yes. The last record is the assistant `tool_use`. No `tool_result` follows it.
- `auto-answered-request.jsonl`: the same chat after the yes. The matching `tool_result`
  is present with `permissionDecision.decision: "accept"`, so the request is closed.
- `auto-blocked.jsonl`: the same chat after the auto mode safety classifier refused the
  step. `toolDenialKind` is `automode-blocked`, the `tool_result` is an error, and
  `permissionDecision` carries `reasonType: "classifier"`, `reasonCode:
  "classifier:auto-mode"` and a `classifierCategory`. Nothing waits after this: the step
  is over and the chat carries on or stops.

## Where the shapes come from

Snapshotted on 2026-11-24 from real Claude Code 2.1.330 session transcripts written to
`~/.claude/projects/<folder>/<session>.jsonl`. Session ids, paths, commands and prompts
are replaced with `example-*` values; field names and record types are unchanged.

- `"permissionMode":"auto"` is a real mode value, written both in the
  `{"type":"permission-mode",...}` record and on every assistant and user record.
  Observed across 1097 records in one project folder, next to `bypassPermissions`.
  `acceptEdits` is not the same thing: accept edits skips the prompt for file edits only.
- An assistant record carries `message.content[].type == "tool_use"` with `id`, `name`
  and `input`, plus the top-level `uuid` and `timestamp`. Nothing more is written while
  the prompt is open, so "open" means the last `tool_use` has no `tool_result`.
- The answer arrives as a `{"type":"user"}` record whose `message.content[]` holds a
  `tool_result` for that `tool_use_id`, with a `permissionDecision` next to it.
- The auto mode refusal is the `automode-blocked` record in `auto-blocked.jsonl`, copied
  from a real one with the project details replaced. Its `toolUseResult` text is what the
  classifier prints to the chat.

Claude Code also fires the `PermissionRequest` hook at the same moment
(`https://docs.claude.com/en/docs/claude-code/hooks`), with `tool_name`, `tool_input` and
`permission_mode`. That event is not in the transcript, so the transcript is the state a
server can read at any time.

Keep it that way when re-snapshotting: no real paths, hosts, repo names, prompts or
commands.
