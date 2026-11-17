# Command palette

Find actions and recent sessions, navigate submenus, and dismiss without accidentally changing the workspace.

Journeys: command-palette

## Sub-features
- `search` opens actions and recent sessions, then narrows by typed query.
- `navigate` opens submenus and accepts or cancels the chosen action.
- `tab-actions` targets right-click actions at the selected session while retaining explicitly named bulk actions.

## How to get to it (user POV)
- Ctrl+K opens actions and recent sessions; Ctrl+Shift+K works from browser surfaces; type a query, Up/Down selects, Enter accepts, Escape cancels; right-click tabs opens tab actions.

## Driving it with drive.ps1
Preconditions: fresh hosted Windows desktop, matching executable/hash/version, isolated app data, and the selected legacy recipe’s prerequisites.
- Run `drive.ps1 palette command-palette -Exe $exe -ExpectedVersion $version -ExpectedHash $hash -Evidence "$pwd/evidence/palette-command-palette"` after workflow acquisition. [Command palette](command-palette.md) defines the existing search, UI Size increase/reset, snippet confirmation, and idle-update journey.
- Require action screenshots, ui_scale 110 then 100 or its omitted default field in saved state, retained snippet state after restart, and no unintended tab-count change on cancel. Inspect `journey.mp4` and `journey.json` after cleanup. Only the selected journey is covered.

The recipes distinguish existing focused journeys from unreachable complete paths. UNREACHABLE names the missing data, endpoint, build mode or driver action; it never means the product passed.

### palette: Find and execute actions

Open Ctrl+K with no text; check recent sessions and grouped actions. Type a documented row label, use Up/Down and Enter, reopen and Escape to cancel. Repeat with pasted query text and Ctrl+Shift+K from the owned browser. Open submenu Back rows and verify return without execution.

Observable proof: Selected production row ID and visible label match. UI Size increase/reset saves 110 then 100; cancel leaves tab count and draft unchanged. Headers cannot be executed, and Most used does not displace the recent-session band.

Journey: command-palette, palette-order. UNREACHABLE for every conditional submenu row until its table row's named prerequisite is present; searching for an unavailable label must not be treated as successful execution.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_TABCTX_BACK` | Open the named submenu, then choose **Back**. Follow `palette` above. |

## Gotchas
- Some legacy checks seed workspace folders and snippets. Those are disclosed fixtures, not proof of creating them through the UI.
