# multiprompt

A lean Windows workspace, written in Zig 0.16, that hosts native console windows in vertical session tabs instead of rendering a terminal. Start with [`openwiki/index.md`](openwiki/index.md). Design and features: [openwiki/architecture/features.md](openwiki/architecture/features.md). Win32 pitfalls: [openwiki/architecture/win32-gotchas.md](openwiki/architecture/win32-gotchas.md). Browser routing: [openwiki/browser/routing-state-machine.md](openwiki/browser/routing-state-machine.md).

This public repo is where Multiprompt is developed, checked and released. GitHub Actions run free here; never add a workflow to a private repo instead.

## Build, test, ship

Full procedure and toolchain notes: [openwiki/operations/build-and-install.md](openwiki/operations/build-and-install.md).

- Build locally for development only: `zig build` on a Windows development machine. On Linux, cross-compile: `zig build -Dtarget=x86_64-windows-gnu` (ARM64: `-Dtarget=aarch64-windows-gnu`). `zig build dev` builds the DEV channel for big or risky changes only.
- Test: push the branch and read `gh pr checks`; GitHub Actions runs the Windows suite and bench. Never run `tools/test-windows-wine.sh` or `tools/chat-bench/run.mjs` on the shared server. Both require GitHub Actions or `MULTIPROMPT_ALLOW_LOCAL_HEAVY=1` on a machine you own. Run only lightweight `node --test tools/<name>.test.js` checks locally.
- Never bump the version in a PR: add `changelog.d/<TICKET>-<slug>.md` (see `changelog.d/README.md`), commit as `<TICKET>: Brief description`, and stop there. The `auto-release` workflow stamps and publishes the next version from green master on its own. Never run `node tools/version-stamp.mjs release` or open a release PR by hand; it can propose a version lower than the published one. CI fails a PR that edits `APP_VERSION` or a `.ver` line by hand.
- Releases are built and published by GitHub Actions after the release PR merges. Install from Linux with `tools/install-laptop1.sh --release latest --bench <results.json>`; never compile on the laptop.
- Every extension change (`bridge.js`, manifest) bumps `"version"` in `extension/manifest.json`, independent of the app version. The extension-version check fails a PR that changes shipped files in `extension/` without a bump.
- Everything here is public: never commit keys, private host names, internal paths, emails or private messages. The secret-scan check runs on every PR.
- Ticket board: https://app.hypertask.ai/project?id=2060 (prefix `IGSH`).

## Hard rules

- **Never restart multiprompt on a user's machine without asking.** Install by renaming the running exe aside and copying the new build in; the app shows a Relaunch card.
- **Never compile on the laptop.** Install verified GitHub Release assets from Linux.
- **Every user-facing feature ships on all three surfaces in the same version:** a keyboard shortcut (when sensible), a Ctrl+K palette entry, and a row in `SHORTCUT_ROWS` (`src/shortcuts.zig`) plus `openwiki/operations/keyboard-shortcuts.md`. Tab actions also go in the tab-context palette band (7100+). `tools/palette-rows.test.js` and `tools/shortcuts-doc.test.js` fail on drift (regenerate with `node tools/shortcuts-doc.mjs`).
- **Changelog fragments are for the end user:** one short plain sentence per line, no internal names. Engineering detail goes in the commit message.
- **Never use Ctrl+Alt shortcuts** (AltGr on US-International layouts).
- The browser extension targets Chrome and loads unpacked from `extension/`.
- **The Chat View shows no status elements around messages:** no sending clock, "Sending...", read checks, ETA, model or capacity badges. Only a real send failure may show. Valentin removed these one by one; do not add new ones.
- Keep this file under 80 lines.

## Rules and what enforces them

| Rule | Enforced by |
| --- | --- |
| Allocate distinct routing IDs outside registered dynamic bands. | `tools/check-routing-ids.mjs`, `tools/routing-id-bands.json` |
| Snapshot regression inputs in `tools/fixtures/<ticket>/`, not Git history. | `tools/check-regression-inputs.mjs` (new reads in PR diffs) |
| Do not bind PowerShell host-owned variables or name functions after aliases. | `tools/check-powershell-host-names.ps1` |
| Keep palette, tab actions and shortcut documentation aligned. | `tools/palette-rows.test.js`, `tools/shortcuts-doc.test.js` |
| Never hand-edit app versions; stamp after merge. | `tools/version-stamp.mjs check` in `test.yml` |
| Keep code comment-free. | `tools/strip-comments.mjs --check` |
| Bump the extension version when shipped extension files change. | `tools/check-extension-version.mjs` |
| Never commit secrets or private information. | `secret-scan` in `.github/workflows/gitleaks.yml`; review for non-secret private information |
| No status elements around Chat View messages. | Chat View status-free journey (IGSH-931); fails on any status text or icon under a message |
