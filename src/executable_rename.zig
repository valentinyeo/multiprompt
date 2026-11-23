const std = @import("std");
const win = @import("win32.zig");
const update = @import("update_check.zig");
const L = std.unicode.utf8ToUtf16LeStringLiteral;

extern "kernel32" fn CopyFileW(win.LPCWSTR, win.LPCWSTR, win.BOOL) callconv(.winapi) win.BOOL;
extern "kernel32" fn GetCommandLineW() callconv(.winapi) [*:0]const u16;

fn updaterProcess() win.HANDLE {
    const snapshot = win.CreateToolhelp32Snapshot(win.TH32CS_SNAPPROCESS, 0);
    if (snapshot == null or snapshot == win.INVALID_HANDLE_VALUE_PTR) return null;
    defer _ = win.CloseHandle(snapshot);
    var entry = std.mem.zeroes(win.PROCESSENTRY32W);
    entry.dwSize = @sizeOf(win.PROCESSENTRY32W);
    var more = win.Process32FirstW(snapshot, &entry);
    while (more != 0) : (more = win.Process32NextW(snapshot, &entry)) {
        if (entry.th32ProcessID == win.GetCurrentProcessId()) return win.OpenProcess(0x00100000, 0, entry.th32ParentProcessID);
    }
    return null;
}

pub fn redirect(args: []const []const u8, version: []const u8) bool {
    var source: [520:0]u16 = @splat(0);
    const length = win.GetModuleFileNameW(null, &source, source.len);
    if (length == 0 or length >= source.len) return false;
    const path = source[0..length];
    const start = (std.mem.lastIndexOfScalar(u16, path, '\\') orelse return false) + 1;
    const legacy = "multiprompt.exe";
    if (path.len - start != legacy.len) return false;
    for (path[start..], legacy) |wide, ascii| {
        if (wide > 127 or std.ascii.toLower(@intCast(wide)) != ascii) return false;
    }
    var target: [550:0]u16 = @splat(0);
    @memcpy(target[0..start], path[0..start]);
    const name = std.mem.span(L("multibot.exe"));
    @memcpy(target[start..][0..name.len], name);
    const target_len = start + name.len;
    var next: [580:0]u16 = @splat(0);
    @memcpy(next[0..target_len], target[0..target_len]);
    const next_suffix = std.mem.span(L(".rename-next.exe"));
    @memcpy(next[target_len..][0..next_suffix.len], next_suffix);
    var previous: [580:0]u16 = @splat(0);
    @memcpy(previous[0..target_len], target[0..target_len]);
    const previous_suffix = std.mem.span(L(".rename-previous.exe"));
    @memcpy(previous[target_len..][0..previous_suffix.len], previous_suffix);

    const mutex = win.CreateMutexW(null, 0, L("Local\\MultibotExecutableRename")) orelse return false;
    defer _ = win.CloseHandle(mutex);
    const locked = win.WaitForSingleObject(mutex, 15000);
    if (locked != 0 and locked != 0x80) return false;
    defer _ = win.ReleaseMutex(mutex);
    var installed_buf: [update.MAX_VERSION_LEN]u8 = undefined;
    const exists = update.statFile(&target) != null;
    const installed = update.scanFileForVersion(&target, &installed_buf);
    const replace = !exists or (installed != null and update.versionNewer(installed.?, version));
    var moved = false;
    if (replace) {
        if (CopyFileW(&source, &next, 0) == 0) return false;
        defer _ = win.DeleteFileW(&next);
        if (exists) {
            if (win.MoveFileExW(&target, &previous, 1 | 8) == 0) return false;
            moved = true;
        }
        if (win.MoveFileExW(&next, &target, 1 | 8) == 0) {
            if (moved) _ = win.MoveFileExW(&previous, &target, 1 | 8);
            return false;
        }
    } else if (installed == null) {
        return false;
    }
    var launched = false;
    defer if (!launched and replace) {
        _ = win.DeleteFileW(&target);
        if (moved) _ = win.MoveFileExW(&previous, &target, 1 | 8);
    };

    const allocator = std.heap.page_allocator;
    const original = std.mem.span(GetCommandLineW());
    var end: usize = 0;
    if (original.len > 0 and original[0] == '"') {
        end = (std.mem.indexOfScalarPos(u16, original, 1, '"') orelse return false) + 1;
    } else {
        while (end < original.len and original[end] != ' ' and original[end] != '\t') : (end += 1) {}
    }
    const tail = original[end..];
    const command = allocator.allocSentinel(u16, target_len + tail.len + 2, 0) catch return false;
    defer allocator.free(command);
    command[0] = '"';
    @memcpy(command[1..][0..target_len], target[0..target_len]);
    command[target_len + 1] = '"';
    @memcpy(command[target_len + 2 ..], tail);

    var ready: win.HANDLE = null;
    for (args, 0..) |arg, i| {
        if (std.mem.eql(u8, arg, "--update-ready") and i + 1 < args.len) {
            const event_name = std.unicode.utf8ToUtf16LeAllocZ(allocator, args[i + 1]) catch return false;
            defer allocator.free(event_name);
            ready = win.OpenEventW(0x00100000, 0, event_name.ptr) orelse return false;
            break;
        }
    }
    defer if (ready != null) {
        _ = win.CloseHandle(ready);
    };
    const parent = if (ready != null) updaterProcess() else null;
    defer if (parent != null) {
        _ = win.CloseHandle(parent);
    };
    if (ready != null and parent == null) return false;
    var startup = std.mem.zeroes(win.STARTUPINFOW);
    startup.cb = @sizeOf(win.STARTUPINFOW);
    var process = std.mem.zeroes(win.PROCESS_INFORMATION);
    if (win.CreateProcessW(&target, command.ptr, null, null, 0, 0, null, null, &startup, &process) == 0) return false;
    _ = win.CloseHandle(process.hThread);
    defer _ = win.CloseHandle(process.hProcess);
    if (ready != null) {
        const handles = [_]win.HANDLE{ process.hProcess, ready };
        if (win.WaitForMultipleObjects(handles.len, &handles, 0, 55000) != 1) {
            _ = win.TerminateProcess(process.hProcess, 1);
            _ = win.WaitForSingleObject(process.hProcess, 5000);
            return true;
        }
        const finishing = [_]win.HANDLE{ process.hProcess, parent };
        if (win.WaitForMultipleObjects(finishing.len, &finishing, 0, 10000) == 0) return true;
    }
    launched = true;
    return true;
}
