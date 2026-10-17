# multiprompt

A lean Windows workspace for prompting, watching and coordinating many AI agent sessions at once. Written in Zig.

multiprompt does not draw a terminal. Each tab hosts a real native console window (cmd, PowerShell, ssh, tmux) in the right pane, and the left sidebar keeps every session organized: which agent is working, which one is waiting for you, and which one finished.

Website: https://multiprompt.dev

## Why

Windows Terminal costs about 30 to 50 MB per window. A raw console costs 2 to 3 MB. With ten agent shells open, the difference adds up.

| | RAM |
|---|---|
| multiprompt itself | about 1 MB |
| Each shell | 2 to 3 MB |
| 10 shells in multiprompt | 25 to 30 MB |
| 10 tabs in Windows Terminal | 300 to 500 MB |

## Features

- Vertical tabs with readable two-line titles, drag to reorder
- Activity spinner while an agent works, and a blue dot when it is waiting for you
- Cross-workspace inbox (Ctrl+Shift+I) for every session in every window
- Ctrl+K command palette for every action, F1 for every shortcut
- Sessions restore after a restart, including tmux tabs on remote machines

Full shortcut list: [openwiki/operations/keyboard-shortcuts.md](openwiki/operations/keyboard-shortcuts.md)

## Install

1. Open the [Releases](../../releases) page and download `multiprompt-x64.exe` (most PCs) or `multiprompt-arm64.exe` (Snapdragon laptops).
2. Rename it to `multiprompt.exe`, put it in a folder of your choice and run it. No installer is needed.

Requires Windows 10 or 11.

## Build from source

Requires [Zig 0.16.0](https://ziglang.org/download/).

On Windows:

```
zig build
```

From Linux or macOS, cross-compile:

```
zig build -Dtarget=x86_64-windows-gnu
zig build -Dtarget=aarch64-windows-gnu
```

The app lands in `zig-out/bin/multiprompt.exe`.

## Contributing

Bug reports and ideas are welcome as GitHub issues. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

Windows only for interactive use. For local development without the optional account service, set `MULTIPROMPT_NO_LOGIN=1` before launching. Remote host slots require your own SSH configuration; see [CONTRIBUTING.md](CONTRIBUTING.md).

[Android companion](https://github.com/valentinyeo/multiprompt-android) · [Optional self-hosted service](service/README.md)

## License

[MIT](LICENSE), copyright 2026 Valentin Yeo. Bundled components retain their own licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
