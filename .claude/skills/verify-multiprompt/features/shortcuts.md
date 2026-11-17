# Keyboard shortcuts

Reach the same session, workspace, chat, browser, and window actions without the mouse.

Journeys: chat-focus, workspace-focus

## Sub-features
- `reference` opens the keyboard shortcut list.
- `selection` routes session and workspace chords to the expected target.
- `surface-focus` restores chat, shell, browser, or window input.

## How to get to it (user POV)
- Open Ctrl+K Keyboard Shortcuts; use Ctrl+Tab, Ctrl+1…9, Alt+1…9, Alt+Left/Right, Ctrl+Shift+B, Ctrl+Shift+F, Alt+C, Alt+Q, Alt+M, or Win+Arrows on the appropriate surface.

## Driving it with drive.ps1
Preconditions: fresh hosted Windows desktop, matching executable/hash/version, isolated app data, and the selected legacy recipe’s prerequisites.
- Migration pending for this feature. Run `gh workflow run verify.yml --ref <branch> -f feature=workspace-focus`. [Workspace focus](workspace-focus.md) and [chat focus](chat-focus.md) pair actual key chords with native draft/shell reads.
- Require the expected selected workspace/session and exact typed text after each chord, plus action/result screenshots. Only the selected journey is covered. Download `verify-workspace-focus` after cleanup. This legacy workflow route does not yet use the video driver; see [inventory](../inventory.md).

## Gotchas
- Browser focus can consume navigation keys. These two journeys do not prove every SHORTCUT_ROWS entry or the shortcuts overlay itself; record those as unexercised.
