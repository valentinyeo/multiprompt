# Dev rig on the laptop

Goal: prove a Multiprompt fix on the real Windows app with the real account and server before it ships.

## Build

`.github/workflows/dev-build.yml` cross-compiles `zig build dev -Dtarget=x86_64-windows-gnu` on
ubuntu-latest for every push to `master` (and on demand with a `ref` input) and uploads the
`multiprompt-dev` artifact: `multiprompt-dev.exe`, `zigshell-bridge.exe`, `SHA256SUMS.txt`.

## Install and drive

`tools/dev-laptop.sh` talks to the laptop over `lh` (PowerShell in the interactive desktop session):

- `install [run-id|latest]` - downloads the artifact, uploads the exe to
  `%LOCALAPPDATA%\MultipromptDev` in 120 KB base64 chunks, stops only `multiprompt-dev` processes
  whose path is inside that folder, and swaps in the new exe. His normal `multiprompt.exe` is never
  matched.
- `place` - starts the dev exe and moves its `MultipromptDevWindow` window maximised onto the second
  monitor (X=-2560, Y=-493, 2048x1280).
- `journey ctrl-t` - `tools/dev-laptop-journey.sh`: presses Ctrl+T, types `say ok`, sends it, then
  waits up to 90 s for a reply in the newest transcript and reports the tmux sessions it created.
  Every keystroke first checks the foreground window class is `MultipromptDevWindow`; otherwise it
  aborts without typing.
- `shot <name>` - PrintWindow of the dev window only.
- `cleanup <term names...>` - kills only the tmux sessions named on the command line.

## Status

The dev exe currently exits with code 0 a few seconds after launch on the laptop: it creates no
`ZigShellDev` data folder, no crash report and writes nothing to stderr, so no dev window appears and
the journey cannot start. Next diagnostic step is to capture the early-exit path in `main.zig`'s
`IS_DEV` startup (single-instance receiver or session restore) with a console/stdout capture.
