# Pane layout

## Sub-features

- Console HWND placement stays inside the primary pane focus ring, including a docked browser, full-width mode, title visibility and reconnect placement.
- Pane gaps are clear except for a short centered splitter grip that cannot touch the ring.
- Gray sidebar group strokes have their own column before session icons and header text.
- Browser button-cover masks match Chrome's own frame pixels rather than the app theme in Dark, Light and AMOLED (IGSH-810).
- Compiled extract-real-Zig regressions cover 100, 125 and 150 percent; the live journey covers the fresh desktop's default UI scale and records DPI.

## How to get to it (user POV)

- Keep the initial CMD tab in console view, not Chat View.
- Ctrl+K `move to group`, Enter, type `new group`, Enter groups the selected session. Escape leaves the inline rename with the app's default group name and gray color.
- Ctrl+K `open browser`, Enter docks the browser without an extension, just as in browser-pane-stuck.
- Create a second, ungrouped CMD through Ctrl+K `new cmd` so the original grouped row stays unselected with its complete rail visible. Win+Up maximizes the main window; Ctrl+2 returns input focus to the ungrouped console.
- Themes → Dark through Ctrl+K selects the known dark palette for the original layout proof; the added mask proof then selects Dark, Light and AMOLED through the same helper. No settings are seeded.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml -f feature=pane-layout` against the proposed revision. Pull requests include pane-layout alongside appearance, workspace-focus and browser-pane-stuck.

1. Launch the real isolated app and pass Doctor. Choose Dark with the existing Themes helper. Require one CMD session with no saved Chat View preference.
2. Use the real Move to Group submenu (palette target 6301), create a new group and read the app-written membership from session.json. Escape the inline rename. Create a second ungrouped CMD through the real palette, require its saved ungrouped membership and active selection, and use its published shell ID for console/browser ownership. This preserves the full continuous-rail positive control without requiring a rail to cross a selected row. Never create fixtures, seed preferences or post private app messages.
3. Open a browser through the existing Open-BrowserPane helper. Wait for connected state, a positive connection ID and a visible HWND carrying `ZigShellPaneOwner` for the verified main window. No extension is needed.
4. Maximize with real Win+Up, require IsZoomed, and select the ungrouped CMD with Ctrl+2. Require console foreground, the real shell-ID title and visible ConsoleWindowClass through UIA. Match UIA bounds against GetWindowRect, then capture `pane-layout.png` and its focus/UIA snapshots.
5. Compute the shared slot's expected ring bounds from the client screen rect, the actual browser HWND left edge, default sidebar width, recorded DPI and saved UI scale. Find the dominant focus-gray stroke in a narrow top-edge band, rejecting a missing or short stroke. Allow antialias blending, but not arbitrary colors. Require a matching pixel at every position along all four straight sides (with only a stroke-width perpendicular search); exclude rounded corners. The measured console HWND must be wholly inside the ring's inner edges.
6. Scan every pixel in the pane gap across the full client height. Reject focus-gray or divider-gray pixels outside the one-stroke-wide, 32-scaled-pixel centered splitter grip. The gap must also be strictly beyond the ring's outer edge.
7. Find the sidebar group stroke by its app-default gray color and a long vertical pixel run, not an invented UIA node. Derive the first row from that observed header top. Find the real CMD icon's contrasting pixels against the sampled unselected-row background in its icon area, require visible glyph height/area, save their bounding box and require at least four scaled pixels between it and the rail. A clipped icon cannot pass merely because the rail overwrote its leftmost pixels.
8. Keep the browser docked and the main window maximized. For each of `dark`, `light` and `amoled`, use Select-Theme and wait at most 10 seconds for all ten visible, nonempty `ZigShellBrowserEdgeMask` HWNDs enumerated by EnumWindows with the verified app PID (`mask-windows-<theme>`). Allow a bounded one-second repaint interval, recheck maximization and the same owned browser, then capture a fresh `pane-layout-mask-<theme>.png` with its UIA/focus snapshots.
9. Require exactly one frame-side controls mask at Chrome's top-right (`mask-top-right-<theme>`). Intersect each mask rectangle with the browser HWND rectangle: the selected interior rectangle touches its top and right, is 100–180 scaled pixels wide and 24–40 high, with at most four scaled pixels of raw top/right bleed. This excludes the thin edge strips, small corner masks and taller nearly transparent hit mask. Save both raw and clipped rectangles. Sample the mask at its horizontal midpoint, 12 scaled pixels below Chrome's top. Sample Chrome at the same y, four scaled pixels left of the mask's left edge; require that reference inside Chrome, within its top 24 scaled pixels (above page content) and outside every mask (`mask-reference-<theme>`).
10. Require RGB channel differences at most 10 (`mask-chrome-<theme>`). Reject a near-black mask (all channels ≤32) whenever the reference is not near black (`mask-not-black-<theme>`). For both dark and amoled, require a light Chrome reference (all channels ≥160), a separately sampled dark app sidebar (all channels ≤80), and a mask farther than 10 from the app and closer to Chrome (`mask-follows-chrome-dark`, `mask-follows-chrome-amoled`). Missing light-Chrome/dark-app contrast fails, never skips the discrimination proof.
11. Save `pane-layout-mask-colours.json` next to `pane-layout-pixels.json`: all owned visible mask HWNDs/rectangles, selected raw/interior mask and browser/screenshot rectangles, screen-coordinate sample points, mask/reference/app RGB, per-channel deltas, maximum Chrome/app distances, thresholds, DPI, scale and screenshot names. Capture and save all three themes before colour assertions so a colour failure retains all measurements. Save discovered rectangles before geometry assertions as well.
12. Every assertion prints `pane-layout <step> PASS`; any missing precondition or failed assertion throws. The pane-layout result checks list includes all new assertion names. Inspect pane-layout.png, pane-layout-pixels.json, pane-layout-rects.json, pane-layout-mask-{dark,light,amoled}.png, pane-layout-mask-colours.json, action/before/after images, UIA/focus snapshots, result.json and owned-job cleanup. Measurements are read-only and persisted separately from app data. The original layout proof runs unchanged before the mask journey.

## Gotchas

- The screenshot is the real console/browser surface, never the Chat View transcript. Console ownership is checked by the original main-window root plus the app-published shell ID, not by conhost sharing the app PID.
- The original layout pixel expectations deliberately select Dark through user input and use the fresh default sidebar width. They must fail on unexpected themes, hidden/collapsed sidebars or missing icons rather than relaxing assertions. The separate mask proof uses fresh screenshots for all three themes and requires Chrome to remain light in the dark/amoled contrast cases.
- UIA does not expose custom sidebar rows or focus-ring nodes; HWND geometry and screenshot pixels provide those proofs. The icon probe covers the initial real CMD icon, while static compiled geometry also exercises status-icon rectangles with and without a favicon.
- Straight-side continuity excludes the rounded corners; compiled geometry checks the full slot. Live 125/150 percent, other icon artwork, full-width/reconnect interaction and browser-focused ring switching remain compiled-harness coverage, not claims of this one screenshot journey.
- IGSH-810 requires the identical pane-layout GitHub Windows PR checks to fail on the app-theme-coloured baseline and pass after the browser-colour fix. No app build, test or desktop execution happens on the VPS; PowerShell parsing (when available) and source/map checks are static evidence only.
- A green job still requires human inspection of screenshots at the exact revision. No journey has been executed merely because this feature map exists.
