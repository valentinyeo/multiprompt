const app_state = @import("app_state.zig");
const std = @import("std");
const IS_DEV = @import("main.zig").IS_DEV;
const DWORD = @import("win32.zig").DWORD;
const LPARAM = @import("win32.zig").LPARAM;
const LPCWSTR = @import("win32.zig").LPCWSTR;
const LoadImageW = @import("win32.zig").LoadImageW;
const IMAGE_ICON = @import("win32.zig").IMAGE_ICON;
const LR_DEFAULTCOLOR = @import("win32.zig").LR_DEFAULTCOLOR;
const ExtractIconExW = @import("win32.zig").ExtractIconExW;
const GetModuleHandleW = @import("win32.zig").GetModuleHandleW;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const GetCommandLineA = @import("win32.zig").GetCommandLineA;
const LoadLibraryA = @import("win32.zig").LoadLibraryA;
const GetProcAddress = @import("win32.zig").GetProcAddress;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const appendDecimal = @import("diagnostics.zig").appendDecimal;

pub fn playNotificationSound() void {
    const mciFn = app_state.g_mciSendStringA orelse return;
    if (app_state.g_notify_sound_len == 0) return;
    _ = mciFn("close zignotify", null, 0, null);
    var open_cmd: [600]u8 = std.mem.zeroes([600]u8);
    const prefix = "open \"";
    @memcpy(open_cmd[0..prefix.len], prefix);
    var pos: usize = prefix.len;
    @memcpy(open_cmd[pos .. pos + app_state.g_notify_sound_len], app_state.g_notify_sound_path[0..app_state.g_notify_sound_len]);
    pos += app_state.g_notify_sound_len;
    const suffix = "\" type mpegvideo alias zignotify";
    @memcpy(open_cmd[pos .. pos + suffix.len], suffix);
    pos += suffix.len;
    open_cmd[pos] = 0;
    _ = mciFn(@ptrCast(&open_cmd), null, 0, null);
    _ = mciFn("play zignotify from 0", null, 0, null);
}

pub fn initNtdll() void {
    app_state.g_ntdll = LoadLibraryA("ntdll.dll");
    if (app_state.g_ntdll) |h| {
        app_state.g_NtQueryInformationProcess = @ptrCast(@alignCast(GetProcAddress(h, "NtQueryInformationProcess")));
    }
    const k32 = LoadLibraryA("kernel32.dll");
    if (k32) |h| {
        app_state.g_K32GetProcessMemoryInfo = @ptrCast(@alignCast(GetProcAddress(h, "K32GetProcessMemoryInfo")));
    }
    const winmm = LoadLibraryA("winmm.dll");
    if (winmm) |h| {
        app_state.g_mciSendStringA = @ptrCast(@alignCast(GetProcAddress(h, "mciSendStringA")));
    }
    const sound_len = GetEnvironmentVariableA("MULTIPROMPT_NOTIFY_SOUND", &app_state.g_notify_sound_path, app_state.g_notify_sound_path.len);
    if (sound_len > 0 and sound_len < app_state.g_notify_sound_path.len) app_state.g_notify_sound_len = sound_len;
}

pub fn L(comptime s: []const u8) LPCWSTR {
    @setEvalBranchQuota(10000);
    return std.unicode.utf8ToUtf16LeStringLiteral(s);
}

pub fn initShellIcons() void {
    _ = ExtractIconExW(L("C:\\Windows\\System32\\cmd.exe"), 0, null, &app_state.g_icon_cmd, 1);
    _ = ExtractIconExW(L("C:\\Program Files\\PowerShell\\7\\pwsh.exe"), 0, null, &app_state.g_icon_pwsh, 1);
    _ = ExtractIconExW(L("C:\\Program Files\\Git\\git-bash.exe"), 0, null, &app_state.g_icon_bash, 1);
    app_state.g_icon_codex_dot = LoadImageW(GetModuleHandleW(null), @ptrFromInt(2), IMAGE_ICON, 16, 16, LR_DEFAULTCOLOR);
}

pub fn RGB(r: u8, g: u8, b: u8) DWORD {
    return @as(DWORD, r) | (@as(DWORD, g) << 8) | (@as(DWORD, b) << 16);
}

pub fn GET_X(lp: LPARAM) i32 {
    return @as(i32, @as(i16, @truncate(lp)));
}
pub fn GET_Y(lp: LPARAM) i32 {
    return @as(i32, @as(i16, @truncate(lp >> 16)));
}

pub fn parseInstanceName() void {
    const cmdline = GetCommandLineA();
    var i: usize = 0;
    while (cmdline[i] != 0) : (i += 1) {}
    const len = i;
    if (len < 8) return;

    const haystack = cmdline[0..len];
    const needle = "--name ";
    var pos: usize = 0;
    while (pos + needle.len <= len) : (pos += 1) {
        if (std.mem.eql(u8, haystack[pos .. pos + needle.len], needle)) {
            var start = pos + needle.len;
            while (start < len and haystack[start] == ' ') start += 1;
            if (start >= len) return;
            var end = start;
            while (end < len and haystack[end] != ' ' and haystack[end] != 0) end += 1;
            const name = haystack[start..end];
            const copy_len = @min(name.len, 63);
            @memcpy(app_state.g_instance_name[0..copy_len], name[0..copy_len]);
            app_state.g_instance_name_len = @intCast(copy_len);
            app_state.g_explicit_instance_name = true;
            return;
        }
    }
}

pub fn parseNoWindowRestoreFlag() void {
    const cmdline = GetCommandLineA();
    var i: usize = 0;
    while (cmdline[i] != 0) : (i += 1) {}
    const haystack = cmdline[0..i];
    app_state.g_no_window_restore = std.mem.indexOf(u8, haystack, "--no-window-restore") != null;
}

pub fn parseEmptyWorkspaceFlag() void {
    const cmdline = GetCommandLineA();
    var i: usize = 0;
    while (cmdline[i] != 0) : (i += 1) {}
    const haystack = cmdline[0..i];
    app_state.g_empty_workspace = std.mem.indexOf(u8, haystack, "--empty-workspace") != null;
}

pub fn parseNewWindowFlag() void {
    const cmdline = GetCommandLineA();
    var i: usize = 0;
    while (cmdline[i] != 0) : (i += 1) {}
    const haystack = cmdline[0..i];
    if (std.mem.indexOf(u8, haystack, "--new-window") == null) return;
    app_state.g_no_window_restore = true;
    if (app_state.g_explicit_instance_name) return;
    var name_buf: [64]u8 = undefined;
    var pos: usize = 0;
    for ("win-") |c| {
        name_buf[pos] = c;
        pos += 1;
    }
    appendDecimal(name_buf[0..], &pos, GetTickCount64());
    const copy_len = @min(pos, app_state.g_instance_name.len - 1);
    @memcpy(app_state.g_instance_name[0..copy_len], name_buf[0..copy_len]);
    app_state.g_instance_name_len = @intCast(copy_len);
    app_state.g_instance_name[copy_len] = 0;
    app_state.g_explicit_instance_name = true;
}

pub fn parseSingleWindowFlag() void {
    const cmdline = GetCommandLineA();
    var i: usize = 0;
    while (cmdline[i] != 0) : (i += 1) {}
    const haystack = cmdline[0..i];
    app_state.g_single_window = std.mem.indexOf(u8, haystack, "--single-window") != null;
}

pub fn parseAdoptArgs() void {
    const cmdline = GetCommandLineA();
    var i: usize = 0;
    while (cmdline[i] != 0) : (i += 1) {}
    const len = i;

    const haystack = cmdline[0..len];
    const needle = "--adopt ";
    var pos: usize = 0;
    while (pos + needle.len <= len) : (pos += 1) {
        if (std.mem.eql(u8, haystack[pos .. pos + needle.len], needle)) {
            var cur = pos + needle.len;

            while (cur < len and haystack[cur] == ' ') cur += 1;

            var hwnd_val: usize = 0;
            while (cur < len and haystack[cur] >= '0' and haystack[cur] <= '9') {
                hwnd_val = hwnd_val * 10 + (haystack[cur] - '0');
                cur += 1;
            }
            app_state.g_adopt_hwnd = hwnd_val;

            while (cur < len and haystack[cur] == ' ') cur += 1;

            var pid_val: u32 = 0;
            while (cur < len and haystack[cur] >= '0' and haystack[cur] <= '9') {
                pid_val = pid_val * 10 + @as(u32, haystack[cur] - '0');
                cur += 1;
            }
            app_state.g_adopt_pid = pid_val;

            while (cur < len and haystack[cur] == ' ') cur += 1;

            if (cur < len and haystack[cur] >= '0' and haystack[cur] <= '9') {
                app_state.g_adopt_kind = haystack[cur] - '0';
                cur += 1;
            }

            while (cur < len and haystack[cur] == ' ') cur += 1;

            if (cur < len and haystack[cur] >= '0' and haystack[cur] <= '9') {
                const ns_val = haystack[cur] - '0';
                app_state.g_adopt_name_source = switch (ns_val) {
                    1 => .console_title,
                    2 => .cwd,
                    3 => .manual,
                    4 => .semantic,
                    else => .default,
                };
                cur += 1;
            }

            while (cur < len and haystack[cur] == ' ') cur += 1;

            if (cur < len and (haystack[cur] == '0' or haystack[cur] == '1')) {
                app_state.g_adopt_muted = haystack[cur] == '1';
                cur += 1;
            }

            while (cur < len and haystack[cur] == ' ') cur += 1;

            if (cur < len and (haystack[cur] == '0' or haystack[cur] == '1')) {
                app_state.g_adopt_pinned_top = haystack[cur] == '1';
                cur += 1;
                while (cur < len and haystack[cur] == ' ') cur += 1;
            }

            if (cur < len and (haystack[cur] == '0' or haystack[cur] == '1')) {
                cur += 1;
                while (cur < len and haystack[cur] == ' ') cur += 1;
            }

            if (cur < len and (haystack[cur] == '0' or haystack[cur] == '1')) {
                app_state.g_adopt_favorite = haystack[cur] == '1';
                cur += 1;
                while (cur < len and haystack[cur] == ' ') cur += 1;
            }

            const used_start = cur;
            while (cur < len and haystack[cur] >= '0' and haystack[cur] <= '9') cur += 1;
            app_state.g_adopt_last_used = std.fmt.parseInt(u64, haystack[used_start..cur], 10) catch 0;
            while (cur < len and haystack[cur] == ' ') cur += 1;

            if (cur < len and haystack[cur] == 'i') {
                cur += 1;
                const start = cur;
                while (cur < len and haystack[cur] >= '0' and haystack[cur] <= '9') cur += 1;
                app_state.g_adopt_input = std.fmt.parseInt(u64, haystack[start..cur], 10) catch 0;
                while (cur < len and haystack[cur] == ' ') cur += 1;
            }

            if (cur + 1 < len and haystack[cur] == 'v') {
                app_state.g_adopt_visits.known = if (haystack[cur + 1] == '1') 1 else 0;
                cur += 2;
                while (cur < len and haystack[cur] == '/') {
                    cur += 1;
                    const start = cur;
                    while (cur < len and haystack[cur] >= '0' and haystack[cur] <= '9') cur += 1;
                    const value = std.fmt.parseInt(u64, haystack[start..cur], 10) catch break;
                    if (value <= 9_007_199_254_740_991) app_state.g_adopt_visits.add(value);
                }
                while (cur < len and haystack[cur] == ' ') cur += 1;
            }

            if (cur < len and haystack[cur] == '"') {
                cur += 1;
                const name_start = cur;
                while (cur < len and haystack[cur] != '"') cur += 1;
                const name_end = cur;
                const nlen = @min(name_end - name_start, 63);
                @memcpy(app_state.g_adopt_name[0..nlen], haystack[name_start .. name_start + nlen]);
                app_state.g_adopt_name_len = @intCast(nlen);
                if (cur < len) cur += 1;
            }

            while (cur < len and haystack[cur] == ' ') cur += 1;

            if (cur < len and haystack[cur] == '"') {
                cur += 1;
                const cwd_start = cur;
                while (cur < len and haystack[cur] != '"') cur += 1;
                const cwd_end = cur;
                const clen = @min(cwd_end - cwd_start, 511);
                @memcpy(app_state.g_adopt_cwd[0..clen], haystack[cwd_start .. cwd_start + clen]);
                app_state.g_adopt_cwd_len = @intCast(clen);
                if (cur < len) cur += 1;
            }

            while (cur < len and haystack[cur] == ' ') cur += 1;

            if (cur < len and haystack[cur] == '"') {
                cur += 1;
                const tmux_start = cur;
                while (cur < len and haystack[cur] != '"') cur += 1;
                const tmux_end = cur;
                const tlen = @min(tmux_end - tmux_start, 63);
                @memcpy(app_state.g_adopt_tmux[0..tlen], haystack[tmux_start .. tmux_start + tlen]);
                app_state.g_adopt_tmux_len = @intCast(tlen);
                if (cur < len) cur += 1;
            }
            while (cur < len and haystack[cur] == ' ') cur += 1;
            if (cur < len and haystack[cur] == '"') {
                cur += 1;
                const identity_start = cur;
                while (cur < len and haystack[cur] != '"') cur += 1;
                const identity_len = @min(cur - identity_start, 63);
                @memcpy(app_state.g_adopt_tmux_identity[0..identity_len], haystack[identity_start .. identity_start + identity_len]);
                app_state.g_adopt_tmux_identity_len = @intCast(identity_len);
            }

            return;
        }
    }
}

pub fn getInstanceName() []const u8 {
    if (app_state.g_instance_name_len == 0) {
        if (IS_DEV) return "dev";
        return "default";
    }
    return app_state.g_instance_name[0..app_state.g_instance_name_len];
}

pub fn buildWindowTitle(buf: *[256]u16) LPCWSTR {
    const title = "Multi Bot";
    for (title, 0..) |c, i| buf[i] = c;
    buf[title.len] = 0;
    return @ptrCast(buf);
}
