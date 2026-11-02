# Inbox order

The desktop Inbox shows recent sessions first.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=inbox-order` after pushing the candidate. The isolated Windows runner launches the checked release executable with two local CMD sessions. Their initial activity times are seeded in the saved session; the older session is unread and the newer session is read. The app publishes the Inbox data and paints the timestamps. The journey verifies both attention states before opening Inbox, then identifies the newer top session by toggling its unread state. After a minute, a scripted local notification updates the older session. The journey checks its app-published timestamp, captures the Inbox again, and identifies the new top row by its session ID. This is a simulated update, not a cloud conversation or a real reply.

Inspect `inbox-order-before.png` and `inbox-order-after.png` for both names and visible, distinguishable relative times. Compare `inbox-order-before.json` and `inbox-order-after.json` with `result.json` for published timestamps and identities. A passing scripted update does not replace a real reply check or Android verification. The harness owns and cleans the isolated process and profile.
