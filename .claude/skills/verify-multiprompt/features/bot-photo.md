# Bot photos

## Sub-features

Bot face offers an image and Reset. Images use a centered circle. Reset keeps the chosen face and color. Remote session pictures upload through background account sync, including existing local pictures. Offline changes retry when sync resumes.

## How to get to it (user POV)

Open Ctrl+K, choose Bot face, then Upload image or Reset.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=bot-photo`. The Windows-only driver uses isolated local sessions and real native file dialogs. Evidence is uploaded as `verify-bot-photo`.

The upload and Cancel paths each Alt+Tab away to a separate, job-owned blank window and back three times with the native picker open. Real keyboard input must return to the same visible, enabled picker owned by the main app window, without focus repair. Each cycle records before/away/return screenshots and independently read native ownership, foreground and enabled state. Upload then proves persisted image pixels; Cancel proves the dialog is destroyed, the main window is enabled and Ctrl+K accepts another query. Both owned jobs must clean up to zero processes.

## Gotchas

This journey uses offline local tabs. It does not verify account sync, remote services, or Android. Review `result.json` and screenshots before claiming success.

Account protocol checks run in the Test workflow. The Worker suite exercises D1 persistence, feature negotiation, layout-write preservation, concurrent writes, reset, and account/workspace isolation. `bot_photo_sync.zig` tests production upload scheduling with an explicit disk/HTTP stand-in for migration, retry, replace, reset, account changes and restart. These do not prove signed-in desktop-to-phone delivery.

For live proof, dispatch `account-journey.yml` with `pictures=true` on the branch. It uses an isolated live account, a real hosted Windows app, and the shipped Android source on a hosted emulator. Disposable device credentials come from the encrypted `IGSH_1612_PHOTO_PROOF` Actions secret. The phone signals readiness only after its actual session avatar is visible. Windows then uploads a generated picture through the native picker. Android must display its distinctive pixels, and independent UTC receipts must show no more than 60 seconds from upload to rendering. Only screenshots and public receipts are retained. Credential seeding stands in for interactive sign-in, not account transport or either app UI.

For physical-device acceptance, upload a synthetic picture through the desktop palette and require the matching phone session picture within 60 seconds. Replace it, then reset it and require the chosen face to return within 60 seconds each time. Repeat an offline upload after reconnect and a pre-upgrade picture after restart. Never publish private pictures or account credentials.
