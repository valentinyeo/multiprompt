# Build and release

Use Zig 0.16 on PATH. On Windows, `zig build` produces `zig-out/bin/multiprompt.exe` and `zigshell-bridge.exe`; `zig build dev` produces a separate development app. Telemetry runs in the main executable with `--usage-telemetry`.

Linux contributors can cross-compile for either supported architecture:

```sh
zig build -Dtarget=x86_64-windows-gnu
zig build -Dtarget=aarch64-windows-gnu
```

Run `zig build test-vps --summary all` for server tools and `python3 tools/public_audit.py --verify` for portable checks. On Linux, `zig build test` is only the server graph; run `tools/test-windows-wine.sh` (Wine, `python3` and PowerShell needed) to run `zig build test-desktop -Dtarget=x86_64-windows-gnu -fwine` then `zig build test-vps --summary all` before opening a pull request. GUI, browser, clipboard and focus acceptance requires Windows. Never replace a running installation or its session data without the operator's permission.

The version is `APP_VERSION` in `src/main.zig`; the title bar and the `MPVERSION` marker derive from it. End-user history is in `src/changelog.zig`. Extension changes must increase `extension/manifest.json`'s version; the native bridge reads the same version at build time.

The release workflow cross-builds x64 and ARM64 artifacts and prepares a draft release. Keep credentials, runtime state, screenshots and build outputs out of commits. See [CONTRIBUTING.md](../../CONTRIBUTING.md) for configuration and checks.

The bridge now makes the running extension reload itself when it sees the installed bridge's newer version; the installer falls back to `extension-reload` and polling only if the first check fails.
