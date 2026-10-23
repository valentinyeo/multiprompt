# Ended remote session

## Sub-features

Confirmed missing server session, Session ended display, automatic retry cessation, and explicit Start new session action.

## How to get to it (user POV)

Keep a remote tab open while its tmux session is removed on the server. Select the tab: it displays Session ended. Ctrl+K → Start new session explicitly recreates the named session; reconnect must not silently recreate it.

## Driving it with the Windows reconnect harness

Case B empties sessions.txt and kills verify-two's transport, exercising the no-server response rather than a list of remaining sessions. Require one reason=session-gone and no attempt for the ended ID in the following 60 seconds. After the observation, Ctrl+2 exposes the ended tab in case-B-session-ended.png. The log plus screenshot is the proof, without OCR. Explicit restart is a mapped manual extension, not claimed by case B; the stand-in supports new-session -A -s for that extension.

## Gotchas

A failed host probe or tmux listing is not proof of deletion. Only a successful listing probe, including its explicitly handled no-server response, emits @@LS_OK@@ alongside the host completion sentinel. Ending requires two consecutive complete gone results for the same tab and a dead transport; a live transport always vetoes ending. Reconnecting and session-creating tabs are excluded. A restored tab or one healthy before an earlier reconnect remains eligible even if its latest spawn never became healthy; only tabs without any healthy history or restored identity are excluded. For the empty list, the stand-in emits the successful-listing marker only when the probe explicitly handles the no-server response, then emits the host completion marker. An attach exit awaiting a probe bypasses the three-second spawn grace; requests during a running probe schedule the next one immediately. The historical negative-control release v0.28.788 lacks the ended state; v0.28.820 passes this case in run 39870853585. Do not count an infrastructure timeout as a valid negative control.
