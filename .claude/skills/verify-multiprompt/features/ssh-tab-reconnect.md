# SSH tab reconnect

## Sub-features

Automatic reconnect after a transport exit, background-tab isolation, retained typing focus, and no full-window layout churn. Automatic starts are limited to one per host per tick and three in-flight attaches per host; healthy completion frees capacity. Healthy monitoring coalesces to 15 seconds; recovery and pending probes use one-second ticks, and ended tabs do not keep an idle recovery timer alive. A visible active respawn sizes only its own console before any show, without activation. Background respawns neither size nor show windows.

## How to get to it (user POV)

Open Multiprompt with two SSH/tmux tabs. Select the first with Ctrl+1 and click its native console. The other tab stays in the background when its network connection drops. Ctrl+Shift+R reconnects an active remote tab manually.

## Driving it with the Windows reconnect harness

Dispatch exe_source=build. Case A records native foreground and GUI-thread focus, kills verify-two's ssh PID while verify-one stays active, and waits for the second tab's respawn and reconnect-ok. case-A.log must contain zero reposition/browser/mask layout lines and focus.json must retain both HWNDs throughout sampled observations. case-A.png shows the active tab after recovery.

## Gotchas

Initial restore and selecting tabs legitimately layout; the measured slice starts only after settling and before the kill. Reconnect preserves the shell ID and allocates a separate bounded console-title ID. The driver reads the stable ID from idx=1's respawn log and also accepts the released app's legacy new_id label. Shell IDs are allocated only for new tabs and never recycled within a process; close retires history and removes browser and WebView2 session files. HWND sampling is not a compositor/frame-by-frame flicker proof; the layout log signals provide the direct regression oracle. Console view is required because Chat View returns before that log point. The released pre-fix app is the negative control.
