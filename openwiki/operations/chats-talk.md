# Chats talk to each other

Agent sessions on the server, Claude, Codex, Pi, hax or Cursor, can list the live chats by the name shown in the desktop app, read a chat's last answer and put a message into another live chat. Every chat gets the same tool: `mp-send` has `list`, `read` and `--to`. Use it only when Valentin asks.

## Install

Run `tools/install-mp-talk.sh` from a checkout. It copies `mp_send.py`, `mp_sessions.py`, `mp_helper.py`, `mp_shell.py`, `multibot_feedback.py` and `mp-layout.mjs` to `~/.local/share/multiprompt-talk/` and writes the `mp-send`, `mp-sessions`, `mp-helper`, `mp-shell`, `multibot-feedback` and `mp-layout` wrappers into `~/.local/bin`. Run it again after a release to update.

Every server account that runs chats needs its own copy, because `~/.local/bin` and `~/.multiprompt-runtime` belong to one account. `--user` repeats the install for another account on the same server and needs password-free sudo:

```sh
sudo tools/install-mp-talk.sh --user inne --user valentin
```

`--check` prints each tool as `ok`, `missing` or `broken` for the accounts you name and exits 1 when one is not usable:

```sh
sudo tools/install-mp-talk.sh --check --user inne --user valentin
```

The desktop publishes `mp-send`, `mp-sessions`, `mp-helper`, `mp-shell`, `multibot-feedback`, `mp-layout` and `mp-zsb` into `~/.multiprompt-runtime` for the account that runs the runtime, so an account whose chats use the runtime copy needs no install step. An account on the same server that has no `~/.multiprompt-runtime` gets the tools from the install step above and nothing else.

## List chats

```sh
mp-send list
mp-send list --json
mp-sessions
mp-sessions health
mp-sessions health --json
```

`mp-sessions list` and `mp-sessions health` read the desktop's current sidebar report. Both show visibility and its reason, Waiting, pinning, the chat's workspace, the workspace on screen, and the selected sidebar view. Visibility means membership in the sidebar's rendered row list, not whether the row is scrolled into the viewport. Waiting uses the same flag as All Sessions; it is not inferred from a missing sidebar row. Archived sessions come from the desktop's archive inventory. Tab and archive matches use this server's host slot: `MULTIPROMPT_HOST` when set, then `multiprompt_slot` on this machine's entry in the installed servers file, then the slot recorded for the calling chat. With none of those the slot is unknown, so every host's tabs are read and `mp-sessions send` still reaches a chat by its name.

Both JSON outputs add `in_layout`, `visible`, `hidden_reason`, `waiting`, `pinned`, `archived`, `user_hidden`, `active_workspace` and `sidebar_view`. Unknown desktop state is `null`, not `false`. Older desktops report `desktop visibility unavailable`; an offline desktop reports `desktop offline`. Older helper bundles can still list chats without the desktop API. These additive diagnostic fields do not change saved layouts, chat delivery, or Android sync.

`mp-sessions health` reports `BROKEN hidden: <reason>` for a chat in the layout but absent from the sidebar. Deliberate Waiting, archive and user-hide states do not make visibility broken, though host or history failures still do. Filters, other workspaces, collapsed groups or sections, and unexplained missing rows retain their reported reason. These are read-only agent diagnostics, so they have no desktop shortcut or palette action.

`mp-sessions health` prints one `OK` or `BROKEN reason` line per chat in its catalog. It checks the host process, the registered conversation, the desktop tab view, and whether history can be read. `--ping` sends a visible health ping through chat delivery. When the desktop app is offline, tab and history checks report `UNKNOWN desktop offline` instead of `OK`. Any broken chat makes the command exit non-zero.

Each row has the session link, AI, state (`busy` while a turn runs, otherwise `idle`), terminal session, session id and folder. The link looks like `Poteto{live-8bc7bac}`. A name with a space looks like `@Alpha Lead{live-alpha}`. `--json` also has a `link` field with that token. In Chat View the token shows the name, and a click opens that session. A click works when that session is open. An unknown session stays plain text. A chat counts as live when its host process runs or its terminal session exists, so a hosted chat needs no terminal and a terminal chat with a stopped host still appears, as `stopped`. A chat whose name has not been published yet uses its terminal session as the name inside the link, and can still be reached by that session.

## Start a chat

```sh
mp-sessions start --name "Late Lead" --folder ~/projects/app --workspace "Studio" --provider claude
```

`start` creates a hosted chat on this server, or reuses the chat with the same name and folder, so a second run reports `already`. Reusing a name that was started with another folder fails and names the chat.

`--workspace` names an existing workspace. When the desktop app is reachable the name is checked against its live sidebar list; when it is closed the name is matched against the synced layout and published chat names, so the chat records that workspace and opens there on its next start or restart. A name in neither place stops with `no workspace named <name>`. With the desktop closed the chat still starts and reports `"visible":false` with `visible_error` `desktop_offline`; no tab opens until the desktop is back.

## Identify your own chat

```sh
mp-sessions whoami
mp-sessions whoami --json
```

Prints only your chat's current desktop name, session id, linked agent provider and clickable chat link. JSON has `name`, `sid`, `provider`, `tmux` and `link` fields. The caller is resolved from `MULTIPROMPT_TAB`, then `TMUX_PANE`, just like workspace-scoped session commands. Hosted chats use their `MULTIBOT_PROVIDER` and `MULTIBOT_SID` to select their own agent binding. Other callers need one unambiguous binding for their terminal session.

Each invocation reads the desktop's live tab name, so the next call reflects a rename without waiting for the published name cache. If the desktop is unavailable, your tab is missing or your agent binding is ambiguous, the command exits 2 without printing another chat's identity.

This is an agent-only command. It needs no Ctrl+K entry, keyboard shortcut or shortcut-documentation row because its caller is the running agent, not the desktop user.

## Read the last answer

```sh
mp-send read "Pi Helper"
```

Prints the newest assistant answer of a Claude, Codex or Pi chat. Names match as for `--to`. A chat with no answer yet exits 3. hax and Cursor chats can be listed and messaged but not read.

## Send a message

```sh
mp-send --to "Multi Bot Opus Lead" "Can you check the release build?"
mp-send --to "multi bot" --wait "short prefix works when it is unique"
mp-send --to "@Multi Bot Opus Lead{live-308b1fc}" "mention form from the @ pill"
mp-sessions send --workspace "Studio" --to "Late Lead" "one chat only"
mp-sessions send --workspace "Studio" "Late Lead please review" "the name in front sends to that chat only"
mp-sessions send --workspace "Studio" --all "every chat in the workspace"
```

- Matching ignores case. An exact name wins, then a unique prefix. Two matches stop with an error that lists each matching chat's name, terminal session and workspace, and nothing is sent.
- `{live-...}` is the terminal session the @ pill appends. It is an exact key and needs no name.
- The text sent starts with `From <your chat name>:`. The sender is found from `MULTIPROMPT_TAB`, then `TMUX_PANE`. Outside a chat, pass `--from NAME`.
- A busy chat queues the message and takes it when its turn ends. `--wait` waits for acceptance. `--json` prints machine output.
- Sending to your own chat is refused.
- Loop cap: one chat takes at most 6 messages from other chats in a minute, and one sender sends at most 12 in a minute. Past a cap `mp-send` prints `slow down` and exits 5.
- `mp-sessions send --workspace W --to NAME TEXT` reaches only NAME, which must be one chat inside W. `--workspace W TEXT` reaches every other running chat in W, and reaches only NAME when TEXT starts with the name of a chat in W. A sent name that two chats in W share stops with the error that lists them. `--all` always means every chat in the workspace, so `--workspace W --all TEXT` is the explicit broadcast.

The old form `mp-send <provider> <sid> "text" --tmux <session>` still works.

## Helper chats

A chat starts its own helper chats with `mp-helper`. The desktop publishes it into `~/.multiprompt-runtime`, which is on every live chat's PATH, so no install step is needed. The desktop also publishes its own zsb wrapper there as `mp-zsb`, and `mp-helper` uses that copy first, then `zsb` on the PATH, then `~/.local/bin/zsb`. The server starts the helper, and the desktop opens its tab through the zsb bridge. A zsb wrapper older than `--after-tab` falls back to the parent's group. A `reply_timeout` from `session-open` is checked against `workspace-list` for the helper's tab and counts as success when the tab is there. `mp-zsb` is kept identical to `tools/vps-multiprompt-browser.sh`.

```sh
mp-helper start --name "Research A" --model sonnet --effort high --task "Find why the build fails"
mp-helper start --name "Research B" --model haiku --folder ~/projects/other --task - < brief.md
mp-helper list
mp-helper read "Research A" --wait
mp-helper send "Research A" "Also check the release log"
mp-helper close "Research A"
```

- `start` runs from inside a chat. That chat is the parent. The helper tab opens right below the parent's tab, in the same workspace and group.
- `--model` is opus, sonnet, haiku or fable. `--effort` is low, medium or high. Both default to the server's Claude defaults. `--folder` defaults to the current folder.
- The same name under the same parent is the same helper. A repeat start reuses it and the same first task is not sent twice.
- The helper runs with bypassPermissions, like other server-started chats. Use trusted folders only.
- `read` prints the helper's reply to its latest prompt. `--wait` waits until its turn ends (default 600 seconds). `--json` prints name, state and reply.
- `send` puts a message into the helper, starting with `From <parent name>:`.
- `list` and `close` see only the calling chat's helpers. `close` stops the helper and closes its tab. The desktop refuses to close the tab you are looking at; the helper still stops.
- When the parent tab is not open on a desktop, the helper still runs and `start` reports `"visible":false`.

## Server shell tabs

From a live chat, `mp-shell` asks the signed-in desktop app to open a server shell tab. It uses the same zsb bridge as `mp-helper`, not the account layout API. When the desktop is offline the command exits with a plain error.

```sh
mp-shell open
mp-shell open --attach projects-2
mp-shell open --attach projects-2 --folder ~/projects/foo
mp-shell open --run "tmux new -A -s work"
mp-shell open --workspace Research --group Ops --host remote-1 --name "VPS shell"
```

- `open` with no options opens a plain VPS shell on the chat's host, placed below the chat tab (or in its group when `--after-tab` is unavailable).
- `--attach` attaches a named tmux session on the server. `--folder` runs `cd` before attach or `--run`.
- `--run` sets the remote startup command. When omitted with `--attach`, the desktop runs a normal `tmux attach`.
- `--workspace`, `--group`, `--host`, and `--after-tab` work without a parent chat when you name the placement explicitly.

## Where names come from

The desktop publishes each live chat's tab name to the server through the reader (`chat_names` request). The reader merges them into `~/.local/state/multiprompt/chat-names.json`, keyed by terminal session. The desktop sends the list when tabs, names or workspaces change. Until a desktop with this feature has connected, chats show without names.
