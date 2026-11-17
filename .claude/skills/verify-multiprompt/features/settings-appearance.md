# Settings and appearance

Change settings, theme, text size, and interface scale while keeping the current sessions usable.

Journeys: appearance, settings-panel

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

## Gotchas
- Theme selection leaves its submenu open until Escape. Appearance proves saved preference, not persistence across relaunch or every Settings control.
