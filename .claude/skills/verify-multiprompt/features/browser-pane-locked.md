# Browser pane locked

## Sub-features

- The docked native browser cannot be dragged out of its pane through its empty tab/title strip.
- Browser-focused Win+Up and a strip double-click cannot maximize it or change its dock rectangle.
- Docking removes maximize/minimize styles; an out-of-context WinEvent guard cancels native moves and restores the dock after unexpected geometry changes.

## How to get to it (user POV)

- Ctrl+K `open browser`, Enter opens the native browser pane without an extension.
- Try dragging the empty top strip, pressing Win+Up with the browser focused, or double-clicking the same strip. The browser stays inside its pane.
- No new command, setting or UI is required.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml -f feature=browser-pane-locked` against the proposed revision. The pull-request matrix includes this journey. To verify a published release, add `-f tag=v<major>.<minor>.<patch>`; require that exact tag and version in the journey log and build.json.

1. Use the fresh isolated GitHub Windows desktop and the same rendered Edge setup precondition as browser-pane-stuck. Pass Doctor and use the existing Open-BrowserPane helper. Require a connected, visible HWND carrying `ZigShellPaneOwner` for the verified main window. No extension or settings fixtures are installed.
2. Record the HWND and its actual GetWindowRect in browser-pane-locked-dock.json, together with release tag/version. Focus the actual browser HWND and verify its ownership and native keyboard focus, not the main window's focus.
3. Choose a point eight pixels below the top edge and 160 pixels from the right edge. Require its UIA ancestry to reach the browser without a tab, button, edit, hyperlink or menu item. Save the point and ancestry; never substitute a tab-drag for an empty-strip window drag. Require the point's real HWND to belong to that focused browser before sending input.
4. Send real absolute SendInput mouse motion, left down, twenty motion steps totaling 300 pixels left and 200 pixels down, and left up in a finally block. After at least one second, wait at most five seconds for the same visible owned HWND to be unzoomed with all four GetWindowRect edges exactly equal to the recorded dock rectangle (tolerance zero). Print `browser-pane-locked drag-blocked PASS` only after those assertions.
5. Focus the browser again and send real Win+Up directly to that foreground HWND, without the main-window Press helper. Apply the same bounded exact-rectangle and IsZoomed-false assertions and print `browser-pane-locked win-up-blocked PASS`.
6. Focus the browser again, revalidate the same empty strip and send a real mouse double-click there. Apply the same bounded exact-rectangle and IsZoomed-false assertions. Print `browser-pane-locked maximize-blocked PASS`.
7. Inspect before/action/drag-blocked/after screenshots, UIA/focus snapshots, actions.json, the per-step browser-pane-locked JSON records, result.json, build.json and owned-job cleanup. The journey prints `browser-pane-locked verified release tag=... version=...` before opening the pane. Branch builds have an empty release tag and still log the version.

## Gotchas

- Input is allowed only on the exact owned browser. Doctor, native foreground checks and window-under-point checks remain mandatory; existing journeys retain their foreground guards.
- A control under the proposed strip point fails the journey rather than silently exercising another surface. The initial single-tab, fresh profile supplies the empty strip; unexpected chrome must be investigated in the screenshots.
- The native-window guard posts WM_CANCELMODE and Escape key messages to the browser's own thread queue. Its cross-process move/size loop consumes them and cancels its capture/modal operation; releasing capture in the app's thread would not cancel the browser's capture.
- Win+Up can route SC_MAXIMIZE to the popup owner. The main frame rejects that command only while the docked browser has foreground focus; normal main-frame maximization remains available. Browser location-change events still restore a zoomed browser and snap it back through positionActiveBrowser.
- The pure Zig regressions also cover unexpected rect changes, zoom restoration, matching-rect idempotence, non-docked-window exclusion and locked styles. Static Node checks verify wiring, not Windows behavior.
- Win+Up exercises Aero Snap; the browser's own maximize button is protected by the styles/geometry guard but is not separately driven by this journey. No local build or desktop execution is required or permitted by this map. A green CI job still requires screenshot inspection at the exact revision.
