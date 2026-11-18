# Start a Multibot session

Use the shared server command. It reads the approved account key once through `yeo-key`, in its own process. Callers do not need a key.

```sh
mp session new --name "Research follow-up" --folder "$PROJECT_FOLDER"
mp session new --name "Release runner" --folder "$PROJECT_FOLDER" --workspace "Work" --group "Runners" --task - < brief.md
mp session star "Release runner"
mp session unstar "Release runner"
mp session move "Release runner" --workspace "Research" --group "Follow-ups"
mp session list
```

New chats are visible top-level chats in the first account workspace. Omit `--task` to leave the chat idle. Use `--helper` only to place a helper immediately after the calling `MULTIPROMPT_TAB`. A helper inherits that tab's workspace and group.

Names match exactly after NFC normalization, outer-space trimming, and case folding. Repeating a name reuses its live host and starts it if stopped. Existing placement wins; use `move` to change it. A different folder or an explicit conflicting provider is refused. Each task text has a durable ID per session. Repeating that text cannot send it twice. Different text gets a different ID.

`star`, `unstar`, and `move` accept a display name or a session ID. An ambiguous display name requires `--host N` or the session ID. `move` without `--group` places the session at the top level of its destination. The destination workspace must exist.

`new` also accepts `--host N` and `--provider claude|hax`. `MULTIPROMPT_HOST` selects the current server's account slot, defaulting to 0. Do not name another machine's slot when starting a local host. The installed reader must exist at `~/.multiprompt-runtime/reader.py`; `MULTIPROMPT_READER` can select another installed copy. Claude hosts use `bypassPermissions`. Use only trusted project folders.

Every mutation reads the account layout back before reporting `visible:true`. Missing publication, refused authorization, unsupported Starred, or an unreachable service exits nonzero. Account visibility proves publication, not pixels on an offline or signed-out device. Confirm the sidebar and Inbox on signed-in desktop and phone before claiming both devices passed.

## Install after merge

Multi Bot installs the merged command for the server user. From the canonical checkout, after it contains this change:

```sh
mkdir -p "$HOME/.local/bin"
ln -sfn "$PWD/tools/mp-layout.mjs" "$HOME/.local/bin/mp"
mp session --help
mp session list
```

Keep `~/.local/bin` on every session's PATH. The linked target must stay in the canonical checkout, not a disposable worktree. `yeo-key` and the installed reader must already be available to the server user. No key is copied into an environment file, command argument, instruction, or log. The key is not inherited by the reader or host process.

The approved 1Password item remains unchanged. Suggested name for a later owner-approved rename: **Multibot Session Admin Key**. Updating that name requires updating the command's lookup too.

The canonical [spawn skill](../../.claude/skills/spawn-multibot-session/SKILL.md) contains one instruction. Link its directory into each owner's Claude, Codex, and hax skill directories. Refresh discovery in running sessions.

## Older automation

`mp-helper` remains available to inspect, message, and close existing parent-scoped helpers. Start new sessions with `mp session new`; use its explicit `--helper` flag for caller-relative placement. The new command does not use the helper bridge's `visible:false` success path.

Existing `mp-layout` and `mb` integrations keep their lower-level forms. Their key handling is unchanged. They are not the default session-start instructions.

## One roster command

`node tools/mb.mjs` lists, opens, closes, renames, and moves runners, and it creates, renames, deletes, and lists workspaces and groups. `mb star`, `mb mute`, and `mb manual` turn those session marks on or off. `mb settings` turns frequent, favorites, all, and frequent-first on or off. `mb pull` reads the shared layout again. Running any of these twice leaves the same result.

These actions stay on this PC and have no command: this window's look and size; the chat open on this screen; the browser or computer pane on this screen; menus that only open another list; marks stored on this PC (pin, lock, keep-alive, snooze, remind, archive), plus quit, restart, and crash tools; sign-in and account devices; focusing a tab or workspace already on screen.

`mb workspace color <workspace> <color>` sets a workspace color from 0 to 7. `mb style <session> --face <0-19> --color <0-7> --photo <png>` sets the face, color, and photo the layout service already stores. A photo is a PNG file; the service keeps the image and a revision on the session.

`mb roster apply <file>` makes the account match the file. The file names workspaces (with an optional color), groups, and runners. Runner fields are name, kind, title, group, workspace, command, model, face, color, and photo. `--dry-run` prints the plan and changes nothing. A second apply of the same file does not publish again. Close, delete, and stopping a host apply only to workspaces, groups, and sessions this command created. There is no separate session registry. An empty group is remembered on this machine and shows up in Multibot once a session carries that group name.

## Compatibility and verification

The command uses the existing account layout, `favorite`, and `group` fields. No new route, schema, desktop command, or phone protocol is needed. Older clients preserve metadata they cannot display. Phone group presentation still depends on the installed Android version.

`service/test/mp-session.test.js` exercises every verb against the production account Worker and D1 in Miniflare, in a disposable account and workspaces. The installed-command case uses the production reader's config and message store, a synthetic key helper, and a host-start stand-in. HTTP goes to the disposable Worker. Cleanup disposes the database and temporary host files. Tests also check retries, stopped-host restart requests, layout readback failure, and secret-safe failures. They do not prove paid-agent operation or device rendering.

The manual route remains **Ctrl+T**, **Ctrl+K → New Claude session**, and the existing shortcut-help rows. No Windows binding is added for server automation.
