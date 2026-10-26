# Build and release

Use Zig 0.16 on PATH. On Windows, `zig build` produces `zig-out/bin/multiprompt.exe` and `zigshell-bridge.exe`; `zig build dev` produces a separate development app. Telemetry runs in the main executable with `--usage-telemetry`.

Linux contributors can cross-compile for either supported architecture:

```sh
zig build -Dtarget=x86_64-windows-gnu
zig build -Dtarget=aarch64-windows-gnu
```

Push the branch and read `gh pr checks`; GitHub Actions runs the Windows suite, bench and server-tool tests. Never run `tools/test-windows-wine.sh` or `tools/chat-bench/run.mjs` on the shared server. The Wine wrapper compiles ARM64, runs the Windows desktop suite and then `test-vps`; the bench launches the app under Wine. Both entry points exit 2 before starting work unless `GITHUB_ACTIONS=true` (set automatically by Actions) or `MULTIPROMPT_ALLOW_LOCAL_HEAVY=1` on a machine you own. Keep local checks lightweight, such as `node --test tools/heavy-guard.test.js`; leave builds and full test suites to GitHub Actions.

Every Tests job starts at once and first runs `tools/classify-test-paths.sh`; when a change touches only docs, changelog fragments or `tools/ci-cost.mjs`, the job skips its build and test steps, and the `test` check still reports the result. CI partitions the desktop suite into five `-Dtest-group=1` through `-Dtest-group=5` shards and the server suite into three `-Dtest-vps-group=1` through `-Dtest-vps-group=3` shards. Omitting either option runs every group in that suite. VPS shard 1 also runs the session restore fixtures. The account Worker dry-run build and Worker tests run in their own `test-worker` job. `build-windows (x64)` cross-compiles `multiprompt.exe` on Linux with `-Drelease=true`, the same command `release.yml` uses, and `test-windows-update` runs the release update tests against that exe instead of building on Windows. SSH compile fixtures run concurrently in isolated temporary directories, bounded by available CPU parallelism per file.

Master pushes bound the combined local and global Zig caches before the cache action saves: 1600 MiB on every shard. If the combined size exceeds the cap, the whole local `.zig-cache` is dropped, because Zig manifests in `.zig-cache/h` still point at any single output removed from `.zig-cache/o`; the global cache is left untouched. PRs only restore these caches. The server and desktop cache prefixes start fresh when the shard layout changes, without restoring the previous layout.

The version is `APP_VERSION` in `src/main.zig`; the title bar and the `MPVERSION` marker derive from it. End-user history is in `src/changelog.zig`. Extension changes must increase `extension/manifest.json`'s version; the native bridge reads the same version at build time.

After the release PR merges, GitHub Actions cross-builds x64 and ARM64 and publishes the new version as the latest GitHub Release, with the extension ZIP and SHA-256 checksums. Existing version tags are not republished. Keep credentials, runtime state, screenshots and build outputs out of commits. See [CONTRIBUTING.md](../../CONTRIBUTING.md) for configuration and checks.

## Automatic desktop updates

The window appears without waiting for GitHub. Checks and downloads run in the background at launch and every five minutes. Only an already staged, verified release can install at cold launch before tabs restore, and only when no other workspace window is running.

Updates accept stable releases published by `github-actions[bot]` in `valentinyeo/multiprompt`. The embedded Ed25519 public key must verify the detached `SHA256SUMS.txt.sig` before any checksums are trusted. Native ARM64 or x64 app and bridge executables and the extension ZIP must match the signed manifest exactly. Authenticode policy remains additional: a signed installation requires a valid update signature from the same publisher.

While working, updates are only staged. The sidebar notice and Ctrl+K **Restart to update** save sessions and restart on request; an active download finishes before the swap. Installation stops the old telemetry and bridge helpers and retains `<app>.previous.exe`. The new app reports ready when its window responds, including the sign-in screen; failed startup restores app, bridge, and extension files and suppresses that release. Rollback starts the old app without a readiness kill deadline. An unusually slow exit remains supervised and reopens the old app after it finishes.

Extension files are updated in the configured unpacked extension directory (or the standard existing installation), excluding `themes/current`, just as the manual installer does. Existing extension reload/self-heal remains responsible for loading those files in the browser.

Publishable builds use `zig build -Drelease=true`, which refuses the fake all-zero public key in `src/release_signing_public_key.txt`; ordinary test builds do not need signing credentials. Release publication requires `MULTIPROMPT_RELEASE_SIGNING_KEY`, a base64 raw 32-byte Ed25519 seed held only in a GitHub secret, matching the embedded public key. The release job signs and self-verifies the checksum manifest before uploading it.

`pub const IGSH_246 = true;` in `src/update_release.zig` is the default-on switch. Set the process environment variable `IGSH_246=0` to disable release checks and installs without changing the executable. The install directory must be writable; network, permission and verification failures leave the current app running. Baseline UI verification disables release updates to keep its revision fixed. The `safe-updates` journey instead uses signed local fake releases and an ephemeral job-only key to prove real staged apply, consecutive swaps and rollback.

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

## Reopen automatically reverted tasks

The Auto-revert master workflow reopens the task itself, in the same job that opens the revert pull request. Nothing runs on a server and nothing polls GitHub.

After the revert pull request is open, `tools/auto-revert-board.js` moves a Done task back to Todo (other columns stay) and posts one comment with the failed journeys and the failed run link. A retry finds the run link in the comments and posts nothing more.

GitHub calls in the job use the job's own `GITHUB_TOKEN`. The board call uses the repository secret `HYPERTASK_AGENT_TOKEN`, the "Multiprompt Auto-Revert" board agent, limited to board 2060. If the board call fails, the job opens a GitHub issue naming the task to reopen by hand and ends red.
