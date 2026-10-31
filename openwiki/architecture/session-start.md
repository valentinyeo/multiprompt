# How a session starts

Two things are called "starting a session" in this app, and today they are the
same thing: a *tab* appears, and an *agent* becomes reachable. The tab comes from
Windows process plumbing on the desktop; the agent becomes reachable only because
a command was typed into that tab's terminal and a hook pushed the resulting
Claude session id back to the app. Nothing on the app side owns a Claude session.

## Today

### 1. The request

Four entries reach one handler:

- `Ctrl+T`, and `Alt+T` when neither the palette nor an editor is open
  (`src/shortcuts.zig`, both post `WM_APP_NEW_TAB_DEFAULT`).
- The plus at the end of the sidebar list.
- `Ctrl+K`, then the `Start new session` row (`SEARCH_TABCTX_START_SESSION`,
  routing id 7184 in `src/app_state.zig`). The same row appears in the tab
  context palette band.
- The palette's `New Codex session` row, which takes a separate path.

`WM_APP_NEW_TAB_DEFAULT` (`src/main.zig`) closes the all-sessions and inbox
overlays, then calls `spawnWorkspaceTmuxSession` in `src/command_palette.zig`.

### 2. Where the tab starts, and with what program

`spawnWorkspaceTmuxSession` reads the workspace's configured default command
(`workspaceConfiguredTerminalFolder`, from the workspace `commands.json`): a
host, an absolute folder and an optional `alt_t` program. Without a default it
falls back to `workspacePrimaryRepo` (the workspace's first repo). With neither,
the app shows `Workspace folder unavailable` for 3 seconds and opens the palette
instead of a tab.

Before anything is spawned, `capacityAdmitNewAgent` (from `src/capacity.zig`)
may refuse a program that creates an agent workload. A refusal produces no tab.

The tmux session name is `term-<hex>` from `GetTickCount64`, so two tabs created
in the same millisecond would collide, and nothing checks that the name is free
on the remote host.

`buildWorkspaceTmuxLaunchCmd` then builds one shell string:

```
tmux new-session -d -s term-<hex> -c <folder> 2>/dev/null;
tmux send-keys -t term-<hex> 'cd <folder> && <program>' Enter;
tmux attach -t term-<hex>
```

That is the first place a command is typed into a pane. The program reaches the
pane through `send-keys`, one keystroke string plus a separate `Enter`, so
whatever the user sees in the prompt box races with it. `New Codex session`
builds the same shape in `buildCodexTmuxLaunchCmd`, with
`codex -c tui.terminal_title=["thread-title"]` as the program.

### 3. The tab process

`spawnShellWithSession` (`src/console.zig`):

- Refuses a duplicate local tab for the same host and session name.
- Caps tabs at 256 and shows `Tab limit reached (256) - close a tab`.
- Builds an `ssh -tt <host>` command, prefixes `export ZSB_SESSION=zss-<shell_id>;`,
  exports `TERM`/`COLORTERM` for remote kinds, and starts it with
  `CreateProcessW`.
- On the synchronous path it then waits for the console window: up to 50 polls
  of 100 ms, five seconds in total, still inside the UI thread. On the
  asynchronous path (`launch_cache` pending or an account is being applied) a
  worker thread does the same wait.
- Records the tab, registers the exit wait, switches to it, requests a focus
  settle, and saves the session file.

Nothing here knows about Claude. The tab is a terminal. If the agent start
command never runs, the tab still looks healthy — it is just a shell.

### 4. The attach guard

`tmux_identity.zig` builds the attach command. When the app has a saved identity
(`start_time:pid:session_id`) it does not attach blindly; it runs one tmux
`if-shell` that compares the identity and attaches the immutable session id only
on a match, otherwise prints `Saved terminal session changed; refusing to
attach.` An identity that fails validation is rejected before the command is
built. This is why a restored tab can come back pointing at a dead session
without an error dialog: the refusal is printed into the pane.

A new-session start has no identity yet, so it uses the plain
`tmux new-session -A -s <name>` form.

### 5. The agent starts itself, and the hook reports it

Claude's own `SessionStart` hook is `tools/vps-zigshell-session-hook.sh`. It
reads the hook JSON from stdin, extracts `session_id` and `cwd`, asks tmux for the
current session name with `tmux display-message -p '#S'`, and pushes
`SESSION:<tmux>:<sid>:<cwd>` to the first answering port of
`127.0.0.1:19548..19552`, one second of timeout per port. Without `TMUX` in the
environment, or without a session id, it exits quietly.

`src/notifications.zig` parses that line: it matches the tab by name, records
`claude_sid` and `claude_cwd`, marks the tab `ai_agent = 1`, may adopt a remote
tmux session by session id (and respawn that pane in place when it does), writes
the pane session file, and saves. Sibling lines set the agent kind (`AGENT:`) and
the display name (`TITLE:`).

Until that line arrives, the app cannot tell a Claude tab from a plain shell tab.
That gap is exactly the window in which Chat View has nothing to read and a sent
message has nowhere structured to go.

### 6. Chat View reads the transcript

`chatHistoryPersistent` (`src/chat_session.zig`) keeps one `ssh ... python3 -u -c
'exec(base64...)' --serve` process per host, feeds it JSON lines and reads JSON
replies. The python side is `src/chat_history_reader.py`, shipped inline in the
command line, self-installed under `~/.multiprompt-runtime` at
`RUNTIME_GENERATION`. If the channel dies, the next attempt is 60 seconds away.

The reader resolves the agent from the pane's process tree
(`resolve_tmux_agent`: pane PIDs from `tmux list-panes`, then the process table,
`/proc/<pid>/cmdline`, `--resume` arguments, and the Claude transcript folder
under `~/.claude/projects`). With no resolvable agent there is no transcript, and
Chat View paints `Chat not available for this session, use the shell view` and
retries once a minute.

### 7. Sending a message

`src/chat_send.zig` sends `message_submit` with a client-minted id, then
`message_dispatch`. `message_dispatch` (`src/chat_history_reader.py`) re-resolves
the agent, requires the same session id and the same transcript path, hands the
row to the Claude connector (`src/chat_connectors/claude.py`), and the connector
calls `send_response_preserve_draft`:

1. `tmux load-buffer` with the text.
2. `resolve_tmux_agent` again; a different session id means `session_changed`.
3. Read the prompt box. Text that is not ours aborts with `draft_present` after
   three short waits (0 s, 0.3 s, 0.7 s).
4. Clear the box (`C-u`, then re-read), aborting with `draft_not_cleared`.
5. `tmux paste-buffer -p -d ... ; send-keys Enter` in one tmux invocation.
6. Put a displaced draft back into the box after delivery.

States move `queued -> sent -> accepted/started/failed`, with a 15 second deadline
on `sent`. The user sees the outcome as `Queued, session is busy`,
`Delivery unconfirmed`, or the `Send again` / `Remove` actions, never as a reason
code.

This is the second place a command is typed into a pane, and the reason the two
fight: the terminal is the only channel, so a half-typed draft, a permission
prompt, or a re-rendered TUI can refuse or swallow a message that the app already
counts as handed off.

### Waits, in order

| Wait | Bound | Owner |
| --- | --- | --- |
| Console window after spawn | 50 x 100 ms | `src/console.zig` |
| tmux attach | ssh connect plus attach; `attach-timeout` reported after 10 s | `src/ssh_reconnect.zig` |
| Reconnect backoff | 1 s doubling to 30 s | `src/ssh_reconnect.zig` |
| Gone probe | 2 results, 20 s deadline, 45 s spawn grace | `src/ssh_reconnect.zig` |
| Claude TUI paint | unbounded, agent-owned | Claude |
| SessionStart hook push | 5 ports x 1 s per port | `tools/vps-zigshell-session-hook.sh` |
| Chat history channel restart | 60 s | `src/chat_history_reader.py` |
| Message deadline | 15 s after `sent` | `src/chat_history_reader.py` |
| Draft re-reads before paste | 0 / 0.3 / 0.7 s | `src/chat_connectors/claude.py` |

### Commands typed into panes today

| Command | Where | Why |
| --- | --- | --- |
| `tmux send-keys -t <s> 'cd <dir> && <program>' Enter` | `buildWorkspaceTmuxLaunchCmd`, `buildCodexTmuxLaunchCmd` | start the agent |
| `tmux send-keys -t <s> ...` | `src/archive.zig` | respawn an archived tab |
| `tmux paste-buffer ... ; send-keys Enter` | `send_response_preserve_draft` | deliver a chat message |
| `tmux send-keys -t <s> C-u / C-k / C-x C-s` | reader stop, permission, queue keys | clear, stop, queue |
| `tmux display-message -p '#S'` | `tools/vps-zigshell-session-hook.sh` | find the pane's session |

### Failures the user can hit

- No workspace folder: `Workspace folder unavailable`, and no tab.
- Capacity refusal: no tab, no agent.
- Tab cap: `Tab limit reached (256) - close a tab`.
- Attach guard mismatch: `Saved terminal session changed; refusing to attach.`
  printed into the pane, tab otherwise fine.
- ssh or attach failing: `SSH exited`, `SSH process missing`, `attach timed out`,
  `remote session detached`, `SSH could not start` notices, with backoff.
- Agent never started (command typed into a pane nobody watched): a healthy shell
  tab with no chat.
- Hook never delivered (no `TMUX`, port closed, hook not installed): a working
  Claude tab the app treats as an unknown shell, so Chat View stays empty until
  the transcript is discovered by another route.
- Message raced a draft: `Queued` forever or `Delivery unconfirmed`, with no way
  to know which keystrokes the agent actually received.

### Tests that cover this path today

`tools/zsb-session-open.test.js`, `tools/zsb-session-isolation.test.js`,
`tools/zsb-session-edit.test.js`, `tools/zsb-who.test.js`,
`tools/session-agent-persistence.test.js`, `tools/ssh-reconnect`-backed source
tests, `tools/chat-tmux-send-test.py` (delivery through the reader),
`tools/chat-history-reader-test.py` (transcript and store),
`tools/chat-shared-runtime.test.py` (runtime generation selection).

## Target

The host contract is `openwiki/architecture/agent-host.md`. One chat is one agent
session id; the runtime owns at most one host process per chat and speaks the
agent CLI's `--print --input-format stream-json --output-format stream-json`
protocol. Nothing is typed into a terminal.

### New session, in order

1. `Ctrl+T`, the sidebar plus and the palette row stay the same entry points.
   `spawnWorkspaceTmuxSession` asks `src/agent_host.zig` whether this program is a
   Claude workload and the app-owned host is enabled.
2. When it is, the app mints the session id itself (`mintSessionId`, a version 4
   UUID) before anything is spawned, and builds one remote command with
   `agent_host.launchCommand`: create the tmux session, run `host enable` and
   `host start` from the selected runtime file, then attach. No `send-keys`, no
   program typed into a pane, no reliance on a hook to discover the id later.
3. The tab records the minted id as the chat's `sid` at spawn time, so Chat View
   has an identity from the first paint and accepts typing immediately. Messages
   sent before the host is up are rows in the shared store keyed by that id; the
   host drains them once it is ready, and a retry after reconnect is idempotent by
   message id.
4. Delivery no longer runs through a terminal prompt box, so a draft, a
   permission prompt or a TUI repaint cannot refuse a message. `draft_present`
   and `draft_not_cleared` disappear from the Claude path.
5. The terminal becomes a user shell. It is still the tab's visible content
   today because that is the existing UI; opening it on demand only, and handing
   the chat back to a `claude --resume` terminal through `host handover`, needs a
   control that does not exist yet — a new UI element, so it is out of scope for
   this change and recorded as such.
6. Codex and Pi keep today's terminal start: `buildCodexTmuxLaunchCmd` and the
   `send-keys` variants are untouched, and their Chat View path is unchanged.

### Switch

- `src/agent_host.zig` `ENABLED` is on. A program whose name starts with `claude`
  starts on the app-owned host; every other program keeps the terminal start.
- The per-chat `~/.local/state/multiprompt/agent-host/<key>.config.json`
  `enabled` flag decides whether `message_dispatch` hands the row to the host
  instead of the connector. The start command writes it, so a new Claude session
  is on. A chat with no such file — anything created before this change — keeps
  the connector path.

### Scripts and the runtime bundle

`tools/mp-send <provider> <sid> <text>` is the script path for "put a message
into a session": it inserts one row through the same store code the app uses
(`message_submit`), dispatches it with `message_dispatch`, prints the id, and with
`--wait` prints the final state. It resolves the reader from the installed
runtime selection (`~/.multiprompt-runtime/active.json`) before falling back to a
repo checkout, and the runtime publishes a stable `reader.py` plus a copy of
`mp-send` next to the selected generation, so both exist on the server without a
script needing `tmux send-keys` or a repo path.
