Sanitised config and state shapes from a worker host whose chats are owned by another
OS user, as they stood during the 2026-11-24 nightly rotation. Account names, session IDs,
chat names and host paths are synthetic. No conversation content.

- `config-owner.json`: a working chat config, no explicit command.
- `config-owner-runner-binary.json`: the failing shape, where the command is the runner's
  own resolved binary inside a home the owner cannot read.
- `state-owner.json`: the state file left behind by a failed start, including the
  `agent_not_found` startup failure.
