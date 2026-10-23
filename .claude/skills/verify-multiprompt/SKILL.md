---
name: verify-multiprompt
description: Verify Multiprompt's real Windows desktop UI on GitHub Windows runners with keyboard journeys, read-only Doctor, screenshots and persisted side effects; use after desktop changes or when reproducing a user journey.
---

# Verify Multiprompt

Multiprompt is a native Windows desktop app hosting real console windows, with custom-drawn sidebar, Inbox and Ctrl+K overlays. It is not a browser page or an Electron app. The account Worker and browser extension are secondary surfaces. The `browser-emulation` map is a separate real-Chrome extension journey driven by `browser-emulation.mjs` through this workflow; it does not launch or verify the embedded app pane.

Read [features/README.md](features/README.md), then the selected feature file before running anything. Never build, launch or drive locally, through Wine, on a VPS, or on a user's laptop. All execution below happens on GitHub's free `windows-latest` machines in the public repository.

Diagnostic verification maps live separately in `diagnostics/`: [Chat sync audit](diagnostics/chat-sync-audit.md) uses the dedicated GitHub Linux job, not the Windows desktop driver.

## Launch

From an authenticated checkout, submit the default branch's workflow and select a feature-map file stem:

```sh
gh workflow run verify.yml -f feature=<name>
gh run list --workflow verify.yml --event workflow_dispatch --limit 5 --json databaseId,headSha,displayTitle,url
gh run watch <id> --interval 60
gh run download <id>
```

Use `appearance` for the first journey. Other names are `sessions`, `session-restore`, `workspaces`, `workspace-focus`, `inbox`, `command-palette`, `session-open`, `favorites-groups`, `browser-pane-stuck`, `browser-pane-locked`, `group-rail`, and `pane-layout`. The `session-open` journey exercises the real agent TCP request and background persistence, not successful SSH/tmux attachment. Verify the listed run's head SHA and title before watching or downloading. To verify a development branch:

```sh
gh workflow run verify.yml --ref ceo/IGSH-525 -f feature=appearance
```

If GitHub refuses because the workflow is not on the default branch yet, open or update the branch's PR. Its path-filtered `pull_request` trigger runs `appearance`, `session-restore`, `workspace-focus`, `favorites-groups`, `browser-pane-stuck`, `browser-pane-locked`, `group-rail`, and `pane-layout` against the PR merge revision; identify that event and head SHA with `gh run list`, then use the same watch and download commands. Never substitute a default-branch run for the proposed change.

To exercise a published executable instead of compiling the branch:

```sh
gh workflow run verify.yml -f feature=appearance -f tag=v0.28.789
```

The tag must be `v<major>.<minor>.<patch>`. The workflow downloads the real x64 release executable and its published SHA256SUMS, verifies the checksum and embedded version, and records the tag. This verifies that release, not the branch's app code. Leave `tag` empty for branch verification. The branch path installs checksum-pinned Zig 0.16.0 and runs the repository's `zig build` on Windows, like release/test workflows. No tests or builds run on the caller's machine.

The `session-restore` journey uses `--single-window` with restoration enabled and retains its private data between launches in the same job. Other Windows journeys start exactly that executable with `--single-window --no-window-restore`, a unique empty directory under RUNNER_TEMP, and private APPDATA, LOCALAPPDATA, USERPROFILE and HOME. It creates no session fixtures or settings. A ready instance has its own visible `ZigShell` main window, the expected version, and a published initial CMD session. Startup is bounded to 60 seconds; missing readiness fails, rather than driving a login screen or an unrelated window.

`IGSH_246=0` keeps the selected branch/release executable fixed during verification; update download and rollback behavior is tested separately on GitHub Windows.

`MULTIPROMPT_NO_LOGIN=1` is the documented development/offline mode. This is an explicit stand-in for account sign-in and layout sync, not proof those work. No account credentials are supplied. `ZIGSHELL_DEBUG=1` enables real app logs. Isolated app data and disabled workspace restoration prevent shared-session driving; the fresh hosted desktop also isolates machine-wide resources. Do not run multiple harnesses on one desktop.

## Doctor

`control.ps1` runs `Doctor` after launch, before each input, and after the journey. Doctor is read-only and cheap: the original Process object must be alive, its path and SHA256 must match the selected executable, its HWND must belong to that PID and class `ZigShell`, its title must contain the expected version, UI Automation must see that window, and its published Inbox state must contain a usable initial shell. It writes only evidence (`doctor.json`), never app state; it does not build, seed, authenticate, invoke actions or repair preconditions.

When something looks off, read the artifact's `doctor.json`, `result.json`, and `data/roaming/ZigShell/debug.log`. Rerun the workflow to obtain a new isolated instance; do not reuse or repair the failed one. Build identity and provenance live in `build.json`.

## Drive

The executable helper is [control.ps1](control.ps1). Its exact workflow-side invocation, using values resolved and checked by the workflow, is:

```powershell
& .claude/skills/verify-multiprompt/control.ps1 -Feature $env:FEATURE -Exe "$pwd/verify-bin/multiprompt.exe" -ExpectedVersion $env:VERIFY_VERSION -ExpectedHash $env:VERIFY_SHA256 -Evidence "$pwd/evidence"
```

Invoke it only through `verify.yml`; it refuses non-GitHub/non-Windows execution. This single command performs Launch, Doctor, the selected feature recipe, Evidence and Cleanup. No helper requires a separate interpreter investigation or an undocumented server.

The harness uses .NET System.Windows.Automation for window identity and accessibility snapshots, and Win32 SendInput for genuine keyboard input. Text uses keyboard-layout-mapped virtual keys, not Unicode packets (the palette hook consumes those). Custom-painted palette rows are not UIA buttons: do not invent accessibility selectors or send private WM_APP messages. Selection uses actual Ctrl+K search terms and arrow/Enter navigation from the feature maps. Native HWND ownership, not screen coordinates, determines where input goes. The foreground root must be our window before every input. Window-relative pixels are used only for screenshots and read-only theme luminance checks, never clicking.

The `pane-layout` journey keeps the real CMD console visible, groups it through Move to Group, docks a browser, maximizes through Win+Up and checks `pane-layout.png` against owned HWND/UIA rectangles. See [pane layout](features/pane-layout.md) for pixel detection and evidence limits.

The `browser-pane-locked` journey uses real mouse dragging, browser-focused Win+Up and a strip double-click, requiring the exact dock rectangle and no maximization. It logs the verified release tag/version. See [browser pane locked](features/browser-pane-locked.md).

The `browser-pane-stuck` journey reads the app-published `browser_state`, `browser_connection_id` and `browser_window_id` fields in `inbox-default.json`; it never writes them or publishes pane URLs. A docked pane does not need an extension window ID. Run `node tools/check-browser-pane-stuck.mjs` for its static map/workflow/driver contract check (no app execution).

Bounded condition waits inspect actual saved state and window titles. A missing precondition fails the journey with an error and retained evidence. Never change the expected outcome, write settings yourself, add a test-only setter, or skip the failing action to make a run green. Fix a broken driver only when the real user path is unchanged.

### SSH reconnect and ended sessions

The separate [verify-reconnect.yml](../../../.github/workflows/verify-reconnect.yml) workflow drives the same real Windows app with the helpers in [tools/verify-reconnect/](../../../tools/verify-reconnect/). It never runs on the Linux server. Read [SSH tab reconnect](features/ssh-tab-reconnect.md), [ended remote session](features/ended-remote-session.md), and [saved remote workspace](features/saved-remote-workspace.md) before dispatching:

```sh
gh workflow run verify-reconnect.yml --ref ceo/IGSH-511 -f exe_source=build
gh workflow run verify-reconnect.yml --ref ceo/IGSH-511 -f exe_source=v0.28.788
gh run list --workflow verify-reconnect.yml --branch ceo/IGSH-511 --event workflow_dispatch --limit 5 --json databaseId,headSha,url
gh run watch <id> --interval 60
gh run download <id>
```

Check the exact head SHA and source mode; never poll more often than once a minute. `build` compiles the branch with pinned Zig 0.16.0 on Windows; `v0.28.788` downloads the published x64 executable and checks its SHA256SUMS entry. The workflow invokes:

```powershell
./tools/verify-reconnect/drive.ps1 -Exe "$PWD/bin/multiprompt.exe" -Ssh "$PWD/bin/ssh.exe" -Output "$PWD/evidence"
```

Unlike the baseline `control.ps1` journeys, this harness seeds two saved tmux tabs in a unique RUNNER_TEMP profile and replaces only the SSH system boundary using the production `ssh-path.txt` override. No network or credentials are used. The console-backed stand-in implements attach, explicit new-session, list-clients, list-sessions, the `@@MP_LIVE@@` host sentinel and the `@@LS_OK@@` successful-listing sentinel. This is proof of app reconnect behavior, not a real SSH server or AI agent. Do not pass these feature stems to `verify.yml`.

Launch/Doctor require both live transports and reconnect-ok after preflight drops, matching PID/executable identity, nonzero main/console HWNDs, and owned foreground/typing focus. `provenance.json` records revision, source mode and executable hash. Case A uses SendInput Ctrl+1 and a native-console click, kills only the background transport, waits for its idx=1 respawn and reconnect-ok, then requires zero reposition/browser/mask layout lines and unchanged sampled foreground/focus. Case B removes that remote session, kills its transport, requires exactly one `reason=session-gone` and no further attempts for 60 seconds, then uses Ctrl+2 to expose `Session ended`.

Require build `PASS A` and `PASS B`, and released `v0.28.788` `FAIL A` from the exercised layout/focus assertion, not launch failure. Artifacts `verify-reconnect-<exe_source>` retain summary/action JSON, debug and case logs, native focus samples, Doctor/provenance, screenshots, stand-in invocations and cleanup. Inspect screenshots and record exact run URLs and revision. `tools/verify-reconnect/check-evidence.js` independently recomputes measurements; execute it only on GitHub for this work, never on the VPS. Failed assertions retain artifacts and fail the job.

Reconnect cleanup runs in `finally`: capture the screen, stop only the owned app PID tree and surviving stand-in PIDs after executable-path checks, preserve logs/state outside the profile, remove that profile, and require zero remaining owned processes in `cleanup.json`. Never kill by process name. Downloaded artifacts remain intact.

## Evidence

Download artifact `verify-<feature>`; GitHub extracts it into a directory of that name. It contains:

- `before.png`, `action.png`, `after.png`: real app identity and baseline, the entry point/selection, and resulting visible state. Some journeys add intermediate screenshots.
- Matching `.uia.json` window/control snapshots; custom-drawn contents require screenshot inspection, not invented accessibility nodes.
- `actions.json`: ordered timestamped real inputs and window titles.
- `result.json`: pass/fail, asserted side effects, explicit offline-login boundary, errors, cleanup outcome and observed scratch removal.
- `process-tree.json`: kernel job accounting, including total owned processes and zero active processes after termination.
- `build.json`, `doctor.json`: source revision/release, executable hash/version and PID/HWND identity.
- `stdout.log`, `stderr.log`, and `data/`: the isolated app's saved files, debug/session-audit logs and any file created by the user journey, copied before scratch removal.

A proof requires the real user path, action plus resulting state, and independently read side effects. A screenshot alone, a green unit test, a log claiming an action, or hand-written app state is insufficient. For appearance, require both a persisted `light` preference and the visible sidebar becoming substantially brighter than the user-selected Dark baseline. Other journeys assert their own saved state/files/window titles. Download and look at the screenshots yourself; reject blank, occluded, login-only, wrong-build or unchanged images even if JSON says passed. A screenshot's existence or luminance is not a substitute for that review.

For example:

```sh
gh run download <id> -n verify-appearance -D /tmp/verify-multiprompt-<id>
```

Inspect `/tmp/verify-multiprompt-<id>/before.png`, `action.png`, `after.png`, `result.json` and `data/roaming/ZigShell/theme-mode.txt`. Record the run URL, exact feature/sub-features, revision and what changed. Report unexercised entry points and unmet prerequisites explicitly. Only a selected journey is covered; the map is not a claim that all features or releases have passed. There are no synthetic accounts, agent transcripts, remote servers or mocked UI in these journeys.

## Cleanup

The helper creates a private Windows Job object with kill-on-close and no breakaway, launches the app suspended in the original scratch working directory, assigns it to that job, then resumes it. Descendants inherit job membership before they can run; no process-name matching or shared-console killing is used. In `finally`, ask only the original app to close and wait up to ten seconds, then terminate the owned job, including surviving CMD/conhost descendants. Wait up to ten seconds for the job's active process count to reach zero and retain its accounting in `process-tree.json`. Copy isolated scratch to `evidence/data` before removing only that scratch directory, with a bounded twenty-second retry for Windows handle release. `result.json` records both owned-tree shutdown and the observed absence of scratch. Evidence stays outside scratch and is uploaded even on failure. A persistent cleanup error fails verification; never hide it behind runner disposal. Finally close the job/process handles and restore the harness environment; abrupt harness termination also closes the non-inherited job handle and kills its owned tree. Never touch a user's machine.

## Maintain

Use `/maintain-verification-skill` when menus, keyboard routing, persistence or startup change. Update the relevant map and harness together, then repeat the GitHub journey and screenshot review. Never relabel an unverified path as covered.
