# Ended remote session

## Sub-features

Confirmed missing server session, Session ended display, automatic retry cessation, and explicit Start new session action.

## How to get to it (user POV)

Keep a remote tab open while its tmux session is removed on the server. Select the tab: it displays Session ended. Ctrl+K → Start new session explicitly recreates the named session; reconnect must not silently recreate it.

## Driving it with the Windows reconnect harness

Case B removes verify-two from sessions.txt and kills its transport. Require one reason=session-gone and no attempt for the ended ID in the following 60 seconds. After the observation, Ctrl+2 exposes the ended tab in case-B-session-ended.png. The log plus screenshot is the proof, without OCR. Explicit restart is a mapped manual extension, not claimed by case B; the stand-in supports new-session -A -s for that extension.

## Gotchas

A failed host probe or tmux listing is not proof of deletion. Only a successful list-sessions command emits @@LS_OK@@, alongside the host completion sentinel. Ending requires two consecutive complete gone results for the same tab and a dead transport; a live transport always vetoes ending. Reconnecting, session-creating, and never-healthy-since-spawn tabs are excluded. The fake emits both markers and lists remaining sessions. An attach exit awaiting a probe bypasses the three-second spawn grace; requests during a running probe schedule the next one immediately. The released build does not have the ended state and should fail this assertion. Do not count an infrastructure timeout as a valid negative control.
