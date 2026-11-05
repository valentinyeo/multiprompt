# Inbox order

The desktop Inbox shows recent sessions first.

## Sub-features

- The Inbox lists the session with the newest displayed time first; new activity moves that session up.
- Displayed time is the later of the session's last activity and its last visit.
- The Favorites split keeps its existing frequent ordering; only the other Inbox tabs sort by displayed time.
- The journey leaves read state alone: the older session stays unread and the newer one stays read.
- Android order is unchanged.

## How to get to it (user POV)

- Alt+I opens the Inbox and selects All; the sidebar inbox button or Ctrl+Shift+I toggles it.
- Each row shows its session and its time; Ctrl+Shift+U toggles the unread-only filter.
- The newest session is the top row after any new activity on it.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=inbox-order` and the published release tag. The isolated Windows runner launches the checked release executable with two local CMD sessions. Their initial activity times are seeded in the saved session; the older session is unread and the newer session is read. The journey checks the app-published identities, timestamps and attention states, then captures the real Inbox. A scripted local notification sends `NOTIFICATION:Inbox Older` to the loopback listener owned by that app process, within the production notification port range. The journey waits for the app-published activity change and an open Inbox, without a fixed delay. The journey checks the app-published timestamp and captures the Inbox again. This is a stand-in update, not a cloud conversation or a real reply.

A successful run captures evidence; it does not automatically verify displayed order. `result.json` marks `visualReviewRequired`. Review `inbox-order-before.png`: Inbox Newer must appear above Inbox Older, with both times visible. Review `inbox-order-after.png`: Inbox Older must appear above Inbox Newer, with both times visible. Compare `inbox-order-before.json` and `inbox-order-after.json` for app-published timestamps and identities. The `inbox-order-notification.json` fixture records the app PID, listener owner, loopback port and scripted payload. The harness records the executable version and hash, and cleans its owned process and profile.

## Gotchas

- The second update is a scripted local notification, not a cloud message, so reply timing and remote ordering are not covered.
- Order is proven by eye on the two captures; `result.json` never decides it and always asks for visual review.
- This map covers desktop only; Android keeps its own order and needs its own journey.
- Static source checks are not proof of a passed Windows journey; GitHub must run the real desktop verification.
