# Browser CLI selftest

Run `zsb selftest` inside the multiprompt-owned tmux session, or set `ZSB_SESSION` explicitly outside tmux. Install `tools/vps-multiprompt-browser.sh` as `multiprompt-browser` on your own remote host and provide a `zsb` alias. Python 3 and the reverse SSH tunnel are required. The native bridge and unpacked browser extension must both be version **1.0.67**; reload the extension after updating it.

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

## Session identity

Durable identity is tmux session plus host, never a display name. Runtime duplicate resolution prefers the active tab, then a visible pane, then the greatest last-viewed timestamp. Restore keeps only the most recently viewed complete record and its name for each identity; different hosts and empty identities are not merged. Opens and adoptions refuse duplicate identities.

Executable coverage: `tools/zsb-selftest.test.js`, `tools/zsb-explicit-tab.test.js`, `tools/zsb-extension-reload.test.js`, `src/tmux_identity.zig`, and `extension/bridge-routing.test.js`.

## Workspace and tmux tabs

`zsb workspace-list` lists every workspace (`id`, `name`, `active`), its shared group definitions (`id`, `name`, `tabs`), and ungrouped `tabs` as JSON. Each tab has `id`, `title`, `host` (SSH alias or null), `tmux` (session name or null), and `active`; top-level `hosts` lists valid SSH aliases. Workspace ids are numeric slots, while tab ids are stable shell ids.

```bash
zsb session-open --workspace "Research" --group "Ops" --host "remote-1" --tmux "runner-7" --name "Runner 7"
```

All flags are required in any order and names match exactly. This reuses the normal SSH/tmux attachment path for an existing remote session, opens in the background, preserves focus and group expansion, and saves the manual title and group placement. An existing tab for the same host/session in any workspace returns `{"ok":true,"existing":true,"tab":42,"workspace":"Research"}` with its current workspace name and without changes; a new tab returns `{"ok":true,"created":true,"tab":42}`. Session identity stays global across workspaces. Unknown workspace, group or host names return `ok:false`, the corresponding `unknown_workspace`, `unknown_group` or `unknown_host` error, and `valid_names`.

Tmux names accept 1–63 ASCII letters, digits, hyphens, underscores and dots. Tab titles accept 1–63 UTF-16 units and no control characters. Both app-level commands use the existing reverse SSH bridge, need no current tmux session, `ZSB_SESSION`, browser pane or extension, and support per-command `--help`. Browser-control commands retain their exact-session binding rules. Regression coverage: `tools/zsb-session-open.test.js` and the unit tests in `src/browser_bridge.zig` and `src/tmux_identity.zig`.
