# SOFT-3002 release evidence

Release: `v0.28.1893`, newest when selected at 2026-11-23 10:18 UTC.
Run: https://github.com/valentinyeo/multiprompt/actions/runs/45154943152
Tested journey revision: `ae4ae174357a99b1f0d260eb71151bfb014ebc97`.

Partial pass: normal quit/restart restored the UI-created tab attached to the same remote session, pane and shell PID ($1|%1|480), and real typed input produced the after-restart receipt. Full acceptance is incomplete: close tab resolved to Archive chat, row 7110, rather than the old expected target 6232. No close/reopen proof was produced. The final code follows the observed alias and requires the same remote session to survive it; this correction has not been run.

All screenshots were opened and inspected. Only GitHub Windows/WSL was driven. The real-server chat baseline passed all four cases. The owned app job finished with zero active processes, keys were removed, WSL stopped, and scratch evidence was copied then removed.

Fault route: Multiprompt repository board/view. The owner files it; this worker made no board writes. Full acceptance is not claimed.
