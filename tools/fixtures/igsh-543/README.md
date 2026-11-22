# Startup regression fixtures

Exact historical function text and the startup timer branch, extracted locally before replacing Git lookups.
These source excerpts are negative controls, not standalone Zig programs.
The tests must reject the old behavior, not missing files or functions.

## save-before

Source commit: `2031a233bb99897988a93e498c2fe3b42bc40e9e`.

- `main.zig`: `initializeDeferred`.
- `startup-timer.zig`: the `TIMER_STARTUP` branch of `wndProc`, through the next timer branch.

## startup-before

Source commit: `508459a0022bb944a152d4f897d196d27dbb5455`.

- `main.zig`: `initializeDeferred`.
- `console.zig`: `spawnShellWithSession`.
- `session.zig`: `restoreSession`.
- `browser_pane.zig`: `browserLaunchWorker`.

## review-before

Source commit: `cb15de6f31da1abd22ae6190cb0a5c25bd70e0f2`.

- `console.zig`: `spawnShellWithSession`, `respawnShellInPlace`, `startupShellWorker`, `finishStartupShell`, `markSshTabDisconnected`, `resolveSshPath`.
- `chat_send.zig`: `armSshReconnectTimerIfNeeded`, `sshAutoReconnectTick`, `sshDisconnect`, `sshReconnectNow`, `sshReconnectAttempt`, `sshReconnectArm`, `sshProbeStart`, `sshNetworkVeto`.
- `launch_cache.zig`: `restore`, `deferred`, `closedDuringStartup`.
- `account_desktop.zig`: `accountLock`, `layoutSyncWorker`, `accountSyncHosts`, `accountRequest`, `handleLayoutReply`.
- `workspaces.zig`: `lockWorkspaceRegistry`.
- `main.zig`: `initializeDeferred`.
- `session.zig`: `restoreSession`.
- `notifications.zig`: `notifyListenerThread`.
- `drawing.zig`: `paintDisconnectedShell`.
