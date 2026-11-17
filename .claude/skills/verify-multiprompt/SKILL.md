---
name: verify-multiprompt
description: Verify Multiprompt's real Windows desktop UI on GitHub Windows runners with keyboard journeys, read-only Doctor, screenshots and persisted side effects; use after desktop changes or when reproducing a user journey.
---

# Verify Multiprompt

Multiprompt is a native Windows desktop app hosting real console windows, with custom-drawn sidebar, Inbox and Ctrl+K overlays. It is not a browser page or an Electron app. The account Worker and browser extension are secondary surfaces. The `browser-emulation` map is a separate real-Chrome extension journey driven by `browser-emulation.mjs` through this workflow; it does not launch or verify the embedded app pane.

Read [features/README.md](features/README.md), then the selected feature file before running anything. See [recent changes coverage](coverage.md) for gaps and this pass's run results. Never build, launch or drive locally, through Wine, on a VPS, or on a user's laptop. Desktop execution below happens on GitHub's free `windows-latest` machines in the public repository.

Diagnostic verification maps live separately in `diagnostics/`: [Chat sync audit](diagnostics/chat-sync-audit.md) uses the dedicated GitHub Linux job, not the Windows desktop driver.

## Reusable driver

Read the complete feature index in [features/README.md](features/README.md), starting with long sessions, server chats, /clear, Stop and sending. Area files map source actions to recipes and exact unreachable prerequisites; their `Journeys:` lines name executable supporting recipes, not a claim that every action passed. The Windows entry point is `./.claude/skills/verify-multiprompt/drive.ps1 settings-appearance appearance -Exe $exe -ExpectedVersion $version -ExpectedHash $hash -Evidence "$pwd/evidence/settings-appearance-appearance"`. It invokes the existing Launch/Doctor/Drive/Cleanup control in a child PowerShell and records the actual desktop with FFmpeg. Use a fresh evidence folder outside the disposable profile. The mapped palette equivalent is `drive.ps1 palette command-palette` with the same arguments.

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=appearance` or `-f feature=command-palette` to acquire the executable and recorder and invoke the new driver automatically. Inspect `journey.mp4`, `journey.json`, screenshots, Doctor, saved side effects, and zero-process cleanup in artifact `verify-<journey>`. The recorder stops only its owned process. Evidence remains in `evidence/` after profile cleanup and is uploaded even on failure. Existing workflow routes and migration decisions are in [inventory.md](inventory.md). Two existing journeys are promoted here; the remaining legacy routes retain their documented coverage limits. Never treat source review as live coverage.

Before desktop launch, the shared `control.ps1` entry runs `node --test .claude/skills/verify-multiprompt/check-feature-map.test.cjs`, including legacy workflow routes that bypass `drive.ps1`. This checks index hygiene, every shortcut row, palette target families, architecture items and recipe links. To check source coverage and the generated-module regression without driving, run that same `node --test` command. Missing source actions fail with the map to repair. These checks do not certify live behavior.

Part A (`w-2567a`, SOFT-2567) owns new real-size seed data. Part B (`w-2567b`, SOFT-2567) owns real SSH/tmux on the hosted runner. Reuse their data/host when available; never replace a missing prerequisite with another undocumented stand-in. Save source-reader returns, actual journeys exercised, screenshot review and triage in scratch notes. Do not commit per-run notes or turn historical coverage into a new live-pass claim.

## Feature control ownership

- `control.ps1` keeps options, setup, dispatch and cleanup.
- `control-feature-<name>.ps1` owns each extracted feature body.
- Existing dedicated scripts keep their names.
- `control-library.ps1` holds shared PowerShell helpers.
- Run palette actions with `Invoke-JourneyCommand 'new cmd shell'`. Names come from the current palette or shortcut rows in `tools/journey-commands.mjs`. The helper reads routing numbers from source, selects the matching row, presses Enter, and requires changed screen pixels. Existing journey assertions still check the command's result.
- Use `-Confirm { Snapshot 'action'; Press @(0x0D) 'Enter: New CMD shell' }` to retain a pre-action capture. Use `-SelectOnly` only to inspect a row or measure Enter separately. Use `Invoke-JourneyCommand 'Restore middle' -Session` for a uniquely named saved session.
- `node --test tools/check-journey-commands.test.mjs` proves that old-style calls fail. `node tools/check-journey-commands.mjs` rejects raw `Palette`/`Focus-Palette` calls and names missing from the catalog.
- `control-native.cs` holds unchanged native types.
- Same-directory dot sourcing preserves scope and paths.
- Source readers use `readControlSource` from `tools/app-source.js`.
- Ordinary checks never pin feature content hashes.

The extraction tool is safe to rerun:

```sh
pwsh -File tools/split-feature-controls.ps1 -Path .claude/skills/verify-multiprompt/control.ps1 -Output control-ast.json
node tools/split-feature-controls.mjs control-ast.json
node tools/split-feature-controls.mjs --check
```

Use `--check --original` only for this migration's proof.
Its fixture records the original source, not future constraints.

## Launch

From an authenticated checkout, submit the default branch's workflow and select a feature-map file stem:

```sh
gh workflow run verify.yml -f feature=<name>
gh run list --workflow verify.yml --event workflow_dispatch --limit 5 --json databaseId,headSha,displayTitle,url
timeout 1800 gh run watch <id> --interval 300
gh run download <id>
```

Use `appearance` for the first journey. Other names are `browser-corners`, `sessions`, `session-restore`, `workspaces`, `workspace-focus`, `inbox`, `command-palette`, `session-open`, `session-tabs`, `favorites-groups`, `server-open-group`, `browser-switch-speed`, `chat-switch-speed`, `browser-pane-stuck`, `browser-pane-locked`, `group-rail`, `pane-layout`, `title-bar`, `window-controls`, `chat-tables`, `chat-code-font`, `safe-updates`, `chat-view`, `chat-view-everywhere`, `chat-focus`, `chat-dictation`, `status-card`, `palette-order`, `remind-me`, `tab-names`, `browser-emulation`, `browser-own-profile`, `chat-first-paint` ([chat first paint](features/chat-first-paint.md)), `chat-send-latency` ([chat send latency](features/chat-send-latency.md)), `app-icon` ([app icon](features/app-icon.md)), and `relaunch-saved-sessions` (the release gate, [relaunch saved sessions](features/relaunch-saved-sessions.md)). [Chat delivery](features/chat-delivery.md) additionally selects `chat-delivery` for the production tmux-channel journey described below. The `session-open` journey exercises the real agent TCP request and background persistence, not successful SSH/tmux attachment. Verify the listed run's head SHA and title before watching or downloading. To verify a development branch:

```sh
gh workflow run verify.yml --ref ceo/IGSH-525 -f feature=appearance
```

If GitHub refuses because the workflow is not on the default branch yet, open or update the branch's PR. Its path-filtered `pull_request` trigger runs `appearance`, `chat-dictation`, `session-restore`, `workspace-focus`, `favorites-groups`, `browser-pane-stuck`, `browser-pane-locked`, `group-rail`, `pane-layout`, `chat-view-everywhere`, `chat-focus`, `status-card`, `palette-order`, `browser-own-profile`, and `remind-me` against the PR merge revision; identify that event and head SHA with `gh run list`, then use the same watch and download commands. Never substitute a default-branch run for the proposed change.

To exercise a published executable instead of compiling the branch:

```sh
gh workflow run verify.yml -f feature=appearance -f tag=v0.28.821
```

The tag must be `v<major>.<minor>.<patch>`. The workflow downloads the real x64 release executable and its published SHA256SUMS, verifies the checksum and embedded version, and records the tag. This verifies that release, not the branch's app code. Leave `tag` empty for branch verification. `safe-updates` and `browser-emulation` run only as branch builds, with no tag: updates need the job-only verifier public key, and emulation needs the matching extension and bridge. A tag run needs a release containing every change the harness asserts; for example, v0.28.820 predates IGSH-587 and fails the current appearance check for maximized startup, while v0.28.821 contains it. The branch path installs checksum-pinned Zig 0.16.0 and runs the repository's `zig build` on Windows, like release/test workflows. No tests or builds run on the caller's machine.

The `sessions` journey seeds two saved remote tabs once, with the third server active, and replaces only SSH with a repository-listing and console-backed transport stand-in. Real Ctrl+T and palette input must preserve the selected server, folder and view, including after Cancel. See [sessions](features/sessions.md) for this boundary; it does not verify real remote agents.

The `session-restore` journey uses `--single-window` with restoration enabled and retains its private data between launches in the same job. For ordinary desktop journeys, the Windows helper starts exactly that executable with `--single-window --no-window-restore`, a unique empty directory under RUNNER_TEMP, and private APPDATA, LOCALAPPDATA, USERPROFILE and HOME. It creates no session fixtures or settings. A ready instance has its own visible `ZigShell` main window, the expected version, and a published initial CMD session. Startup is bounded to 60 seconds; missing readiness fails, rather than driving a login screen or an unrelated window.

`IGSH_246=0` keeps the selected branch/release executable fixed during verification; update download and rollback behavior is tested separately on GitHub Windows.

`MULTIPROMPT_NO_LOGIN=1` is the documented development/offline mode. This is an explicit stand-in for account sign-in and layout sync, not proof those work. No account credentials are supplied. `ZIGSHELL_DEBUG=1` enables real app logs. Isolated app data and disabled workspace restoration prevent shared-session driving; the fresh hosted desktop also isolates machine-wide resources. Do not run multiple harnesses on one desktop.

The [Chat View everywhere](features/chat-view-everywhere.md) journey switches all three local sessions once, checks pinned-tab protection and independent view toggles, unpins before restarting the owned app in the same isolated profile, and proves the removed lock/view palette queries have no rows. Alt+T creates workspace tmux sessions; this offline journey instead uses the real Ctrl+K New CMD Shell action.

The [Chat focus](features/chat-focus.md) journey restarts an offline CMD session, proves immediate composer typing through bounded WM_GETTEXT with UI Automation focus identity, and recovers typing with Alt+Q and Alt+M while Find is open and without a browser pane. The native Edit may appear as a UIA Pane with no text patterns; validate its Edit class and owned root before reading standard WM_GETTEXTLENGTH/WM_GETTEXT messages.

The [Chat dictation](features/chat-dictation.md) journey (`feature=chat-dictation`, branch build only) drives Ctrl+D, Enter, repeated Ctrl+D and a real mic click. Recorded PCM and offline provider-response replay traverse the production worker/parser/draft delivery; exact native composer text must appear within 1000 ms, while listening-time typing and active/idle microphone pixels are checked independently. This does not verify acoustic recognition or microphone hardware.

The [Jump to newest](features/chat-newest.md) journey (`feature=chat-newest`) verifies Shift+G twice and the matching palette action with exact native draft reads. Its named `result.json` checks are independent of the separate full-history restart/performance journey.

## PR verifier

Every pull request from this repository gets an independent verdict from `.github/workflows/pr-verifier.yml`. It runs on GitHub's hosted runners only. To verify an open pull request by hand:

```sh
gh workflow run pr-verifier.yml --ref master -f pr=<number>
gh run list --workflow pr-verifier.yml --limit 5 --json databaseId,headSha,url
timeout 3000 gh run watch <id> --interval 300
```

DeepSeek picks up to three journeys from `features/` that exercise the change, `verify.yml` runs them on the pull request head and on the merge base with the same harness, and a second pass reads the evidence against the Done-when lines. The picker and the judge call `https://api.deepseek.com` with model `deepseek-flash` (DeepSeek-V4.1-Flash, never Pro). Claude runs both passes only when a commit carries a DeepSeek Co-Authored-By trailer, so the judge is never the author's model family. Grok-authored and Claude-authored pull requests stay on DeepSeek. The check is named `pstack-verifier` and the result is one comment whose first line is `pstack-verifier: PASS|PASS+NOTES|FAIL @ <head sha>`. A failed head journey forces `FAIL`. A change no journey covers is capped at `PASS+NOTES`, with a generated journey map in the `pr-verifier-selection` artifact as the reviewer's checklist. The generated map is not run, because every journey needs a PowerShell driver in `control.ps1`. The decision logic lives in `tools/pr-verifier.cjs`.

### Reproduce before fixing

A PR marked as a repair must name exactly one runnable journey in its description:

```text
Repro journey: `chat-delivery`
```

The gate treats titles containing `bug`, `bug fix`, `fix`, `fixes`, or `fixed`, including conventional `fix(scope):` titles, as repairs. Labels `bug`, `bug-fix`, `bugfix`, `bug fix`, `defect`, and `regression` also mark repairs.

For these PRs, the named journey takes priority over the picker and runs against both head and the current master commit captured when verification starts. Both runs use the PR's journey harness. The journey must fail on master for a product assertion and pass on head. A master pass, missing result, infrastructure failure, unknown journey, or an omitted declaration makes `pstack-verifier` FAIL even if the judge says PASS. An unrelated failing journey and inherited failures on both revisions do not prove a repair. Keep the failure screenshots and result files in the uploaded artifacts.

Other PRs retain the existing failed-head baseline comparison. Title, description, and label changes also rerun the gate, and resolution resets the required status to pending, so adding a repair label cannot reuse an earlier green verdict. `node --test tools/pr-verifier-repro.test.js` checks rejection without a failing-master repro and acceptance with matching before-and-after evidence. See [the rule and evidence contract](../../../openwiki/operations/reproduce-before-fixing.md).

## Doctor

For ordinary desktop journeys, `control.ps1` runs `Doctor` after launch, before each input, and after the journey. Doctor is read-only and cheap: the original Process object must be alive, its path and SHA256 must match the selected executable, its HWND must belong to that PID and class `ZigShell`, its title must be `Multi Bot` or carry the expected legacy version, UI Automation must see that window, and its published Inbox state must contain a usable initial shell. It writes only evidence (`doctor.json`), never app state; it does not build, seed, authenticate, invoke actions or repair preconditions.

When something looks off, read the artifact's `doctor.json`, `result.json`, and `data/roaming/ZigShell/debug.log`. Rerun the workflow to obtain a new isolated instance; do not reuse or repair the failed one. Build identity and provenance live in `build.json`.

## Drive

The executable helper is [control.ps1](control.ps1). Its exact workflow-side invocation, using values resolved and checked by the workflow, is:

```powershell
& .claude/skills/verify-multiprompt/control.ps1 -Feature $env:FEATURE -Exe "$pwd/verify-bin/multiprompt.exe" -ExpectedVersion $env:VERIFY_VERSION -ExpectedHash $env:VERIFY_SHA256 -Evidence "$pwd/evidence"
```

Invoke it only through `verify.yml`; it refuses non-GitHub/non-Windows execution. For ordinary desktop journeys this command performs Launch, Doctor, the selected feature recipe, Evidence and Cleanup. `safe-updates` delegates to its fixture driver and `browser-emulation` to its Chrome driver before desktop Doctor; each has its own checks and cleanup. No helper requires a separate interpreter investigation or an undocumented server.

The harness uses .NET System.Windows.Automation for window identity and accessibility snapshots, and Win32 SendInput for genuine keyboard input. Text uses keyboard-layout-mapped virtual keys, not Unicode packets (the palette hook consumes those). Custom-painted palette rows are not UIA buttons: do not invent accessibility selectors or send private WM_APP messages. Selection uses actual Ctrl+K search terms and arrow/Enter navigation from the feature maps. Native HWND ownership, not screen coordinates, determines where input goes. The foreground root must be our window before every input. Window-relative pixels support screenshots and theme luminance checks; mapped mouse journeys also target ownership-checked browser strips and workspace pills.

The `pane-layout` journey groups a real CMD, docks its browser and checks native pane geometry. It cycles Alt+Q twice in shell and Chat View for every production theme, proves shell/composer/page input, and compares exact focused/unfocused margin pixels. Branch builds run the identical journey first on pinned pre-fix commit `9618091700e09f5958a48390449dc5067874d5dd`, retaining visible-ring screenshots under `focus-negative/`, then require no ring on the fixed build. See [pane layout](features/pane-layout.md) for pixel detection and evidence limits.

The `browser-pane-locked` journey uses real mouse dragging, browser-focused Win+Up and a strip double-click, requiring the exact dock rectangle and no maximization. It logs the verified release tag/version. See [browser pane locked](features/browser-pane-locked.md).

The on-demand-only `browser-switch-speed` journey (`workflow_dispatch`, not the PR journey matrix) measures 20 real Ctrl+Tab switches per browser-off/warm-on set and five freshly frozen browser returns in both console view and Chat View. Frozen sets wait at most 150 seconds per app-published `panehib-zss-<shell_id>.flag`, never force freeze, and require marker removal on wake. The disposable profile includes the bridge extension needed for CDP. Browser-on samples require the target page color on screen, with separate window-visible timings. Artifact `verify-browser-switch-speed` includes `switch-timings.json`, optional debug traces and native window identities; either view’s warm or frozen browser-on median gap above 50 ms or an unreachable end state fails. Older releases without debug timing traces remain measurable. See [browser switch speed](features/browser-switch-speed.md).

The `browser-pane-stuck` journey reads the app-published `browser_state`, `browser_connection_id` and `browser_window_id` fields in `inbox-default.json`; it never writes them or publishes pane URLs. A docked pane does not need an extension window ID. Run `node tools/check-browser-pane-stuck.mjs` for its static map/workflow/driver contract check (no app execution).

Bounded condition waits inspect actual saved state and window titles. A missing precondition fails the journey with an error and retained evidence. Never change the expected outcome, write settings yourself, add a test-only setter, or skip the failing action to make a run green. Fix a broken driver only when the real user path is unchanged.

### Messages only

- [Every session message](features/chat-full-history.md): open and restart a long known-count session; require all messages through native layout and transcript copy on GitHub Windows.

Read [Messages only](features/chat-messages-only.md). Dispatch `gh workflow run verify.yml --ref ceo/IGSH-759 -f feature=chat-messages-only`. The identical driver runs first against the pinned pre-fix commit 42cecfd3 (required visible-row failure) and then against the branch. Both screenshots include the real composer and transcript. This journey reuses the delivery stand-in's explicit isolated saved-tab and synthetic-agent-transcript boundary; it does not write the app's transcript cache or use an app setter. All builds and tests run on GitHub Windows.

### Chat delivery

Read [Chat delivery](features/chat-delivery.md). Dispatch `gh workflow run verify.yml --ref ceo/IGSH-595 -f feature=chat-delivery -f tag=v0.28.811` and repeat with `tag=v0.28.821`; omit the tag for a branch build. After merge the default-branch dispatch may omit `--ref`. The artifact is `verify-chat-delivery`, with root `result.json` status and all three named cases. This journey delegates from control.ps1 to tools/verify-chat-delivery/drive.ps1 and uses the reconnect pattern's explicit saved-session exception: isolated saved tmux tabs plus the production ssh-path.txt override, never an app test setter.

The remote-shell stand-in launches Python with the app-supplied embedded reader and its real stdin protocol. Fake tmux supplies scripted capture-pane screens and logs raw timestamped send-keys arguments; its busy/grey-suggestion screens are mirrored into the attached console. Real SendInput selects the tab, opens Chat View, types and sends or steers. Separate owned jobs/profiles keep all three cases independent. Doctor, screenshots, buffer/invocation/debug logs, and zero-process cleanup are mandatory. The result's agentBoundary is stand-in remote shell + fake tmux + scripted agent screen, not real Claude or a real server. It does not verify SSH networking, agent consumption, responses or transcript discovery. The local direct-input suggestion gap remains uncovered. Require paired GitHub regression evidence, not only local source contracts.

### SSH reconnect and ended sessions

The separate [verify-reconnect.yml](../../../.github/workflows/verify-reconnect.yml) workflow drives the same real Windows app with the helpers in [tools/verify-reconnect/](../../../tools/verify-reconnect/). It never runs on the Linux server. Read [SSH tab reconnect](features/ssh-tab-reconnect.md), [ended remote session](features/ended-remote-session.md), and [saved remote workspace](features/saved-remote-workspace.md) before dispatching:

```sh
gh workflow run verify-reconnect.yml --ref ceo/IGSH-511 -f exe_source=build
gh workflow run verify-reconnect.yml --ref ceo/IGSH-511 -f exe_source=v0.28.788
gh run list --workflow verify-reconnect.yml --branch ceo/IGSH-511 --event workflow_dispatch --limit 5 --json databaseId,headSha,url
timeout 1800 gh run watch <id> --interval 300
gh run download <id>
```

Check the exact head SHA and source mode; never poll more often than once a minute. `build` compiles the branch with pinned Zig 0.16.0 on Windows; `v0.28.788` downloads the published x64 executable and checks its SHA256SUMS entry. The workflow invokes:

```powershell
./tools/verify-reconnect/drive.ps1 -Exe "$PWD/bin/multiprompt.exe" -Ssh "$PWD/bin/ssh.exe" -Output "$PWD/evidence"
```

Unlike the baseline `control.ps1` journeys, this harness seeds two saved tmux tabs in a unique RUNNER_TEMP profile and replaces only the SSH system boundary using the production `ssh-path.txt` override. No network or credentials are used. The console-backed stand-in implements attach, explicit new-session, list-clients, list-sessions, the `@@MP_LIVE@@` host sentinel and the `@@LS_OK@@` successful-listing sentinel. This is proof of app reconnect behavior, not a real SSH server or AI agent. Do not pass these feature stems to `verify.yml`.

Reconnect Launch/Doctor require both live transports and reconnect-ok after preflight drops, a visible non-console window owned by the app PID, a native console owned by the selected transport, and foreground/typing focus. Doctor records the app path but does not recheck its hash, version or `ZigShell` class; workflow acquisition records the executable hash in provenance. `provenance.json` records revision, source mode and executable hash. Case A uses SendInput Ctrl+1 and a native-console click, kills only the background transport, waits for its idx=1 respawn and reconnect-ok, then requires zero reposition/browser/mask layout lines and unchanged sampled foreground/focus. Case F repeats the background loss while typing in the active Chat View composer and requires exact retained text and no focus events. Case B empties the server session list, kills verify-two's transport, requires exactly one `reason=session-gone` and no further attempts for 60 seconds, then uses Ctrl+2 to expose `Session ended`.

Require build `PASS A`, `PASS F` and `PASS B`, and released `v0.28.788` `FAIL A` from the exercised layout/focus assertion, not launch failure. Artifacts `verify-reconnect-<exe_source>` retain summary/action JSON, debug and case logs, native focus samples, Doctor/provenance, screenshots, stand-in invocations and cleanup. Inspect screenshots and record exact run URLs and revision. `tools/verify-reconnect/check-evidence.js` can independently recompute measurements, but the workflow does not invoke it. It needs build and v0.28.788 artifact directories plus externally collected `run.json` metadata for each. Execute it only on GitHub for this work, never on the server; a green driver run alone is not that comparison.

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

Inspect `/tmp/verify-multiprompt-<id>/before.png`, `action.png`, `after.png`, `result.json` and `data/roaming/ZigShell/theme-mode.txt`. Record the run URL, exact feature/sub-features, revision and what changed. Report unexercised entry points and unmet prerequisites explicitly. Only a selected journey is covered; the map is not a claim that all features or releases have passed. Ordinary desktop journeys use no synthetic accounts, transcripts, remote servers or mocked UI. Reconnect seeds saved tabs and replaces SSH; the branch Chat View painter uses a synthetic message; safe updates uses signed fixture releases; emulation serves a synthetic page to real Chrome; chat delivery replaces the remote-shell boundary with a stand-in. None proves live agent or account behavior.

## Cleanup

The helper creates a private Windows Job object with kill-on-close and no breakaway, launches the app suspended in the original scratch working directory, assigns it to that job, then resumes it. Descendants inherit job membership before they can run; no process-name matching or shared-console killing is used. In `finally`, ask only the original app to close and wait up to ten seconds, then terminate the owned job, including surviving CMD/conhost descendants. Wait up to ten seconds for the job's active process count to reach zero and retain its accounting in `process-tree.json`. Copy isolated scratch to `evidence/data` before removing only that scratch directory, with a bounded twenty-second retry for Windows handle release. `result.json` records both owned-tree shutdown and the observed absence of scratch. Evidence stays outside scratch and is uploaded even on failure. A persistent cleanup error fails verification; never hide it behind runner disposal. Finally close the job/process handles and restore the harness environment; abrupt harness termination also closes the non-inherited job handle and kills its owned tree. Never touch a user's machine.

## Maintain

Use `/maintain-verification-skill` when menus, keyboard routing, persistence or startup change. Update the relevant map, [coverage table](coverage.md) and harness together, then repeat the GitHub journey and screenshot review. Never relabel an unverified path as covered.

- [Skill pills](features/chat-skill-pill.md): native draft and sent-history colors on dark and light themes.
- [Chat options](features/chat-options.md): clickable answer cards for lettered or numbered options and terminal pick lists.

## Part S. Verification speed

PRs select journeys from each feature map's `Source files:` line. Run every match. An unknown application source selects all runnable journeys; never cap the result to save time. Documentation and CI-only edits use the required Tests and independent verifier without unrelated UI journeys.

Selection and desktop journeys overlap Tests. A verdict still requires Tests to pass for the exact PR head. The independent judge, PASS, PASS+NOTES, FAIL, BLOCKED, inherited-failure handling, and cleanup requirements do not change.

One application build per revision is shared within each run. Signed update fixtures, source instrumentation, and symbolized builds retain separate binaries because their build inputs differ. Zig toolchains and compilation are cached. Never accept a cached binary without the embedded version, revision, and hash checks.

All workflows cancel superseded work. Keep reusable workflow groups separate from their callers. Run the full runnable set nightly on master and before release publication. Keep all Tests shards, update scenarios, speed comparisons, and five-minute idle observations.

Measure real automatic runs, including queue time and cancellations. Put run links, sample counts, elapsed times, and conclusions in the PR body. Do not report a failed or cancelled run as a speedup. Push once per fix and never dispatch additional measurements.

Cancelled verifier runs recover the latest open PR head automatically, at most once per head. Recovery skips drafts, existing active runs, and successful verdicts. It never retries product failures or dispatches measurement runs. Cancelling a superseded run stops its queued report jobs; the separate completion observer keeps cancellation BLOCKED until a fresh independent verdict passes.

Verifier recovery reads PR metadata, head checks, comments and Tests status in one GraphQL snapshot. Tests and release-status polling start at one minute and back off to five minutes. Missing head state, API errors, and non-green Tests remain fail-closed; snapshots never substitute an older successful head or attempt.

A terminal check-suite result is confirmed once against the actual Tests workflow run. Custom verifier checks can attach to another workflow's suite, so the suite's conclusion alone cannot prove that Tests passed or failed.
