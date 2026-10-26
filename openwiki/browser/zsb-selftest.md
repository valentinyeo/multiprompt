# Browser CLI selftest

Run `zsb selftest` inside the multiprompt-owned tmux session, or set `ZSB_SESSION` explicitly outside tmux. Install `tools/vps-multiprompt-browser.sh` as `multiprompt-browser` on your own remote host and provide a `zsb` alias. Python 3 and the reverse SSH tunnel are required. The native bridge and unpacked browser extension must both be version **1.0.90**; reload the extension after updating it.

The selftest creates an example.com marker tab, installs an input/button fixture, and checks:

- `open`: exactly one marker page in the bound pane
- `text`: the expected title and marker
- `type`: trusted typing and independent input-value readback
- `click`: a button's changed result
- `screenshot`: valid PNG bytes and dimensions
- `hosting`: the owning desktop tab and matching pane window
- `close`: exact test-tab removal

Commands target the exact test tab. On failure, cleanup is still attempted; existing tabs are not closed. A hidden hosting pane fails visibility instead of switching the user's workspace. Automated commands never take OS keyboard focus.

Output contains one JSON summary and a human result line. Every step has `pass:true/false`; hosting diagnostics include `tab_name`, `active`, `visible`, and `windowId`. Exit 0 means all steps passed; exit 1 means a step failed, including cleanup. `visible` checks the pane's live on-screen rectangle and minimized state, not whether another application occludes it.

`zsb pane-info` returns the hosting snapshot without creating a test page. `zsb extension-reload` acknowledges a scheduled profile-wide extension reload, not that new code has loaded. Old workers may require a manual reload through `chrome://extensions`. Missing or outdated loaded versions report an explicit error rather than silently accepting empty tab lists.

## Reply deadlines

The remote wrapper bounds the entire reply using a monotonic clock from the start of sending, including all received fragments. Bytes arriving slowly do not reset the deadline. Connecting to the IPv4 tunnel has a separate maximum of 5 seconds.

| Commands | Default total seconds |
| --- | ---: |
| `status`, `version` | 5 |
| Other commands, including `open` | 15 |
| `doctor` | 20 |
| `text`, `get-text`, `snapshot`, `cdp`, `eval`, `script` | 30 |
| `screenshot`, `shoturl` | 60 |
| `selftest` (all requests and cleanup combined) | 180 |
| `cdp --script` | 360 |

The longer read/script/CDP budgets accommodate pane recovery (up to 12 seconds) plus page work (up to 15 seconds). Screenshots allow capture retries and the extension's 35-second action budget; `doctor` allows pane recovery rather than serving as a quick liveness probe. Existing app-side limits still apply: a larger wrapper deadline does not extend those limits. The current CLI has no per-command `--timeout` flag; CDP JSON parameters are forwarded unchanged.

Set `ZSB_TIMEOUT` to override any default in seconds, for example `ZSB_TIMEOUT=2.5 zsb open https://example.com` or `ZSB_TIMEOUT=60 zsb eval 'somePromise'`. Values must be finite numbers greater than zero and at most 86400; an empty or invalid value returns JSON `error:"bad_args"` before sending. Local help does not contact the tunnel.

On expiry, the wrapper exits nonzero and prints JSON `{"ok":false,"error":"reply_timeout","message":"…after 5.001s (deadline 5s)…","session":"…","port":19548,"hint":"…"}`. `status` and `version` therefore fail promptly even if the app or bridge stops answering. Reconnect the SSH session, open/rebind its pane, then retry `status`; use `doctor` when intentionally allowing pane recovery. A timeout does not cancel app-side work, so check the tab list before repeating an `open`. If selftest exhausts its shared deadline, cleanup may be incomplete; its timeout hint says so.

Regression coverage: `tools/zsb-deadline.test.js` exercises silent and continuously trickling TCP peers without building the app.

## Session identity

Durable identity is tmux session plus host, never a display name. Runtime duplicate resolution prefers the active tab, then a visible pane, then the greatest last-viewed timestamp. Restore keeps only the most recently viewed complete record and its name for each identity; different hosts and empty identities are not merged. Opens and adoptions refuse duplicate identities.

Executable coverage: `tools/zsb-selftest.test.js`, `tools/zsb-explicit-tab.test.js`, `tools/zsb-extension-reload.test.js`, `src/tmux_identity.zig`, and `extension/bridge-routing.test.js`.

## Workspace and tmux tabs

`zsb workspace-list` lists every workspace (`id`, `name`, `active`), its shared group definitions (`id`, `name`, `tabs`), and ungrouped `tabs` as JSON. Each tab has `id`, `title`, `host` (SSH alias or null), `tmux` (session name or null), and `active`; top-level `hosts` lists valid SSH aliases. Workspace ids are numeric slots, while tab ids are stable shell ids.

```bash
zsb session-open --workspace "Research" --group "Ops" --host "remote-1" --tmux "runner-7" --name "Runner 7"
```

All flags are required in any order and names match exactly. This reuses the normal SSH/tmux attachment path for an existing remote session, opens in the background, preserves focus and group expansion, and saves the manual title and group placement. An existing tab for the same host/session in any workspace returns `{"ok":true,"existing":true,"tab":42,"workspace":"Research","state":"connecting"}` with its current workspace name and without changes; a new tab returns `{"ok":true,"created":true,"tab":42,"state":"connecting"}`. Session identity stays global across workspaces. Unknown workspace, group or host names return `ok:false`, the corresponding `unknown_workspace`, `unknown_group` or `unknown_host` error, and `valid_names`.

Creation does not prove connection. Run `zsb session-status --tab 42` with the returned tab ID. It returns `{"ok":true,"tab":42,"state":"connecting"}` while attachment is pending, `{"ok":true,"tab":42,"state":"connected"}` only after the existing tmux health probe confirms attachment and the SSH process is still live, or `{"ok":true,"tab":42,"state":"disconnected","exit_code":255}` after failure. The disconnected exit code is the process exit code retained before its handle closes; `4294967295` means no code is known. No `exit_code` field appears while connecting or connected. An unknown tab returns `{"ok":false,"error":"unknown_tab"}`. Use a positive decimal tab ID; invalid arguments return `bad_args`.

Both session-open reply forms include the same state; an existing tab reports its current state, including `exit_code` when disconnected. A new tab normally starts connecting, but can already report disconnected if its launch has failed. Neither `ok:true` nor `created:true` means the remote attachment succeeded. Automatic reconnect can move a disconnected tab back to connecting.

Tmux names accept 1–63 ASCII letters, digits, hyphens, underscores and dots. Tab titles accept 1–63 UTF-16 units and no control characters. All three app-level commands use the existing reverse SSH bridge, need no current tmux session, `ZSB_SESSION`, browser pane or extension, and support per-command `--help`. Browser-control commands retain their exact-session binding rules. Regression coverage: `tools/zsb-session-open.test.js` and the unit tests in `src/browser_bridge.zig` and `src/tmux_identity.zig`.

## Device previews

Run `zsb emulate iphone` (390 by 844) or `zsb emulate pixel` (412 by 915) to preview the target tab with a mobile viewport, user agent and touch. Use `zsb emulate 390x844 --mobile` for a custom mobile size, or `zsb emulate 800x600` for a desktop size. Dimensions range from 1 to 10000 pixels. `zsb emulate --help` is available locally without a pane or tunnel.

The preview stays on that tab through page links, reloads and ordinary zsb CDP or screenshot commands. Reload an already-open page if its content depends on the request's user agent. Run `zsb emulate off` to restore the normal desktop viewport, user agent and touch settings. New tabs are independent; `zsb navigate` can open a new tab rather than navigate the emulated one.

Closing the tab, externally detaching its debugger, or restarting the extension/browser ends its preview. This changes Chromium's page environment, not the browser engine. F12 and browser DevTools shortcuts are browser-chrome controls and remain outside zsb's page-key automation.

## Repairing tabs from the command line

Four more app-level commands fix a tab layout without a keyboard, a restart or a window switch. Each runs in the background, never changes the active tab, workspace or foreground window, and saves the layout at once so a restart keeps it. Every reply is JSON, and a refusal exits nonzero with `ok:false` and an `error` code.

```bash
zsb session-rename --tab 42 --name "Runner 7"
zsb session-rebind --tab 42 --host "remote-1" --tmux "runner-9"
zsb session-move --tab 42 --workspace "Research" --group "Ops"
zsb session-move --tab 42 --ungrouped
zsb session-close --tab 42
```

- `session-rename` sets a manual title (1–63 UTF-16 units, no control characters) and replies `{"ok":true,"renamed":true,"tab":42}`.
- `session-rebind` points an existing remote tab at another tmux session and reconnects it, keeping its title, group and place. `--host` is optional and defaults to the tab's own host. It replies `{"ok":true,"rebound":true,"tab":42,"state":"connecting"}`; follow it with `session-status --tab 42`. A session another tab already uses returns `{"ok":false,"error":"duplicate_session","tab":43}` with that tab's id and changes nothing. A tab that is not a remote tab returns `not_remote_tab`, and a locked account returns `account_locked`.
- `session-move` takes `--workspace`, `--group` or `--ungrouped` (one of them is required, `--group` and `--ungrouped` are exclusive) and matches names exactly, like `session-open`. Moving to another workspace without `--group` leaves the tab ungrouped. Unknown names return `unknown_workspace` or `unknown_group` with `valid_names`, and a snoozed workspace returns `workspace_snoozed`.
- `session-close` closes one tab and replies `{"ok":true,"closed":true,"tab":42}`. It does not touch the remote tmux session.

`session-move`, `session-rebind` and `session-close` refuse the active tab with `active_tab`, because moving or closing it would change what the user is looking at. `session-close` refuses a pinned tab with `pinned_tab`. An unknown tab id returns `unknown_tab`. `workspace-list` now also reports each remote tab's `state` (`connecting`, `connected` or `disconnected`), and `null` for local shells.
