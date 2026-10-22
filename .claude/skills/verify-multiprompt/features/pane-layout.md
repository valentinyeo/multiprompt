# Pane layout

## Sub-features

- Console HWND placement stays inside the primary pane focus ring, including a docked browser, full-width mode, title visibility and reconnect placement.
- Pane gaps are clear except for a short centered splitter grip that cannot touch the ring.
- Gray sidebar group strokes have their own column before session icons and header text.
- Compiled extract-real-Zig regressions cover 100, 125 and 150 percent; the live journey covers the fresh desktop's default UI scale and records DPI.

## How to get to it (user POV)

- Keep the initial CMD tab in console view, not Chat View.
- Ctrl+K `move to group`, Enter, type `new group`, Enter groups the selected session. Escape leaves the inline rename with the app's default group name and gray color.
- Ctrl+K `open browser`, Enter docks the browser without an extension, just as in browser-pane-stuck.
- Win+Up maximizes the main window; Ctrl+1 returns input focus to the original console.
- Themes → Dark through Ctrl+K selects the known dark palette; no settings are seeded.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml -f feature=pane-layout` against the proposed revision. Pull requests include pane-layout alongside appearance, workspace-focus and browser-pane-stuck.

1. On GitHub only, compile the new extracted-production tests against pre-fix master `6b8295f57d5932651d2324ed5f672ae88dbfeb88`. Require assertion failures for all three IGSH-549 cases, not a compiler or launch error, then run the same harness against the branch and require success. Retain `pane-layout-before.log` and `pane-layout-after.log`.
2. Launch the real isolated app and pass Doctor. Choose Dark with the existing Themes helper. Require one CMD session with no saved Chat View preference.
3. Use the real Move to Group submenu (palette target 6301), create a new group and read the app-written membership from session.json. Escape the inline rename. Never create fixtures, seed preferences or post private app messages.
4. Open a browser through the existing Open-BrowserPane helper. Wait for connected state, a positive connection ID and a visible HWND carrying `ZigShellPaneOwner` for the verified main window. No extension is needed.
5. Maximize with real Win+Up, require IsZoomed, and select CMD with Ctrl+1. Require console foreground, the real shell-ID title and visible ConsoleWindowClass through UIA. Match UIA bounds against GetWindowRect, then capture `pane-layout.png` and its focus/UIA snapshots.
6. Compute the shared slot's expected ring bounds from the client screen rect, the actual browser HWND left edge, default sidebar width, recorded DPI and saved UI scale. Find the dominant focus-gray stroke in a narrow top-edge band, rejecting a missing or short stroke. Allow antialias blending, but not arbitrary colors. Require a matching pixel at every position along all four straight sides (with only a stroke-width perpendicular search); exclude rounded corners. The measured console HWND must be wholly inside the ring's inner edges.
7. Scan every pixel in the pane gap across the full client height. Reject focus-gray or divider-gray pixels outside the one-stroke-wide, 32-scaled-pixel centered splitter grip. The gap must also be strictly beyond the ring's outer edge.
8. Find the sidebar group stroke by its app-default gray color and a long vertical pixel run, not an invented UIA node. Derive the first row from that observed header top. Find the real CMD icon's contrasting pixels against the sampled active-row background in its icon area, require visible glyph height/area, save their bounding box and require at least four scaled pixels between it and the rail. A clipped icon cannot pass merely because the rail overwrote its leftmost pixels.
9. Every assertion prints `pane-layout <step> PASS`; any missing precondition or failed assertion throws. Inspect pane-layout.png, pane-layout-pixels.json, pane-layout-rects.json, action/before/after images, UIA/focus snapshots, result.json and owned-job cleanup. Measurements are read-only and persisted separately from app data.

## Gotchas

- The screenshot is the real console/browser surface, never the Chat View transcript. Console ownership is checked by the original main-window root plus the app-published shell ID, not by conhost sharing the app PID.
- Pixel expectations deliberately select Dark through user input and use the fresh default sidebar width. They must fail on unexpected themes, hidden/collapsed sidebars or missing icons rather than relaxing assertions.
- UIA does not expose custom sidebar rows or focus-ring nodes; HWND geometry and screenshot pixels provide those proofs. The icon probe covers the initial real CMD icon, while static compiled geometry also exercises status-icon rectangles with and without a favicon.
- Straight-side continuity excludes the rounded corners; compiled geometry checks the full slot. Live 125/150 percent, other icon artwork, full-width/reconnect interaction and browser-focused ring switching remain compiled-harness coverage, not claims of this one screenshot journey.
- A green job still requires human inspection of screenshots at the exact revision. No journey has been executed merely because this feature map exists.
