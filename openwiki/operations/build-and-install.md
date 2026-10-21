# Build and release

Use Zig 0.16 on PATH. On Windows, `zig build` produces `zig-out/bin/multiprompt.exe` and `zigshell-bridge.exe`; `zig build dev` produces a separate development app. Telemetry runs in the main executable with `--usage-telemetry`.

Linux contributors can cross-compile for either supported architecture:

```sh
zig build -Dtarget=x86_64-windows-gnu
zig build -Dtarget=aarch64-windows-gnu
```

Push the branch and read `gh pr checks`; GitHub Actions runs the Windows suite, bench tests and server-tool tests. Never run `tools/test-windows-wine.sh` or `tools/chat-bench/run.mjs` on the shared server. The Wine wrapper compiles ARM64, runs the Windows desktop suite and then `test-vps`; the bench launches the app under Wine. Both entry points exit 2 before starting work unless `GITHUB_ACTIONS=true` (set automatically by Actions) or `MULTIPROMPT_ALLOW_LOCAL_HEAVY=1` on a machine you own. Keep local checks lightweight, such as `node --test tools/heavy-guard.test.js`; leave builds and full test suites to GitHub Actions.

The version is `APP_VERSION` in `src/main.zig`; the title bar and the `MPVERSION` marker derive from it. End-user history is in `src/changelog.zig`. Extension changes must increase `extension/manifest.json`'s version; the native bridge reads the same version at build time.

After the release PR merges, GitHub Actions cross-builds x64 and ARM64 and publishes the new version as the latest GitHub Release, with the extension ZIP and SHA-256 checksums. Existing version tags are not republished. Keep credentials, runtime state, screenshots and build outputs out of commits. See [CONTRIBUTING.md](../../CONTRIBUTING.md) for configuration and checks.

## Install a release

Never compile on the laptop. Run the installer on Linux with `gh`, `lh`, Node and a default-config passing bench receipt for the exact released x64 executable:

```sh
tools/install-laptop1.sh --release latest --bench <results.json>
tools/install-laptop1.sh --release vX.Y.Z --bench <results.json>
tools/install-laptop1.sh --extension-only --release vX.Y.Z
```

The installer downloads assets from `valentinyeo/multiprompt`, verifies GitHub asset digests and `SHA256SUMS.txt`, validates the bench receipt, then uploads and hashes the PC copies. It trusts the published version tag; no source checkout is needed on the PC. Before uploading, it reads the installed exe’s `MPVERSION` marker (falling back to file version, then embedded title) and refuses equal, older, or unreadable versions unless `--allow-downgrade` is passed; `--extension-only` skips this check. The running exe is renamed aside with the existing backup retention, not restarted. The extension ZIP is expanded into the app's extension folder without replacing `themes/current`. A running Zig process before or after installation fails the install; a successful install prints `NO_ZIG_ON_LAPTOP <tag>` and `EXTENSION_OK`.

The bridge now makes the running extension reload itself when it sees the installed bridge's newer version; the installer falls back to `extension-reload` and polling only if the first check fails.

### Get a GitHub bench receipt for a release

The chat bench runs on GitHub Actions, using Linux/Wine in WSL2 on `windows-latest`, not native Windows acceptance. Dispatch both A/B slots for the release you want to install. One run per slot is enough for an installable receipt: each run uses the full default config, not smoke settings.

```sh
tag=v0.28.789
gh workflow run chat-bench-ab.yml --repo valentinyeo/multiprompt --ref master -f tag_a="$tag" -f tag_b="$tag" -f runs=1
gh run list --repo valentinyeo/multiprompt --workflow chat-bench-ab.yml --event workflow_dispatch --limit 5
```

Take the run ID matching your dispatch, then watch and download its evidence:

```sh
run_id=<run-id>
gh run watch "$run_id" --repo valentinyeo/multiprompt --interval 60 --exit-status
gh run download "$run_id" --repo valentinyeo/multiprompt --name chat-bench-ab --dir "bench-$tag"
```

A successful workflow or A/B summary does not guarantee a PASS receipt. Use the artifact's manifest to find a clean PASS `results.json` for the requested tag:

```sh
node --input-type=module - "bench-$tag" "$tag" <<'NODE'
import fs from 'node:fs';
import path from 'node:path';
const [dir, tag] = process.argv.slice(2);
const passes = JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json'), 'utf8'))
  .filter(entry => entry.tag === tag)
  .map(entry => path.join(dir, entry.path))
  .filter(file => {
    const run = JSON.parse(fs.readFileSync(file, 'utf8'));
    return run.binary?.version === tag.slice(1) && run.status === 'PASS' && run.pass === true && Array.isArray(run.failures) && run.failures.length === 0;
  });
if (!passes.length) throw new Error(`No clean PASS receipt for ${tag}`);
console.log(passes.join('\n'));
NODE
```

Install with a printed path, for example:

```sh
tools/install-laptop1.sh --release "$tag" --bench "bench-$tag/runs/A-$tag-1/results.json"
```

If only B passed, use its printed path instead. The installer validates the receipt against the release executable it downloaded and SHA-checked, not the GitHub runner's recorded executable path. It leaves the original receipt unchanged and still rejects mismatched executable hashes, non-default configs, stale runner hashes, invalid PE files and failed or incomplete verdicts. The artifact records its bench tooling revision in `tooling-commit.txt`; if bench tooling changes, obtain a fresh receipt rather than weakening runner-hash checks.

### Wine rendering prerequisite

Wine's built-in GDI+ accepts smoothing settings without anti-aliasing shapes. The Windows test runner therefore requires the Microsoft x64 `gdiplus.dll`, available from a licensed Windows installation or Microsoft's redistributable through Winetricks. Put it in `${XDG_CACHE_HOME:-$HOME/.cache}/multiprompt/gdiplus/gdiplus.dll`, or set `MP_WINE_GDIPLUS_DIR` to its directory. The runner installs that DLL into an isolated `${XDG_CACHE_HOME:-$HOME/.cache}/multiprompt/wine-tests` prefix, overridable with `MP_WINE_TEST_PREFIX`; it does not alter your normal Wine prefix. No Windows DLL is distributed in this repository. Headless runs also require `xvfb-run`.
