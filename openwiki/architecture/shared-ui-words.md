# Shared UI words

## Contract

`src/ui_words.zon` is the only authored list.
It is a flat record.
Each stable ID uses lowercase snake_case.
Each value is an exact UTF-8 string.
Desktop imports the record directly.

`shared/ui_words.json` distributes the derived flat JSON.
Never edit that JSON independently.
This snapshot was manually transcribed.
The exporter was not run for it.
It is **UNVERIFIED** until CI Boss compares bytes.
CI Boss must run the exporter first.
Do not treat this snapshot as verified publication.

`src/export_ui_words.zig` writes JSON to stdout.
It preserves source field order.
Zig's JSON serializer handles string escaping.
Output uses two-space indentation and a final LF.
Use Zig 0.16.0 on an authorized host.
Run this from the repository root:

```sh
zig run src/export_ui_words.zig > shared/ui_words.json
```

Do not run this on the shared VPS.
CI Boss owns hosted drift checks.
CI Boss also owns missing-word checks and workflows.
CI Boss owns their execution.
For hosted readback, use a separate temporary file.
Compare its bytes with the committed JSON.
Accept the snapshot only after that comparison.

Desktop examples:

```zig
const words = @import("ui_words.zon");
const label = L(words.settings_theme);
paintText(hdc, words.settings_theme, rect, 0, color, 0);
```

These examples use existing APIs.
`L` converts UTF-8 at compile time.
It returns zero-terminated UTF-16 for Win32.
Painted text continues to use UTF-8.
The app does not parse JSON for labels.
It does not allocate for labels at runtime.

Android's paired work must pin verified JSON.
Pin it to a desktop commit or release.
Android then consumes the JSON independently.
UI code needs no runtime network fetch.
UI code needs no JSON parsing.
Android has not adopted the list yet.

Add IDs instead of renaming published IDs.
Do not delete IDs already published to clients.
Coordinate value changes with consumers.
Preserve old pinned versions.
IDs represent UI roles, not source positions.
Reuse IDs only for matching roles and text.
Text must match exactly.
Add distinct IDs for different casing or punctuation.
Also separate ellipses, spacing, emoji and wording variants.
Preserve Win32 `&` accelerators and shortcut hints exactly.
Provide separate plain and native-menu variants when needed.
Do not strip markers or change appearance.
Some plain labels also name debug events.
Reaction labels keep the existing React wording.
Their menu captions use Like, Dislike, or Heart.
Choose keys by role, not suffix.
Palette keys hold the full visible caption.
Clipping depends on the available screen width.
Some palette captions bypass sentence-case drawing.
Those keys preserve their exact displayed case.
Some context keys are text fragments.
They precede dynamic group or workspace names.
Their trailing spaces are significant.
Android must treat them as fragments.

Native class names are not word-list labels.
Examples include `BUTTON` and `EDIT`.
Control and routing IDs are not labels.
Protocol strings are not labels.
User-provided names and dynamic values are not labels.

## Coverage ledger

The list covers Settings and selected menus.
It also covers selected palette captions.
It does not cover the whole application.

| Surface | Current status |
| --- | --- |
| Settings `src/settings_panel.zig` controls and key dialog | Catalogued. Includes Cancel, Save, title and save error. |
| Settings painted captions and font sizes | Catalogued. |
| Settings theme names and theme popup | Catalogued. Version and workspace names remain dynamic. Graphical indicators remain presentation. |
| Edit and message menus `src/fonts.zig` | Catalogued. Native and plain variants keep separate IDs. |
| Main palette navigation and settings `src/sidebar.zig` | Selected captions catalogued. Other palette actions remain. |
| Tab, group and move palette contexts | Selected captions and fragments catalogued. |
| Group color names `src/app_state.zig` | Not migrated. Eight names remain separate. |
| Other sidebar menus and palette contexts | Not migrated. Keep sentence-case drawing and shortcut hints. |
| Usage menu `src/telemetry_panel.zig` | Inventory incomplete. Classify dynamic values and static labels. |
| `src/inbox.zig`, `src/archive.zig`, `src/workspaces.zig`, `src/browser_pane.zig` | Inventory incomplete. Inspect every button and menu. Include conditional states. |
| `src/account_desktop.zig`, `src/update_card.zig`, `src/reminders.zig` | Inventory incomplete. Inspect every button and menu. Include conditional states. |
| Other desktop screens, dialogs, tooltips and accessibility | Not inventoried. Include conditional states. Discover owners and record exclusions. |
| Protected reader/host/provider/session/send/confirmation and `src/chat_composer.zig` | Not edited. Coordinate label migration with the protected owner. |
| Android buttons, menus, dialogs and accessibility | Not inventoried or migrated here. Android's owner must establish complete coverage. |

The same feature owner should continue.
Migrate remaining palette and sidebar captions next.
Then inventory remaining desktop screens in bounded batches.
Commit each component separately.
Keep draft changes local during release repairs.
Push only after the build recovers.
Verify published changes before calling them complete.

Missing-label checks must catch literal bypasses.
They must also catch missing IDs.
Lookup-only checks cannot prove whole-app coverage.
CI Boss owns those checks.
Both clients need hosted checks before completion.
Both clients also need native UI evidence.
