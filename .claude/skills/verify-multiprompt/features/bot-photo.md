# Bot photos

## Sub-features

Bot face offers an image and Reset. Images use a centered circle. Reset keeps the chosen face and color. Remote session pictures upload through background account sync, including existing local pictures. Offline changes retry when sync resumes.

## How to get to it (user POV)

Open Ctrl+K, choose Bot face, then Upload image or Reset.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=bot-photo`. The Windows-only driver seeds two isolated local CMD tabs, then uses real native file dialogs to import generated PNG and JPEG fixtures. Evidence is uploaded as `verify-bot-photo`.

IGSH-1541 adds the real Alt+S / Alt+1 Starred path, pins the selected bot there, opens Chat View with Alt+C and toggles Inbox with Ctrl+Shift+I. Pixel samples at the production-painted avatar rectangles must show the same asymmetric image on the Starred tile, chat title and Inbox row. The journey repeats with a different image before any restart, then resets and checks the selected generated face and color across all three. Full-window screenshots and individual crops are retained, including failed samples. The journey also selects Light, AMOLED and Edge Grey through the real Themes palette, reads each saved theme value, and repeats the three-surface picture measurements and captures. The added theme pass requires a fresh hosted run; the older recorded proof below covers the default theme only.

Before launching Multiprompt, an independent legacy Windows file picker must pass the identical Alt+Tab and file-entry sequence against a separate blank window. It records the actual selected path. This distinguishes driver/native-dialog failures from app behavior.

The upload and Cancel paths each Alt+Tab away to a separate, job-owned blank window and back three times with the native picker open. Real keyboard input must return to the same visible, enabled picker owned by the main app window, without focus repair. Each cycle records before/away/return screenshots and independently read native ownership, foreground and enabled state. Upload then proves persisted image pixels; Cancel proves the dialog is destroyed, the main window is enabled and Ctrl+K accepts another query. Both owned jobs must clean up to zero processes.
### Recorded desktop proof

- Positive: [41933658328](https://github.com/valentinyeo/multiprompt/actions/runs/41933658328), app/harness/embedded revision `a1f75a771853c63495f95410314e0d190b276da8`. All 67 checks passed; cleanup reported zero owned processes.
- Negative: [41935826746](https://github.com/valentinyeo/multiprompt/actions/runs/41935826746), revision `c1d1e5842f836e5c3a851e8c0e9cde9fb5fa6071`. Identical driver, original generated-only title/Inbox rendering. Upload and Starred pixels passed; both header and Inbox image-center assertions failed, with zero owned processes after cleanup.
- Six full-window screenshots and nine avatar crops were inspected. [Matching-image contact sheet](https://screencast2.com/QTgp9.png), [Starred and header](https://screencast2.com/bjXNf.png), [Inbox](https://screencast2.com/6N5F3.png). The sheet enlarges actual native crops, not a mockup.

## Gotchas

This journey uses offline local tabs. It does not verify account sync, remote services, or Android. Review `result.json` and screenshots before claiming success.

Account protocol checks run in the Test workflow. The Worker suite exercises D1 persistence, feature negotiation, layout-write preservation, concurrent writes, reset, and account/workspace isolation. `bot_photo_sync.zig` tests production upload scheduling with an explicit disk/HTTP stand-in for migration, retry, replace, reset, account changes and restart. These do not prove signed-in desktop-to-phone delivery.

For live proof, dispatch `account-journey.yml` with `pictures=true` on the branch. It uses an isolated live account, a real hosted Windows app, and the shipped Android source on a hosted emulator. Disposable device credentials come from the encrypted `IGSH_1612_PHOTO_PROOF` Actions secret. The phone signals readiness only after its actual session avatar is visible. Windows then uploads a generated picture through the native picker. Android must display its distinctive pixels, and independent UTC receipts must show no more than 60 seconds from upload to rendering. Only screenshots and public receipts are retained. Credential seeding stands in for interactive sign-in, not account transport or either app UI.

For an isolated cross-client proof, dispatch `account-journey.yml` with `pictures_isolated=true`. The encrypted `IGSH_1612_FIXTURE_PROOF` secret supplies two disposable fixture devices. The production Worker code runs with local D1 on hosted Windows behind a free ephemeral TryCloudflare HTTPS tunnel. Job-only source substitutions point the desktop and Android builds at that endpoint; they are not release-byte-equivalent builds. The same native picker, Android avatar pixel assertions and 0–60 second UTC comparator run without production accounts. The public fixture cleanup receipt must show zero owned survivors. This does not prove owner-account behavior, production-service latency, physical-device behavior, or the separate replace and reset journeys.

[Isolated proof 41966928496](https://github.com/valentinyeo/multiprompt/actions/runs/41966928496) passed at desktop revision `146b7b06` with Android `b109a086`: the actual avatar rendered the native-picker image in 9.094 seconds. Both cleanup receipts verified two owned roots and zero survivors; the private fixture directory and generated SSH keys were removed. Screenshots were inspected. Artifacts are suffixed with the Actions run attempt to prevent stale rerun evidence. This proves the isolated cross-client path, not owner-account, production-service or physical-device latency.

For physical-device acceptance, upload a synthetic picture through the desktop palette and require the matching phone session picture within 60 seconds. Replace it, then reset it and require the chosen face to return within 60 seconds each time. Repeat an offline upload after reconnect and a pre-upgrade picture after restart. Never publish private pictures or account credentials.
