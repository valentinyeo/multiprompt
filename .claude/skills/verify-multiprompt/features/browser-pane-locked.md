# Browser pane locked

## Sub-features

- Fresh browser windows launch on Multiprompt's own monitor and keep normal scale after a relaunch, including mixed-DPI monitor setups.
- The docked native browser cannot be dragged out of its pane through its empty tab/title strip.
- Browser-focused Win+Up and a strip double-click cannot maximize it or change its dock rectangle.
- Docking removes maximize/minimize styles; an out-of-context WinEvent guard cancels native moves and restores the dock after unexpected geometry changes.

## How to get to it (user POV)

- Ctrl+K `open browser`, Enter opens the native browser pane without an extension.
- Try dragging the empty top strip, pressing Win+Up with the browser focused, or double-clicking the same strip. The browser stays inside its pane.
- No new command, setting or UI is required.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml -f feature=browser-pane-locked` against the proposed revision. The pull-request matrix includes this journey. To verify a published release, add `-f tag=v<major>.<minor>.<patch>`; require that exact tag and version in the journey log and build.json.

1. Use the fresh isolated GitHub Windows desktop and the same rendered Edge setup precondition as browser-pane-stuck: give the isolated Edge profile up to 60 seconds to render the owned setup page, then hide it. Do not switch browser engines through the palette. Immediately before Open-BrowserPane, stop the setup job tree if its active process count is nonzero; save browser-pane-locked-warmup-initial-stopped.json. Open-BrowserPane uses saved pane state and native ownership, not the setup process, so the initialized profile remains usable after the tree stops. Stopping the entire tree and waiting for zero active processes prevents Edge forwarding to the warmup PID, whose setup command line has no `--window-position=`. Pass Doctor and use the existing Open-BrowserPane helper. Require a connected, visible HWND carrying `ZigShellPaneOwner` for the verified main window. No extension or fake reply is allowed.
2. Immediately capture the first launch: enumerate chrome.exe or msedge.exe command lines with `--user-data-dir` pointing at either ZigShell/ChromeUserData or ZigShell/EdgeUserData under the isolated LOCALAPPDATA and containing `--window-position=`. Normalize both slash styles before matching the escaped profile root. Parse x,y and require each point inside the owner monitor's rcMonitor from MonitorFromWindow/GetMonitorInfoW. Require a nonempty set containing the owned pane's process, and GetDpiForWindow(pane) equal to the nonzero GetDpiForWindow(main). Save command lines, coordinates, monitor rectangle, owned HWNDs and both DPI values in browser-pane-locked-launch-initial.json. Close the owned app normally, wait up to ten seconds, stop its job, and again stop any still-active setup job tree before relaunch; save browser-pane-locked-warmup-restored-stopped.json if that tree needed stopping. Relaunch the same verified executable with the same saved scratch state. Without another open command, require the startup-restored visible pane and repeat the command-line/monitor/DPI proof in browser-pane-locked-launch-restored.json. Reject any launch PID reused from the first capture. Print `browser-pane-locked launch-on-own-monitor PASS` only after both captures and the relaunch assertions pass.
3. Record the HWND and its actual GetWindowRect in browser-pane-locked-dock.json, together with release tag/version. Focus the actual browser HWND and verify its ownership and native keyboard focus, not the main window's focus.
4. Choose a point eight pixels below the top edge and 160 pixels from the right edge. Require its UIA ancestry to reach the browser without a tab, button, edit, hyperlink or menu item. Save the point and ancestry; never substitute a tab-drag for an empty-strip window drag. Require the point's real HWND to belong to that focused browser before sending input.
5. Send real absolute SendInput mouse motion, left down, twenty motion steps totaling 300 pixels left and 200 pixels down, and left up in a finally block. After at least one second, wait at most five seconds for the same visible owned HWND to be unzoomed with all four GetWindowRect edges exactly equal to the recorded dock rectangle (tolerance zero). Print `browser-pane-locked drag-blocked PASS` only after those assertions.
6. Focus the browser again and send real Win+Up directly to that foreground HWND, without the main-window Press helper. Apply the same bounded exact-rectangle and IsZoomed-false assertions and print `browser-pane-locked win-up-blocked PASS`.
7. Focus the browser again, revalidate the same empty strip and send a real mouse double-click there. Apply the same bounded exact-rectangle and IsZoomed-false assertions. Print `browser-pane-locked maximize-blocked PASS`.
8. Inspect before/action/drag-blocked/after screenshots, UIA/focus snapshots, actions.json, the per-step browser-pane-locked JSON records, result.json, build.json and owned-job cleanup. The journey prints `browser-pane-locked verified release tag=... version=...` before opening the pane. Branch builds have an empty release tag and still log the version.

## Gotchas

- The rendered Edge setup remains unchanged for the other browser journeys, which keep their setup job until cleanup. This journey stops it only after rendering, outside setup, so both pane launches have persistent observable command lines rather than depending on catching short-lived forwarding processes.
- A launch at -32000,-32000 fails the monitor-point check even on a single-DPI runner, so release v0.28.821 cannot pass if either captured launch used that fallback. The GitHub desktop checks launch coordinates and window DPI; the real two-monitor devicePixelRatio regression still needs mixed-DPI laptop verification.
- Input is allowed only on the exact owned browser. Doctor, native foreground checks and window-under-point checks remain mandatory; existing journeys retain their foreground guards.
- A control under the proposed strip point fails the journey rather than silently exercising another surface. The initial single-tab, fresh profile supplies the empty strip; unexpected chrome must be investigated in the screenshots.
- The native-window guard posts WM_CANCELMODE and Escape key messages to the browser's own thread queue. Its cross-process move/size loop consumes them and cancels its capture/modal operation; releasing capture in the app's thread would not cancel the browser's capture.
- Win+Up can route SC_MAXIMIZE to the popup owner. The main frame rejects that command only while the docked browser has foreground focus; normal main-frame maximization remains available. Browser location-change events still restore a zoomed browser and snap it back through positionActiveBrowser.
- The pure Zig regressions also cover unexpected rect changes, zoom restoration, matching-rect idempotence, non-docked-window exclusion and locked styles. Static Node checks verify wiring, not Windows behavior.
- Win+Up exercises Aero Snap; the browser's own maximize button is protected by the styles/geometry guard but is not separately driven by this journey. No local build or desktop execution is required or permitted by this map. A green CI job still requires screenshot inspection at the exact revision.
