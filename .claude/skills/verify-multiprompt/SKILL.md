---
name: verify-multiprompt
description: Verify Multiprompt's real Windows desktop UI on GitHub Windows runners with keyboard journeys, read-only Doctor, screenshots and persisted side effects; use after desktop changes or when reproducing a user journey.
pstack: 0.15.46
---

# Verify Multiprompt

Multiprompt is a native Windows desktop app with real console windows, a custom sidebar, Inbox and Ctrl+K overlays — not Electron or a browser page. Never build, launch or drive locally, through Wine, on a VPS, or on a user's laptop. Execution uses GitHub `windows-latest` in this public repository.

Read [features/README.md](features/README.md), then the selected feature file before running anything. Gaps and run notes: [coverage.md](coverage.md). Diagnostics: [diagnostics/](diagnostics/) — [Chat sync audit](diagnostics/chat-sync-audit.md) uses a Linux job, not the Windows driver. Legacy workflow routes: [inventory.md](inventory.md). Dispatch, PR selection, and citation detail: [verification-reference.md](verification-reference.md).

## Launch

Agents use `node tools/mbv.mjs` (`run`, `watch`, `proof`, `doctor`, `failures`, `list`). Dispatch:

```sh
gh workflow run verify.yml -f feature=<stem>
```

Use `appearance` when unsure. Stems include `session-restore`, `palette-order`, `status-card`, `remind-me`, `tab-names`, `relaunch-saved-sessions`, `chat-first-paint`, `chat-send-latency`, `browser-switch-speed`, `browser-pane-locked`, and `browser-pane-stuck`. Optional `--ref <branch>` and `-f tag=v<version>`; tag runs download a release binary instead of building the branch. See [verification-reference.md](verification-reference.md#launch) for the full stem list, PR-triggered set, and tag rules.

The workflow builds with pinned Zig 0.16.0 or verifies a tagged release. Ordinary journeys start `--single-window --no-window-restore` in an empty isolated profile with `MULTIPROMPT_NO_LOGIN=1`, bounded 60s readiness for an owned `ZigShell` window and initial CMD tab. `IGSH_246=0` keeps the selected binary fixed for the run. One owned instance per harness; do not double-drive a shared desktop. `session-restore` retains data within the job; `safe-updates` and `browser-emulation` need branch builds.

Chat UI work may also require [verify-chat-still](../verify-chat-still/SKILL.md) and [chat-still](features/chat-still.md).

## Doctor

`control.ps1` runs Doctor after launch, before each input, and after the journey when the recipe requires it. Doctor is read-only: Process alive; path and SHA256 match the executable; HWND is owned with class `ZigShell`; title is `Multi Bot` or carries the expected version; UI Automation sees the window; Inbox exposes a usable initial shell. It writes only `doctor.json`. When something looks off, read `doctor.json`, `result.json`, and `data/roaming/ZigShell/debug.log`, then dispatch a fresh run — do not reuse a failed instance. Identity and provenance: `build.json`.

## Drive

Invoke [control.ps1](control.ps1) only through `verify.yml` on GitHub Windows:

```powershell
& .claude/skills/verify-multiprompt/control.ps1 -Feature $env:FEATURE -Exe "$pwd/verify-bin/multiprompt.exe" -ExpectedVersion $env:VERIFY_VERSION -ExpectedHash $env:VERIFY_SHA256 -Evidence "$pwd/evidence"
```

Area maps may use `drive.ps1 <feature> <journey>` with the same identity arguments (see each file). Harness: .NET UI Automation for identity, Win32 SendInput with layout-mapped keys (not Unicode packets). Custom palette rows: real Ctrl+K search plus arrow/Enter — no invented accessibility nodes or private WM_APP messages. Foreground must be our window before input.

Reconnect maps ([ssh-tab-reconnect](features/ssh-tab-reconnect.md), [ended remote session](features/ended-remote-session.md), [saved remote workspace](features/saved-remote-workspace.md)) use [`.github/workflows/verify-reconnect.yml`](../../../.github/workflows/verify-reconnect.yml) and [`tools/verify-reconnect/`](../../../tools/verify-reconnect/) on Windows; the harness never runs on the Linux server. Do not pass those stems to `verify.yml`.

Journey detail: [Chat delivery](features/chat-delivery.md), [chat focus](features/chat-focus.md) (`WM_GETTEXTLENGTH/WM_GETTEXT`), [chat dictation](features/chat-dictation.md), [server chat](features/server-chat.md), [browser pane stuck](features/browser-pane-stuck.md) (static contract: `node tools/check-browser-pane-stuck.mjs`). Missing preconditions fail with evidence; never weaken the user path or write app settings to green a run.

## Evidence

Artifact `verify-<feature>` holds `journey.mp4`, `video.json`, screenshots, `.uia.json`, `actions.json`, `result.json`, optional `process-tree.json`, `build.json`, `doctor.json`, logs, and `data/` before scratch removal. Prove the real user path, the action and resulting state, and independently read side effects. Cite only files you opened; if you cannot view PNGs, read JSON and saved state and say screenshots were unreviewed. More: [verification-reference.md](verification-reference.md#evidence).

## Done video

Every journey records `journey.mp4`. The PR verifier runs the same journey with the head's driver on pinned master and head builds, preserving `before.mp4` and `after.mp4` in their evidence artifacts. For every screen change or urgent fix, run `node tools/done-video.mjs <pr-number> [journey]`; it prints the before and after paths, one per line. Post the ticket's Done comment with the board CLI's `comment-add` command using `--kind done`, 2-3 plain sentences, and `--attach <before-path> --attach <after-path>`. Attach both video files so they play on the ticket, and link both in the PR, labelled BEFORE and AFTER. Never mark Done with only one clip.

## Cleanup

Private Windows Job with kill-on-close; launch suspended, assign to job, resume. In `finally`, close the app, terminate the owned job, wait for zero active processes, copy scratch to `evidence/data`, remove only scratch with bounded retries. Never kill by process name. Evidence survives teardown and uploads on failure.

## Helpers

- [control.ps1](control.ps1), [control-library.ps1](control-library.ps1), [control-native.cs](control-native.cs), `control-feature-<name>.ps1`
- `Invoke-JourneyCommand` + `tools/journey-commands.mjs`; `node tools/check-journey-commands.mjs`
- `node --test .claude/skills/verify-multiprompt/check-feature-map.test.cjs` before desktop launch
- `node tools/check-feature-coverage.mjs` (weekly report, not a PR gate)
- `node tools/mbv.mjs` for agent dispatch and artifact reads
- `tools/split-feature-controls.ps1` / `node tools/split-feature-controls.mjs --check` for control extraction

## Feature map

[features/README.md](features/README.md) is the maintained source: Sub-features, user entry points, driving recipe, Gotchas per file. One selected journey does not cover the whole map; report unreachable prerequisites explicitly.

## Maintain

Use `/maintain-verification-skill` when menus, routing, persistence or startup change. Update the map, [coverage](coverage.md), and harness together, then re-run hosted proof. Tuesday `maintain-verification.yml` runs the pstack upkeep loop; corrections stay inside this skill directory.