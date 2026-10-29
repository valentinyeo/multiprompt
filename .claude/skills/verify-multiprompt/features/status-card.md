# Status card

Verify on: push

Verify all three compact status pages. The AI page is a grey floating pill; click it to expand the approved usage card.

## Sub-features

- Overview and VPS remain compact 20–30 px cards, with their existing hover detail.
- AI usage uses a fully rounded grey pill. Repeated provider pools have distinct labels, such as CL1, CX and CL2.
- Clicking the AI pill opens a rounded usage card above it. Each account shows weekly usage, an elapsed-week tick, reset details and its five-hour window. Missing windows say not reported.
- Second click, Escape and outside click dismiss the panel without changing the AI page.
- Ctrl+Shift+G and the wheel retain the existing three-page navigation.
- The installed version stays visible above the pill. A pending update replaces this line with the existing Restart action.
- The card footer shows the installed version and opens release notes through Tab, Enter or a click.
- Optional pace proof covers each plan window in the compact pill.

## How to get to it (user POV)

Press Ctrl+Shift+G twice from Overview. Click the AI usage pill at the bottom of the sidebar. Read the full usage/reset data; click again, press Escape or click elsewhere to close.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=status-card`, optionally `tag=vX.Y.Z` for a release.

The private GitHub profile receives the normal collector file `usage-telemetry.json` from `tools/fixtures/IGSH-908/`. A held `Local\MultipromptUsageTelemetryLaunch` mutex stands in for the collector and keeps a real collector from replacing the fixture or making provider calls. The app uses its ordinary file reader. No app state is set directly; Ctrl+Shift+G selects each page through real input. This proves the file/UI boundary, not live provider authentication.

The journey measures all three frames with screenshots and DPI normalization, preserving the 20–30 px compact-height checks. The AI frame must also be at the sidebar bottom, so an earlier unrelated frame cannot satisfy it. The original plain AI line fails this condition.

Capture `pill-closed.png` and require version text pixels above the pill. Click with SendInput, require the app-owned `MultiPromptUsageCard` child, then capture `pill-open.png`. The screenshot must contain the approved dark panel, neutral quota tracks, bright used portions and readable grey details. Real second click, Escape and outside click must remove the card. Tab and Enter open release notes. The saved page must remain AI. `status-card.json` and `result.json` retain each outcome; `action.png` and `after.png` remain available to the shared harness.

Set `usage_pace_proof=true` for pace checks.
Optional `usage_pace_status` accepts base64 sanitized status JSON.
Generate live input with `tools/capture-usage-pace.py`.
It removes account identities, emails, hosts and credentials.
The job replays sample, above and below snapshots.
Each uses the normal `ssh-path.txt` boundary.
The external SSH stand-in only answers status reads.
Startup may await the normal three-minute refresh.
Reader setup waits up to four minutes.
Fixture snapshots live under `tools/fixtures/IGSH-997/`.
The closed pill must show expected pace colors.
The expanded card uses approved neutral bars.
Screenshots and source JSON remain in `pace-*` folders.
Only `ts` advances to the replay clock.
Snapshots keep usage, rates, ratios, forecasts and resets.
Source timestamps remain visible alongside replay timestamps.
Production provider authentication remains outside this proof.

## Gotchas

- The original IGSH-673 AI page was deliberately plain; IGSH-908 replaces that visual requirement, not the compact height of the other pages.
- Releases before IGSH-673, such as `v0.28.839`, draw a 222 px card and still fail the compact-height check.
- Fixture numbers prove rendering, not live authentication.
- Live numeric snapshots require the explicit input.
- Missing history must display unknown, never zero.
- Everything runs on GitHub Windows. Never drive a user's desktop or build locally.
