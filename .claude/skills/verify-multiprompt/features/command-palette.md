# Command palette

Covers: palette:SEARCH_UI_BIGGER_OFFSET, palette:SEARCH_UI_RESET_OFFSET
Source files: src/command_palette.zig, src/shortcuts.zig, src/main.zig, build.zig, build.zig.zon, .claude/skills/verify-multiprompt/control-feature-command-palette.ps1

Find real actions in Ctrl+K, execute an app-size change and reset it while checking the saved setting.

## Sub-features

- `changelog-speed`: a cold Ctrl+K Changelog open finishes below 200 milliseconds, and Page Down, Escape and the response after close finish below 100 milliseconds, across five samples; screen pixels must change and the UI thread must respond. Full history stays available.
- `local-shells`: Ctrl+K `powershell` selects the local PowerShell row, command 2005. Command Prompt, Bash and Git Bash use the same search list.
- `palette-search`: filter commands using an actual supported query.
- `pick-repo-list`: Ctrl+N leaves the catch-all workspace, Ctrl+T opens the saved folder, then Ctrl+K `pick repo` opens Back plus that one harness folder, and Esc returns with the tab count unchanged.
- `palette-execute`: execute UI Size: Increase and save 110% app scale.
- `update-command-idle`: search Restart to update and execute with no staged update, retaining the owned app and session.
- `palette-reset`: navigate to UI Size: Reset and restore 100%.
- `palette-keyboard-priority`: with the pointer parked over a row, Up and Down still move the selection and Enter runs the keyboard's row; a real move of three pixels or more hands the selection to the pointer, and a click selects the row under the pointer (IGSH-836).

- `manage-snippets`: prepare two saved snippets, cancel named deletion with Esc, delete only the selected snippet, then restart and verify the retained entry in Use Snippets (IGSH-1065).

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
- **Changelog speed.** Before app-size changes, run five Ctrl+K `changelog` selections. Time native Enter, Page Down and Escape through changed text pixels plus a UI-thread response, without forced repaint. Save all samples and before/after response times in `changelog-speed.json`; capture `changelog-open.png`, `changelog-scrolled.png` and `changelog-closed.png`. Cold opening is included. The cold open must stay below 200 milliseconds. Scroll, close and the response after close must stay below 100 milliseconds. Run 43664894874 measured cold opens of 125.4 ms and 125.8 ms on the pull request head and the merge base. 200 ms is 1.6 times the slower cold open, leaving about 74 ms spare. The other samples in those runs stayed at or below 46.9 ms.
- **Local shells.** After the empty palette, press Ctrl+K and type `powershell`. The selected command must be 2005, the local PowerShell row. Capture `more-shells-search.png`. The merge-base build does not list that row, so this wait is the before-and-after for the shell restoration. Esc closes the palette before the later steps.
- **Pick repo.** Before the app-size steps, record the saved tab count, press Ctrl+K, type `pick repo`, capture `pick-repo-row.png`, press Enter, capture `pick-repo-list.png` (the list opens with `Back` and any repo rows), press Esc to leave the list and again to close the palette, and require the saved tab count to be unchanged. `pick-repo-back.png` shows the palette back in its main state.
- **Search.** Press Ctrl+K and type `interface`. `action.png` shows the filtered UI Size rows with Increase selected.
- **Execute.** Press Enter for `UI Size: Increase`. The palette closes and the app's saved `ui_scale` must be 110. Capture `after.png` showing larger chrome.
- **Reset.** Reopen Ctrl+K and type `interface`; Down twice reaches `UI Size: Reset`, then Enter. Capture `reset.png`. The saved scale must be default 100 (the default may be omitted from the file).
- **Update entry.** Search `restart to update`, capture `update-command.png`, reject a blank selected row by checking its screenshot text pixels, then Enter with no staged update. Doctor must still identify the original live PID, executable hash, HWND and initial shell; capture `update-idle.png`. The updater switch is OFF in this isolated harness to prevent a release from replacing the branch being verified. This proves the palette entry and no-ready behavior, not the ready notice or an actual release install; Windows update regression tests separately exercise download validation and rollback.
- **Proof.** Compare `before.png`, `action.png`, `after.png` and `reset.png`. `actions.json` records both selections; `result.json` records the checked 110 and 100 values. The final `data/roaming/ZigShell/session.json` confirms the reset state.

- **Manage Snippets.** The same command-palette dispatch seeds Remove Me and Keep Me in the existing version-one storage format, captures `manage-snippets-command.png` and `snippet-delete-confirmation.png`, checks Escape leaves the file byte-identical, confirms deletion with Delete then Enter, and verifies only Keep Me survives a restart. `snippet-deleted.png` and `snippet-kept-after-restart.png` show the existing picker.

## Gotchas

The current driver resolves source action IDs instead of relying on a literal interface query and fixed Down count. It also opens a repo after the cancellation check, reads its saved cwd/selection and archives the created tabs. The plain-terminal Move chat exclusion is a separate negative assertion.


- UI Size affects app chrome, not console font zoom. Ctrl+Plus is a different feature and is not a valid substitute.
- Use `interface`, not a guessed full display label: these size commands accept a fixed set of search keywords and then show Increase, Decrease and Reset in that order.
- Enter executes and closes these actions; unlike Themes, no Esc is needed afterward.
- Browser-focused Ctrl+K goes to the page; Ctrl+Shift+K is the app's explicit alternative and needs its own browser prerequisite to verify.
- This journey does not prove every palette command, recent-session ordering, the shortcuts overlay or tab-context targeting.
