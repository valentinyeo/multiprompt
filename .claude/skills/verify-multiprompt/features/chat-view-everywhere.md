# Chat View everywhere

## Sub-features

- On Everywhere and Off Everywhere switch every session once, including pinned sessions.
- Alt+C remains independent on each tab, pinned or unpinned, after either bulk action.
- Per-session Always view commands and Lock Session have no palette rows.
- Session view preferences survive restart; old lock keys are ignored by the native load regression.

## How to get to it (user POV)

- Ctrl+K, New CMD Shell, Enter creates a local tab. Create three sessions after choosing Tab Order: Manual.
- Ctrl+K, Pin to Top, Enter pins the selected session; the tab context palette offers the same action.
- Alt+C switches the selected tab between Chat View and shell.
- Ctrl+K, Chat View on everywhere or Chat View off everywhere, Enter switches all tabs once.
- Ctrl+K, Unpin from Top, Enter removes protection before closing a tab or its workspace.

## Driving it with control.ps1

- Dispatch verify.yml with feature=chat-view-everywhere, or use the existing PR matrix entry. No new workflow journey stem is needed.
- Launch the isolated offline CMD instance. Persist the initial session through UI Size: Reset, then choose Tab Order: Manual before creating two more CMD sessions. Require the app-written launch snapshot to save sort_auto=false.
- Pin session 3 through Ctrl+K, target 6293. Require its saved pinned_top=true, all three views shell, and no saved locked or chat_view_lock keys. Capture pin-action.png and pinned-shell.png.
- Press Ctrl+W and capture pinned-close-refused.png. Inspect the unpin-first notice and normal close cross with no pin marker. Alt+C must then open and close session 3's Chat View while all three saved tabs remain present.
- Run On Everywhere, target 6346. Require cv=true on all three sessions and the selected native transcript visible.
- With session 3 pinned first in the displayed list, Ctrl+2 selects saved session 1. Toggle it to shell with Alt+C. Ctrl+3 selects session 2, which stays in Chat View; Ctrl+2 returns to session 1, which stays shell.
- Run Off Everywhere, target 6347. Require all three sessions shell. Ctrl+1 selects pinned session 3, which also follows the bulk action.
- Unpin session 3 before normal app close. Restart the same owned executable/profile, visit all three restored tabs with Ctrl+1/2/3, and require their shell preferences to persist. Retain restart-process-tree.json and per-session snapshots.
- Query chat view per tab, lock session, always chat view for this session, always shell view for this session, and clear always view for this session. For each, first query a known existing bulk command as a positive control, then require the app's bounded palette-ready trace to report zero rows for the full removed query. Retain each absent-query screenshot.
- Every view checkpoint independently reads app-written session JSON and counts visible ZigShellChatTranscript controls. Doctor runs before input. The normal finally block retains screenshots, actions, app data and zero-process cleanup evidence.

## Gotchas

- Ctrl+digits follows displayed sidebar order. Pinning session 3 moves it ahead of sessions 1 and 2 even with manual ordering; unpinning restores creation order.
- Normal close refuses while a pin exists, so the journey explicitly unpins before its restart. Native session write/load tests cover pinned persistence separately.
- The native suite covers each refused destructive action and a frozen pre-change session-format fixture. The desktop recipe directly exercises Ctrl+W and view toggles, not remote tmux archive/end operations.
- Do not seed or edit session JSON, send private app messages, or treat screenshots alone as proof of saved state.
- No live agent, SSH, account synchronization or remote workspace creation is claimed.
- This is a runnable recipe, not a successful run claim. Require GitHub Windows results and inspect screenshots before reporting desktop verification.
