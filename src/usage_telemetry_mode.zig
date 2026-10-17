const std = @import("std");

pub const FLAG = "--usage-telemetry";
pub const MUTEX_NAME: [*:0]const u16 = std.unicode.utf8ToUtf16LeStringLiteral("Local\\MultipromptUsageTelemetry");
pub const STOP_EVENT_NAME: [*:0]const u16 = std.unicode.utf8ToUtf16LeStringLiteral("Local\\MultipromptUsageTelemetryStop");

pub fn isRequested(args: []const []const u8) bool {
    return args.len > 1 and std.mem.eql(u8, args[1], FLAG);
}

const win = struct {
    const HANDLE = ?*anyopaque;
    extern "kernel32" fn OpenMutexW(u32, i32, [*:0]const u16) callconv(.winapi) HANDLE;
    extern "kernel32" fn OpenEventW(u32, i32, [*:0]const u16) callconv(.winapi) HANDLE;
    extern "kernel32" fn SetEvent(HANDLE) callconv(.winapi) i32;
    extern "kernel32" fn WaitForSingleObject(HANDLE, u32) callconv(.winapi) u32;
    extern "kernel32" fn ReleaseMutex(HANDLE) callconv(.winapi) i32;
    extern "kernel32" fn CloseHandle(HANDLE) callconv(.winapi) i32;
};

pub fn isRunning() bool {
    const mutex = win.OpenMutexW(0x00100000, 0, MUTEX_NAME) orelse return false;
    _ = win.CloseHandle(mutex);
    return true;
}

pub fn stopForRelaunch() void {
    const mutex = win.OpenMutexW(0x00100001, 0, MUTEX_NAME) orelse return;
    defer _ = win.CloseHandle(mutex);
    if (win.OpenEventW(0x0002, 0, STOP_EVENT_NAME)) |event| {
        defer _ = win.CloseHandle(event);
        _ = win.SetEvent(event);
        const result = win.WaitForSingleObject(mutex, 0xFFFFFFFF);
        if (result == 0 or result == 0x80) _ = win.ReleaseMutex(mutex);
    }
}

test "collector dispatch requires an exact first argument" {
    try std.testing.expect(isRequested(&.{ "multiprompt.exe", "--usage-telemetry" }));
    try std.testing.expect(isRequested(&.{ "multiprompt-dev.exe", "--usage-telemetry", "--relaunch-after", "123" }));
    try std.testing.expect(!isRequested(&.{}));
    try std.testing.expect(!isRequested(&.{"multiprompt.exe"}));
    try std.testing.expect(!isRequested(&.{ "--usage-telemetry", "--name", "Work" }));
    try std.testing.expect(!isRequested(&.{ "multiprompt.exe", "--name", "--usage-telemetry" }));
    try std.testing.expect(!isRequested(&.{ "multiprompt.exe", "--notify", "--usage-telemetry" }));
    try std.testing.expect(!isRequested(&.{ "multiprompt.exe", "--usage-telemetry-other" }));
    try std.testing.expect(!isRequested(&.{ "multiprompt.exe", "--USAGE-TELEMETRY" }));
}

test "Windows quoting is decoded before collector dispatch" {
    var it = try std.process.Args.Iterator.Windows.init(std.testing.allocator, std.unicode.utf8ToUtf16LeStringLiteral("\"C:\\Program Files\\multiprompt.exe\" \"--usage-telemetry\""));
    defer it.deinit();
    const exe = it.next().?;
    const flag = it.next().?;
    try std.testing.expect(isRequested(&.{ exe, flag }));
}
