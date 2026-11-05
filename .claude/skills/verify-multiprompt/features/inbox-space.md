# Inbox bottom space

## Sub-features

- Existing rows use all space above the existing footer.
- The screenshot-height Inbox fits sixteen complete rows without changing row styling.
- Keyboard selection, inline rename and native clicking agree on the added bottom row.

## How to get to it (user POV)

Open All Inbox with Alt+I in a full-height desktop window.
Move down through the existing sessions and click the bottom row to open it.
No new action or UI element is introduced.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=inbox-space`.
Use `-f tag=v0.28.1504` for the checksum-verified original-layout control.

The hosted Windows journey uses the existing display helper and sets the owned app client to the screenshot's1920x1032 at96DPI/default UI scale. Select AMOLED through the real Themes palette. Create eighteen real CMD tabs through the existing New CMD palette action; no saved tabs, Inbox rows or settings are seeded. Open All Inbox, select the first row and capture `before.png`. Move down fifteen rows and capture `action.png`. The sixteenth row must paint its existing selected fill in the formerly empty band, ending at998 above the footer at1002. Record native geometry and independent selected-pixel count in `inbox-space-pixels.json`.

Read the selected row's actual name through its owned F2 rename edit using bounded native EditText. Give that test session the unique name `Inbox bottom row` through real typing and Enter, then read its app-written stable shell ID. Click the newly visible bottom row using real mouse input. Require Inbox to close and the app-written selected tab name and stable shell ID to match that exact row. A name match alone is insufficient because initial CMD titles can be identical. Keep rename and resulting workspace screenshots, action trace, saved sessions, executable identity and zero-process cleanup evidence. The original release must fail specifically `IGSH1688_UNUSED_INBOX_SPACE` after creating and painting the long list, not during setup.

## Gotchas

- The row must remain wholly above the existing footer; this ticket does not remove the separately requested shortcut legend.
- Painting, click hit-testing and rename positioning must use the same layout.
- Geometry checks also cover search, small windows and UI scaling. The screenshot journey itself deliberately fixes96DPI/default UI scale for a direct before/after comparison.
- This verifies local CMD sessions and the native Inbox, not account sync or remote agents.
