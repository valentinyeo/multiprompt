# Settings and appearance

Change settings, theme, text size, and interface scale while keeping the current sessions usable.

Journeys: appearance, settings-panel
Release paths: src/settings*.zig, src/appearance*.zig, src/themes.zig, src/font*.zig, src/window*.zig, src/main.zig, build.zig

## Sub-features
- `settings` opens and dismisses the settings panel.
- `theme` changes the global color preference and visible sidebar.
- `size` changes active text size separately from interface scale.

## How to get to it (user POV)
- Ctrl+, opens Settings; Ctrl+K Settings opens the same panel; Ctrl+K Themes selects a theme; Ctrl++/Ctrl+-/Ctrl+0 changes active text size; Ctrl+K search `interface` changes interface scale.

## Driving it with drive.ps1
Preconditions: fresh hosted Windows desktop, matching executable/hash/version, isolated app data, and the selected legacy recipe’s prerequisites.
- Run `drive.ps1 settings-appearance appearance -Exe $exe -ExpectedVersion $version -ExpectedHash $hash -Evidence "$pwd/evidence/settings-appearance-appearance"` after workflow acquisition. [Appearance](appearance.md) selects Dark then Light through Ctrl+K Themes; [settings panel](settings-panel.md) covers panel entry and dismissal.
- Require before/action/after screenshots, at least 60 extra sidebar luminance, theme-mode.txt equal to light, and successful owned cleanup. Inspect `journey.mp4` and `journey.json` after cleanup. Only the selected journey is covered.

The recipes distinguish existing focused journeys from unreachable complete paths. UNREACHABLE names the missing data, endpoint, build mode or driver action; it never means the product passed.

### look: Theme, size and window layout

Open Settings through Ctrl+, and Ctrl+K; change one preference, cancel another and reopen. Pick each theme in Themes, change font and UI size separately, toggle full-width, sidebar and workspace-switcher visibility, then restore defaults. Exercise app window controls and owned-window snap/move routes.

Observable proof: Screenshots show the selected theme and geometry. Saved theme/scale agree; font-only changes leave sidebar scale unchanged. Closing Settings restores draft focus. No pane overlaps, duplicate caption buttons or inaccessible hidden sidebar remain.

Journey: appearance, settings-panel, command-palette, pane-layout, window-controls, title-bar. UNREACHABLE for multi-monitor movement until the hosted desktop exposes a second monitor; default hosted geometry cannot prove that shortcut.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_FONT_BIGGER_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_FONT_RESET_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_FONT_SMALLER_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_FULLWIDTH_OFFSET` | Ctrl+K, type **full-width**, then select the matching action with Up/Down and Enter. Follow `look` above. |
| `SEARCH_HIDEPILLS_OFFSET` | Ctrl+K, type **workspace switcher**, then select the matching action with Up/Down and Enter. Follow `look` above. |
| `SEARCH_HIDESIDEBAR_OFFSET` | Ctrl+K, type **sidebar**, then select the matching action with Up/Down and Enter. Follow `look` above. |
| `SEARCH_SETTINGS_OFFSET` | Ctrl+K, type **settings**, then select the matching action with Up/Down and Enter. Follow `look` above. |
| `SEARCH_SIDEBAR_COLLAPSE_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_SIDEBAR_HIDE_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_SOUND_OFFSET` | Ctrl+K, search for **notification sounds**. Follow `look` above. |
| `SEARCH_THEME_AMOLED_OFFSET` | Ctrl+K, search for **amoled**. Follow `look` above. |
| `SEARCH_THEME_BACK_OFFSET` | Open the named submenu, then choose **Back from Themes**. Follow `look` above. |
| `SEARCH_THEME_DARK_OFFSET` | Ctrl+K, search for **dark**. Follow `look` above. |
| `SEARCH_THEME_DEV_BLUE_OFFSET` | Ctrl+K, search for **dev blue**. Follow `look` above. |
| `SEARCH_THEME_EDGE_GRAY_OFFSET` | Ctrl+K, search for **edge grey**. Follow `look` above. |
| `SEARCH_THEME_LIGHT_OFFSET` | Ctrl+K, search for **light**. Follow `look` above. |
| `SEARCH_THEME_DEV_EDIT_OFFSET` | Ctrl+K, search for **edit dev theme json** to open the developer theme file. Follow `look` above. |
| `SEARCH_THEME_DEV_RELOAD_OFFSET` | Ctrl+K, search for **reload dev theme** after editing that file. Follow `look` above. |
| `SEARCH_THEME_MENU_OFFSET` | Ctrl+K, search for **themes**. Follow `look` above. |
| `SEARCH_THEME_MID_OFFSET` | Ctrl+K, search for **mid**. Follow `look` above. |
| `SEARCH_THEME_MULTIPROMPT_OFFSET` | Ctrl+K, search for **multi bot**. Follow `look` above. |
| `SEARCH_THEME_SYSTEM_OFFSET` | Ctrl+K, search for **system**. Follow `look` above. |
| `SEARCH_UI_BIGGER_OFFSET` | Ctrl+K, type **ui**, then select the matching action with Up/Down and Enter. Follow `look` above. |
| `SEARCH_UI_RESET_OFFSET` | Ctrl+K, type **ui**, then select the matching action with Up/Down and Enter. Follow `look` above. |
| `SEARCH_UI_SMALLER_OFFSET` | Ctrl+K, type **ui**, then select the matching action with Up/Down and Enter. Follow `look` above. |

### usage: Usage, ETA and power

Cycle the collapsed cards, hover the footprint card, cycle Power Saver and Token Ladder policy, open the ladder dashboard, and toggle ETA numbers/progress separately on a reporting agent. Change usage login only in a disposable telemetry profile.

Observable proof: Card pages and hover content stay legible. Saved policy changes match the selected cycle; footprint covers app descendants, while ETA/countdown accuracy uses the reporting session's actual start/finish events. Keep account usage distinct from native process telemetry.

Journey: status-card covers card geometry, not live totals. UNREACHABLE for usage/ETA/sign-in until authenticated disposable telemetry profiles, an agent emitting ETA start/finish events and native policy/dashboard assertions are available. Power policy must not be claimed from a screenshot alone.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_AI_USAGE_OFFSET` | Ctrl+K, type **usage and servers**, then select the matching action with Up/Down and Enter. Follow `usage` above. |
| `SEARCH_ETA_ACCURACY_OFFSET` | Ctrl+K, search for **estimate accuracy**. Follow `usage` above. |
| `SEARCH_ETA_NUMBERS_OFFSET` | Ctrl+K, search for **eta countdown numbers**. Follow `usage` above. |
| `SEARCH_ETA_PROGRESS_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_LADDER_AUTO_OFFSET` | Ctrl+K, type **token ladder**, then select the matching action with Up/Down and Enter. Follow `usage` above. |
| `SEARCH_LADDER_CLAUDE_OFFSET` | No distinct palette row. Cycle **Token Ladder: Auto** to this value; use the recipe above. |
| `SEARCH_LADDER_CODEX_OFFSET` | No distinct palette row. Cycle **Token Ladder: Auto** to this value; use the recipe above. |
| `SEARCH_LADDER_DASH_OFFSET` | Ctrl+K, type **token ladder**, then select the matching action with Up/Down and Enter. Follow `usage` above. |
| `SEARCH_MOBILE_OFFSET` | Ctrl+K, type **mobile**, then select the matching action with Up/Down and Enter. Follow `usage` above. |
| `SEARCH_POWER_ALWAYS_OFFSET` | No distinct palette row. Cycle **Power Saver** to this value; use the recipe above. |
| `SEARCH_POWER_AUTO_OFFSET` | Ctrl+K, type **power saver**, then select the matching action with Up/Down and Enter. Follow `usage` above. |
| `SEARCH_POWER_OFF_OFFSET` | No distinct palette row. Cycle **Power Saver** to this value; use the recipe above. |

## Gotchas
- Theme selection leaves its submenu open until Escape. Appearance proves saved preference, not persistence across relaunch or every Settings control.
