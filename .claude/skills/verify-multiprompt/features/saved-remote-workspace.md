# Saved remote workspace

## Sub-features

Persisted tab names, tmux session/host identity, active-tab restoration, and console typing focus.

## How to get to it (user POV)

Close and reopen a workspace containing SSH tabs. Existing named server sessions return as tabs, with the selected tab and typing surface usable. Ctrl+1 and Ctrl+2 switch between them.

## Driving it with the Windows reconnect harness

The driver seeds the real APPDATA/ZigShell/session.json with two kind=tmux records, tmux_session verify-one/verify-two, tmux_host=0, active_tab=0 and cv=false on both tabs; it omits chat_view_mode so case F can enable Chat View with Alt+C. It launches the actual app normally, waits for both live ssh transports, preflight-kills each in turn and requires its respawn and reconnect-ok, sends Ctrl+1, clicks the visible ConsoleWindowClass child, and verifies foreground/focus via native APIs. seed-session.json, doctor.json, debug.log, and before.png preserve the input and resulting state.

## Gotchas

The production restore path directly calls spawnShellWithSession for saved remote tabs; it no longer queues their initial spawn. A successful spawn is not yet a healthy attachment. Do not infer readiness from a window existing. Isolated APPDATA/LOCALAPPDATA and MULTIPROMPT_NO_LOGIN avoid real workspace/account state. This fixture covers remote restore only, not local console recovery or multi-workspace restoration.
