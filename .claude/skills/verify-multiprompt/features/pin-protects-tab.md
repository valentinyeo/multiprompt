# Pin protects a tab

## Sub-features

- Pin to Top is the only session close-protection action; Lock Session is removed.
- A pinned tab refuses its close cross, Ctrl+W, archive, end session, group close, workspace close and close-all with one unpin-first notice.
- Group, workspace and close-all preflights refuse before removing any member.
- Pinned rows have no pin or lock marker and retain the normal close cross when selected.
- Normal and everywhere Chat View toggles work on pinned tabs.
- Pre-change saved session/workspace files load with locked and chat_view_lock ignored, while pinned_top remains effective.

## How to get to it (user POV)

- Ctrl+K, Pin to Top, Enter, or right-click a tab and choose Pin to Top.
- Click the normal close cross or press Ctrl+W: unpin first rather than removing the tab.
- Archive Session and End Session are available for remote tabs. Local tabs offer Close Session.
- Right-click a group and choose Close all tabs in group; close a workspace through its palette action; Quit multiprompt is also searchable as close all.
- Choose Unpin from Top from Ctrl+K or the tab context palette before removing the tab.

## Driving it with control.ps1

- This map shares the existing feature=chat-view-everywhere journey; do not dispatch pin-protects-tab as a separate workflow stem.
- Follow [Chat View everywhere](chat-view-everywhere.md). Pin a real local CMD tab, press Ctrl+W, inspect pinned-close-refused.png for the notice and ordinary cross, then require saved tab count and identity to remain while Alt+C changes its saved/visible view.
- On Everywhere and Off Everywhere must include that pinned session. Each removed lock/view command must yield zero palette rows with a known positive query control.
- The branch journey runs test-main on GitHub Windows. Native tests invoke the production close, Ctrl+W handler, archive, Inbox archive, end, group, workspace and close-all paths with pinned state, require no tab mutation and the exact unpin-first notice.
- The frozen session-pre-IGSH-820.json fixture contains both obsolete lock keys, pinned and unpinned tabs, and view values conflicting with the old lock. Native load coverage requires the saved views rather than the ignored locks and checks pinned_top preservation.
- Native session write/read coverage additionally requires pins and independent views to survive without re-emitting either obsolete key.

## Gotchas

- The desktop journey directly covers local Ctrl+W and view changes. Native tests supplement the other refused paths; they are not live remote archive/end verification.
- The fixture is a frozen representative pre-change session-format file, not state injected into the desktop journey.
- The notice and marker-free row need screenshot review. Source assertions alone do not prove pixels.
- Unpin before the journey's normal close/restart. Forced job cleanup owns only the isolated runner app and descendants.
- No GitHub run is claimed here until the committed revision's Windows tests and screenshots have been reviewed.
