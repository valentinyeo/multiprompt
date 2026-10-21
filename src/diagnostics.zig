const app_state = @import("app_state.zig");
const std = @import("std");
const HANDLE = @import("win32.zig").HANDLE;
const SYSTEMTIME = @import("win32.zig").SYSTEMTIME;
const Sleep = @import("win32.zig").Sleep;
const CloseHandle = @import("win32.zig").CloseHandle;
const GetFileSizeEx = @import("win32.zig").GetFileSizeEx;
const MoveFileExW = @import("win32.zig").MoveFileExW;
const MOVEFILE_REPLACE_EXISTING = @import("win32.zig").MOVEFILE_REPLACE_EXISTING;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const GetLocalTime = @import("win32.zig").GetLocalTime;
const getInstanceName = @import("startup.zig").getInstanceName;
const remoteHostForShell = @import("capacity.zig").remoteHostForShell;
const tmuxHostLongLabel = @import("capacity.zig").tmuxHostLongLabel;
const getSessionDir = @import("session.zig").getSessionDir;
const win32OpenAppend = @import("file_io.zig").win32OpenAppend;
const win32WidePath = @import("file_io.zig").win32WidePath;
const win32WriteAll = @import("file_io.zig").win32WriteAll;
const win32MakeDir = @import("file_io.zig").win32MakeDir;

pub fn verboseLoggingEnabled() bool {
    if (!app_state.g_verbose_logging_known) {
        var buf: [16]u8 = undefined;
        const len = GetEnvironmentVariableA("ZIGSHELL_DEBUG", &buf, buf.len);
        app_state.g_verbose_logging_enabled = len > 0 and len < buf.len and
            (buf[0] == '1' or buf[0] == 'y' or buf[0] == 'Y' or buf[0] == 't' or buf[0] == 'T');
        app_state.g_verbose_logging_known = true;
    }
    return app_state.g_verbose_logging_enabled;
}

fn getLogPath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 500) return null;
    const rest = "\\ZigShell\\debug.log";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

fn getSessionAuditPath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 470) return null;
    const inst = getInstanceName();
    if (std.mem.eql(u8, inst, "default")) {
        const rest = "\\ZigShell\\session-audit.log";
        @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
        return buf[0 .. appdata_len + rest.len];
    } else {
        const prefix = "\\ZigShell\\session-audit-";
        const suffix = ".log";
        var pos: usize = appdata_len;
        @memcpy(buf[pos .. pos + prefix.len], prefix);
        pos += prefix.len;
        @memcpy(buf[pos .. pos + inst.len], inst);
        pos += inst.len;
        @memcpy(buf[pos .. pos + suffix.len], suffix);
        pos += suffix.len;
        return buf[0..pos];
    }
}

pub fn getSessionAuditPathForWorkspace(buf: *[512]u8, id: []const u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 470) return null;
    if (std.mem.eql(u8, id, "default")) {
        const rest = "\\ZigShell\\session-audit.log";
        @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
        return buf[0 .. appdata_len + rest.len];
    } else {
        const prefix = "\\ZigShell\\session-audit-";
        const suffix = ".log";
        if (appdata_len + prefix.len + id.len + suffix.len >= buf.len) return null;
        var pos: usize = appdata_len;
        @memcpy(buf[pos .. pos + prefix.len], prefix);
        pos += prefix.len;
        @memcpy(buf[pos .. pos + id.len], id);
        pos += id.len;
        @memcpy(buf[pos .. pos + suffix.len], suffix);
        pos += suffix.len;
        return buf[0..pos];
    }
}

pub fn debugLog(msg: []const u8) void {
    if (!verboseLoggingEnabled() and !std.mem.startsWith(u8, msg, "[consolefont] ")) return;
    while (!app_state.g_debug_log_mutex.tryLock()) Sleep(1);
    defer app_state.g_debug_log_mutex.unlock();
    var path_buf: [512]u8 = undefined;
    const path = getLogPath(&path_buf) orelse return;
    const h = openAppendRotating(path) orelse return;
    defer _ = CloseHandle(h);
    var st: SYSTEMTIME = undefined;
    GetLocalTime(&st);
    var timestamp_buf: [23]u8 = undefined;
    const timestamp = formatLogTimestamp(&timestamp_buf, st) orelse return;
    var buf: [4096]u8 = undefined;
    if (buildDebugLine(&buf, timestamp, msg)) |line| {
        win32WriteAll(h, line);
    } else {
        @memcpy(buf[0..timestamp.len], timestamp);
        buf[timestamp.len] = ' ';
        win32WriteAll(h, buf[0 .. timestamp.len + 1]);
        var pos: usize = 0;
        while (pos < msg.len) {
            const len = @min(buf.len, msg.len - pos);
            for (msg[pos .. pos + len], 0..) |c, i| {
                buf[i] = if (c == '\r' or c == '\n') ' ' else c;
            }
            win32WriteAll(h, buf[0..len]);
            pos += len;
        }
        win32WriteAll(h, "\n");
    }
}

fn buildDebugLine(buf: []u8, timestamp: []const u8, msg: []const u8) ?[]const u8 {
    if (timestamp.len > buf.len or buf.len - timestamp.len < 2 or
        msg.len > buf.len - timestamp.len - 2) return null;
    @memcpy(buf[0..timestamp.len], timestamp);
    buf[timestamp.len] = ' ';
    const start = timestamp.len + 1;
    for (msg, 0..) |c, i| {
        buf[start + i] = if (c == '\r' or c == '\n') ' ' else c;
    }
    const end = start + msg.len;
    buf[end] = '\n';
    return buf[0 .. end + 1];
}

test "debug line has a timestamp and only a final newline" {
    var buf: [128]u8 = undefined;
    const timestamp = "2026-10-18 03:04:05.067";
    const line = buildDebugLine(&buf, timestamp, "first\r\nsecond\nthird\rlast") orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.startsWith(u8, line, timestamp ++ " "));
    try std.testing.expectEqualStrings(timestamp ++ " first  second third last\n", line);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, line, "\n"));
    try std.testing.expectEqual(@as(u8, '\n'), line[line.len - 1]);
    try std.testing.expectEqual(@as(usize, 0), std.mem.count(u8, line, "\r"));
}

test "debug line requires room for the complete message and final newline" {
    const timestamp = "2026-10-18 03:04:05.067";
    var buf: [28]u8 = undefined;
    try std.testing.expectEqualStrings(timestamp ++ " abc\n", buildDebugLine(&buf, timestamp, "abc").?);
    try std.testing.expect(buildDebugLine(buf[0..27], timestamp, "abc") == null);
    try std.testing.expect(buildDebugLine(buf[0..24], timestamp, "") == null);
    try std.testing.expect(buildDebugLine(buf[0..0], timestamp, "") == null);
    try std.testing.expectEqualStrings(timestamp ++ " \n", buildDebugLine(buf[0..25], timestamp, "").?);
}

pub fn browserTrace(reason: []const u8) void {
    if (!verboseLoggingEnabled()) return;
    var buf: [160]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, "[bt {d}] {s}", .{ GetTickCount64() & 0xFFFFFF, reason }) catch return;
    debugLog(line);
}
pub fn browserTraceN(reason: []const u8, n: i64) void {
    if (!verboseLoggingEnabled()) return;
    var buf: [176]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, "[bt {d}] {s} {d}", .{ GetTickCount64() & 0xFFFFFF, reason, n }) catch return;
    debugLog(line);
}

pub fn altqLog(comptime fmt: []const u8, args: anytype) void {
    if (!verboseLoggingEnabled()) return;
    var buf: [320]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, "[altq] " ++ fmt, args) catch return;
    debugLog(line);
}

pub fn altqPtr(h: HANDLE) usize {
    return if (h) |p| @intFromPtr(p) else 0;
}

pub fn debugLog2(prefix: []const u8, value: []const u8) void {
    if (!verboseLoggingEnabled()) return;
    var buf: [512]u8 = undefined;
    if (prefix.len + value.len + 2 > buf.len) return;
    @memcpy(buf[0..prefix.len], prefix);
    @memcpy(buf[prefix.len .. prefix.len + value.len], value);
    debugLog(buf[0 .. prefix.len + value.len]);
}

pub fn formatLogTimestamp(buf: []u8, st: SYSTEMTIME) ?[]const u8 {
    return std.fmt.bufPrint(
        buf,
        "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}",
        .{ st.year, st.month, st.day, st.hour, st.minute, st.second, st.milliseconds },
    ) catch null;
}

test "log timestamp formats local date and time with milliseconds" {
    const st: SYSTEMTIME = .{
        .year = 2026,
        .month = 10,
        .day_of_week = 0,
        .day = 18,
        .hour = 3,
        .minute = 4,
        .second = 5,
        .milliseconds = 67,
    };
    var buf: [23]u8 = undefined;
    try std.testing.expectEqualStrings("2026-10-18 03:04:05.067", formatLogTimestamp(&buf, st).?);
    try std.testing.expect(formatLogTimestamp(buf[0..22], st) == null);
}

fn writeAuditTimestamp(h: HANDLE) void {
    var st: SYSTEMTIME = undefined;
    GetLocalTime(&st);
    var buf: [64]u8 = undefined;
    const s = formatLogTimestamp(&buf, st) orelse return;
    win32WriteAll(h, s);
}

pub fn writeAuditEscapedBytes(h: HANDLE, bytes: []const u8) void {
    for (bytes) |c| {
        switch (c) {
            '\\' => win32WriteAll(h, "\\\\"),
            '"' => win32WriteAll(h, "\\\""),
            '\r' => win32WriteAll(h, "\\r"),
            '\n' => win32WriteAll(h, "\\n"),
            else => {
                var b = [_]u8{c};
                win32WriteAll(h, &b);
            },
        }
    }
}

pub fn writeAuditEscapedWideAscii(h: HANDLE, chars: []const u16) void {
    for (chars) |wc| {
        const c: u8 = if (wc >= 32 and wc <= 126) @intCast(wc) else '?';
        writeAuditEscapedBytes(h, (&[_]u8{c})[0..]);
    }
}

pub fn writeAuditU64(h: HANDLE, value: u64) void {
    var buf: [24]u8 = undefined;
    var pos: usize = 0;
    appendDecimal(&buf, &pos, value);
    win32WriteAll(h, buf[0..pos]);
}

pub fn logNeedsRotate(size: u64) bool {
    return size > 20 * 1024 * 1024;
}

test "logs rotate only above twenty MiB" {
    try std.testing.expect(!logNeedsRotate(0));
    try std.testing.expect(!logNeedsRotate(20 * 1024 * 1024));
    try std.testing.expect(logNeedsRotate(20 * 1024 * 1024 + 1));
    try std.testing.expect(logNeedsRotate(std.math.maxInt(u64)));
}

pub fn openSessionAudit() ?HANDLE {
    var dir_buf: [512]u8 = undefined;
    if (getSessionDir(&dir_buf)) |dir| {
        win32MakeDir(dir);
    }
    var path_buf: [512]u8 = undefined;
    const path = getSessionAuditPath(&path_buf) orelse return null;
    return openAppendRotating(path);
}

fn openAppendRotating(path: []const u8) ?HANDLE {
    const h = win32OpenAppend(path) orelse return null;
    var size: i64 = 0;
    if (GetFileSizeEx(h, &size) != 0 and size >= 0 and logNeedsRotate(@intCast(size))) {
        _ = CloseHandle(h);
        var old_path_buf: [516]u8 = undefined;
        const old_path = std.fmt.bufPrint(&old_path_buf, "{s}.old", .{path}) catch return null;
        var wide_buf: [520]u16 = undefined;
        var old_wide_buf: [520]u16 = undefined;
        const wide = win32WidePath(&wide_buf, path) orelse return null;
        const old_wide = win32WidePath(&old_wide_buf, old_path) orelse return null;
        _ = MoveFileExW(wide.ptr, old_wide.ptr, MOVEFILE_REPLACE_EXISTING);
        return win32OpenAppend(path);
    }
    return h;
}

pub fn writeAuditHeader(h: HANDLE, reason: []const u8, count: u32) void {
    win32WriteAll(h, "\n");
    writeAuditTimestamp(h);
    win32WriteAll(h, " reason=");
    writeAuditEscapedBytes(h, reason);
    win32WriteAll(h, " instance=");
    writeAuditEscapedBytes(h, getInstanceName());
    win32WriteAll(h, " count=");
    writeAuditU64(h, count);
    win32WriteAll(h, " active=");
    writeAuditU64(h, app_state.active_shell);
    win32WriteAll(h, "\n");
}

pub fn logSessionAuditAlways(reason: []const u8) void {
    const h = openSessionAudit() orelse return;
    defer _ = CloseHandle(h);
    writeAuditHeader(h, reason, app_state.shell_count);
}

pub fn logSessionAudit(reason: []const u8) void {
    if (!verboseLoggingEnabled()) return;
    const h = openSessionAudit() orelse return;
    defer _ = CloseHandle(h);

    writeAuditHeader(h, reason, app_state.shell_count);
    const kind_names = [_][]const u8{ "cmd", "pwsh", "vps", "tmux", "vps2", "bash", "gitbash" };
    for (0..app_state.shell_count) |i| {
        const shell = app_state.shells[i];
        win32WriteAll(h, "  tab=");
        writeAuditU64(h, i);
        win32WriteAll(h, " kind=");
        writeAuditEscapedBytes(h, kind_names[@intFromEnum(shell.kind)]);
        win32WriteAll(h, " host=");
        if (remoteHostForShell(&shell)) |host| {
            win32WriteAll(h, tmuxHostLongLabel(host));
        } else {
            win32WriteAll(h, "-");
        }
        win32WriteAll(h, " pid=");
        writeAuditU64(h, shell.pid);
        win32WriteAll(h, " shell_id=");
        writeAuditU64(h, shell.shell_id);
        win32WriteAll(h, " keep_alive=");
        win32WriteAll(h, if (shell.keep_alive) "1" else "0");
        win32WriteAll(h, " muted=");
        win32WriteAll(h, if (shell.muted) "1" else "0");
        win32WriteAll(h, " name=\"");
        writeAuditEscapedWideAscii(h, shell.name[0..shell.name_len]);
        win32WriteAll(h, "\" tmux=\"");
        writeAuditEscapedBytes(h, shell.tmux_session[0..shell.tmux_session_len]);
        win32WriteAll(h, "\" cwd=\"");
        writeAuditEscapedBytes(h, shell.cached_cwd[0..shell.cached_cwd_len]);
        win32WriteAll(h, "\"\n");
    }
}

pub fn appendDecimal(buf: []u8, pos: *usize, value: u64) void {
    var n = value;
    var num: [20]u8 = undefined;
    var ni: usize = 0;
    if (n == 0) {
        num[ni] = '0';
        ni += 1;
    } else {
        while (n > 0 and ni < num.len) {
            num[ni] = @intCast('0' + (n % 10));
            ni += 1;
            n /= 10;
        }
    }
    while (ni > 0) {
        ni -= 1;
        buf[pos.*] = num[ni];
        pos.* += 1;
    }
}

pub fn logSlowMs(label: []const u8, start_tick: u64) void {
    if (!verboseLoggingEnabled()) return;
    const now = GetTickCount64();
    const elapsed = now - start_tick;
    if (elapsed < 5) return;
    var buf: [128]u8 = undefined;
    var pos: usize = 0;
    const tag = "PERF[t=";
    @memcpy(buf[0..tag.len], tag);
    pos = tag.len;
    appendDecimal(&buf, &pos, now);
    const sep = "ms]: ";
    @memcpy(buf[pos .. pos + sep.len], sep);
    pos += sep.len;
    const lcap = @min(label.len, 40);
    @memcpy(buf[pos .. pos + lcap], label[0..lcap]);
    pos += lcap;
    buf[pos] = ' ';
    pos += 1;
    appendDecimal(&buf, &pos, elapsed);
    buf[pos] = 'm';
    pos += 1;
    buf[pos] = 's';
    pos += 1;
    debugLog(buf[0..pos]);
}
pub fn logPollShellEnter() void {
    if (!verboseLoggingEnabled()) return;
    app_state.g_pollshell_count += 1;
    var buf: [128]u8 = undefined;
    var pos: usize = 0;
    const tag = "POLL[t=";
    @memcpy(buf[0..tag.len], tag);
    pos = tag.len;
    appendDecimal(&buf, &pos, GetTickCount64());
    const sep = "ms,#";
    @memcpy(buf[pos .. pos + sep.len], sep);
    pos += sep.len;
    appendDecimal(&buf, &pos, app_state.g_pollshell_count);
    buf[pos] = ']';
    pos += 1;
    debugLog(buf[0..pos]);
}
