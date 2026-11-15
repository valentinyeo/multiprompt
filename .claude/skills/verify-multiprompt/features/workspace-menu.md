# Workspace menu responsiveness

The workspace name above the sessions opens a native card. This journey exercises the reported registry-lock freeze and the row highlight with real mouse and keyboard input.

## Sub-features

- The card first paints within 200 ms, both normally and while another thread owns the production registry mutex.
- The window answers native responsiveness probes within 200 ms for 1.2 seconds per contested open.
- Moving the pointer highlights only its row. Up and Down move the same highlight, while the active workspace name remains bold in the screenshots.
- Escape dismisses the menu without switching. Clicking another workspace switches it, and Enter activates the hovered workspace on return.
- Both real in-process CMD sessions and workspace identities survive every menu open and switch.
- Opening an unchanged registry never changes its last-write timestamp. An exclusively opened registry file does not prevent the cached menu from painting or responding.

## How to get to it (user POV)

Click the workspace name above the sidebar sessions. Ctrl+N creates the second local workspace used here. This journey does not use account sync, SSH, real agents, or a user's saved workspaces.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=workspace-menu`. The PR verifier can select this map automatically.

1. Start the ordinary isolated offline desktop and create a second workspace through Ctrl+N. Read its app-saved identities and registry order.
2. Compile a tiny hosted-only DLL using the same Zig Wyhash implementation as production. A separate native thread uses that hash of the actual registry path to own the production named mutex. No settings or workspace data are injected.
3. Measure click through first visible selected-row pixels once without contention and five times with the mutex held. Fail any sample over 200 ms. Probe the real owned window throughout 1.2 seconds of each contested open.
4. Send absolute native mouse input onto the other row. Require selected-row pixels there and plain panel pixels on the active row. Repeat with Down and Up. Save the screenshots with the bold active name visible for independent inspection.
5. Dismiss with Escape each time, release the mutex in `finally`, and repeat one measured open while the registry file is exclusively held. Release that handle in `finally` too.
6. Require the registry write time to stay unchanged. Click the other workspace, then return through hover and Enter. Require both original identities and CMD sessions in saved state.
7. Check app-published menu-open durations against the same 200 ms limit. Preserve `menu-latency.json`, `menu-responses-*.json`, `menu-log-open-ms.json`, `registry-contention.json`, `menu-preserved.session.json`, screenshots, Doctor and zero-process cleanup.

`workspace-menu-proof.yml` automatically runs this same head driver against both the PR app and its merge-base app through `verify.yml`'s reusable `app_revision` input. The pre-fix app must fail the contested first-paint deadline, not launch or setup. A base run with only a setup failure does not prove this fix.

## Gotchas

- Pixel coordinates require 96 DPI and 100% app scale. The driver fails another scale instead of silently reading the wrong row.
- Timings include real input delivery and first painted selection pixels. Window visibility alone is not a paint measurement. Screenshot and Doctor overhead are outside the timed interval.
- The mutex and exclusive file handle are system-boundary contention fixtures, not UI or registry-data stand-ins. No test-only app switch is used.
- Production keeps local slots authoritative and serves a menu snapshot while a worker reads the registry. A completed external snapshot becomes available on a later open. A newer local save invalidates an older worker snapshot.
- Hosted evidence covers the reproduced contention and local sessions. It does not claim a run on Valentin's laptop or account-sync coverage.
