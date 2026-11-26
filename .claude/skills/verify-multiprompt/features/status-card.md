# Status card

Source files: src/inbox*, src/notification*, src/settings*, src/themes.zig, src/fonts*, src/main.zig, build.zig, build.zig.zon, src/command_palette.zig, src/shortcuts.zig, src/usage_card.zig, src/capacity.zig, src/telemetry_panel.zig, src/update_card.zig, .claude/skills/verify-multiprompt/control-feature-status-card.ps1, tools/usage-icon-geometry.js, tools/capture-usage-pace.py

Verify on: push

Verify all three compact status pages. The AI page is a 36 px round usage icon at the sidebar bottom; click it to expand the approved usage card.

## Sub-features

- Overview and VPS remain compact 20–30 px cards, with their existing hover detail.
- AI usage is a 36 px dark disc at the sidebar bottom, holding a half-circle gauge: a grey track, a status-coloured used arc and a centre dot. Repeated provider pools have distinct labels, such as CL1, CX and CL2 inside the card.
- Clicking or hovering the icon opens a rounded usage card above it. Each account shows weekly usage, an elapsed-week tick, reset details and its five-hour window. Missing windows say not reported.
- Second click, Escape and outside click dismiss the panel without changing the AI page.
- Ctrl+Shift+G and the wheel retain the existing three-page navigation.
- The installed version sits in the expanded card footer. A pending update no longer uses the footer: it floats a rounded update card over the sidebar bottom, with its own Restart button.
- The card footer shows the installed version and opens release notes through Tab, Enter or a click.
- Optional pace proof reads the expanded card. The closed icon carries one gauge colour for the worst pool, so per-window pace ink is not visible while the card is closed.

## How to get to it (user POV)

Press Ctrl+Shift+G twice from Overview. Click the round usage icon at the bottom-left of the sidebar. Read the full usage/reset data; click again, press Escape or click elsewhere to close.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=status-card`, optionally `tag=vX.Y.Z` for a release.

The private GitHub profile receives the normal collector file `usage-telemetry.json` from `tools/fixtures/IGSH-908/`. A held `Local\MultipromptUsageTelemetry` mutex stands in for the collector and keeps a real collector from replacing the fixture or making provider calls. The app uses its ordinary file reader. No app state is set directly; Ctrl+Shift+G selects each page through real input. This proves the file/UI boundary, not live provider authentication.

The journey measures all three frames with screenshots and DPI normalization, preserving the 20–30 px compact-height checks. The AI frame must also be at the sidebar bottom, so an earlier unrelated frame cannot satisfy it. The original plain AI line fails this condition.

Capture `pill-closed.png` and require the icon itself.
`tools/usage-icon-geometry.js` reads its bounds, fill colour, gauge track, dot and the usage card palette from `src/capacity.zig` and `src/usage_card.zig`, so the driver never keeps a second copy of the geometry or the colours.
The disc must fill those bounds, the gauge must carry track and usage ink, and no icon pixel may paint outside them.
The removed 104 px footer is checked in the negative: no divider row and no usage bar colours may come back.
Hover opens the card, and both hover and click land on the icon centre.
Hover opens the card. The real click that expands it lands on the icon while the hover card is up and the app frame is foreground, which is what a user does; the passive card converts that click into the expanded card.
Click with SendInput, then require the app-owned `MultiPromptUsageCard` child, matched by the class and window title `tools/usage-icon-geometry.js` reads from `src/usage_card.zig`, and capture `pill-open.png`. The screenshot must contain the approved dark panel, neutral quota tracks, bright ink and readable grey detail in the card's lowest 220 logical pixels above the icon, scanned within the app-published sidebar width so a closed card cannot satisfy it. The card palette comes from the same reader. The journey reads the app-published tab-order state from `session.json.launch.json` and switches to manual order only when the app reports auto order, so the footer proof runs against a stable order. Real second click, Escape and outside click must remove the card. Tab and Enter open release notes. The saved page must remain AI. `status-card.json` and `result.json` retain each outcome; `action.png` and `after.png` remain available to the shared harness.

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
The closed icon carries one gauge colour for the worst pool, so per-window pace ink is read from the expanded card.
The expanded card uses approved neutral bars.
Screenshots and source JSON remain in `pace-*` folders.
Only `ts` advances to the replay clock.
Snapshots keep usage, rates, ratios, forecasts and resets.
Source timestamps remain visible alongside replay timestamps.
Production provider authentication remains outside this proof.

## Gotchas

- The original IGSH-673 AI page was deliberately plain; IGSH-908 replaces that visual requirement, not the compact height of the other pages.
- IGSH-1303 removed the sidebar footer: divider, installed-version line and three usage bars. A driver that still looks for them reports a missing footer, so keep the icon proof in step with `src/usage_card.zig`.
- Releases before IGSH-673, such as `v0.28.839`, draw a 222 px card and still fail the compact-height check.
- Fixture numbers prove rendering, not live authentication.
- Live numeric snapshots require the explicit input.
- Missing history must display unknown, never zero.
- Everything runs on GitHub Windows. Never drive a user's desktop or build locally.
- `tools/usage-icon-geometry.js` throws when the icon layout changes shape. Update the reader with the new source, never paste the numbers into the driver.
