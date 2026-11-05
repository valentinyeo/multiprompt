# Ended remote session

## Sub-features

Confirmed missing server session, Session ended display, automatic retry cessation, and explicit Start new session action.

## How to get to it (user POV)

Keep a remote tab open while its tmux session is removed on the server. Select the tab: it displays Session ended. Ctrl+K → Start new session explicitly recreates the named session; reconnect must not silently recreate it.

## Driving it with the Windows reconnect harness

Case B empties sessions.txt and kills verify-two's transport, exercising the no-server response rather than a list of remaining sessions. Require one reason=session-gone and no attempt for the ended ID in the following 60 seconds. After the observation, Ctrl+2 exposes the ended tab in case-B-session-ended.png. The log plus screenshot is the proof, without OCR. Explicit restart is a mapped manual extension, not claimed by case B; the stand-in supports new-session -A -s for that extension.

## Offline close and explicit reopen

`verify-close-unattached.yml` also runs `tools/verify-reconnect/pending-close.ps1` sequentially on its owned hosted Windows desktop. It seeds two saved remote tabs once, then uses real Ctrl+Shift+W, Ctrl+Shift+T and Ctrl+K → Show all sessions. The SSH boundary rejects kills while `kill-offline` exists and holds a connecting retry while `kill-hold` exists. It never modifies app state after launch.

Require the app-written closed tombstone and absent tab despite a stale successful listing, exactly one successful remote end after reconnect, and explicit reopen terminating the held retry with no later remote end. Inspect `pending-close/summary.json`, saved-session snapshots, stand-in success/held markers and screenshots. Account login is offline; stale account layout is covered separately by native execution of the exact production end entry and layout-filter loop, not claimed as live account sync. Queued remote ends remain in memory, as before; restarting before reconnect is not covered.

## Gotchas

A failed host probe or tmux listing is not proof of deletion. Only a successful listing probe, including its explicitly handled no-server response, emits @@LS_OK@@ alongside the host completion sentinel. Ending requires two consecutive complete gone results for the same tab and a dead transport; a live transport always vetoes ending. Reconnecting and session-creating tabs are excluded. A restored tab or one healthy before an earlier reconnect remains eligible even if its latest spawn never became healthy; only tabs without any healthy history or restored identity are excluded. For the empty list, the stand-in emits the successful-listing marker only when the probe explicitly handles the no-server response, then emits the host completion marker. An attach exit awaiting a probe bypasses the three-second spawn grace; requests during a running probe schedule the next one immediately. The historical negative-control release v0.28.788 lacks the ended state; v0.28.820 passes this case in run 39870853585. Do not count an infrastructure timeout as a valid negative control.
