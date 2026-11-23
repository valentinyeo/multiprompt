# SOFT-3001 release evidence

Release: `v0.28.1893`, newest when selected at 2026-11-23 10:18 UTC.
Run: https://github.com/valentinyeo/multiprompt/actions/runs/45154943152
Tested journey revision: `ae4ae174357a99b1f0d260eb71151bfb014ebc97`.

Incomplete, not a confirmed product failure. The real clipboard contains the selected marker plus padding, 60 characters. The run incorrectly expected the stale remote PTY width of 80. It stopped before the required post-copy heartbeat and no-selection interrupt checks. The final code uses an exact one-character selection; that correction has not been run.

All screenshots were opened and inspected. Only GitHub Windows/WSL was driven. The real-server chat baseline passed all four cases. The owned app job finished with zero active processes, keys were removed, WSL stopped, and scratch evidence was copied then removed.

Fault route: Multiprompt repository board/view. The owner files it; this worker made no board writes. Full acceptance is not claimed.
