const std = @import("std");
const win = @import("win32.zig");
const W = std.unicode.utf8ToUtf16LeStringLiteral;

const StartupInput = extern struct {
    version: u32 = 1,
    debug_callback: ?*anyopaque = null,
    suppress_thread: i32 = 0,
    suppress_codecs: i32 = 0,
};
const Stream = extern struct {
    vtable: *const extern struct {
        query_interface: usize,
        add_ref: usize,
        release: *const fn (*Stream) callconv(.winapi) u32,
        read: usize,
        write: usize,
        seek: *const fn (*Stream, i64, u32, *u64) callconv(.winapi) i32,
    },
};
extern "user32" fn PrintWindow(win.HANDLE, win.HANDLE, u32) callconv(.winapi) i32;
extern "gdiplus" fn GdiplusStartup(*usize, *const StartupInput, ?*anyopaque) callconv(.winapi) i32;
extern "gdiplus" fn GdiplusShutdown(usize) callconv(.winapi) void;
extern "gdiplus" fn GdipCreateBitmapFromHBITMAP(win.HANDLE, win.HANDLE, *win.HANDLE) callconv(.winapi) i32;
extern "gdiplus" fn GdipDisposeImage(win.HANDLE) callconv(.winapi) i32;
extern "gdiplus" fn GdipSaveImageToStream(win.HANDLE, *Stream, *const win.GUID, ?*anyopaque) callconv(.winapi) i32;
extern "ole32" fn CreateStreamOnHGlobal(win.HANDLE, i32, *?*Stream) callconv(.winapi) i32;
extern "ole32" fn GetHGlobalFromStream(*Stream, *win.HANDLE) callconv(.winapi) i32;
extern "kernel32" fn GlobalLock(win.HANDLE) callconv(.winapi) ?[*]const u8;
extern "kernel32" fn GlobalUnlock(win.HANDLE) callconv(.winapi) i32;

const PaneSearch = struct { window_id: usize, owner_pid: u32, hwnd: win.HANDLE = null, ambiguous: bool = false };

fn findPane(hwnd: win.HANDLE, param: win.LPARAM) callconv(.winapi) win.BOOL {
    const search: *PaneSearch = @ptrFromInt(@as(usize, @bitCast(param)));
    if (@intFromPtr(win.GetPropW(hwnd, W("ZigShellBrowserWindowId"))) != search.window_id) return 1;
    const owner = win.GetPropW(hwnd, W("ZigShellPaneOwner"));
    if (owner == null or win.IsWindow(owner) == 0) return 1;
    var pid: u32 = 0;
    _ = win.GetWindowThreadProcessId(owner, &pid);
    if (pid != search.owner_pid) return 1;
    if (search.hwnd != null) search.ambiguous = true;
    search.hwnd = hwnd;
    return 1;
}

pub fn capture(allocator: std.mem.Allocator, window_id: i64, owner_pid: i64) ![]u8 {
    if (window_id <= 0 or owner_pid <= 0 or owner_pid > std.math.maxInt(u32)) return error.InvalidPaneIdentity;
    var search = PaneSearch{ .window_id = @intCast(window_id), .owner_pid = @intCast(owner_pid) };
    _ = win.EnumWindows(findPane, @bitCast(@intFromPtr(&search)));
    if (search.hwnd == null or search.ambiguous) return error.HostedPaneNotFound;
    const hwnd = search.hwnd;
    if (win.IsWindowVisible(hwnd) == 0 or win.IsIconic(hwnd) != 0) return error.HostedPaneNotVisible;
    var rect: win.RECT = undefined;
    if (win.GetWindowRect(hwnd, &rect) == 0) return error.NativeCaptureFailed;
    const width = rect.right - rect.left;
    const height = rect.bottom - rect.top;
    if (width <= 0 or height <= 0 or width > 8192 or height > 8192) return error.InvalidPaneSize;
    const dc = win.GetDC(hwnd);
    if (dc == null) return error.NativeCaptureFailed;
    defer _ = win.ReleaseDC(hwnd, dc);
    const memory_dc = win.CreateCompatibleDC(dc);
    if (memory_dc == null) return error.NativeCaptureFailed;
    defer _ = win.DeleteDC(memory_dc);
    const bitmap = win.CreateCompatibleBitmap(dc, width, height);
    if (bitmap == null) return error.NativeCaptureFailed;
    defer _ = win.DeleteObject(bitmap);
    const previous = win.SelectObject(memory_dc, bitmap);
    const printed = PrintWindow(hwnd, memory_dc, 2);
    const copied = printed != 0 or win.BitBlt(memory_dc, 0, 0, width, height, dc, 0, 0, win.GDI_SRCCOPY) != 0;
    _ = win.SelectObject(memory_dc, previous);
    if (!copied) return error.NativeCaptureFailed;
    return encodePng(allocator, bitmap);
}

fn encodePng(allocator: std.mem.Allocator, bitmap: win.HANDLE) ![]u8 {
    var token: usize = 0;
    if (GdiplusStartup(&token, &.{}, null) != 0) return error.NativePngFailed;
    defer GdiplusShutdown(token);
    var image: win.HANDLE = null;
    if (GdipCreateBitmapFromHBITMAP(bitmap, null, &image) != 0) return error.NativePngFailed;
    defer _ = GdipDisposeImage(image);
    var stream_opt: ?*Stream = null;
    if (CreateStreamOnHGlobal(null, 1, &stream_opt) < 0) return error.NativePngFailed;
    const stream = stream_opt orelse return error.NativePngFailed;
    defer _ = stream.vtable.release(stream);
    const encoder = win.GUID{ .Data1 = 0x557cf406, .Data2 = 0x1a04, .Data3 = 0x11d3, .Data4 = .{ 0x9a, 0x73, 0x00, 0x00, 0xf8, 0x1e, 0xf3, 0x2e } };
    if (GdipSaveImageToStream(image, stream, &encoder, null) != 0) return error.NativePngFailed;
    var length: u64 = 0;
    if (stream.vtable.seek(stream, 0, 2, &length) < 0 or length == 0 or length > 700 * 1024) return error.NativePngTooLarge;
    var global: win.HANDLE = null;
    if (GetHGlobalFromStream(stream, &global) < 0) return error.NativePngFailed;
    const bytes = GlobalLock(global) orelse return error.NativePngFailed;
    defer _ = GlobalUnlock(global);
    return allocator.dupe(u8, bytes[0..@intCast(length)]);
}

test "native capture rejects invalid and unhosted identities" {
    try std.testing.expectError(error.InvalidPaneIdentity, capture(std.testing.allocator, 0, 1));
    try std.testing.expectError(error.InvalidPaneIdentity, capture(std.testing.allocator, 1, 0));
    try std.testing.expectError(error.InvalidPaneIdentity, capture(std.testing.allocator, 1, 0x100000000));
    try std.testing.expectError(error.HostedPaneNotFound, capture(std.testing.allocator, std.math.maxInt(i64), win.GetCurrentProcessId()));
}

test "native capture encodes only the exact visible hosted pane without changing foreground" {
    const owner = win.CreateWindowExW(win.WS_EX_NOACTIVATE, W("STATIC"), W("Owner fixture"), win.WS_POPUP, 0, 0, 160, 100, null, null, null, null);
    try std.testing.expect(owner != null);
    defer _ = win.DestroyWindow(owner);
    const pane = win.CreateWindowExW(win.WS_EX_NOACTIVATE, W("STATIC"), W("Pane fixture"), win.WS_POPUP | win.WS_VISIBLE, 0, 0, 160, 100, owner, null, null, null);
    try std.testing.expect(pane != null);
    defer _ = win.DestroyWindow(pane);
    const window_id: i64 = 0x12345678;
    try std.testing.expect(win.SetPropW(pane, W("ZigShellPaneOwner"), owner) != 0);
    try std.testing.expect(win.SetPropW(pane, W("ZigShellBrowserWindowId"), @ptrFromInt(window_id)) != 0);
    const pid = win.GetCurrentProcessId();
    const foreground = win.GetForegroundWindow();
    var before: win.RECT = undefined;
    try std.testing.expect(win.GetWindowRect(pane, &before) != 0);
    const png = try capture(std.testing.allocator, window_id, pid);
    defer std.testing.allocator.free(png);
    try std.testing.expect(png.len > 24);
    try std.testing.expectEqualSlices(u8, "\x89PNG\r\n\x1a\n", png[0..8]);
    try std.testing.expectEqual(@as(u32, 160), std.mem.readInt(u32, png[16..20], .big));
    try std.testing.expectEqual(@as(u32, 100), std.mem.readInt(u32, png[20..24], .big));
    try std.testing.expectEqual(foreground, win.GetForegroundWindow());
    try std.testing.expect(win.IsWindowVisible(pane) != 0);
    var after: win.RECT = undefined;
    try std.testing.expect(win.GetWindowRect(pane, &after) != 0);
    try std.testing.expectEqualDeep(before, after);
    try std.testing.expectError(error.HostedPaneNotFound, capture(std.testing.allocator, window_id + 1, pid));
    try std.testing.expectError(error.HostedPaneNotFound, capture(std.testing.allocator, window_id, @as(i64, pid) + 1));
    {
        const duplicate = win.CreateWindowExW(win.WS_EX_NOACTIVATE, W("STATIC"), W("Duplicate fixture"), win.WS_POPUP, 0, 0, 160, 100, owner, null, null, null);
        try std.testing.expect(duplicate != null);
        defer _ = win.DestroyWindow(duplicate);
        try std.testing.expect(win.SetPropW(duplicate, W("ZigShellPaneOwner"), owner) != 0);
        try std.testing.expect(win.SetPropW(duplicate, W("ZigShellBrowserWindowId"), @ptrFromInt(window_id)) != 0);
        try std.testing.expectError(error.HostedPaneNotFound, capture(std.testing.allocator, window_id, pid));
    }
    const hidden = win.CreateWindowExW(win.WS_EX_NOACTIVATE, W("STATIC"), W("Hidden fixture"), win.WS_POPUP, 0, 0, 160, 100, owner, null, null, null);
    try std.testing.expect(hidden != null);
    defer _ = win.DestroyWindow(hidden);
    try std.testing.expect(win.SetPropW(hidden, W("ZigShellPaneOwner"), owner) != 0);
    try std.testing.expect(win.SetPropW(hidden, W("ZigShellBrowserWindowId"), @ptrFromInt(window_id + 1)) != 0);
    try std.testing.expect(win.IsWindowVisible(hidden) == 0);
    try std.testing.expectError(error.HostedPaneNotVisible, capture(std.testing.allocator, window_id + 1, pid));
    try std.testing.expect(win.IsWindowVisible(hidden) == 0);
    try std.testing.expectEqual(foreground, win.GetForegroundWindow());
}
