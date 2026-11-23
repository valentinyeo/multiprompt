# SOFT-3003 release evidence

Release: `v0.28.1893`, newest when selected at 2026-11-23 10:18 UTC.
Run: https://github.com/valentinyeo/multiprompt/actions/runs/45154943152
Tested journey revision: `ae4ae174357a99b1f0d260eb71151bfb014ebc97`.

Failed requested palette path: from the real server chat, Ctrl+K Open shell on VPS 1 opened a live shell on the right server, but pwd was /home/mpverify instead of the chat folder /home/mpverify/shell-proof-folder. This does not test or disprove the separate mp-shell open agent command shipped in SOFT-3003.

All screenshots were opened and inspected. Only GitHub Windows/WSL was driven. The real-server chat baseline passed all four cases. The owned app job finished with zero active processes, keys were removed, WSL stopped, and scratch evidence was copied then removed.

Fault route: Multiprompt repository board/view. The owner files it; this worker made no board writes. Full acceptance is not claimed.
