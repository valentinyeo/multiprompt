# Test laptop release check

Every Multiprompt release is installed and checked on the second Windows laptop (`lh --machine laptop2`, the Z16) by one routine, and the result is posted on the tickets that shipped in that release. No hand work and no help from Valentin.

## What runs

`tools/laptop-check/run.mjs` runs on the VPS from a user timer every ten minutes:

1. Read the latest release tag from `valentinyeo/multiprompt`.
2. Skip the run when that tag already passed, or already failed twice. Polling costs two GitHub calls.
3. Skip the run when `lh machines` does not list the laptop as connected. Nothing queues up while the laptop sleeps.
4. Copy `check.ps1` to the laptop and run it there under Windows PowerShell.
5. Read the single JSON result, save it under `~/.local/state/multiprompt-laptop-check/`, and post one comment per ticket named in the commits between this release and the previous one.

## What the laptop proves

`check.ps1` starts the installed app when needed and waits for a staged update to apply, so a release installs on the laptop by itself through the app's own signed updater. It then reports these checks:

| Check | Proves |
| --- | --- |
| `install` | The executable carries `MPVERSION=<release>` |
| `start` | A process runs, its window class is `ZigShell`, the title names the version |
| `chats` | The newest `inbox-*.json` publishes at least one tab |
| `computer-view` | `zigshell-bridge status` answers with `"ok":true` |
| `sync` | A signed-in account has no layout pending for more than fifteen minutes |
| `memory` | The working set stays under 3000 MB |
| `crashes` | No `crash-*.txt` since the app started |

The verdict is PASS only when every check is present and true. A missing check is a failure, not a pass.

## Install and stop

Requirements on the machine that runs the routine: `lh` with `local-helper` answering on `127.0.0.1:8766`, `gh` authenticated, `node`, and a board identity for the account that posts comments.

```sh
tools/laptop-check/setup.sh
systemctl --user list-timers multiprompt-laptop-check.timer
systemctl --user start multiprompt-laptop-check.service
journalctl --user -u multiprompt-laptop-check.service -n 40
```

`setup.sh` keeps its own shallow clone in `~/projects/multiprompt-laptop-check` and rewrites the timer units in `~/.config/systemd/user`. It never touches a working checkout.

Stop the routine with `systemctl --user disable --now multiprompt-laptop-check.timer`.

## Run it by hand

```sh
node tools/laptop-check/run.mjs --host laptop2 --no-post
node tools/laptop-check/run.mjs --host laptop2 --tag v0.28.1626 --no-post
node --test tools/laptop-check/run.test.js
```

`--no-post` prints the result without writing to the board. The raw machine result for a tag stays in `~/.local/state/multiprompt-laptop-check/result-<tag>.json`; delete that file, or the matching `state.json` entry, to force a new attempt.

The laptop needs `multiprompt.exe`, `zigshell-bridge.exe` and the extension installed under `%USERPROFILE%\Documents\GitHub\zigshell`, which `tools/install-laptop1.sh` already produces.
