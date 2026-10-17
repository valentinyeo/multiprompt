# Browser CLI selftest

Run `zsb selftest` inside the multiprompt-owned tmux session, or set `ZSB_SESSION` explicitly outside tmux. Install `tools/vps-multiprompt-browser.sh` as `multiprompt-browser` on your own remote host and provide a `zsb` alias. Python 3 and the reverse SSH tunnel are required. The native bridge and unpacked browser extension must both be version **1.0.65**; reload the extension after updating it.

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
