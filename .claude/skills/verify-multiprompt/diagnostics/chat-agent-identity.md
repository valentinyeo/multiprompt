# Chat agent identity

SOFT-2443 links each hosted chat record to one Hypertask agent ID and token-file path. Names are never used to find an agent. The helper runtime provisions before starting the AI and checks the published chat name every 20 seconds, including during a reply. Switching AI carries the binding forward.

## Hosted proof

`.github/workflows/hypertask-agent.yml` runs `timeout 120 python3 tools/hypertask-agent-test.py -v` on GitHub Ubuntu. All HTTP requests go to a loopback fake server. No live credentials or Hypertask calls are needed.

The workflow first runs the rename regression against `tools/fixtures/SOFT-2443/mp_sessions.before.py` and requires the original name to remain unchanged. The same test must then pass against production code. It checks the resulting remote name and the exact chat-token authorization. Other cases cover distinct agents, duplicate-binding refusal, close/archive, retries, denied permissions, parent-token isolation, and an actual `mb rename` followed by the desktop's name-publication boundary and runtime sync.

The existing Switch AI tests check that the agent ID, token path and name survive provider changes. Both formal coverage records retain the unchanged modeled delivery and switch decisions and refresh their file hashes. Their hosted workflows rerun the native probes and mutation checks.

## Permissions and setup

An existing session token is linked only through its recorded `hypertask_token_file`, or the stable `<tmux>-agent-token` filename under the session credentials directory. Old display-name token filenames need an explicit `hypertask_token_file` in the chat record. The code never searches by display name, rotates a token, or borrows another chat's login.

New-agent creation requires an explicitly supplied `HYPERTASK_MANAGEMENT_KEY`. The runtime never reads a saved human login. It removes inherited board tokens and the management key from the AI process environment and supplies only the linked chat token. An ambiguous creation failure requires recovery instead of automatically creating a second agent.

Rename and archive requests always use that chat's own token. Hypertask currently rejects these operations for agent tokens with `Agents cannot manage agents`. Failed operations remain pending and report an error; they never fall back to the owner's login. This upstream permission limit prevents a live end-to-end success today. The fake server proves both permitted behavior and the refusal path, not a production API permission grant.

Closing through `mp-sessions close` or disabling a helper is permanent for this binding. Stopping or rotating the runtime is not. Closed records retain their agent ID for archive recovery. A new top-level chat using a closed name gets a new session address. Hiding a desktop tab alone is not treated as permanent closure.

No Windows UI, Android UI, production archive or production self-rename success is claimed by this proof. Existing clients can ignore the additional helper-record fields; no shared wire schema changes.
