# Agent completion notifications

Optional adapters for supported coding tools. Install on your own local machine
or remote server. No configured servers or live session data are included.

| Agent | Starts working | Finished | Activation |
| --- | --- | --- | --- |
| Claude Code | `UserPromptSubmit` command | `Stop` command | New sessions load the config. Also carries the estimate hooks below |
| Codex | `UserPromptSubmit` command | `Stop` command | Resume in a new process. Also carries the estimate hooks below, after trusting them once |
| Grok Build | `UserPromptSubmit` command | `Stop` command | Resume in a new process |
| Cursor CLI | `beforeSubmitPrompt` command | `stop` command | Resume in a new process; behavior depends on the installed CLI emitting these hooks |
| Pi | `agent_start` listener | `agent_settled` listener | Run `/reload` or resume in a new process |
| Hax | VPS terminal activity watcher | Debounced terminal inactivity | Inferred completion, not an exact agent event |

Hax has no documented lifecycle-hook interface, so it gets the estimate rule in its system prompt instead of a hook (see below). Its fallback can mistake a long
quiet thinking period for completion. It needs an upstream completion event to
match the precision of the other integrations. The watcher checks visible text
every three seconds, requires two changed samples to infer work, and ten seconds
of stable text to infer completion. Processing time adds to those intervals.

The scripts make no model calls and write no hook output or context messages.
Claude's `Notification` hook sends `NOTIFICATION:<tab>` only for a real
`permission_prompt`, not for idle reminders; it can raise a blue dot during
an active turn. Codex's `agent-turn-complete` notification remains a DONE.
They send only an agent name, tab identity, and lifecycle event. Claude also sends
its conversation ID and working directory for resume. Prompts, replies, tokens,
and credentials are never transmitted by these adapters.

## Install or repair

From this directory on the target machine:

```sh
python3 install.py
```

On Windows use `python install.py`. Copy this entire directory to each VPS before
running it there. The installer preserves unrelated hook handlers and backs up
each changed file beside itself with a `.pre-zigshell-<timestamp>` suffix. It only
configures agent profile directories that already exist. Rerunning is idempotent.
Use Python 3.11 or newer.

Files installed:

- `~/.local/share/zigshell/notify.py`, shared silent dispatcher.
- On Linux, `mp-notify-relay.service` and `mp_notify_relay.py` route TCP 19548
  to every connected laptop's private Unix socket in `/tmp/mp-notify-<uid>/`
  (mode 700). Install under each server user that needs notifications.
- `~/.local/share/zigshell/mp_complete.py` and two versioned command tables, read-only Chat View suggestions on remote tabs.
- `~/.claude/settings.json` and existing `~/.claude-secondary/settings.json`.
- `~/.codex/hooks.json`.
- `~/.grok/hooks/zigshell.json`.
- `~/.cursor/hooks.json`.
- `~/.pi/agent/extensions/zigshell.ts`.
- Existing VPS `~/.local/bin/zigshell-watcher.sh` and Claude script entrypoints.

The installer enables the user service and writes
`~/.local/state/multiprompt/relay-v1` after it starts. Browser (ZSB) requests
skip ownership probing when only one laptop socket exists. With multiple
sockets, the relay probes in parallel with `ZSBWHO:<hex-encoded-tmux-session>\n`
under a shared 400 ms deadline. Encoding avoids old apps treating the session
as a legacy DONE notification. Each app replies with one JSON line containing
`has_tab`, `idle_ms` (machine-wide keyboard/mouse inactivity), and `host`. The UI thread
resolves ownership; the listener returns its locked snapshot without reading
live tabs. A blocked UI lookup expires after 200 ms without claiming ownership.
The relay prefers laptops with that session's tab, lowest idle time first;
unknown ownership (old apps/timeouts) follows, newest socket mtime first;
explicit nonowners rank last by idle time. Ties retain newest-first order.
Per-session choices and fallback order are cached for five seconds in a locked,
bounded cache; a changed socket inventory invalidates the cached ranking.
The chosen laptop returns its reply on the original connection; notifications
still broadcast to every laptop. If an old
laptop tunnel holds port 19548, the relay retries binding every five seconds.
If user linger is off, the installer prints a note; it never changes linger
itself. Each laptop removes its own stale socket before forwarding; the relay
sweeps refused sockets every five seconds even without notification traffic.
The relay requires its socket directory to be owned by the service user and
mode 700; it repairs permissions when owned, otherwise exits with status 78
without a systemd restart loop. Two failed legacy forwards trigger a relay
recheck, so installing the service later does not require an app restart. A
failed forward backs off from 5 to 15 to 60 seconds, then 5 minutes.

Grok imports Claude/Cursor hooks as well as its own. The dispatcher recognizes
Grok's payload and ignores the imported copies, preventing duplicate events and
incorrect Claude resume registration. Subagent completion must not mark its
parent tab complete. Do not register this dispatcher on `SubagentStop`.

## Chat View command and skill suggestions

Install the directory on each VPS user account whose tabs need completion.
Type `/` in a remote Claude or Codex Chat View, or `$` for Codex skills.
Ctrl+/ and the composer plus button browse without typing a trigger. The helper
lists commands without sending text to the agent. Enter inserts a choice;
press Enter again to send it. The cache refreshes on Claude session start and
on a version or settings change. For a wire check without an agent prompt:

```sh
printf '1\tslash\tclaude\t-\t-\t\n' | python3 mp_complete.py --serve
```

Only scratch tmux sessions named `mp-ac-test-*` can use the optional
`--harvest` parity command, since harvesting navigates the terminal menu.
File suggestions and local Windows agent tabs are planned for phase 2.

## Routing and dot behavior

Remote hooks require both `TMUX` and `TMUX_PANE`. They resolve the exact inherited
pane, then use the existing reverse SSH tunnel on localhost:19548. They never use
tmux's ambient session or infer identity from a project folder. Outside tmux they
do nothing. Names containing protocol delimiters are rejected.

Local Windows hooks require inherited `ZIGSHELL_SHELL_ID` and
`ZIGSHELL_NOTIFY_PORT`. For existing clients that address local notifications by
tab name, the dispatcher resolves a unique live inbox row and refuses ambiguous
identities. Older local sessions without those environment variables retain the
native console-detection fallback.

`ACTIVE` clears attention and starts the spinner. `DONE` sets attention on a
background tab. Claude PostToolUse sends one ACTIVE when the last delivered
state for that exact session was DONE, including when a background task resumes
without a new prompt or a Stop hook prevented the turn from ending. The currently
viewed tab intentionally has no completion dot; muted tabs ignore these events.
Opening a tab acknowledges its attention state.

A delivered completion records which agent owns the lifecycle hook. The VPS
watcher then defers to full lifecycle hooks, so a final terminal repaint cannot
clear a valid blue dot. Legacy Codex `notify` still uses heuristic start detection.
Markers from another agent cannot suppress Hax after a tab changes agent type.

## Lifecycle state for clients without the notify channel

The notify channel tells the desktop directly that a tab started working (`ACTIVE`) or finished
(`DONE`). The phone has no channel, so `notify.py` also writes
`~/.local/state/multiprompt/tab-state.json`: one entry per tab with `state` (`active` or `done`)
and the epoch second it was recorded. Entries older than 24 hours are pruned and at most 200 are
kept. It is best effort, like the estimate bookkeeping: a missing or unwritable state directory
never changes delivery.

## Verification

```sh
python3 -m unittest discover -s . -p 'test_*.py'
bash -n zigshell-watcher.sh
```

The tests cover exact pane routing, headless rejection, protocol delimiters,
agent events, installation, silent Claude warm-up, command framing, plugin
selection, and frontmatter. Run the Python suite on each VPS after installation;
Windows skips Bash-only watcher tests. The repository test graph includes this
suite on systems with a `python` command.

## Time estimates (mp-eta)

`mp-eta` lets an agent declare how long the current request will take. Multiprompt
shows the countdown on the tab, and the estimate plus the real duration are logged
so each agent's accuracy can be reported back to it.

The command identifies the tab exactly like `notify.py` and sends one line on the
same transport. The duration is `45s`, `20m`, `1h`, `1h20m`, or a plain number of
minutes. The description is optional and is trimmed to 80 characters.

```sh
mp-eta 20m "Fix the login bug"   # set the estimate for this request
mp-eta 10m                       # still working, 10 minutes left from now
mp-eta +10m                      # the request grew, add ten minutes
mp-eta 15m --bg                  # ending the turn, background work goes on
mp-eta stats                     # per agent accuracy, last 20 finished tasks
```

A second `mp-eta <time>` for the same request means "this much is left from
now". The entry keeps its original `started_at` and freezes the first estimate
in `first_est_seconds`, so the total becomes the time already spent plus the new
remaining time. The description is kept when the revision omits it, `updated_at`
moves to now, and `revisions` counts the updates (zero on the first estimate).
The command prints `Estimate updated: 10m left (first estimate 20m) on <tab>`.
`mp-eta +10m` extends the total, also moving `updated_at` and bumping
`revisions`. The tab countdown always reflects the latest wire line.

An estimate normally closes when the turn ends (`DONE`). When the agent hands
work to a background agent and ends its turn, `--bg` (with a time, or alone to
keep the current estimate) marks the job as still running: the next `DONE`
keeps it open and sends `DONE` followed by `ETA` so the countdown returns
without consuming the reply's blue dot. A duplicate completion for that
already ended turn sends nothing. A new prompt drops the carried countdown
and asks for a fresh estimate, so a quick question never shows the background
job's time left. `ACTIVE` for an open estimate in the same turn still resends
that estimate; a new prompt resets it.

Wire line, sent to the same port as `ACTIVE` and `DONE`:

```
ETA:<tab name>:<remaining seconds>:<description>
```

The name is the same tab identity `ACTIVE:<name>` uses. The description is
everything after the third colon and may be empty.

State files, both under `~/.local/state/multiprompt/`:

- `eta-open.json`: the estimate for the current request, keyed by tab name.
- `eta-log.jsonl`: one JSON object per finished request (`agent`, `est_seconds`,
  `final_est_seconds`, `revisions`, `actual_seconds`, `finished_at`, `desc`).
  `est_seconds` is the first estimate, so accuracy is measured against what the
  agent claimed before doing the work. Rows written before revisions existed
  only carry the original `est_seconds`; readers keep working with them.

`notify.py` closes the loop on its own. A delivered `DONE` normally moves the
open entry into the log; a `DONE` with `--bg` carries the estimate instead, and
a duplicate completion while carried is ignored. An `ACTIVE` (a new request
started) drops a stale carried entry without logging it. A missing or
unwritable state directory does not block delivery.

### Estimate hooks (Claude Code and Codex)

Codex carries the same hook payloads and hook output shape as Claude Code, so one helper
asks either agent for the estimate before any real work happens:

- `eta_hook.py prompt` (`UserPromptSubmit`) adds one short instruction to the
  prompt context, including the agent's recent accuracy when stats exist, and
  tells it to run `mp-eta <time left>` again when what it learns changes the
  picture.
- `eta_hook.py pretool` (`PreToolUse`) denies the first tool call once when no
  estimate was given, with the reason `Give a time estimate first`. A Bash call
  that runs `mp-eta` is allowed, and after one denial everything is allowed, so
  an agent can never get stuck.
- `eta_hook.py posttool` (`PostToolUse`) sends ACTIVE after a delivered DONE,
  even with no open estimate, then adds a short nudge when an estimate needs
  attention. It never blocks anything.
- If `eta_hook.py stop` is configured separately, it exits successfully without
  blocking the Stop, even when an estimate is missing.

The nudge has two rules and one cooldown each:

- The estimate ran out and the last nudge is at least 5 minutes old: "Your
  estimate for this request ran out {N}m ago. If you are still working, run:
  mp-eta <time left>."
- The estimate is not out yet, at least max(10 minutes, 40% of the estimate)
  passed since the last revision, and the last nudge is at least 10 minutes old:
  "{N}m since your last estimate ({total} total). If what you found changes the
  picture, run: mp-eta <time left>. Otherwise carry on."

The last nudge time per tab lives in the `eta-hook.json` state file. Any error
makes the hook print nothing and exit 0, so a PostToolUse nudge can never break
a tool call.

Enable all three hooks and install `mp-eta`:

```sh
python3 install.py --with-eta
```

That registers the three hooks for Claude Code and Codex, installs `mp-eta`, and (on a machine
that already has a hax config) gives Hax its own standing rule.

Codex reviews new hooks before running them: the first interactive Codex session after this
install shows a Hooks screen with the three entries waiting. Review and trust only hooks you intend to run.

### Hax instruction

Hax has no hook interface, so it cannot be gated. Instead the installer writes
`~/.config/hax/zigshell-eta.md` and adds `@zigshell-eta.md` to the `system_prompt_append` in
`~/.config/hax/config.json`, keeping any append that was already there. Every Hax turn then
carries the same rule: estimate first, revise when the picture changes, and use `--bg` when the
turn ends with background work still running.

It is a standing instruction rather than a gate, so compliance depends on the model behind the
preset. Models can skip the estimate despite the standing instruction. Claude Code and Codex avoid that by denying the
first tool call once.

`mp-eta` is a wrapper in `~/.local/bin` (`.cmd` on Windows). A plain
`python3 install.py` never touches the estimate hooks or files, so reruns on
existing machines stay unchanged.

## Primary references

- [Claude command hooks](https://code.claude.com/docs/en/hooks)
- [Codex hooks](https://learn.chatgpt.com/docs/hooks)
- [Grok hook format and compatibility](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-pager/docs/user-guide/10-hooks.md)
- [Cursor hooks](https://prod.cursor.com/docs/hooks)
- [Pi lifecycle extensions](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/extensions.md)
- [Hax configuration](https://github.com/OleksandrChekhovskyi/hax/blob/master/docs/configuration.md)
