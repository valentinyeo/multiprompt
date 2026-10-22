# SSH tab reconnect

## Sub-features

Automatic reconnect after a transport exit, background-tab isolation, retained typing focus in the console and in the Chat View composer, and no full-window layout churn. Automatic reconnect starts are limited to one attempted start per host per tick; there is no three-in-flight-attach cap. Initial saved-tab spawns are direct and separate from that scheduler. Healthy monitoring coalesces to 15 seconds; recovery and pending probes use one-second ticks, and ended tabs do not keep an idle recovery timer alive. A visible active respawn sizes only its own console before any show, without activation. Background respawns neither size nor show windows.

## How to get to it (user POV)

Open Multiprompt with two SSH/tmux tabs. Select the first with Ctrl+1 and click its native console. The other tab stays in the background when its network connection drops. With Alt+C, the first tab shows Chat View and the user keeps typing in the composer while the other tab reconnects. Ctrl+Shift+R reconnects an active remote tab manually.

## Driving it with the Windows reconnect harness

Dispatch exe_source=build. Case A records native foreground and GUI-thread focus, kills verify-two's ssh PID while verify-one stays active, and waits for the second tab's respawn and reconnect-ok. case-A.log must contain zero reposition/browser/mask layout lines and focus.json must retain both HWNDs throughout sampled observations. case-A.png shows the active tab after recovery. Case F presses Alt+C on the first tab, clicks the composer, kills verify-two's ssh again and types letters until reconnect completes. A WinEvent hook records every foreground/focus event, including transient steals that polling misses. Both cases require zero focus_events; case F also reads the composer text back and requires typed_chars_lost=0. The summary order is A, F, B. Case B removes the last sessions, exercises the fake SSH no-server response and observes the ended session for at least 60 seconds. Dispatch exe_source=v0.28.788 as the negative control: case A must fail on layout and either A or F must show focus_changed=true.

## Gotchas

Initial restore and selecting tabs legitimately layout; the measured slice starts only after settling and before the kill. Reconnect preserves the shell ID and allocates a separate bounded console-title ID. The driver reads the stable ID from idx=1's respawn log and also accepts the released app's legacy new_id label. Shell IDs are allocated only for new tabs and never recycled within a process; close retires history and removes browser and WebView2 session files. Case A needs console view for the layout oracle; case F needs Chat View to measure composer focus. The seed uses default per-tab Chat View with cv=false on both tabs, since chat_view_mode=nowhere disables Alt+C. v0.28.788 can repair composer focus within milliseconds, so the hook is required in addition to sampling. HWND sampling is not a compositor/frame-by-frame flicker proof; the layout log signals provide the direct regression oracle. Console view is required because Chat View returns before that log point. The released pre-fix app is the negative control.
