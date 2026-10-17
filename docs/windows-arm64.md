# Windows ARM64 builds

Cross-compile from Windows with Zig 0.16.0:

```powershell
zig build -Dtarget=aarch64-windows -Doptimize=ReleaseSmall --prefix zig-out-arm64
```

The output includes ARM64 versions of `multiprompt.exe`, `multiprompt-dev.exe`,
and `zigshell-bridge.exe`. Telemetry is included in the main executable and
runs headlessly with `--usage-telemetry`; there is no telemetry file to copy.
Keep the main executable and browser bridge together. A portable archive should retain the `zig-out/bin`
layout, include the extension's runtime JavaScript and theme manifests, and
include the telemetry reconnect script and example configuration under
`tools/usage-telemetry`. Never include local configuration, credentials, SSH
keys, runtime session data, or Chromium's generated theme caches.

Extract the archive on the ARM laptop and run `zig-out/bin/multiprompt.exe`.
Configure SSH and browser extension/native-host integration on that computer.
The optional internal WebView2 DLL is not included in the ARM preview.

The September 8 preview cross-compiled successfully and all shipped executable
PE headers identify ARM64. Startup, console input, shortcuts, SSH and browser
docking still require testing on actual ARM hardware.
