const std = @import("std");
const WINAPI: std.builtin.CallingConvention = .winapi;
const H = ?*anyopaque;
const W = [*:0]const u16;
const a = std.heap.page_allocator;
const cwd = std.Io.Dir.cwd;
const Startup = extern struct {
    cb: u32 = @sizeOf(Startup),
    reserved: ?[*:0]u16 = null,
    desktop: ?[*:0]u16 = null,
    title: ?[*:0]u16 = null,
    x: u32 = 0,
    y: u32 = 0,
    width: u32 = 0,
    height: u32 = 0,
    chars_x: u32 = 0,
    chars_y: u32 = 0,
    fill: u32 = 0,
    flags: u32 = 0,
    show: u16 = 0,
    reserved_size: u16 = 0,
    reserved_bytes: ?*u8 = null,
    stdin: H = null,
    stdout: H = null,
    stderr: H = null,
};
const Process = extern struct { process: H, thread: H, pid: u32, tid: u32 };
const LastInput = extern struct { size: u32 = @sizeOf(LastInput), tick: u32 = 0 };
const Keyboard = extern struct { vk: u16 = 0, scan: u16 = 0, flags: u32 = 0, time: u32 = 0, extra: usize = 0 };
const Input = extern struct {
    kind: u32 = 1,
    data: extern union {
        keyboard: Keyboard,
        mouse: extern struct { x: i32, y: i32, data: u32, flags: u32, time: u32, extra: usize },
    },
};
extern "kernel32" fn CompareStringOrdinal([*]const u16, i32, [*]const u16, i32, i32) callconv(WINAPI) i32;
extern "kernel32" fn GetEnvironmentVariableW(W, [*]u16, u32) callconv(WINAPI) u32;
extern "kernel32" fn GetEnvironmentStringsW() callconv(WINAPI) ?[*:0]u16;
extern "kernel32" fn FreeEnvironmentStringsW([*:0]u16) callconv(WINAPI) i32;
extern "kernel32" fn GetFullPathNameW(W, u32, [*]u16, ?*anyopaque) callconv(WINAPI) u32;
extern "kernel32" fn CreateProcessW(W, [*:0]u16, H, H, i32, u32, H, ?W, *Startup, *Process) callconv(WINAPI) i32;
extern "kernel32" fn GetLastError() callconv(WINAPI) u32;
extern "kernel32" fn GetCurrentProcessId() callconv(WINAPI) u32;
extern "kernel32" fn GetTickCount() callconv(WINAPI) u32;
extern "kernel32" fn GetTickCount64() callconv(WINAPI) u64;
extern "kernel32" fn Sleep(u32) callconv(WINAPI) void;
extern "kernel32" fn OpenProcess(u32, i32, u32) callconv(WINAPI) H;
extern "kernel32" fn CloseHandle(H) callconv(WINAPI) i32;
extern "kernel32" fn WaitForSingleObject(H, u32) callconv(WINAPI) u32;
extern "kernel32" fn TerminateProcess(H, u32) callconv(WINAPI) i32;
extern "kernel32" fn QueryFullProcessImageNameW(H, u32, [*]u16, *u32) callconv(WINAPI) i32;
extern "kernel32" fn GetProcessTimes(H, *u64, *u64, *u64, *u64) callconv(WINAPI) i32;
extern "kernel32" fn GetStdHandle(u32) callconv(WINAPI) H;
extern "kernel32" fn WriteFile(H, [*]const u8, u32, *u32, H) callconv(WINAPI) i32;
extern "kernel32" fn CreateFileW(W, u32, u32, H, u32, u32, H) callconv(WINAPI) H;
extern "user32" fn GetLastInputInfo(*LastInput) callconv(WINAPI) i32;
extern "user32" fn EnumWindows(*const fn (H, isize) callconv(WINAPI) i32, isize) callconv(WINAPI) i32;
extern "user32" fn GetWindowThreadProcessId(H, *u32) callconv(WINAPI) u32;
extern "user32" fn IsWindowVisible(H) callconv(WINAPI) i32;
extern "user32" fn GetWindowTextW(H, [*]u16, i32) callconv(WINAPI) i32;
extern "user32" fn GetForegroundWindow() callconv(WINAPI) H;
extern "user32" fn GetAncestor(H, u32) callconv(WINAPI) H;
extern "user32" fn SendInput(u32, [*]const Input, i32) callconv(WINAPI) u32;
extern "user32" fn PostMessageW(H, u32, usize, isize) callconv(WINAPI) i32;

const Point = extern struct { x: i32, y: i32 };
const Rect = extern struct { left: i32, top: i32, right: i32, bottom: i32 };
extern "user32" fn GetClientRect(H, *Rect) callconv(WINAPI) i32;
extern "user32" fn ClientToScreen(H, *Point) callconv(WINAPI) i32;
extern "user32" fn GetSystemMetrics(i32) callconv(WINAPI) i32;
extern "user32" fn WindowFromPoint(Point) callconv(WINAPI) H;
extern "user32" fn SetProcessDpiAwarenessContext(isize) callconv(WINAPI) i32;
extern "user32" fn OpenClipboard(H) callconv(WINAPI) i32;
extern "user32" fn CloseClipboard() callconv(WINAPI) i32;
extern "user32" fn GetClipboardData(u32) callconv(WINAPI) H;
extern "kernel32" fn GlobalLock(H) callconv(WINAPI) H;
extern "kernel32" fn GlobalUnlock(H) callconv(WINAPI) i32;
extern "kernel32" fn GlobalSize(H) callconv(WINAPI) usize;
extern "user32" fn GetDC(H) callconv(WINAPI) H;
extern "user32" fn ReleaseDC(H, H) callconv(WINAPI) i32;
extern "gdi32" fn BitBlt(H, i32, i32, i32, i32, H, i32, i32, u32) callconv(WINAPI) i32;
extern "gdi32" fn CreateCompatibleDC(H) callconv(WINAPI) H;
extern "gdi32" fn CreateCompatibleBitmap(H, i32, i32) callconv(WINAPI) H;
extern "gdi32" fn SelectObject(H, H) callconv(WINAPI) H;
extern "gdi32" fn DeleteObject(H) callconv(WINAPI) i32;
extern "gdi32" fn DeleteDC(H) callconv(WINAPI) i32;
const GdiStartup = extern struct { version: u32 = 1, callback: H = null, no_thread: i32 = 0, no_codecs: i32 = 0 };
const Guid = extern struct { a: u32, b: u16, c: u16, d: [8]u8 };
extern "gdiplus" fn GdiplusStartup(*usize, *const GdiStartup, H) callconv(WINAPI) i32;
extern "gdiplus" fn GdiplusShutdown(usize) callconv(WINAPI) void;
extern "gdiplus" fn GdipCreateBitmapFromHBITMAP(H, H, *H) callconv(WINAPI) i32;
extern "gdiplus" fn GdipSaveImageToFile(H, W, *const Guid, H) callconv(WINAPI) i32;
extern "gdiplus" fn GdipDisposeImage(H) callconv(WINAPI) i32;

pub const Decision = enum { send, refuse_foreground, refuse_active };

pub fn sendDecision(foreground_mine: bool, idle_ms: u64, min_idle_ms: u64, first: bool) Decision {
    if (!foreground_mine) return .refuse_foreground;
    if (first and idle_ms < min_idle_ms) return .refuse_active;
    return .send;
}

test "send decision checks foreground on every send and idle only before the first" {
    const expect = std.testing.expectEqual;
    try expect(Decision.refuse_foreground, sendDecision(false, 0, 300000, true));
    try expect(Decision.refuse_foreground, sendDecision(false, 400000, 300000, true));
    try expect(Decision.refuse_foreground, sendDecision(false, 0, 300000, false));
    try expect(Decision.refuse_foreground, sendDecision(false, 400000, 300000, false));
    try expect(Decision.refuse_active, sendDecision(true, 299999, 300000, true));
    try expect(Decision.send, sendDecision(true, 300000, 300000, true));
    try expect(Decision.send, sendDecision(true, 400000, 300000, true));
    try expect(Decision.send, sendDecision(true, 0, 300000, false));
}

const State = struct { pid: u32, hwnd: usize, folder: []const u8, exe: []const u8, created: u64 };

fn wide(text: []const u8) ![:0]u16 {
    return std.unicode.utf8ToUtf16LeAllocZ(a, text);
}

fn fmt(comptime format: []const u8, args: anytype) ![]const u8 {
    return std.fmt.allocPrint(a, format, args);
}

fn print(comptime format: []const u8, args: anytype) void {
    const text = fmt(format, args) catch return;
    defer a.free(text);
    var written: u32 = 0;
    _ = WriteFile(GetStdHandle(@bitCast(@as(i32, -11))), text.ptr, @intCast(text.len), &written, null);
}

fn env(name: W) ![]const u8 {
    var buf: [32768]u16 = undefined;
    const n = GetEnvironmentVariableW(name, &buf, buf.len);
    if (n == 0 or n >= buf.len) return error.MissingEnvironment;
    return std.unicode.utf16LeToUtf8Alloc(a, buf[0..n]);
}

fn fullPath(path: []const u8) ![]const u8 {
    var buf: [32768]u16 = undefined;
    const n = GetFullPathNameW(try wide(path), buf.len, &buf, null);
    if (n == 0 or n >= buf.len) return error.InvalidPath;
    return std.unicode.utf16LeToUtf8Alloc(a, buf[0..n]);
}

fn idleMs() !u64 {
    var last: LastInput = .{};
    if (GetLastInputInfo(&last) == 0) return error.IdleUnavailable;
    return GetTickCount() -% last.tick;
}

fn activeRefusal(idle: u64, minimum: u64) u8 {
    print("refused: user active, idle {d}s < {d}s\n", .{ idle / 1000, minimum / 1000 });
    return 3;
}

fn processCreated(h: H) !u64 {
    var created: u64 = 0;
    var exited: u64 = 0;
    var kernel: u64 = 0;
    var user: u64 = 0;
    if (GetProcessTimes(h, &created, &exited, &kernel, &user) == 0) return error.ProcessIdentityUnavailable;
    return created;
}

fn equalWide(left: []const u16, right: []const u16) bool {
    return CompareStringOrdinal(left.ptr, @intCast(left.len), right.ptr, @intCast(right.len), 1) == 2;
}

fn sameProcess(h: H, state: State) bool {
    if ((processCreated(h) catch return false) != state.created) return false;
    var buf: [32768]u16 = undefined;
    var n: u32 = buf.len;
    if (QueryFullProcessImageNameW(h, 0, &buf, &n) == 0) return false;
    const expected = wide(state.exe) catch return false;
    defer a.free(expected);
    return equalWide(buf[0..n], expected);
}

fn alive(state: State) bool {
    const h = OpenProcess(0x100000 | 0x1000, 0, state.pid) orelse return false;
    defer _ = CloseHandle(h);
    return WaitForSingleObject(h, 0) == 258 and sameProcess(h, state);
}

fn windowPid(hwnd: H) u32 {
    var pid: u32 = 0;
    _ = GetWindowThreadProcessId(hwnd, &pid);
    return pid;
}

fn foregroundMine(state: State) bool {
    const fg = GetForegroundWindow() orelse return false;
    const hwnd: H = @ptrFromInt(state.hwnd);
    return windowPid(hwnd) == state.pid and (windowPid(fg) == state.pid or GetAncestor(fg, 2) == hwnd);
}

const Search = struct { pid: u32, hwnd: H = null };
fn findWindow(hwnd: H, param: isize) callconv(WINAPI) i32 {
    const search: *Search = @ptrFromInt(@as(usize, @bitCast(param)));
    if (windowPid(hwnd) != search.pid or IsWindowVisible(hwnd) == 0) return 1;
    var title: [512]u16 = undefined;
    const n = GetWindowTextW(hwnd, &title, title.len);
    if (n < 11) return 1;
    const text = title[0..@intCast(n)];
    if (!std.mem.startsWith(u16, text, std.unicode.utf8ToUtf16LeStringLiteral("multiprompt")) and !std.mem.startsWith(u16, text, std.unicode.utf8ToUtf16LeStringLiteral("livetest - multiprompt"))) return 1;
    search.hwnd = hwnd;
    return 0;
}

fn load(io: std.Io, path: []const u8) !?State {
    const text = cwd().readFileAlloc(io, path, a, .limited(131072)) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    return (try std.json.parseFromSlice(State, a, text, .{ .allocate = .alloc_always })).value;
}

fn removeFolder(io: std.Io, folder: []const u8) !void {
    for (0..10) |_| {
        cwd().deleteTree(io, folder) catch {
            Sleep(500);
            continue;
        };
        return;
    }
    return error.FolderStillLocked;
}

fn environment(appdata: []const u8) ![]u16 {
    const block = GetEnvironmentStringsW() orelse return error.EnvironmentUnavailable;
    defer _ = FreeEnvironmentStringsW(block);
    var entries: std.ArrayList([]const u16) = .empty;
    var pos: usize = 0;
    while (block[pos] != 0) {
        const end = pos + std.mem.len(@as([*:0]u16, @ptrCast(block + pos)));
        const entry = block[pos..end];
        pos = end + 1;
        const name_end = std.mem.indexOfScalar(u16, entry, '=') orelse continue;
        const name = entry[0..name_end];
        if (equalWide(name, std.unicode.utf8ToUtf16LeStringLiteral("APPDATA")) or equalWide(name, std.unicode.utf8ToUtf16LeStringLiteral("MULTIPROMPT_NO_LOGIN"))) continue;
        try entries.append(a, entry);
    }
    try entries.append(a, try wide(try fmt("APPDATA={s}", .{appdata})));
    try entries.append(a, std.unicode.utf8ToUtf16LeStringLiteral("MULTIPROMPT_NO_LOGIN=1"));
    std.mem.sort([]const u16, entries.items, {}, struct {
        fn less(_: void, left: []const u16, right: []const u16) bool {
            return CompareStringOrdinal(left.ptr, @intCast(left.len), right.ptr, @intCast(right.len), 1) == 1;
        }
    }.less);
    var result: std.ArrayList(u16) = .empty;
    for (entries.items) |entry| {
        try result.appendSlice(a, entry);
        try result.append(a, 0);
    }
    try result.append(a, 0);
    return result.items;
}

fn start(io: std.Io, path: []const u8, exe_arg: ?[]const u8, session: ?[]const u8, minimum: u64, idle: u64) !u8 {
    if (idle < minimum) return activeRefusal(idle, minimum);
    if (try load(io, path)) |state| {
        if (alive(state)) {
            print("refused: test window is still alive\n", .{});
            return 4;
        }
        try removeFolder(io, state.folder);
    }
    const exe = try fullPath(exe_arg orelse try fmt("{s}\\Documents\\GitHub\\zigshell\\zig-out\\bin\\multiprompt.exe", .{try env(std.unicode.utf8ToUtf16LeStringLiteral("USERPROFILE"))}));
    const folder = try fmt("{s}\\mp-livetest-{d}-{d}", .{ try env(std.unicode.utf8ToUtf16LeStringLiteral("TEMP")), GetCurrentProcessId(), GetTickCount64() });
    const appdata = try fmt("{s}\\appdata", .{folder});
    try cwd().createDirPath(io, appdata);
    errdefer removeFolder(io, folder) catch {};
    if (session) |seed| {
        const settings = try fmt("{s}\\ZigShell", .{appdata});
        try cwd().createDirPath(io, settings);
        const data = try cwd().readFileAlloc(io, seed, a, .limited(131072));
        _ = try std.json.parseFromSlice(std.json.Value, a, data, .{});
        try cwd().writeFile(io, .{ .sub_path = try fmt("{s}\\session-livetest.json", .{settings}), .data = data });
    }
    const block = try environment(appdata);
    var startup: Startup = .{};
    var process: Process = undefined;
    if (CreateProcessW(try wide(exe), try wide(try fmt("\"{s}\" --name livetest", .{exe})), null, null, 0, 0x400, block.ptr, null, &startup, &process) == 0) return error.LaunchFailed;
    defer _ = CloseHandle(process.thread);
    defer _ = CloseHandle(process.process);
    errdefer {
        _ = TerminateProcess(process.process, 1);
        _ = WaitForSingleObject(process.process, 5000);
    }
    var search: Search = .{ .pid = process.pid };
    const deadline = GetTickCount64() + 90000;
    while (GetTickCount64() < deadline) {
        _ = EnumWindows(findWindow, @bitCast(@intFromPtr(&search)));
        if (search.hwnd != null) break;
        if (WaitForSingleObject(process.process, 0) != 258) break;
        Sleep(100);
    }
    if (search.hwnd == null) {
        _ = TerminateProcess(process.process, 1);
        _ = WaitForSingleObject(process.process, 5000);
        try removeFolder(io, folder);
        print("refused: no test window appeared\n", .{});
        return 5;
    }
    const state: State = .{ .pid = process.pid, .hwnd = @intFromPtr(search.hwnd), .folder = folder, .exe = exe, .created = try processCreated(process.process) };
    try cwd().writeFile(io, .{ .sub_path = path, .data = try std.json.Stringify.valueAlloc(a, state, .{}) });
    print("started pid={d} hwnd={x} appdata={s}\n", .{ state.pid, state.hwnd, appdata });
    return 0;
}

const Chord = struct { vk: u16, ctrl: bool = false, shift: bool = false };
fn chord(name: []const u8) !Chord {
    var key = name;
    var result: Chord = .{ .vk = 0 };
    if (std.mem.startsWith(u8, key, "ctrl+")) {
        result.ctrl = true;
        key = key[5..];
        if (std.mem.startsWith(u8, key, "shift+")) {
            result.shift = true;
            key = key[6..];
        }
        if (key.len != 1 or !std.ascii.isAlphabetic(key[0])) return error.InvalidKey;
        result.vk = std.ascii.toUpper(key[0]);
        return result;
    }
    const names = [_][]const u8{ "enter", "tab", "esc", "up", "down", "left", "right", "backspace" };
    const keys = [_]u16{ 13, 9, 27, 38, 40, 37, 39, 8 };
    for (names, keys) |n, k| {
        if (std.mem.eql(u8, key, n)) return .{ .vk = k };
    }
    if (key.len >= 2 and key[0] == 'f') {
        const n = std.fmt.parseInt(u16, key[1..], 10) catch return error.InvalidKey;
        if (n >= 1 and n <= 12) return .{ .vk = 0x70 + n - 1 };
    }
    return error.InvalidKey;
}

test "key names and modifier chords" {
    try std.testing.expectEqual(Chord{ .vk = 'A', .ctrl = true, .shift = true }, try chord("ctrl+shift+a"));
    try std.testing.expectEqual(@as(u16, 'Z'), (try chord("ctrl+z")).vk);
    try std.testing.expectEqual(@as(u16, 0x7b), (try chord("f12")).vk);
    try std.testing.expectEqual(@as(u16, 13), (try chord("enter")).vk);
    try std.testing.expectError(error.InvalidKey, chord("ctrl+enter"));
    try std.testing.expectError(error.InvalidKey, chord("f13"));
}

fn keyboard(vk: u16, scan: u16, flags: u32) Input {
    return .{ .data = .{ .keyboard = .{ .vk = vk, .scan = scan, .flags = flags } } };
}

fn send(state: State, inputs: []const Input, idle: u64, minimum: u64, first: bool) !u8 {
    switch (sendDecision(foregroundMine(state), idle, minimum, first)) {
        .refuse_foreground => {
            print("refused: foreground is not the test window\n", .{});
            return 3;
        },
        .refuse_active => return activeRefusal(idle, minimum),
        .send => {},
    }
    if (SendInput(@intCast(inputs.len), inputs.ptr, @sizeOf(Input)) != inputs.len) return error.SendFailed;
    return 0;
}

fn typeOrKey(state: State, text: []const u8, is_key: bool, minimum: u64, idle: u64) !u8 {
    if (!alive(state)) {
        print("refused: test pid is not alive\n", .{});
        return 4;
    }
    if (idle < minimum) return activeRefusal(idle, minimum);
    if (is_key) {
        const k = try chord(text);
        var inputs: std.ArrayList(Input) = .empty;
        if (k.ctrl) try inputs.append(a, keyboard(17, 0, 0));
        if (k.shift) try inputs.append(a, keyboard(16, 0, 0));
        const extended: u32 = if (k.vk >= 37 and k.vk <= 40) 1 else 0;
        try inputs.append(a, keyboard(k.vk, 0, extended));
        try inputs.append(a, keyboard(k.vk, 0, extended | 2));
        if (k.shift) try inputs.append(a, keyboard(16, 0, 2));
        if (k.ctrl) try inputs.append(a, keyboard(17, 0, 2));
        return send(state, inputs.items, idle, minimum, true);
    }
    const units = try wide(text);
    for (units, 0..) |unit, index| {
        const inputs = [_]Input{ keyboard(0, unit, 4), keyboard(0, unit, 4 | 2) };
        const code = try send(state, &inputs, idle, minimum, index == 0);
        if (code != 0) return code;
    }
    return 0;
}

fn clientRect(state: State) !Rect {
    if (!alive(state) or windowPid(@ptrFromInt(state.hwnd)) != state.pid) return error.ProcessIdentityMismatch;
    var rect: Rect = undefined;
    const hwnd: H = @ptrFromInt(state.hwnd);
    if (GetClientRect(hwnd, &rect) == 0) return error.RectUnavailable;
    var origin: Point = .{ .x = 0, .y = 0 };
    if (ClientToScreen(hwnd, &origin) == 0) return error.RectUnavailable;
    return .{ .left = origin.x, .top = origin.y, .right = origin.x + rect.right, .bottom = origin.y + rect.bottom };
}

fn screenPoint(rect: Rect, x: i32, y: i32) !Point {
    if (x < 0 or y < 0 or x >= rect.right - rect.left or y >= rect.bottom - rect.top) return error.PointOutsideClient;
    return .{ .x = rect.left + x, .y = rect.top + y };
}

fn absoluteAxis(value: i32, origin: i32, extent: i32) !i32 {
    const offset = @as(i64, value) - origin;
    if (extent <= 0 or offset < 0 or offset >= extent) return error.PointOutsideDesktop;
    return @intCast(@divTrunc(offset * 65536 + 32768, extent));
}

test "ISSUE-438 client coordinates and absolute mouse coordinates include negative monitor origins" {
    const rect: Rect = .{ .left = -1200, .top = 80, .right = -200, .bottom = 780 };
    try std.testing.expectEqual(Point{ .x = -1180, .y = 110 }, try screenPoint(rect, 20, 30));
    try std.testing.expectError(error.PointOutsideClient, screenPoint(rect, -1, 0));
    try std.testing.expectError(error.PointOutsideClient, screenPoint(rect, 1000, 0));
    try std.testing.expectError(error.PointOutsideClient, screenPoint(rect, 0, 700));
    try std.testing.expectEqual(@as(i32, 32776), try absoluteAxis(0, -1920, 3840));
    try std.testing.expectError(error.PointOutsideDesktop, absoluteAxis(-1921, -1920, 3840));
    try std.testing.expectError(error.PointOutsideDesktop, absoluteAxis(1920, -1920, 3840));
    try std.testing.expectError(error.PointOutsideDesktop, absoluteAxis(0, 0, 0));
}

test "ISSUE-438 mouse sends use the foreground and initial idle guard" {
    try std.testing.expectEqual(Decision.refuse_foreground, sendDecision(false, 60000, 60000, true));
    try std.testing.expectEqual(Decision.refuse_active, sendDecision(true, 59999, 60000, true));
    try std.testing.expectEqual(Decision.send, sendDecision(true, 60000, 60000, true));
    try std.testing.expectEqual(Decision.refuse_foreground, sendDecision(false, 0, 60000, false));
    try std.testing.expectEqual(Decision.send, sendDecision(true, 0, 60000, false));
}

fn mouseInput(point: Point, flags: u32) !Input {
    return .{ .kind = 0, .data = .{ .mouse = .{
        .x = try absoluteAxis(point.x, GetSystemMetrics(76), GetSystemMetrics(78)),
        .y = try absoluteAxis(point.y, GetSystemMetrics(77), GetSystemMetrics(79)),
        .data = 0,
        .flags = flags | 0x8000 | 0x4000 | 0x2000 | 1,
        .time = 0,
        .extra = 0,
    } } };
}

fn mouse(state: State, positions: []const []const u8, drag: bool, right: bool, steps: u32, minimum: u64, idle: u64) !u8 {
    const rect = try clientRect(state);
    const from = try screenPoint(rect, try std.fmt.parseInt(i32, positions[0], 10), try std.fmt.parseInt(i32, positions[1], 10));
    const to = if (drag) try screenPoint(rect, try std.fmt.parseInt(i32, positions[2], 10), try std.fmt.parseInt(i32, positions[3], 10)) else from;
    var inputs: std.ArrayList(Input) = .empty;
    defer inputs.deinit(a);
    try inputs.append(a, try mouseInput(from, 0));
    try inputs.append(a, try mouseInput(from, if (right) 8 else 2));
    if (drag) {
        for (1..steps + 2) |i| {
            const point: Point = .{
                .x = from.x + @as(i32, @intCast(@divTrunc((@as(i64, to.x) - from.x) * @as(i64, @intCast(i)), steps + 1))),
                .y = from.y + @as(i32, @intCast(@divTrunc((@as(i64, to.y) - from.y) * @as(i64, @intCast(i)), steps + 1))),
            };
            try inputs.append(a, try mouseInput(point, 0));
        }
    }
    try inputs.append(a, try mouseInput(to, if (right) 16 else 4));
    if (windowPid(WindowFromPoint(from)) != state.pid or windowPid(WindowFromPoint(to)) != state.pid) {
        print("refused: mouse point is not the test window\n", .{});
        return 3;
    }
    return send(state, inputs.items, idle, minimum, true);
}

fn clipboard() !u8 {
    if (OpenClipboard(null) == 0) return error.ClipboardUnavailable;
    defer _ = CloseClipboard();
    const handle = GetClipboardData(13) orelse return error.ClipboardTextUnavailable;
    const ptr: [*]const u16 = @ptrCast(@alignCast(GlobalLock(handle) orelse return error.ClipboardTextUnavailable));
    defer _ = GlobalUnlock(handle);
    const units = ptr[0 .. GlobalSize(handle) / 2];
    const end = std.mem.indexOfScalar(u16, units, 0) orelse return error.InvalidClipboardText;
    const text = try std.unicode.utf16LeToUtf8Alloc(a, units[0..end]);
    print("{s}\n", .{try std.json.Stringify.valueAlloc(a, text, .{})});
    return 0;
}

fn shot(state: State, path: []const u8) !u8 {
    const rect = try clientRect(state);
    const hwnd: H = @ptrFromInt(state.hwnd);
    const dc = GetDC(hwnd) orelse return error.CaptureDCFailed;
    defer _ = ReleaseDC(hwnd, dc);
    const memory = CreateCompatibleDC(dc) orelse return error.CaptureDCFailed;
    defer _ = DeleteDC(memory);
    const bitmap = CreateCompatibleBitmap(dc, rect.right - rect.left, rect.bottom - rect.top) orelse return error.CaptureBitmapFailed;
    defer _ = DeleteObject(bitmap);
    const previous = SelectObject(memory, bitmap);
    defer _ = SelectObject(memory, previous);
    if (BitBlt(memory, 0, 0, rect.right - rect.left, rect.bottom - rect.top, dc, 0, 0, 0x00cc0020) == 0) return error.CapturePrintFailed;
    var token: usize = 0;
    const startup: GdiStartup = .{};
    if (GdiplusStartup(&token, &startup, null) != 0) return error.CaptureStartupFailed;
    defer GdiplusShutdown(token);
    var image: H = null;
    if (GdipCreateBitmapFromHBITMAP(bitmap, null, &image) != 0) return error.CaptureBitmapFailed;
    defer _ = GdipDisposeImage(image);
    const png: Guid = .{ .a = 0x557cf406, .b = 0x1a04, .c = 0x11d3, .d = .{ 0x9a, 0x73, 0, 0, 0xf8, 0x1e, 0xf3, 0x2e } };
    if (GdipSaveImageToFile(image, try wide(path), &png, null) != 0) return error.CaptureSaveFailed;
    print("saved\n", .{});
    return 0;
}

fn stop(io: std.Io, path: []const u8, state: State) !u8 {
    const h = OpenProcess(0x100000 | 0x1000 | 1, 0, state.pid);
    defer if (h != null) {
        _ = CloseHandle(h);
    };
    if (h != null and WaitForSingleObject(h, 0) == 258) {
        if (!sameProcess(h, state)) return error.ProcessIdentityMismatch;
        if (windowPid(@ptrFromInt(state.hwnd)) == state.pid) _ = PostMessageW(@ptrFromInt(state.hwnd), 0x10, 0, 0);
        if (WaitForSingleObject(h, 20000) != 0) {
            if (!sameProcess(h, state)) return error.ProcessIdentityMismatch;
            if (TerminateProcess(h, 1) == 0 or WaitForSingleObject(h, 5000) != 0) return error.StopFailed;
        }
    } else if (h == null) {
        if (GetLastError() != 87) return error.StopFailed;
    }
    try removeFolder(io, state.folder);
    try cwd().deleteFile(io, path);
    print("stopped pid={d} folder_removed=1\n", .{state.pid});
    return 0;
}

fn run(init: std.process.Init) !u8 {
    _ = SetProcessDpiAwarenessContext(-4);
    const idle = try idleMs();
    const args = try init.minimal.args.toSlice(a);
    var state_path: ?[]const u8 = null;
    var exe: ?[]const u8 = null;
    var session: ?[]const u8 = null;
    var steps: u32 = 20;
    var right = false;
    var minimum: u64 = 300000;
    var positional: std.ArrayList([]const u8) = .empty;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (positional.items.len == 1 and (std.mem.eql(u8, positional.items[0], "type") or std.mem.eql(u8, positional.items[0], "key"))) {
            try positional.append(a, args[i]);
            continue;
        }
        if (std.mem.eql(u8, args[i], "--state") or std.mem.eql(u8, args[i], "--exe") or std.mem.eql(u8, args[i], "--idle-seconds") or std.mem.eql(u8, args[i], "--session") or std.mem.eql(u8, args[i], "--steps")) {
            if (i + 1 == args.len) return error.InvalidArguments;
            const option = args[i];
            i += 1;
            if (std.mem.eql(u8, option, "--state")) state_path = args[i] else if (std.mem.eql(u8, option, "--exe")) exe = args[i] else if (std.mem.eql(u8, option, "--session")) session = args[i] else if (std.mem.eql(u8, option, "--steps")) {
                steps = try std.fmt.parseInt(u32, args[i], 10);
                if (steps > 1000) return error.InvalidArguments;
            } else minimum = try std.math.mul(u64, try std.fmt.parseInt(u64, args[i], 10), 1000);
        } else if (std.mem.eql(u8, args[i], "--right")) {
            right = true;
        } else try positional.append(a, args[i]);
    }
    if (positional.items.len == 0) return error.InvalidArguments;
    const command = positional.items[0];
    const is_type = std.mem.eql(u8, command, "type");
    const is_key = std.mem.eql(u8, command, "key");
    const is_drag = std.mem.eql(u8, command, "drag");
    const is_click = std.mem.eql(u8, command, "click");
    const is_shot = std.mem.eql(u8, command, "shot");
    if (positional.items.len != @as(usize, if (is_drag) 5 else if (is_click) 3 else if (is_type or is_key or is_shot) 2 else 1)) return error.InvalidArguments;
    if (right and !is_click) return error.InvalidArguments;
    if (std.mem.eql(u8, command, "clipboard")) return clipboard();
    const path = try fullPath(state_path orelse try fmt("{s}\\mp-livetest\\state.txt", .{try env(std.unicode.utf8ToUtf16LeStringLiteral("LOCALAPPDATA"))}));
    if (std.fs.path.dirname(path)) |parent| try cwd().createDirPath(init.io, parent);
    const lock = CreateFileW(try wide(try fmt("{s}.lock", .{path})), 0x80000000 | 0x40000000, 0, null, 4, 0x80, null);
    if (lock == @as(H, @ptrFromInt(std.math.maxInt(usize)))) {
        print("refused: another test command is running\n", .{});
        return 4;
    }
    defer _ = CloseHandle(lock);
    if (std.mem.eql(u8, command, "start")) return start(init.io, path, exe, session, minimum, idle);
    const state = try load(init.io, path);
    if (std.mem.eql(u8, command, "status")) {
        const fg = GetForegroundWindow();
        print("pid={d} alive={d} hwnd={x} foreground_mine={d} idle_ms={d} fg_hwnd={x} fg_root={x} fg_pid={d}\n", .{ if (state) |s| s.pid else @as(u32, 0), @intFromBool(if (state) |s| alive(s) else false), if (state) |s| s.hwnd else @as(usize, 0), @intFromBool(if (state) |s| alive(s) and foregroundMine(s) else false), idle, @intFromPtr(fg), @intFromPtr(if (fg != null) GetAncestor(fg, 2) else null), if (fg != null) windowPid(fg) else @as(u32, 0) });
        return 0;
    }
    const s = state orelse {
        print("refused: test pid is not alive\n", .{});
        return 4;
    };
    if (is_type or is_key) return typeOrKey(s, positional.items[1], is_key, minimum, idle);
    if (is_drag or is_click) return mouse(s, positional.items[1..], is_drag, right, steps, minimum, idle);
    if (std.mem.eql(u8, command, "rect")) {
        print("{s}\n", .{try std.json.Stringify.valueAlloc(a, try clientRect(s), .{})});
        return 0;
    }
    if (is_shot) return shot(s, positional.items[1]);
    if (std.mem.eql(u8, command, "stop")) return stop(init.io, path, s);
    return error.InvalidArguments;
}

pub fn main(init: std.process.Init) void {
    const code = run(init) catch |err| {
        print("error: {s}\nusage: mp-livetest [--state path] start [--exe path] [--session json] [--idle-seconds N] | status | type text | key name | drag x1 y1 x2 y2 [--steps N] | click x y [--right] | clipboard | rect | shot path | stop (input commands accept --idle-seconds N)\n", .{@errorName(err)});
        std.process.exit(1);
    };
    std.process.exit(code);
}
