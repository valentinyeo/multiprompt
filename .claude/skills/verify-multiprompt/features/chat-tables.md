# Chat tables

## Sub-features

Real console Unicode tables become formatted Chat View grids. Returning to an unchanged table tab retains its layout without rebuilding it.

## How to get to it (user POV)

Print a table in a local CMD session, open Chat View with Alt+C, create another CMD through Ctrl+K, then return with Ctrl+Shift+Tab.

## Driving it with control.ps1

On the isolated GitHub Windows desktop, type a PowerShell command into the real CMD tab to print a two-column Unicode box table, then execute a completion-marker command. Open Chat View, require the app's box-table layout trace and saved per-tab Chat View setting, and capture the grid. Create another CMD through the palette, capture the away state, and return through the previous-tab shortcut. Require the original active tab and Chat View setting, a content paint, and an unchanged table-build count. Inspect before/action/away/after screenshots and the real console marker, session state, action trace and debug log.

## Gotchas

This journey uses real console output, not a seeded transcript, fake agent or table setter. It covers console box tables and tab retention, not remote agents, file-backed markdown history, horizontal dragging, or font/DPI changes; Zig regressions cover metric and layout invalidation. The console command uses character codes so genuine keyboard input works with the runner's keyboard layout.
