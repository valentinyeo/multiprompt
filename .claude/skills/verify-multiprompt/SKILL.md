---
name: verify-multiprompt
description: Drive the real Multiprompt Windows desktop app on a GitHub windows-latest runner to verify SSH reconnect, saved remote tabs, and ended-session behavior with screenshots and native focus evidence.
---

# Verify Multiprompt

## Launch

This surface is the Windows desktop app on a GitHub windows-latest runner. It never runs on the Linux server. Do not run Zig, Wine, the exe, or desktop tests there.

From a checkout with this workflow pushed, dispatch:

```sh
gh workflow run verify-reconnect.yml --ref ceo/IGSH-511-verify -f exe_source=build
gh run list --workflow verify-reconnect.yml --branch ceo/IGSH-511-verify --limit 5
gh run watch RUN_ID --interval 60
```

Use the numeric run ID printed by `gh run list`. Never poll GitHub more often than once a minute. `exe_source=build` builds the checked-out ref using pinned Zig 0.16.0. `exe_source=v0.28.788` downloads the published x64 app and validates its SHA256SUMS.txt entry, rather than rebuilding the tag. The job is bounded to 20 minutes.

On the runner the workflow invokes:

```powershell
./tools/verify-reconnect/drive.ps1 -Exe "$PWD/bin/multiprompt.exe" -Ssh "$PWD/bin/ssh.exe" -Output "$PWD/evidence"
```

The build job also runs the existing SSH reconnect/probe logic tests on Windows. The driver creates a unique RUNNER_TEMP profile, sets APPDATA and LOCALAPPDATA, bypasses account login with the existing MULTIPROMPT_NO_LOGIN=1 option, enables ZIGSHELL_DEBUG, and seeds session.json with two named tmux tabs. No credentials are needed. Readiness requires live stand-in transports and explicit reconnect-ok evidence for both tabs after using the normal Ctrl+Shift+R shortcut, not just a main HWND. The fixture uses console view (chat_view_mode=nowhere): Chat View returns before the production [reposition] log and would make that absence check vacuous. An existing desktop instance is not safe to double-drive; use a fresh hosted runner.

## Doctor

Download the run's `verify-reconnect-build` artifact with `gh run download RUN_ID -n verify-reconnect-build -D evidence/build`. Inspect doctor.json: the launched PID/exe, nonzero main/input-surface HWNDs, foreground owned by main or its embedded console, and console typing focus in the app or console GUI thread, two live transports, and the configured ssh path must all agree. provenance.json records source revision, run URL, source mode, and actual exe SHA256. On the Windows runner, the read-only probe `[ReconnectDesktop]::Focus($main)` uses GetGUIThreadInfo on the application's GUI thread, not the PowerShell thread. Any startup/doctor error is infrastructure failure, never regression proof.

## Drive

Run the PowerShell helper above only in the Windows job. It uses SendInput Ctrl+1 and clicks the visible native console; Ctrl+2 reveals the ended tab after measurement. Case A kills only the background tab's transport, requires its idx=1 respawn and new-id reconnect-ok log, counts all `[reposition]`, `posBrowser`, and `posMasks` lines after the kill, and compares native foreground/focus samples against the baseline. Case B deletes that session from the stand-in file, kills its transport, requires exactly one reason=session-gone, then observes at least 60 seconds without another attempt for the ended ID. The screenshot and ended log together document Session ended; there is no OCR assertion.

The stand-in uses the production `%APPDATA%\ZigShell\ssh-path.txt` executable override consumed by resolveSshPath/appendSshExe. tmuxSshTarget remains production code; the fake executable ignores the target and never opens a network connection. This is narrower than installing/configuring OpenSSH server and needs no app test seam. It emulates attach, new-session, live-client lists, session lists, and the probe completion sentinel. Only the remote system boundary is mocked; layout, reconnect state, process exit handling, rendering, and input are real app behavior.

## Evidence

`verify-reconnect-<exe_source>` contains summary.json (one record per case), action-A/B.json (PID, action, log offset, time), debug.log, case-A/B.log, after-gone.log, focus.json (baseline, samples, final), doctor.json, provenance.json, seed-session.json, stand-in invocations, screenshots, driver.log, and cleanup.json. PASS/FAIL lines also appear in the job log and GitHub step summary. Failed assertions leave artifacts and make the job fail.

Prove the harness with build green and v0.28.788 red using the same harness revision. Red case A must be an exercised layout/focus assertion failure, not a launch failure. Download each artifact and each `gh run view RUN_ID --json databaseId,url,conclusion,headSha,event` result as run.json into separate build and v0.28.788 folders. Run `node tools/verify-reconnect/check-evidence.js EVIDENCE_ROOT` to independently recompute the critical measurements after cleanup. Keep the screenshots: a log alone does not prove what a user saw. Source-only tests are structural checks, not desktop proof.

## Cleanup

The driver always runs finally: capture the final screen, taskkill only the app PID tree it started, terminate any surviving owned fake transport PID after matching its executable path, copy logs/stand-in state to evidence, remove the unique temporary profile, and record remaining owned processes. Never kill by process name. cleanup.json must show zero remaining owned processes and preserved debug.log. Artifacts remain outside the removed profile even after failures. Downloaded evidence is not deleted.

## Helpers

- `tools/verify-reconnect/drive.ps1`: complete launch/doctor/drive/evidence/cleanup lifecycle, invoked above.
- `tools/verify-reconnect/desktop.cs`: loaded by Add-Type in the driver; native SendInput, HWND discovery, and GUI-thread/foreground measurements.
- `tools/verify-reconnect/fake-ssh.c`: compiled by `zig cc -target x86_64-windows-gnu -O2 tools/verify-reconnect/fake-ssh.c -o bin/ssh.exe` on Windows only; MP_VERIFY_STATE points at its isolated sessions.txt and per-PID transport/invocation files.
- `node tools/verify-reconnect.test.js`: source-reading contract checks only; safe on Linux.
- `node tools/verify-reconnect/check-evidence.js EVIDENCE_ROOT`: independent downloaded-artifact proof checker; safe on Linux.

Feature entry points are indexed in [features/README.md](features/README.md). Keep this map aligned with app changes; `/maintain-verification-skill` is the follow-up maintenance loop.
