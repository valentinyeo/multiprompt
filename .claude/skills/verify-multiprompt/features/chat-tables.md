# Chat tables

## Sub-features

Real console Unicode tables become formatted Chat View grids. Returning to an unchanged table tab retains its layout without rebuilding it.

A wide table opens full size through Ctrl+K `Chat View: Expand table`: a centered card over the dimmed window, closed with Esc, which returns focus to the app window.

## How to get to it (user POV)

Print a table in a local CMD session, open Chat View with Alt+C, create another CMD through Ctrl+K, then return with Ctrl+Shift+Tab. Then size the window to 1920x1032, print a wide four-column table in the same CMD, return to Chat View, run Ctrl+K `Chat View: Expand table`, and press Esc.

## Driving it with control.ps1

On the isolated GitHub Windows desktop, type a PowerShell command into the real CMD tab to print a two-column Unicode box table, then execute a completion-marker command. Open Chat View, require the app's box-table layout trace and saved per-tab Chat View setting, and capture the grid. Create another CMD through the palette, capture the away state, and return through the previous-tab shortcut. Require the original active tab and Chat View setting, a content paint, and an unchanged table-build count. For the expanded table, require the app's four-column box-table trace, the `CHAT_TABLE_EXPAND open` trace with a view at least as wide as the content or wider than Chat View, an app-owned `MultiPromptTableOverlay` foreground window, then `CHAT_TABLE_EXPAND closed` and the app window back in the foreground after Esc. Inspect before/action/away/after/wide-in-chat/expanded/collapsed screenshots and the real console marker, session state, action trace and debug log.

## Gotchas

This journey uses real console output, not a seeded transcript, fake agent or table setter. It covers console box tables and tab retention, not remote agents, file-backed markdown history, horizontal dragging, or font/DPI changes; Zig regressions cover metric and layout invalidation. The console command uses character codes so genuine keyboard input works with the runner's keyboard layout.
