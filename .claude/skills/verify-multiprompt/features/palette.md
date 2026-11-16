# Command palette

Find actions and recent sessions, navigate submenus, and dismiss without accidentally changing the workspace.

Journeys: command-palette

## Sub-features
- `search` opens actions and recent sessions, then narrows by typed query.
- `navigate` opens submenus and accepts or cancels the chosen action.
- `tab-actions` limits right-click actions to the selected session.

## How to get to it (user POV)
- Ctrl+K opens actions and recent sessions; Ctrl+Shift+K works from browser surfaces; type a query, Up/Down selects, Enter accepts, Escape cancels; right-click tabs opens tab actions.

## Driving it with drive.ps1
Preconditions: fresh hosted Windows desktop, matching executable/hash/version, isolated app data, and the selected legacy recipe’s prerequisites.
- Run `drive.ps1 palette command-palette -Exe $exe -ExpectedVersion $version -ExpectedHash $hash -Evidence "$pwd/evidence/palette-command-palette"` after workflow acquisition. [Command palette](command-palette.md) defines the existing search, UI Size increase/reset, snippet confirmation, and idle-update journey.
- Require action screenshots, ui_scale 110 then 100 in saved state, retained snippet state after restart, and no unintended tab-count change on cancel. Inspect `journey.mp4` and `journey.json` after cleanup. Only the selected journey is covered.

## Gotchas
- Some legacy checks seed workspace folders and snippets. Those are disclosed fixtures, not proof of creating them through the UI.
