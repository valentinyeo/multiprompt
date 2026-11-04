---
name: spawn-multibot-session
description: Create a named Multibot chat or background runner in a project, workspace, and optional group. Use when asked to start a session, when a lead starts a runner, or when making a headless chat visible. Not for subagents inside an existing session.
---

# Start a named Multibot session

Use the account layout command, not terminal typing.

## Before creating

- Confirm the user requested a session, or a lead assigned runner work.
- Use the requested name, project folder, account workspace, and group.
- Infer a missing folder from the current project. Read account workspaces with `list --json`; do not invent a workspace or choose another silently.
- Use the server's configured host slot. `MULTIPROMPT_HOST` or `--host` must identify this server in the account, not another machine.
- An approved account service key must already be available as `MULTIPROMPT_KEY`. Never print it, put it in command arguments, or add it to agent instructions. Never create or broaden a key to finish this task.
- Use the canonical Multiprompt checkout containing this skill and `tools/mp-layout.mjs`. The reader must already be installed for the server user. `MULTIPROMPT_READER` can select its installed location.
- This command uses the existing Claude live host and its `bypassPermissions` mode. Use only trusted project folders. It is not a general launcher for arbitrary executables or in-session subagents.

## Visible chat

From the canonical checkout:

```sh
node tools/mp-layout.mjs list --json
node tools/mp-layout.mjs spawn \
  --name "Research follow-up" \
  --folder "$PROJECT_FOLDER" \
  --workspace "Research" \
  --group "Follow-ups" \
  --mode visible
```

`visible` is the default. Omit `--group` when no group was requested. A missing group is created on the desktop; a matching group name is reused. Group names match exactly after NFC normalization and outer-space trimming.

Include `--task "$FIRST_TASK"` only when requested or assigned. With no first task, omit the flag. Never send a greeting or readiness test. Leave the chat idle for the user's first message.

## Headless chat and lead-started runners

A lead starts a separate runner with this same command. Prefer headless mode for assigned background work unless the user requested a visible chat:

```sh
node tools/mp-layout.mjs spawn \
  --name "$RUNNER_NAME" \
  --folder "$PROJECT_FOLDER" \
  --workspace "$WORKSPACE" \
  --group "$RUNNER_GROUP" \
  --mode headless \
  --task "$RUNNER_TASK"
```

Headless mode starts the live host without a discoverable tmux pane or account tab. It does not open a chat on either device. It still requires account authorization and an existing workspace. The group is retained for later visibility. Do not use terminal Claude or a separate terminal-runner launcher as a substitute.

To make that runner visible, repeat the command with the same name, folder, workspace, and group, but `--mode visible`. Omit `--task` unless retrying the identical first task. Promotion retains its SID, history, and durable first-task ID; it does not restart an already-running host.

Subagents inside an existing session remain outside this command's scope. This skill starts independent live-host chats, not a different provider or an internal subagent.

## Repeat and verify

- Keep the same name, folder, workspace, group, and host when retrying. The same normalized name on one host has one stable identity.
- Keep the same first task on a retry. Its durable message ID prevents a second submission. A different first task is a conflict, not a second task.
- Visible-to-headless is refused. This command never silently hides an existing visible chat.
- Treat a nonzero exit as failure. Follow its refusal instead of changing the name to evade a collision.
- A successful visible JSON result proves account publication, not screen rendering. Check the named chat and its group on signed-in, online desktop and phone within ten seconds. Record which devices were actually checked. Older phone clients retain the chat but lack group presentation.
- A successful headless result proves host setup, not task completion or visibility. Check the assigned work's actual output. Promote it when the user wants to inspect the chat.
- Never claim live visibility from a layout readback alone.
- Do not use `tmux send-keys`, attach to someone else's pane, or use `mp-layout open` as a substitute.

## Fleet installation

The lead links this canonical skill directory into each harness's skill directory for every workspace owner. Claude uses `.claude/skills`, Codex uses `.agents/skills`, and hax uses `.config/hax/skills` under that owner's home. Keep one source; do not make divergent copies. Refresh discovery in already-running sessions. A repo-local skill file alone does not prove fleet-wide installation.
