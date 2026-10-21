# Ended remote session

## Sub-features

Confirmed missing server session, Session ended display, automatic retry cessation, and explicit Start new session action.

## How to get to it (user POV)

Keep a remote tab open while its tmux session is removed on the server. Select the tab: it displays Session ended. Ctrl+K → Start new session explicitly recreates the named session; reconnect must not silently recreate it.

## Driving it with the Windows reconnect harness

Case B removes verify-two from sessions.txt and kills its transport. Require one reason=session-gone and no attempt for the ended ID in the following 60 seconds. After the observation, Ctrl+2 exposes the ended tab in case-B-session-ended.png. The log plus screenshot is the proof, without OCR. Explicit restart is a mapped manual extension, not claimed by case B; the stand-in supports new-session -A -s for that extension.

## Gotchas

A failed host probe is not proof of deletion. The fake returns the production completion sentinel and lists remaining sessions, so the app must positively confirm absence. The released build does not have the ended state and should fail this assertion. Do not count an infrastructure timeout as a valid negative control.
