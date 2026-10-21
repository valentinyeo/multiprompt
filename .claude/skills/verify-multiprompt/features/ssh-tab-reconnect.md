# SSH tab reconnect

## Sub-features

Automatic reconnect after a transport exit, background-tab isolation, retained typing focus in the console and in the Chat View composer, and no full-window layout churn.

## How to get to it (user POV)

Open Multiprompt with two SSH/tmux tabs. Select the first with Ctrl+1 and click its native console. The other tab stays in the background when its network connection drops. With Alt+C, the first tab shows Chat View and the user keeps typing in the composer while the other tab reconnects. Ctrl+Shift+R reconnects an active remote tab manually.

## Driving it with the Windows reconnect harness

Dispatch exe_source=build. Case A records native foreground and GUI-thread focus, kills verify-two's ssh PID while verify-one stays active, and waits for the second tab's respawn and reconnect-ok. case-A.log must contain zero reposition/browser/mask layout lines and focus.json must retain both HWNDs throughout sampled observations. Case F presses Alt+C on the first tab, clicks the composer, kills verify-two's ssh again and types letters into the composer until the reconnect completes. A WinEvent hook (EVENT_SYSTEM_FOREGROUND and EVENT_OBJECT_FOCUS, out of context) records every focus change for the whole run; focus_events counts the ones in each case's window that land on another window than the one focused before the kill, and focus_changed is true when either the hook or the samples saw a change. typed_chars_lost compares the composer text with the typed letters. focus-F.json holds the raw events, samples and texts. A build passes only with zero layout lines, zero focus events and zero lost letters in both cases. The released v0.28.788 must fail case A on layout and show focus_changed in case A or F.

## Gotchas

Initial restore and selecting tabs legitimately layout; the measured slice starts only after settling and before the kill. Reconnect allocates a new shell ID, so the driver obtains it from idx=1's respawn log. HWND sampling is not a compositor/frame-by-frame flicker proof; the layout log signals provide the direct regression oracle. Case A needs console view for the layout oracle because Chat View returns before that log point; case F needs Chat View because that is where the composer loses focus. Polling every 100 ms misses a steal the app repairs within milliseconds, so the hook counts transitions instead of comparing before and after. The seed uses the default per-tab Chat View mode because Alt+C does nothing when Chat View is off everywhere. The released pre-fix app is the negative control.
