# Start a named live chat from a server

Run the account layout command on the server that will own the chat. Do not create a terminal Claude session or type into another session's pane.

## Prerequisites

- Node.js 22, Python 3, tmux, and `flock` are available on the Unix server.
- The selected Multibot reader is already installed for the server user.
- An approved account service key is available as `MULTIPROMPT_KEY`. A workspace key can create sessions only in its own workspace. Keep the key out of arguments, logs, transcripts, and agent instructions.
- `MULTIPROMPT_HOST` identifies this server's account slot, 0 through 2. `--host` overrides it. Do not publish a local session under another server's slot.
- Desktop and phone are signed into that account and online.

## Create the chat

From the Multiprompt checkout, inspect the available workspaces:

```sh
node tools/mp-layout.mjs list --json
```

Create a blank chat:

```sh
node tools/mp-layout.mjs spawn \
  --name "Research follow-up" \
  --folder "$PROJECT_FOLDER" \
  --workspace "Research"
```

To start with a task, add `--task "$FIRST_TASK"`. With no task, omit the flag. The command does not send a greeting or test message.

Like desktop live-chat creation, this command enables the reader's `bypassPermissions` mode. Run it only for a user-requested chat in a trusted project folder.

The folder must exist and satisfy the installed reader's folder grammar. Workspace names match exactly. Display names are not truncated. The tool uses `MULTIPROMPT_READER` when set; otherwise it uses the server user's selected reader.

A successful command prints one JSON object. The account tab has a manual display name, a `live-` parking-session name, and the existing host/workspace fields. No folder, credential, or first-task text is added to account layout metadata.

## Retry without duplicates

Use the same name, folder, workspace, and host on retries. Names use NFC normalization, outer-space trimming, and case-insensitive identity on one host. A deterministic UUIDv8 identifies the chat; its hex digits form the parking-session name. Different workspace/folder requests and existing terminal-name collisions are refused rather than overwritten.

The optional first task uses one durable message ID. Repeating the same task cannot create another submission. Changing that task on a retry is refused. To send a later task, use the existing chat's normal send path instead.

Setup is serialized per chat through an operating-system file lock. The host configuration records a pending creation before setup, so a crash or failed account write can be retried. A process crash releases the lock. Account writes use the existing revision comparison and retry against the latest layout; unrelated tabs and optional layout fields are retained.

## Check both screens

Check the named chat on desktop and phone within ten seconds of the command. Account publication is not proof of rendering. A healthy desktop normally polls account layout every five seconds; unavailable, busy, signed-out, or offline clients cannot satisfy the visibility check.

Desktop restores the deterministic live-chat identity when importing the tab and opens it in Chat View. Existing phone clients already recognize live parking sessions and their host-session marker. The wire layout and reader protocol do not change. Older desktop clients can retain the tab but do not gain the new identity-import behavior until updated.

The manual equivalents remain **Ctrl+T**, **Ctrl+K → New Claude session**, and the existing shortcut-help rows. This server automation adds no new Windows key binding.

## Install the agent skill

The canonical skill is [spawn-multibot-session](../../.claude/skills/spawn-multibot-session/SKILL.md). The fleet lead links that directory for each workspace owner into the skill directories used by Claude, Codex, and hax, then refreshes discovery in running sessions. Do not report fleet installation from the existence of this repository file alone.
