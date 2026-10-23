# Sessions

Open a real local console tab, give it a recognizable name and execute a command in that console.

## Sub-features

- `session-create`: add one local CMD session without replacing the initial tab.
- `session-rename`: rename the active tab and confirm the saved name.
- `session-command`: type and execute a command that creates a file, proving the console is usable.

## How to get to it (user POV)

- Press Ctrl+K, type `new cmd`, and choose `New CMD Shell`.
- The CMD spawn button and Ctrl+Shift+1 also open CMD; this journey covers the palette entry only.
- Press F2 or double-click the active tab to rename it. This journey uses F2.
- Type in the console and press Enter to execute. Ctrl+Tab / Ctrl+Shift+Tab cycle sessions; Ctrl+1 through Ctrl+9 select one; Ctrl+W closes the active session.
- Right-click a tab opens its tab-actions palette for pin, lock, move and other actions; these are not exercised by this create/rename journey.

## Driving it with control.ps1

Preconditions:

- Baseline Doctor passes with a live CMD tab and a readable saved session.
- The isolated data directory contains no tab named `Verification session`.

- **Dispatch.** Run `gh workflow run verify.yml -f feature=sessions`. The Windows invocation selects `control.ps1 -Feature sessions`.
- **Create.** Ctrl+K, type `new cmd`, capture `action.png`, then Enter. The helper requires saved tab count to increase by exactly one.
- **Rename.** Press F2, Ctrl+A, type `Verification session`, Enter. The saved session must contain exactly one tab with that name.
- **Execute.** Type `echo verified-from-real-cmd>"<isolated scratch>/user-created.txt"` in the active console and press Enter. The helper substitutes its actual scratch path, records the literal typed command in `actions.json`, and requires that file's content to be `verified-from-real-cmd`.
- **Proof.** `after.png` must show the new named tab and real CMD console. `data/user-created.txt`, `data/roaming/ZigShell/session.json` and `result.json` independently confirm command execution, tab count and saved name. The file is not created by the harness.

## Gotchas

- **Known failing:** run [39871210688](https://github.com/valentinyeo/multiprompt/actions/runs/39871210688), v0.28.821: after F2 rename and Enter, foreground and native focus stay on the ZigShell main frame, not ConsoleWindowClass. The echo never reaches CMD; `real console command wrote file` fails. This focus-after-rename product gap is tracked as IGSH-597; keep the journey unchanged. See [coverage](../coverage.md) for the other failing releases and run history.

- The CMD shell is a real hosted console, not an emulated terminal or a mock agent.
- Rename must finish before typing a shell command; typing into the rename UI is not successful console execution.
- Remote tmux, SSH, PowerShell and Bash require their actual programs/configuration. They are not substitutes for or covered by this local CMD journey.
- Closing a tab is a user action with process side effects; the harness does not verify all close/reopen or pin/lock behaviors in this journey.
