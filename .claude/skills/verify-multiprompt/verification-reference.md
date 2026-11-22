# Verify-multiprompt reference

Agent-facing detail that used to live in `SKILL.md`. Read the feature map first; use this when dispatching, judging PRs, or citing evidence.

## Agent CLI (`mbv.mjs`)

```sh
node tools/mbv.mjs run appearance --ref <branch>   dispatch; prints run id and URL
node tools/mbv.mjs watch <run-id>                  per-job results, one poll a minute
node tools/mbv.mjs proof <run-id>                  result.json, cleanup, evidence present
node tools/mbv.mjs doctor <run-id> --feature f     app identity from doctor.json
node tools/mbv.mjs failures <run-id>               failed jobs and the decisive line
node tools/mbv.mjs list                            every journey stem
```

## Launch

### Dispatch

```sh
gh workflow run verify.yml -f feature=<name>
gh workflow run verify.yml --ref <branch> -f feature=appearance
gh workflow run verify.yml -f feature=appearance -f tag=v0.28.821
gh run list --workflow verify.yml --event workflow_dispatch --limit 5 --json databaseId,headSha,displayTitle,url
timeout 1800 gh run watch <id> --interval 300
gh run download <id>
```

If GitHub refuses a branch workflow, open or update the branch PR. Two things answer a pull request: the path-filtered `pull_request` trigger of `verify.yml`, which runs only the maps that declare `Verify on: pull_request` (`appearance`, `chat-still`, `server-chat`), and `pr-verifier.yml`, which picks journeys from each map's `Source files:` against the changed files and runs them on the head. Identify that event and head SHA with `gh run list`, then watch and download the PR run, and never substitute a default-branch run for the proposed change.

`tag` must be `v<major>.<minor>.<patch>`. The workflow downloads the x64 release and SHA256SUMS, verifies checksum and embedded version, and records the tag. Empty `tag` builds the branch. Tag verification checks the release artifact, not branch app code.

### Journey stems (`verify.yml -f feature=`)

`appearance`, `browser-corners`, `sessions`, `session-restore`, `workspaces`, `workspace-focus`, `inbox`, `command-palette`, `session-open`, `session-tabs`, `favorites-groups`, `server-open-group`, `browser-switch-speed`, `chat-switch-speed`, `browser-pane-stuck`, `browser-pane-locked`, `group-rail`, `pane-layout`, `title-bar`, `window-controls`, `chat-tables`, `chat-code-font`, `safe-updates`, `chat-view`, `chat-view-everywhere`, `chat-focus`, `chat-dictation`, `status-card`, `palette-order`, `remind-me`, `tab-names`, `browser-emulation`, `browser-own-profile`, `chat-first-paint`, `chat-send-latency`, `app-icon`, `relaunch-saved-sessions`, `chat-delivery`, `chat-messages-only`, `chat-still`, and others named in [features/README.md](features/README.md). Reconnect stems use `verify-reconnect.yml`, not this matrix.

### Environment and isolation

`ZIGSHELL_DEBUG=1` enables app logs. `MULTIPROMPT_NO_LOGIN=1` is documented offline mode (explicit stand-in for account sign-in and sync). Isolated profiles and disabled workspace restoration prevent shared-session driving.

The `sessions` journey replaces only SSH with a repository transport stand-in; see [sessions](features/sessions.md). `session-open` exercises agent TCP and persistence, not successful SSH attach.

## PR verification

Pull requests get an independent verdict from `.github/workflows/pr-verifier.yml` on GitHub-hosted runners:

```sh
gh workflow run pr-verifier.yml --ref master -f pr=<number>
gh run list --workflow pr-verifier.yml --limit 5 --json databaseId,headSha,url
```

Changed files match `Source files:` ownership in feature maps. A changed map selects its own journey; a wide map-maintenance pull request therefore drives up to eight capped desktop journeys from edited `features/*.md` files, independent of whether `Source files:` breadth changed on that stem. Shared core (`src/main.zig`, `src/command_palette.zig` when listed on more than five maps) selects no journey alone; bare `src/` changes run `appearance` as smoke. Tool paths select only owning journeys. Cap and drop rules live in `tools/pr-verifier.cjs` and `tools/touched-journeys.test.js`.

When `pstack-verifier` blocks on Tests while every selected head journey passed, read the PR head's `test.yml` run: `test-vps (1)` and the aggregate `test` job sometimes fail on unrelated flakes (for example `run chat echo CPU budgets` or a duplicate `bot-photo` matrix job) and are not caused by map-only edits. Same-named jobs must fail on master's latest completed `test.yml` for `wait-for-tests` to treat the failure as inherited.

`verify.yml` on PRs runs the selected set on head only. Journeys already red on the latest master nightly are inherited (named, non-blocking). Formal non-desktop checks with `CI workflow:` use the same ownership rules and require a successful exact-head PR run plus artifact `summary.json`.

Every PR body needs `Author model: <family>/<model>` from a family the verifier can contrast. Green Tests alone is not a verdict; `pstack-verifier` is required.

Outages: revert the bad change before repair, then ship the fix through normal PR verification. There is no automatic-revert workflow at this revision: `tools/auto-revert-master.js` and its test still exist, but `.github/workflows/auto-revert-master.yml` does not, so the revert is manual.

## SSH reconnect workflow

```sh
gh workflow run verify-reconnect.yml --ref <branch> -f exe_source=build
gh workflow run verify-reconnect.yml --ref <branch> -f exe_source=v0.28.788
gh run list --workflow verify-reconnect.yml --branch <branch> --event workflow_dispatch --limit 5 --json databaseId,headSha,url
timeout 1800 gh run watch <id> --interval 300
gh run download <id>
```

```powershell
./tools/verify-reconnect/drive.ps1 -Exe "$PWD/bin/multiprompt.exe" -Ssh "$PWD/bin/ssh.exe" -Output "$PWD/evidence"
```

Unlike `control.ps1` journeys, this harness seeds saved tmux tabs and replaces only the SSH boundary via production `ssh-path.txt`. Artifacts `verify-reconnect-<exe_source>` retain case logs, Doctor, screenshots, and cleanup. `tools/verify-reconnect/check-evidence.js` can recompute measurements when run with artifact dirs and `run.json` metadata.

## Server chat (Part B)

`control.ps1 -Feature server-chat` on Windows installs WSL1 Ubuntu, OpenSSH and tmux; OpenSSH is locked to the runner SID. See [server-chat.md](features/server-chat.md) for receipts, `/clear` transport proof, and provider-boundary limits.

## Control layout

- `control.ps1`: options, setup, dispatch, cleanup.
- `control-feature-<name>.ps1`: per-feature bodies.
- `control-library.ps1`: shared PowerShell helpers.
- Source readers use `readControlSource` from `tools/app-source.js`.
- Same-directory dot sourcing preserves scope.

## Evidence

```sh
gh run download <id> -n verify-appearance -D /tmp/verify-multiprompt-<id>
```

Inspect PNGs, `result.json`, and feature-specific files under `data/`. Record run URL, feature/sub-features, revision, and what changed. Report unexercised entry points explicitly.

Stand-ins (offline login, reconnect SSH, chat delivery remote shell, safe-update fixtures, browser emulation synthetic page) are named in each feature's Gotchas; they do not prove live agents or accounts.

## Reusable `drive.ps1` entry

`./.claude/skills/verify-multiprompt/drive.ps1 settings-appearance appearance -Exe $exe -ExpectedVersion $version -ExpectedHash $hash -Evidence "$pwd/evidence/settings-appearance-appearance"` records desktop video via FFmpeg. Palette equivalent: `drive.ps1 palette command-palette` with the same arguments. Dispatch `gh workflow run verify.yml -f feature=appearance` or `command-palette` to use the new driver automatically.