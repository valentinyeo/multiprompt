---
type: Architecture
title: Zig 0.16 and Win32 gotchas
description: Platform pitfalls when building multiprompt.
tags:
  - zig
  - win32
updated: 2026-10-16
---

# Zig 0.16 and Win32 gotchas

- `std.os.windows.WINAPI` doesn't exist — use `const WINAPI: std.builtin.CallingConvention = .winapi;`
- `std.net` TCP server crashes on Windows (`ReadFile` param error) — use raw Winsock (`ws2_32`) instead
- Many `L()` (utf8ToUtf16LeStringLiteral) calls exhaust comptime branch limit — add `@setEvalBranchQuota(10000)` inside the helper
- Windows GUI subsystem: `exe.subsystem = .Windows` (capital W) in build.zig
- Cross-process focus (reparented console): `SetFocus` alone fails — use `keybd_event(VK_MENU)` + `AttachThreadInput` + `SetForegroundWindow`
- Keyboard hook (`WH_KEYBOARD_LL`): `GetForegroundWindow()` returns the console HWND when console has focus, not the parent — check against all shell HWNDs
- `taskkill` in bash: use `//f //im` (bash eats single `/`)
- Shell activity detection: process tree doesn't work (conhost always a child, tools persist when idle). Window title polling doesn't work for SSH/tmux (title never changes). Use `AttachConsole` + `ReadConsoleOutputCharacterW` to hash screen buffer content — works for both local and remote shells.
- Console cursor position (`GetConsoleScreenBufferInfo`) alone fails for SSH/tmux because they use alternate screen buffer — cursor stays at (0,0). Must read actual character content.
- Reparenting round-trip: `SetParent(hwnd, null)` then later `SetParent(hwnd, new_parent)` loses `WS_CHILD` and regains `WS_CAPTION | WS_THICKFRAME | WS_BORDER`. Must reapply style stripping + `SWP_FRAMECHANGED` on every reparent, not just the first time.
- `AttachConsole(pid)` for reading other processes' consoles: call `FreeConsole()` first (even for GUI apps), can only attach to one console at a time — cycle through shells sequentially
- `NtQueryInformationProcess` must be loaded at runtime via `LoadLibraryA("ntdll.dll")` + `GetProcAddress` — can't link ntdll directly in Zig
- GDI has no alpha blending for solid brushes — gradient fade effects require `AlphaBlend` with memory DCs. Solid rect overlays don't work for text fade-out.
- `FindWindowW` by title fails when `cmd.exe /K <command>` changes the console title before the poll loop finds it. Use `findConsoleWindowByPid()` (EnumWindows + GetWindowThreadProcessId + class match "ConsoleWindowClass") as fallback.
- Taskbar icon size: `LoadIconW` only loads 32x32. Must use `LoadImageW(hInst, @ptrFromInt(1), IMAGE_ICON, 256, 256, LR_DEFAULTCOLOR)` + `SendMessageW(hwnd, WM_SETICON, ICON_BIG, ...)` for full-size taskbar icons. Icons with transparent corners appear smaller — fill the full pixel space.
- Activity detection conflict: `pollActivity` title-change detection and `pollShellNames` subtitle updates both write to `last_title`. For tmux/vps tabs, disable title-change activity detection — use screen hash only.
- Shell struct has TWO initialization sites: `empty_shell` constant AND the struct literal in `spawnShellWithSession()`. New fields must be added to both or Zig will error.
- Muted tabs (`shells[i].muted`): persisted in session JSON, must force `.activity = .idle` on restore
- Orphan processes: `taskkill /f` during dev rebuilds can leak ssh.exe/cmd.exe if Job Object doesn't catch them. `cleanupStaleWindows()` runs after session restore — kills remaining "ZigShell-*" top-level windows via `killProcessTree`. For manual cleanup: check PIDs in session.json against running ssh.exe/cmd.exe processes.
- Startup order matters: `cleanupStaleWindows()` must run AFTER `restoreSession()` — it kills all "ZigShell-*" windows via `EnumWindows`, which would destroy keep-alive shells before reclaim. After reclaim, reparented children don't appear in `EnumWindows`.
- GDI `Ellipse` at radius ≤3px renders as a diamond shape due to aliasing — use 4px+ for circles that look round.
- `SetConsoleScreenBufferInfoEx` resets the console font to a built-in default (usually Consolas ~8pt), ignoring the user's `HKCU\Console` preferences. Documented MS bug — always bracket the call with `GetCurrentConsoleFontEx` / `SetCurrentConsoleFontEx` to capture-then-restore `CONSOLE_FONT_INFOEX`, or the user's configured face/size silently disappears.
