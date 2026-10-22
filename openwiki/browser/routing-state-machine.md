# Browser routing and isolation

The browser pane stays docked in place and cannot be dragged away or maximized to full screen.

The browser engine uses dedicated `%LOCALAPPDATA%\ZigShell\EdgeUserData` or `ChromeUserData` profiles. Normal browser windows, OS URL launches, and installed web apps do not share that profile. Tabs created inside a protected pane remain in it; navigation provenance is not used to eject them into the user's normal browser.

Each browser-control command requires an exact session and browser window binding. App-level `workspace-list` and `session-open` bypass browser routing; see [workspace and tmux tabs](zsb-selftest.md#workspace-and-tmux-tabs). `multiprompt-browser` (`zsb` compatibility alias) uses the current tmux session only when `TMUX` is present. Outside tmux, set `ZSB_SESSION` explicitly. An ambient attached session never authorizes a headless caller.

`navigate` creates a background tab and remembers it as the session's target. It may reuse that tab only if the same session's agent created it, it is still in the bound window, it is inactive, and the user has never selected or navigated it. User takeover permanently revokes reuse authority; worker reload discards it. `navigate --new-tab` always creates a fresh background tab. Navigation never overwrites an active tab, a user tab, or the launch beacon, and never uses a read/action fallback as reuse authority.

Subsequent reads and actions follow the remembered target unless `--tab` selects another tab in the same window. Foreign window/tab IDs fail closed. Commands cannot use a global focused-tab search to repair stale bindings. A stale binding may be re-established through the app's exact-session worker/UI request path. The navigation-commit observer only revokes reuse authority; it cannot eject, move, mute or close tabs.

Physical app actions can transfer keyboard focus. Automated navigation, screenshots, notifications, extension reconnects, and selftests cannot acquire foreground authority. The UI thread must not block waiting for browser commands. Native screenshot delivery uses nonblocking loopback connects/sends with a per-port deadline.

`MULTIPROMPT_BROWSER_PROFILE` (or `--profile <token>`) sends commands to that profile's own pipe `multiprompt-browser-isolated-<token>` (1 to 32 of `a-z`, `0-9`, `-`, no leading `-`); no token keeps the default pipe, and an unknown or invalid profile fails instead of falling back.

The extension and native bridge versions must match. Reload unpacked extension code after changes; `zsb extension-reload` schedules a profile-wide reload and reports acknowledgement, not completed reload. See [zsb-selftest.md](zsb-selftest.md) for installation checks and diagnostics.

## Per-workspace routing (IGSH-224)

By default each stable workspace ID selects its own engine-specific profile in
`%LOCALAPPDATA%\ZigShell\BrowserWorkspaces\<engine>\<workspace-id-hash>`.
Names and slots never select storage. The first 30 SHA-256 hex characters form
the directory; `e-` or `c-` prefixes its pipe token. The launch notice identifies
the active profile before manual bookmark editing. Workspace deletion retains
the profile for recovery. Existing EdgeUserData/ChromeUserData stay in place for the restored active
workspace, bound by an adjacent create-only `.workspace-owner` sidecar. New
workspaces get empty separate roots, not copies of existing logins/bookmarks.

A native host derives its registration token from its live Chromium ancestor's
user-data argument, not from connection order. A mismatched environment override
or duplicate workspace registration is refused. Exact session binding returns
the profile token with the Chromium window ID on the UI thread; worker commands
carry that snapshot, including unfreeze, retries and background URL reads.
Unknown/stale profile pipes never fall back to another workspace or the shared
pipe. The extension's existing exact-window/tab ownership checks remain in force.

Upgrade records the existing root owner before any browser launch; new-profile
initialization completes off the UI thread before launch/adoption starts.
See [the lifecycle contract](../../docs/browser-pane-lifecycle.md#workspace-browser-profiles)
for in-place upgrade, explicit clone checks, incomplete-profile handling and the default-on
one-line `IGSH_224` rollback switch.

Local CLI callers inherit `BROWSER_CLI_WINDOW_FILE`; its atomically replaced
contents now pair the window ID with the workspace token. They are read together,
not as separate potentially mismatched mappings. In default-on mode an absent,
invalid, or legacy numeric-only binding refuses host commands rather than using
the shared pipe. Explicit `--profile` remains an intentional override.
