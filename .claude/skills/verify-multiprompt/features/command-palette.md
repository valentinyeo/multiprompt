# Command palette

Find real actions in Ctrl+K, execute an app-size change and reset it while checking the saved setting.

## Sub-features

- `palette-search`: filter commands using an actual supported query.
- `palette-execute`: execute UI Size: Increase and save 110% app scale.
- `update-command-idle`: search Restart to update and execute with no staged update, retaining the owned app and session.
- `palette-reset`: navigate to UI Size: Reset and restore 100%.
- `palette-keyboard-priority`: with the pointer parked over a row, Up and Down still move the selection and Enter runs the keyboard's row; a real move of three pixels or more hands the selection to the pointer, and a click selects the row under the pointer (IGSH-836).

- `manage-snippets`: create two snippets, cancel named deletion with Esc, delete only the selected snippet, then restart and verify the retained entry in Use Snippets (IGSH-1065).

## How to get to it (user POV)

- Press Ctrl+K from the workspace, console or Chat View to open the palette. It initially offers recent sessions.
- Ctrl+Shift+K opens it even when a browser surface owns Ctrl+K. This baseline uses the ordinary Ctrl+K path.
- Type a query, use Up/Down and Enter to choose an action; Esc cancels.
- F1 opens the keyboard-shortcuts overview; Ctrl+K `Keyboard Shortcuts` is its palette alternative. These overview paths are not part of the app-size journey.
- Right-clicking a tab opens a context-specific band of palette actions rather than the global starting view.

## Driving it with control.ps1

Preconditions:

- Baseline Doctor passes with default 100% app scale and a usable initial CMD tab.
- The palette has not inherited a submenu or query from another journey; every dispatch uses fresh data.

- **Dispatch.** Run `gh workflow run verify.yml -f feature=command-palette`; Windows runs `control.ps1 -Feature command-palette`.
- **Search.** Press Ctrl+K and type `interface`. `action.png` shows the filtered UI Size rows with Increase selected.
- **Execute.** Press Enter for `UI Size: Increase`. The palette closes and the app's saved `ui_scale` must be 110. Capture `after.png` showing larger chrome.
- **Reset.** Reopen Ctrl+K and type `interface`; Down twice reaches `UI Size: Reset`, then Enter. Capture `reset.png`. The saved scale must be default 100 (the default may be omitted from the file).
- **Update entry.** Search `restart to update`, capture `update-command.png`, reject a blank selected row by checking its screenshot text pixels, then Enter with no staged update. Doctor must still identify the original live PID, executable hash, HWND and initial shell; capture `update-idle.png`. The updater switch is OFF in this isolated harness to prevent a release from replacing the branch being verified. This proves the palette entry and no-ready behavior, not the ready notice or an actual release install; Windows update regression tests separately exercise download validation and rollback.
- **Proof.** Compare `before.png`, `action.png`, `after.png` and `reset.png`. `actions.json` records both selections; `result.json` records the checked 110 and 100 values. The final `data/roaming/ZigShell/session.json` confirms the reset state.

- **Manage Snippets.** The same command-palette dispatch creates Remove Me and Keep Me through Create Snippet, captures `manage-snippets-command.png` and `snippet-delete-confirmation.png`, checks Escape leaves the file byte-identical, confirms deletion with Delete then Enter, and verifies only Keep Me survives a restart. `snippet-deleted.png` and `snippet-kept-after-restart.png` show the existing picker.

## Gotchas

- UI Size affects app chrome, not console font zoom. Ctrl+Plus is a different feature and is not a valid substitute.
- Use `interface`, not a guessed full display label: these size commands accept a fixed set of search keywords and then show Increase, Decrease and Reset in that order.
- Enter executes and closes these actions; unlike Themes, no Esc is needed afterward.
- Browser-focused Ctrl+K goes to the page; Ctrl+Shift+K is the app's explicit alternative and needs its own browser prerequisite to verify.
- This journey does not prove every palette command, recent-session ordering, the shortcuts overlay or tab-context targeting.
