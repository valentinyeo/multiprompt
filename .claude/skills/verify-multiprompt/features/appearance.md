# Appearance

Confirm the main window starts maximized, then choose a global color theme through the command palette and confirm both the visible desktop and saved preference change.

## Sub-features

- `startup-maximized`: the first main window is maximized without the driver maximizing it.
- `themes-open`: open the Themes submenu through Ctrl+K.
- `themes-dark`: select explicit Dark as a known user-created baseline.
- `themes-light`: select explicit Light and confirm brighter chrome and the saved global preference.

## How to get to it (user POV)

- Press Ctrl+K, type `themes`, press Enter on `Themes...`.
- Ctrl+Shift+K is the palette alternative when a browser surface owns Ctrl+K; this baseline uses Ctrl+K from the main app.
- Inside Themes, type a theme name and use Up/Down and Enter. Esc returns to the workspace.
- There is no dedicated direct theme shortcut or native menu selector.

## Driving it with control.ps1

Preconditions:

- Baseline Doctor passes and the initial CMD tab is usable on the isolated hosted desktop.
- No existing preference is seeded; the baseline is selected through the UI, even if the initial theme already looks dark.

- **Dispatch.** Run `gh workflow run verify.yml -f feature=appearance`; watch and download as described in the index. This invokes `control.ps1 -Feature appearance` on Windows.
- **Maximized startup.** Before restoring or moving the window for theme screenshots, Doctor verifies the owned process and `ZigShell` HWND. `IsZoomed` must be true immediately, with no maximize command or retry. `startup-maximized.json`, `startup-maximized.png` and the `startup-maximized` result check record the observation. This appearance journey runs on every code PR; `--single-window --no-window-restore` still uses maximized startup.
- **Dark baseline.** The helper presses Ctrl+K, types `themes`, Enter, types `dark` and Enter, then Esc. The app saves `dark`. `before.png` shows the normal dark workspace, not just a palette.
- **Light selection.** Repeat Ctrl+K, `themes`, Enter, then type `light`. `action.png` shows Light selected before Enter. Enter changes the theme; `action-selected.png` shows Light marked current. Esc closes the overlay.
- **Result.** `after.png` shows the normal light workspace with the same app/version identity. The saved `data/roaming/ZigShell/theme-mode.txt` contains `light`.
- **Selected session.** In the normal workspace screenshots, the selected session row has a visible neutral gray background, not a blue tint. Unread dots and status icons retain their colors. The production-color regression in `tools/pane-spacing.test.js` also checks AMOLED, Dark, Edge Gray, Mid and Light.
- **Proof.** The helper reads that file, checks sidebar luminance increases by at least 60 on the 0–255 channel scale, and reports both readings in `result.json`. Inspect the screenshots as well; pixel brightness alone is not proof of the right UI.

## Gotchas

- The filtered `dark` and `light` lists also include `System`, but exact-name matches rank first. Enter selects explicit Dark or Light; confirm that selection in the action screenshot. Never accept `system` as the expected saved result.
- A theme selection keeps the Themes overlay open; Esc is necessary for comparable workspace screenshots.
- System follows Windows appearance and is not equivalent to a fixed Light preference.
- This journey proves live application and saved preference, not persistence across an app restart, every available theme, or a browser pane's theme.
- Dev Blue and theme-file editing are DEV-channel features, not required stable-channel entries.
