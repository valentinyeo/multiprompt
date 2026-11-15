# Harness matrix

Every live chat and every shell CLI for Claude, Codex, Pi, and Cursor, on both servers, plus the shell tab behaving like a normal terminal. The cell list, the journeys, and the report all come from [tools/harness-matrix.json](../../../../tools/harness-matrix.json). Do not copy that list into this file.

## Sub-features

- `live_chat`: Ctrl+K starts that harness chat, a reply contains pong, the model picker lists that harness's models, a non-default model is the one that answers, and Pi and Cursor also list skills.
- `shell_cli`: Ctrl+K opens a shell tab on that server, the tab's cols and rows match the window, and the harness version command prints a version line.
- `fit_on_resize`: resizing the window changes the shell grid with the window.
- `font_change_changes_grid`: Ctrl+Plus changes the shell grid while the window size stays put.
- `keystroke_echo_ms`: forty typed characters echo with p95 at or under 50 ms, and the run records the number.

## How to get to it (user POV)

- Press Ctrl+K and choose New Claude session, New Codex chat, New Pi chat, or New Cursor chat.
- Press Ctrl+K and choose Open shell on VPS 1 or Open shell on VPS 2.
- Press Ctrl+K and choose New terminal when the workspace already has a folder.
- Press Ctrl+Plus on a shell tab to change the console font. Resize the window from its edges.

## Driving it with control.ps1

Preconditions:

- Doctor passes on a fresh GitHub Windows desktop.
- `HARNESS_SSH_EXE` is the runner's local ssh stand-in. It answers `ssh -V` and, for a `python3` channel, runs `tools/harness-matrix/host.py`.
- The saved session keeps one local Command Prompt so Doctor sees a shell, and it turns on shared server connection. An empty tab list restores as a valid session and the desktop never becomes ready. Ctrl+K does not list that switch. Open shell on VPS is then the native terminal whose cols and rows follow the window. The stand-in does not provide a console window for the older ssh login command.
- The stand-in maps the app's remote-1 argument to vps1 and remote-2 to vps2.

Dispatch the matrix on demand, or let a pull request that touches chat, terminal, or palette files run it:

```sh
gh workflow run harness-matrix.yml --ref <branch>
gh workflow run harness-matrix.yml --ref <branch> -f part=shell -f app_revision=<sha>
gh run list --workflow harness-matrix.yml --limit 5 --json databaseId,headSha,url,conclusion
gh run watch <id> --interval 300
```

`part=shell` runs only the three shell-quality rows. `part=cells` runs the sixteen harness rows. An empty part runs both. The Windows helper is `control.ps1 -Feature harness-matrix`.

- **Journeys.** `node tools/harness-matrix.js journeys <part>` prints the rows for that part. The driver performs each row from that output. It does not keep a second list.
- **Live chat.** Ctrl+K, type the row's chat label, Enter, and require the ssh stand-in log for that host to gain a channel. Type `reply with the word pong`, Enter, and require the reply to contain pong. Ctrl+K, type `Chat View: Model`, and require the palette row trace to include that harness's model ids. Pick the row's non-default model, send again, and require the host log or the chat header to name it. For Pi and Cursor, Ctrl+K, type `skills`, and require a skill-row id.
- **Shell CLI.** Ctrl+K, type the row's Open shell label, Enter, require a logged size other than 80x24 that fits the terminal window, type the version command, Enter, and require a version line in the host log.
- **Shell quality.** The saved session already has shared server connection on. Ctrl+K, Open shell on VPS 1. That is the native terminal grid. Resize the main window and require cols to change in proportion to the terminal width. Press Ctrl+Plus and require the grid to change while the width stays. Type 40 letters and digits one at a time and record the p95 of the pixel-change times. Fail when p95 is above 50 ms.
- **Report.** `node tools/harness-matrix.js report <results.json>` writes one markdown grid. The job uploads that file and the screenshots and appends the grid to the job summary.
- **Proof.** The shell-quality rows must fail on the commit before the plain-shell fix and pass on master. Download the screenshots and the grid. A red shell job is the before proof. A green shell job is the master proof.

## Gotchas

- The runner stand-in skips the real servers, their network, accounts, and home directories, a Unix pty and bash login on those servers, the harness CLIs and their credentials, and the live model catalogs and skill lists from those CLIs.
- A live chat cell fails unless that chat starts the terminal channel for the same host. New Claude session, New Codex chat, New Pi chat, and New Cursor chat use the current workspace host, so the other host stays failed until the chat can be aimed at it.
- Claude model rows exist as labels and are not inserted into the palette. Codex model rows appear only after a live Codex chat reports settings. Pi and Cursor have no model rows. Those live-chat cells stay failed until the picker lists the models and the reply names the picked one.
- Pi and Cursor skill lists stay failed while the palette has no skill-row ids.
- A shell CLI stays failed while the stand-in host has no real version output for that command. Do not print a stand-in version to make the cell pass.
- A shell-quality row that fails on master stays failed. Do not raise the 50 ms budget and do not accept 80x24.
- New terminal on a GitHub runner opens the folder picker when the workspace has no folder. The shell-quality rows use Open shell on VPS 1 with the saved shared server connection, so the tab is the native grid. Without that switch, the app starts a login console, and the stand-in has no Unix login to keep that console open. Ctrl+K has no row for the switch. Searching for it fails, and the app test forbids inserting the row.
