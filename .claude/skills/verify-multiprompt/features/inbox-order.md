# Inbox order

The desktop Inbox shows recent sessions first.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=inbox-order` and the published release tag. The isolated Windows runner launches the checked release executable with two local CMD sessions. Their initial activity times are seeded in the saved session; the older session is unread and the newer session is read. The journey checks the app-published identities, timestamps and attention states, then captures the real Inbox. After a minute, a scripted local notification updates the older session. The journey checks the app-published timestamp and captures the Inbox again. This is a stand-in update, not a cloud conversation or a real reply.

A successful run captures evidence; it does not automatically verify displayed order. `result.json` marks `visualReviewRequired`. Review `inbox-order-before.png`: Inbox Newer must appear above Inbox Older, with both times visible. Review `inbox-order-after.png`: Inbox Older must appear above Inbox Newer, with both times visible. Compare `inbox-order-before.json` and `inbox-order-after.json` for app-published timestamps and identities. The harness records the executable version and hash, and cleans its owned process and profile.
