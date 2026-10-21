# SSH tab reconnect

## Sub-features

Automatic reconnect after a transport exit, background-tab isolation, retained typing focus, and no full-window layout churn.

## How to get to it (user POV)

Open Multiprompt with two SSH/tmux tabs. Select the first with Ctrl+1 and click its typing box. The other tab stays in the background when its network connection drops. Ctrl+Shift+R reconnects an active remote tab manually.

## Driving it with the Windows reconnect harness

Dispatch exe_source=build. Case A records native foreground and GUI-thread focus, kills verify-two's ssh PID while verify-one stays active, and waits for the second tab's respawn and reconnect-ok. case-A.log must contain zero reposition/browser/mask layout lines and focus.json must retain both HWNDs throughout sampled observations. case-A.png shows the active tab after recovery.

## Gotchas

Initial restore and selecting tabs legitimately layout; the measured slice starts only after settling and before the kill. Reconnect allocates a new shell ID, so the driver obtains it from idx=1's respawn log. HWND sampling is not a compositor/frame-by-frame flicker proof; the layout log signals provide the direct regression oracle. The released pre-fix app is the negative control.
