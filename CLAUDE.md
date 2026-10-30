# multiprompt

A lean Windows workspace, written in Zig 0.16, that hosts native console windows in vertical session tabs instead of rendering a terminal. Start with [`openwiki/index.md`](openwiki/index.md). Design and features: [openwiki/architecture/features.md](openwiki/architecture/features.md). Win32 pitfalls: [openwiki/architecture/win32-gotchas.md](openwiki/architecture/win32-gotchas.md). Browser routing: [openwiki/browser/routing-state-machine.md](openwiki/browser/routing-state-machine.md).

This public repo is where Multiprompt is developed, checked and released. GitHub Actions run free here; never add a workflow to a private repo instead.

## Build, test, ship

Full procedure and toolchain notes: [openwiki/operations/build-and-install.md](openwiki/operations/build-and-install.md).

- Hard blockers interrupt PRs and tickets. If Valentin cannot work, publish a replacement. Then resume the queue.
- Follow the solo-dev skill's work order.
- Drain existing PRs first. Do not open new PRs.
- Commit small units directly to `master`. Include a one-line undo. Add it to each commit.
- Never build or test on shared servers. This includes lightweight tests. Use GitHub-hosted public CI only.
- Each `master` push starts a release. CI builds x64 and arm64. The built x64 app must launch. Its main window must appear within five minutes. Gitleaks blocks publication on failure. CI signs and publishes the assets.
- Other checks run nightly or manually. They report only. Automatic revert is disabled. The built release must launch. If it fails, revert the change immediately. Revert it manually.
- Add `changelog.d/<TICKET>-<slug>.md` fragments (see `changelog.d/README.md`). Commit as `<TICKET>: Brief description`. CI stamps versions. Never hand-edit app versions.
- Release updates reach users via the in-app updater. Never compile on the laptop.
- Every extension change (`bridge.js`, manifest) bumps `"version"` in `extension/manifest.json`, independent of the app version. The extension-version check fails a PR that changes shipped files in `extension/` without a bump.
- Everything here is public: never commit keys, private host names, internal paths, emails or private messages. The secret-scan check runs on every PR.
- Ticket board: https://app.hypertask.ai/project?id=2060 (prefix `IGSH`).

## Hard rules

- Every inner reader edit increments `RUNTIME_GENERATION` in `src/chat_history_reader.py`. See [runtime contract](openwiki/operations/chat-shared-runtime.md).
- Fundamental shared changes need Android tickets. This includes chat, sessions, and sync. Create or update one paired ticket first. Link both tickets in both directions. Reuse board 2060's Multiprompt Android label. Record old and new client compatibility. Verify both clients before declaring Done. Existing release gates remain unchanged.
- **Never restart multiprompt without asking the user.** Use the in-app updater.
- **Never compile on the laptop.** Use the in-app updater.
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
| Never hand-edit app versions; CI stamps versions. | `tools/version-stamp.mjs check` in `test.yml` |
| Keep code comment-free. | `tools/strip-comments.mjs --check` |
| Bump the extension version when shipped extension files change. | `tools/check-extension-version.mjs` |
| Never commit secrets or private information. | `secret-scan` in `.github/workflows/gitleaks.yml`; review for non-secret private information |
| No status elements around Chat View messages. | Chat View status-free journey (IGSH-931); fails on any status text or icon under a message |
