# All Sessions card

Source files: src/all_sessions*.zig, src/archive.zig, src/shortcuts.zig, .claude/skills/verify-multiprompt/control-feature-all-sessions.ps1, .claude/skills/verify-multiprompt/control-seed-all-sessions.ps1, tools/fixtures/SOFT-2445/*

## Sub-features

- Design A uses one card with bot pictures, known message previews, workspace, time and run state.
- Server buttons and counted state filters compose with the inbox-style tabs.
- Waiting-on-you rows precede Today and Earlier. Memory appears only from 400 MB.
- Arrows, Enter, Tab, Space, A, S and Ctrl+F retain list navigation and actions. Shift+A opens Archived.

## How to get to it (user POV)

Press Ctrl+K, search for Show all sessions and press Enter. Ctrl+F or clicking the top search box focuses search. Tab moves through All, Frequent, Favorites, Waiting, workspaces, Other and Archived.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=all-sessions` on hosted Windows. The driver seeds four explicitly synthetic archived sessions and their cached previews before app launch, using `tools/fixtures/SOFT-2445/archived-cards.json`. These fixture sessions never connect to a server. Doctor must pass on the owned app and its real CMD tab.

Open the card through Ctrl+K. Inspect `all-sessions-before.png` for the card, four archived rows, bot pictures, previews and Today/Earlier headings. Press S and require the app to save exactly Studio Guide as starred. Tab through Frequent and Favorites; inspect the empty Frequent view and the single starred favorite. Ctrl+F searches for Studio Guide. Escape clears search; Shift+A selects Archived. Inspect the saved screenshots and `result.json`; Escape returns without changing the real open-tab count. Doctor and owned-job cleanup must pass.

`tools/soft-2445-all-sessions.test.js` compiles the actual portable row model and extracted Waiting membership. Its frozen Zig fixtures prove waiting-first ordering, midnight boundaries, all three run states, disjoint counts, combined server/state/workspace filters, Favorites/Frequent, deduplication and high-memory visibility. The recorded pre-change hosted run fails the Waiting assertion.

## Gotchas

This journey proves the real native card and persistent star action using disclosed synthetic archive input. It does not prove remote transport, live host counts, attached-session archive or confirmed remote close. Those retain their existing service boundaries. Missing message history shows No message preview rather than invented text. Workspace snapshot reminders must be woken before individually archiving their sessions.
