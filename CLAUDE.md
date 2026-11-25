# multiprompt

A lean Windows workspace, written in Zig 0.16, that hosts native console windows in vertical session tabs instead of rendering a terminal. Start with [`openwiki/index.md`](openwiki/index.md). Design and features: [openwiki/architecture/features.md](openwiki/architecture/features.md). Win32 pitfalls: [openwiki/architecture/win32-gotchas.md](openwiki/architecture/win32-gotchas.md). Browser routing: [openwiki/browser/routing-state-machine.md](openwiki/browser/routing-state-machine.md).

This public repo is where Multiprompt is developed, checked and released. GitHub Actions run free here; never add a workflow to a private repo instead.

## Build, test, ship

Full procedure and toolchain notes: [openwiki/operations/build-and-install.md](openwiki/operations/build-and-install.md).

- An outage interrupts the queue. Revert the bad change first, then send the real fix through reproduction, failing repro, PR verification and normal release.
- Follow the solo-dev skill's work order.
- Drain existing PRs first; keep at most 10 open PRs in the repo.
- Every change is a small PR: one small commit with a one-line undo, squash-merged once the pstack-verifier passes at its head.
- Never build or test on shared servers. This includes lightweight tests. Use GitHub-hosted public CI only.
- Each master push publishes a release automatically. CI builds x64 and arm64. The built x64 app must launch. Its main window must appear within five minutes. Gitleaks blocks publication on failure. CI signs and publishes the assets.
- Heavy desktop checks run nightly or manually. The built release must launch. Use `auto-revert-master.yml` for rollback evidence; while automatic revert is disabled, revert manually before attempting a fix.
- Add `changelog.d/<TICKET>-<slug>.md` fragments (see `changelog.d/README.md`). Commit as `<TICKET>: Brief description`. CI stamps versions. Never hand-edit app versions.
- Release updates reach users via the in-app updater. Never compile on the laptop.
- Every extension change (`bridge.js`, manifest) bumps `"version"` in `extension/manifest.json`, independent of the app version. The extension-version check fails a PR that changes shipped files in `extension/` without a bump.
- Everything here is public: never commit keys, private host names, internal paths, emails or private messages. The secret-scan check runs on every PR.
- Ticket board: https://app.hypertask.ai/project?id=2060 (prefix `IGSH`).
- Hypertask board: 2060, label: Multiprompt

## Hard rules

- The helper bundle derives its runtime fingerprint from its contents; never hand-bump `RUNTIME_GENERATION`. See [runtime contract](openwiki/operations/chat-shared-runtime.md).
- Fundamental shared changes need Android tickets. This includes chat, sessions, and sync. Create or update one paired ticket first. Link both tickets in both directions. Reuse board 2060's Multiprompt Android label. Record old and new client compatibility. Verify both clients before declaring Done. Existing release gates remain unchanged.
- **Never restart multiprompt without asking the user.** Use the in-app updater.
- **Never compile on the laptop.** Use the in-app updater.
- **Every user-facing feature ships on all three surfaces in the same version:** a keyboard shortcut (when sensible), a Ctrl+K palette entry, and a row in `SHORTCUT_ROWS` (`src/shortcuts.zig`) plus `openwiki/operations/keyboard-shortcuts.md`. Tab actions also go in the tab-context palette band (7100+). `tools/palette-rows.test.js` and `tools/shortcuts-doc.test.js` fail on drift (regenerate with `node tools/shortcuts-doc.mjs`).
- **Every palette action also has a command-line verb, or it is on the screen-only list:** the verb is an `mb` command in `tools/mb.mjs` (list, open, close, pin, unpin, rename, move, style, star, mute, manual, settings, pull, workspace, group, roster). Running a verb twice leaves the same result. Screen-only: this window's look and size; the chat open on this screen; the browser or computer pane on this screen; menus that only open another list; marks stored on this PC (lock, keep-alive, snooze, remind, archive), plus quit, restart, and crash tools; sign-in and account devices; focusing a tab or workspace already on screen. `tools/palette-verbs.test.js` fails when a palette row has neither.
- **Changelog fragments are for the end user:** one short plain sentence per line, no internal names. Engineering detail goes in the commit message.
- **Never use Ctrl+Alt shortcuts** (AltGr on US-International layouts).
- The browser extension targets Chrome and loads unpacked from `extension/`.
- **The Chat View shows no status elements around messages:** no sending clock, "Sending...", read checks, ETA, model or capacity badges. Only a real send failure may show. Valentin removed these one by one; do not add new ones.
- **Minimal chat UI:** add a chat or sidebar element only when a ticket asks for it. Tickets filed by Valentin or the design lead need no further yes; a wrong change is rolled back. New actions go into Ctrl+K. Busy state is only the three ticking dots.
- Keep this file under 80 lines.

## Rules and what enforces them

| Rule | Enforced by |
| --- | --- |
| Allocate distinct routing IDs outside registered dynamic bands. | `tools/check-routing-ids.mjs`, `tools/routing-id-bands.json` |
| Snapshot regression inputs in `tools/fixtures/<ticket>/`, not Git history. | `tools/check-regression-inputs.mjs` (new reads in PR diffs) |
| Do not bind PowerShell host-owned variables or name functions after aliases. | `tools/check-powershell-host-names.ps1` |
| Server-chat native commands use exit codes and retain stderr evidence through `Invoke-ServerNative`. | `tools/verify-server-chat/native.ps1`, `tools/verify-server-chat.test.py` |
| Keep palette, tab actions and shortcut documentation aligned. | `tools/palette-rows.test.js`, `tools/shortcuts-doc.test.js` |
| Keep source feature coverage visible; it never gates a pull request. | `tools/check-feature-coverage.mjs` reports in `maintain-verification.yml` with `continue-on-error: true`; existing gaps belong to Part H, w-2567h |
| Maintain the feature map weekly; open at most one PR of proven corrections. | `maintain-verification.yml` runs pstack `maintain-verification-skill` with the PR verifier's Claude setup; `tools/publish-verification-maintenance.mjs` checks live coverage and edit scope |
| Never hand-edit app versions; CI stamps versions. | `tools/version-stamp.mjs check` in `test.yml` |
| Update cards never promise a duration. | `tools/check-update-card-time-wording.mjs`, `tools/check-update-card-time-wording.test.js` in `test.yml` |
| Every reader and bundled helper edit changes its runtime fingerprint automatically. | `tools/check-runtime-generation.mjs` runs `tools/runtime-fingerprint.test.py` (test workflow) |
| Every installed chat tool is executable, and an install leaves no temporary files behind. | `tools/chat-shared-runtime.test.py` (`test_every_installed_chat_tool_runs`, `test_install_removes_leftover_temporary_files`) |
| Outages revert the bad change before a repair; the repair follows the normal process. | `auto-revert-master.yml`, `.claude/skills/verify-multiprompt/SKILL.md` |
| Repair PRs wait only on the journeys their changed files own. | `tools/pr-verifier.cjs`, `tools/pr-verifier-repro.test.js`, `pr-verifier.yml` |
| Emergency lane: when Valentin cannot reach or see his chats, or cannot work, the fix jumps the merge order, other merges pause, and it waits only on the journeys its files own. | `tools/check-emergency-lane.mjs`, `tools/check-emergency-lane.test.mjs`, `emergency-lane.yml` |
| Every push to `master` gets a full run; only a superseded pull request run is cancelled. | `tools/ci-concurrency.test.js` reads every workflow in `.github/workflows` |
| A tab's host is the server its chat runs on: recorded at creation, carried on a reopen, never defaulted. | `tools/mp-layout-host.test.js`, `tools/mp-sessions-test.py` |
| Every servers file the repo ships names a slot per server. | `tools/check-servers-slots.mjs`, `tools/check-servers-slots.test.js` |
| Keep code comment-free. | `tools/strip-comments.mjs --check` |
| Cap Zig source files at 6000 lines; existing over-cap files may only shrink. | `tools/check-file-size.mjs`, `tools/file-size-baseline.json`; `--write` lowers limits after splits |
| Journey evidence uploads run even when a run fails or is cancelled, and no step deletes them before the upload. | `tools/check-journey-evidence.mjs` runs `tools/check-journey-evidence.test.js` in `test.yml` |
| Install Zig only through the cached, time-limited setup-zig action. | `tools/check-zig-download.mjs` |
| Do not add Sleep, std.Thread.sleep or SetTimer quick fixes; use events or messages. | `tools/check-timer-ratchet.mjs`; `--write` lowers per-file limits after removals, never raises them |
| A chat owned by another OS user starts with its own agent binary, retries a missing agent a few times, and never rotates the nightly restart inside an auto-update window. | `tools/chat-host-owner-binary.test.js` |
| Bump the extension version when shipped extension files change. | `tools/check-extension-version.mjs` |
| Never commit secrets or private information. | `secret-scan` in `.github/workflows/gitleaks.yml`; review for non-secret private information |
| Author and committer emails must be `348741585+software-factory-runners[bot]@users.noreply.github.com`, `3296316+valentinyeo@users.noreply.github.com` or `noreply@github.com`; no Co-authored-by lines. Workers use the bot identity. | `tools/check-commit-identities.mjs` checks every new commit on a pull request and on a master push in `test.yml`; the squash-merge helper strips trailers |
| Merge titles come from the PR's changelog fragments, never from a typed squash title; a key mismatch warns and publishes. | `tools/merge-title.js` builds the squash title in `tools/automerge-admit-run.js`; `tools/check-pr-title.mjs` refuses a PR title whose keys disagree with its fragments; `tools/version-stamp.mjs` and `tools/release-notes.mjs` publish with a `Release notes warning` line |
| A second OS user's hosted chat reaches its own browser pane through the current runtime CLI and the owner relay, and a stale process on the pane port is named. | `tools/owner-chat-browser.test.py` creates the second user on an Ubuntu runner and drives the delegated chat; `tools/chat-shared-runtime.test.py` proves `zsb` ships in the runtime |
| No status elements around Chat View messages. | Chat View status-free journey (IGSH-931); fails on any status text or icon under a message |
| Every verifier journey records a non-empty `journey.mp4`; screen changes keep matching BEFORE and AFTER clips on the ticket and PR. | `.claude/skills/verify-multiprompt/drive.ps1`, `tools/check-journey-evidence.mjs`, `tools/pr-verifier.cjs` |
