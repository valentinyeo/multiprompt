# Start a named session from a server

Use one command for visible live chats and background runners. Run it on the server that owns the project, not through terminal typing in another session.

## Prerequisites

- Node.js 22, Python 3, tmux, and `flock` on the Unix server.
- The Multibot reader already installed for the server user.
- An approved account service key in `MULTIPROMPT_KEY`. A workspace key is limited to its own workspace. Keep keys out of arguments, logs, transcripts, and agent instructions.
- `MULTIPROMPT_HOST` identifies this server's account slot, 0 through 2. `--host` overrides it. Never publish a local session under another server's slot.
- Visible chats need signed-in, online desktop and phone clients. Headless chats need account authorization, but no running client.
- Group placement needs the service's `groups` capability. Older services are refused before setup when a group is requested.

## Visible chat

Inspect workspaces from the Multiprompt checkout:

```sh
node tools/mp-layout.mjs list --json
```

Create a blank chat:

```sh
node tools/mp-layout.mjs spawn \
  --name "Research follow-up" \
  --folder "$PROJECT_FOLDER" \
  --workspace "Research" \
  --group "Follow-ups" \
  --mode visible
```

`visible` is the default. Omit `--group` when none was requested. The desktop creates a missing group or reuses its matching name. Device-local numeric group IDs never cross the account protocol.

Add `--task "$FIRST_TASK"` only for an assigned first task. Otherwise omit it; the command sends no greeting or test message. It enables the existing Claude live host's `bypassPermissions` mode, like desktop creation. Use trusted project folders only.

The folder must exist and satisfy the reader's folder grammar. Workspace names match exactly. Group names use NFC normalization and outer-space trimming, remain case-sensitive, and allow at most 64 UTF-16 units. Display names are not truncated. `MULTIPROMPT_READER` can select the installed reader.

## Headless chat

Use the same inputs with `--mode headless`. This starts the native live host without creating a tmux parking pane or publishing an account tab. It cannot appear through ordinary tmux discovery. The existing private host configuration retains its name, workspace, folder, and group; no separate session registry is introduced.

A lead starts an independent runner through this command too:

```sh
node tools/mp-layout.mjs spawn \
  --name "$RUNNER_NAME" \
  --folder "$PROJECT_FOLDER" \
  --workspace "$WORKSPACE" \
  --group "$RUNNER_GROUP" \
  --mode headless \
  --task "$RUNNER_TASK"
```

This uses the Claude live host, not an arbitrary executable or provider. Subagents inside an existing session are out of scope. This command does not replace their harness-native controls.

To make a headless session visible, repeat its inputs with `--mode visible`. Omit the task or repeat its exact original text. Promotion creates the parking pane, binds its existing SID, and publishes one grouped account tab. The existing host and message history remain intact. Visible-to-headless requests are refused rather than silently hiding an existing chat.

## Retry without duplicates

Keep the same name, folder, workspace, group, and host. Names use NFC normalization, outer-space trimming, and case-insensitive identity on one host. A deterministic UUIDv8 identifies the chat; its hex digits form the eventual parking-session name. Conflicting placement and terminal ownership are refused.

The first task has one durable message ID across retries and promotion. Repeating its text cannot create another submission. Changing that text is refused; send later tasks through the existing chat instead.

Setup uses an operating-system file lock and a private pending host configuration. A crash releases the lock; partial setup can be retried. Visible publication uses the existing account revision comparison and preserves unrelated tabs and unsupported metadata.

The JSON result includes `mode`, `group`, and the stable `sid`. Headless success means host setup, not task completion. Visible success means account publication, not screen rendering.

## Device compatibility and proof

Check a visible chat on both devices within ten seconds. A healthy desktop normally polls every five seconds; busy, signed-out, or offline clients cannot satisfy this check. Headless sessions intentionally have no screen-visibility gate until promoted.

Desktop restores live-chat identity, Chat View, and the named group during import. Current phone clients already recognize visible live-host sessions and their host marker. They lack group presentation. The additive `group` tab field is capability-gated: older clients do not receive it, and their uploads preserve stored group metadata. An absent field means unknown; an empty string explicitly clears grouping. Older desktop clients need an update for identity import and grouping. Older services remain usable without grouping; desktop omits group writes when unsupported.

Phone group presentation requires an Android update. Metadata preservation alone does not prove cross-client grouping or real phone visibility.

The manual route remains **Ctrl+T**, **Ctrl+K → New Claude session**, and the existing shortcut-help rows. No new Windows key binding is added for server automation.

## Install the agent skill

The canonical skill is [spawn-multibot-session](../../.claude/skills/spawn-multibot-session/SKILL.md). The lead links that directory for each workspace owner into Claude, Codex, and hax skill directories, then refreshes discovery in running sessions. Repository presence alone does not prove fleet installation.
