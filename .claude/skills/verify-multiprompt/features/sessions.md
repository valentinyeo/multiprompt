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
- Right-click a tab opens its tab-actions palette for pin, move and other actions; these are not exercised by this create/rename journey.

## Driving it with control.ps1

Preconditions:

- Doctor passes with a live restored tab and a readable saved session.
- The isolated data directory contains no tab named `Verification session`.

- **Dispatch.** Run `gh workflow run verify.yml -f feature=sessions`. The Windows invocation selects `control.ps1 -Feature sessions`.
- **Repository picker.** Use a branch build with Zig available on the hosted runner. Before launch, seed two saved tmux tabs in Other, host 0 followed by host 2, with workspace 0 and the second tab active. Capture `seed-session.json`. Launch with restore enabled. The SSH-only stand-in returns 100 project folders: `alpha`, `beta`, 94 numbered code folders, an ancestor-only match `/work/soft-tools/factory/alpha`, `software-factory`, `notes-only` and `zz-last-folder`. It holds tmux transports open. This is not real SSH, tmux or an agent.
- **Ctrl+T.** Wait for the app-saved second tab to be active on host 2; capture `sessions-initial.json` without selecting another host. Wait for all 100 discovered folder rows, capture the picker, filter `notes-only`, press Enter, and require the saved active tab to have notes-only as its cwd, Chat View enabled and host 2. Inspect the picker screenshots: the discovery receipt alone does not prove the custom-painted rows appeared.
- **Partial names (IGSH-1680).** After notes-only, reopen Ctrl+T on host 2 for `soft` and then `factory soft`. The picker must put `software-factory` before the earlier-discovered ancestor-only match. Press Enter without moving selection; require `/work/projects/software-factory`, Chat View and host 2 in each saved session. Inspect `ctrl-t-soft-picker.png`, `ctrl-t-reversed-words-picker.png`, both chat screenshots, saved `ctrl-t-*-session.json` and named `result.json` checks. Single-word substring lookup already worked before this change; the regression is missing out-of-order tokens and basename-first ordering.
- **Cancel.** Close the chat, return to the seeded host 2 session through Ctrl+K search for `Second` and require host 2 active. Closing a tab may select a different server; close-selection behavior is not this journey's assertion. Choose `New Claude in terminal`, cancel the picker and close the palette; require host 2 remains active. Ctrl+T selects `zz-last-folder` and must save a chat tab with that late-alphabet cwd on host 2. Close it, select `Second` again through Ctrl+K, require host 2 active, choose `New Claude in terminal` again, select `beta`, and require beta cwd on host 2 with Chat View disabled. Missing `cv` means false in the saved format.
- **Scope.** [Windows red run](https://github.com/valentinyeo/multiprompt/actions/runs/41858934109) created the beta chat on host 0 instead of active host 2. The [production chooser red run](https://github.com/valentinyeo/multiprompt/actions/runs/41859393431) expected host 2 and found host 1. Neither reproduces the original disappeared-row text; neither uses real SSH or an agent. Require a passing run on the candidate revision.
- **Evidence.** Inspect the picker and resulting screenshots, saved session, per-process SSH invocations and `result.json`. A timeout before selection is a harness or setup failure, not proof of the product bug. The existing CMD journey runs afterward.
- **Other with a saved folder (IGSH-1527).** Return to `Second` through Ctrl+K, then use `Set workspace folder` to save `notes-only` for Other. Read the app-written commands file; never write it from the driver. Open Ctrl+T twice, choosing `beta` and then `zz-last-folder`. Each picker must appear despite the saved default, and each resulting chat must persist its chosen cwd and host 2. Capture both `other-saved-default-*-picker.png` and `other-saved-default-*-chat.png`, plus the corresponding session snapshots.
- **Named workspace default (IGSH-1527).** Ctrl+N creates a new non-Other workspace. Use its persisted name, or its normal `Workspace N` display name when unnamed. Through the palette, save `notes-only` as its folder. Capture `named-workspace-saved-default-before.png`; then press Ctrl+T without typing a query or pressing Enter. Require an additional saved Chat View tab in that same workspace and cwd. Capture `named-workspace-saved-default-chat.png` and `named-workspace-saved-default-session.json`. A picker instead of direct creation must fail this wait. Both cases use the existing SSH-only stand-in, not a real remote agent.
- **Create.** Ctrl+K, type `new cmd`, capture `action.png`, then Enter. The helper requires saved tab count to increase by exactly one.
- **Rename.** Press F2, Ctrl+A, type `Verification session`, Enter. The saved session must contain exactly one tab with that name.
- **Execute.** Type `echo verified-from-real-cmd>"<isolated scratch>/user-created.txt"` in the active console and press Enter. The helper substitutes its actual scratch path, records the literal typed command in `actions.json`, and requires that file's content to be `verified-from-real-cmd`.
- **Proof.** `after.png` must show the new named tab and real CMD console. `data/user-created.txt`, `data/roaming/ZigShell/session.json` and `result.json` independently confirm command execution, tab count and saved name. The file is not created by the harness.

## Gotchas

- **Known failing:** run [39871210688](https://github.com/valentinyeo/multiprompt/actions/runs/39871210688), v0.28.821: after F2 rename and Enter, foreground and native focus stay on the ZigShell main frame, not ConsoleWindowClass. The echo never reaches CMD; `real console command wrote file` fails. This focus-after-rename product gap is tracked as IGSH-597; keep the journey unchanged. See [coverage](../coverage.md) for the other failing releases and run history.

- The CMD shell is a real hosted console, not an emulated terminal or a mock agent.
- Rename must finish before typing a shell command; typing into the rename UI is not successful console execution.
- Remote tmux, SSH, PowerShell and Bash require their actual programs/configuration. They are not substitutes for or covered by this local CMD journey.
- Closing a tab is a user action with process side effects; the harness does not verify all close/reopen or pin-protection behaviors in this journey.
