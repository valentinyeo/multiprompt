---
name: spawn-multibot-session
description: Create a named Multibot live chat for the user from a server. Use when asked to start, open, or spawn a new Multibot session in a project and workspace, optionally with a first task. Do not substitute a terminal session.
---

# Start a named Multibot live chat

Use the account layout command, not terminal typing.

## Before creating

- Confirm the user requested a new session.
- Use the requested name, project folder, and account workspace.
- Infer a missing folder from the current project. Read account workspaces with `list --json`; do not invent a workspace or choose another silently.
- Use the server's configured host slot. `MULTIPROMPT_HOST` or `--host` must identify this server in the account, not another machine.
- An approved account service key must already be available as `MULTIPROMPT_KEY`. Never print it, put it in command arguments, or add it to agent instructions. Never create or broaden a key to finish this task.
- Use the canonical Multiprompt checkout containing this skill and `tools/mp-layout.mjs`. The selected reader must already be installed for the server user. `MULTIPROMPT_READER` can select its installed location.

## Run the command

From the canonical checkout:

```sh
node tools/mp-layout.mjs list --json
node tools/mp-layout.mjs spawn \
  --name "Research follow-up" \
  --folder "$PROJECT_FOLDER" \
  --workspace "Research"
```

Include a first task only when requested:

```sh
node tools/mp-layout.mjs spawn \
  --name "Research follow-up" \
  --folder "$PROJECT_FOLDER" \
  --workspace "Research" \
  --task "$FIRST_TASK"
```

With no first task, omit `--task`. Do not send a greeting or a readiness test. Leave the chat idle for the user's first message.

The command creates a live-host parking session and publishes a manually named account tab. Desktop uses the session name to restore its chat identity. Phone discovers the same host identity. Existing Ctrl+T and Ctrl+K **New Claude session** remain the manual creation route.

## Repeat and verify

- Keep the same name, folder, workspace, and host when retrying. The same normalized name on one host has one stable identity.
- Keep the same first task on a retry. Its durable message ID prevents a second submission. A different first task is a conflict, not a second task.
- Treat a nonzero exit as failure. Follow its refusal instead of changing the name to evade a collision.
- A successful JSON result proves account publication, not that either screen has rendered it. Check the named chat on signed-in, online desktop and phone within ten seconds. Record which devices were actually checked.
- Never claim the live visibility gate from a layout readback alone.
- Do not use `tmux send-keys`, start terminal Claude, attach to someone else's pane, or use `mp-layout open` as a substitute. Those do not create this live chat.

## Fleet installation

The lead links this canonical skill directory into each harness's skill directory for every workspace owner. Claude uses `.claude/skills`, Codex uses `.agents/skills`, and hax uses `.config/hax/skills` under that owner's home. Keep one source; do not make divergent copies. Refresh discovery in already-running sessions. A repo-local skill file alone does not prove fleet-wide installation.
