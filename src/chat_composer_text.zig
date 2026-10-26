const std = @import("std");
const w = @import("win32.zig");
const dwrite = @import("dwrite_text.zig");
const L = std.unicode.utf8ToUtf16LeStringLiteral;

extern "user32" fn HideCaret(w.HANDLE) callconv(w.WINAPI) w.BOOL;
extern "user32" fn ShowCaret(w.HANDLE) callconv(w.WINAPI) w.BOOL;

pub threadlocal var native_paint = false;

pub fn enabled() bool {
    var value: [8]u16 = undefined;
    return !(w.GetEnvironmentVariableW(L("IGSH_731"), &value, value.len) == 1 and value[0] == '0');
}

fn position(hwnd: w.HANDLE, index: usize) ?w.POINT {
    const coordinates: u32 = @truncate(@as(usize, @bitCast(w.SendMessageW(hwnd, 0x00D6, index, 0))));
    if (coordinates == 0xffffffff) return null;
    return .{ .x = @as(i16, @bitCast(@as(u16, @truncate(coordinates)))), .y = @as(i16, @bitCast(@as(u16, @truncate(coordinates >> 16)))) };
}

pub fn paint(hwnd: w.HANDLE, dc: w.HANDLE, foreground: u32, background: u32) bool {
    const length: usize = @intCast(@max(0, w.GetWindowTextLengthW(hwnd)));
    if (length == 0) return true;
    const allocator = std.heap.page_allocator;
    const text = allocator.alloc(u16, length + 1) catch return false;
    defer allocator.free(text);
    const n: usize = @intCast(@max(0, w.GetWindowTextW(hwnd, text.ptr, @intCast(text.len))));
    const advances = allocator.alloc(f32, n) catch return false;
    defer allocator.free(advances);
    var clip: w.RECT = undefined;
    _ = w.SendMessageW(hwnd, 0x00B2, 0, @bitCast(@intFromPtr(&clip)));
    var client: w.RECT = undefined;
    if (w.GetClientRect(hwnd, &client) == 0) return false;
    clip.left = @max(clip.left, client.left);
    clip.top = @max(clip.top, client.top);
    clip.right = @min(clip.right, client.right);
    clip.bottom = @min(clip.bottom, client.bottom);
    if (clip.right <= clip.left or clip.bottom <= clip.top) return true;
    const saved = w.SaveDC(dc);
    if (saved == 0) return false;
    defer _ = w.RestoreDC(dc, saved);
    _ = w.IntersectClipRect(dc, clip.left, clip.top, clip.right, clip.bottom);
    const font: w.HANDLE = @ptrFromInt(@as(usize, @bitCast(w.SendMessageW(hwnd, 0x0031, 0, 0))));
    _ = w.SelectObject(dc, font);
    var metric: w.SIZE = undefined;
    if (w.GetTextExtentPoint32W(dc, L("M"), 1, &metric) == 0) return false;
    var start: u32 = 0;
    var end: u32 = 0;
    _ = w.SendMessageW(hwnd, 0x00B0, @intFromPtr(&start), @bitCast(@intFromPtr(&end)));
    const selected = w.GetFocus() == hwnd or w.GetWindowLongPtrW(hwnd, -16) & 0x0100 != 0;
    const brush = w.CreateSolidBrush(background) orelse return false;
    defer _ = w.DeleteObject(brush);
    const selection_brush = w.CreateSolidBrush(w.GetSysColor(13)) orelse return false;
    defer _ = w.DeleteObject(selection_brush);
    const hidden = HideCaret(hwnd) != 0;
    defer if (hidden) {
        _ = ShowCaret(hwnd);
    };
    _ = w.FillRect(dc, &clip, brush);
    const first_line = w.SendMessageW(hwnd, 0x00CE, 0, 0);
    const first = w.SendMessageW(hwnd, 0x00BB, @intCast(@max(0, first_line)), 0);
    var i: usize = @intCast(@max(0, first));
    while (i < n) {
        const origin = position(hwnd, i) orelse break;
        if (origin.y >= clip.bottom) break;
        const begin = i;
        var right = origin.x;
        while (i < n) {
            const point = position(hwnd, i) orelse break;
            if (point.y != origin.y) break;
            const units: usize = if (text[i] >= 0xd800 and text[i] <= 0xdbff and i + 1 < n and text[i + 1] >= 0xdc00 and text[i + 1] <= 0xdfff) 2 else 1;
            const next = position(hwnd, i + units);
            var size: w.SIZE = undefined;
            if (w.GetTextExtentPoint32W(dc, text[i..].ptr, @intCast(units), &size) == 0) return false;
            right = if (next != null and next.?.y == point.y) next.?.x else point.x + size.cx;
            advances[i] = @floatFromInt(right - point.x);
            if (units == 2) advances[i + 1] = 0;
            if (text[i] == '\r' or text[i] == '\n' or text[i] == '\t') break;
            i += units;
        }
        if (origin.y + metric.cy > clip.top and @max(right, origin.x) > clip.left and @min(origin.x, right) < clip.right) {
            if (i > begin and !dwrite.drawPositioned(dc, text[begin..i], advances[begin..i], origin.x, origin.y, clip, foreground)) return false;
            var cursor: usize = 0;
            while (@import("chat_skill.zig").next(text[0..n], cursor)) |skill| {
                cursor = skill.end;
                const lo = @max(begin, skill.start);
                const hi = @min(i, skill.end);
                if (hi <= lo) continue;
                const left = position(hwnd, lo) orelse continue;
                const after = position(hwnd, hi);
                const edge = if (after != null and after.?.y == origin.y) after.?.x else right;
                const rect = w.RECT{ .left = left.x, .top = origin.y, .right = edge, .bottom = origin.y + metric.cy };
                const accent = @import("chat_skill.zig").paint(dc, rect, background);
                if (!dwrite.drawPositioned(dc, text[lo..hi], advances[lo..hi], left.x, origin.y, clip, accent)) return false;
            }
            if (selected and end > begin and start < i + @as(usize, @intFromBool(i < n and text[i] == '\t'))) {
                const selected_start: usize = @max(start, begin);
                const selected_end: usize = @min(end, i + @as(usize, @intFromBool(i < n and text[i] == '\t')));
                const left_point = position(hwnd, selected_start) orelse origin;
                const end_point = position(hwnd, selected_end);
                const selection_right = if (end_point != null and end_point.?.y == origin.y) end_point.?.x else right;
                const rect = w.RECT{ .left = @max(clip.left, @min(left_point.x, selection_right)), .top = @max(clip.top, origin.y), .right = @min(clip.right, @max(left_point.x, selection_right)), .bottom = @min(clip.bottom, origin.y + metric.cy) };
                _ = w.FillRect(dc, &rect, selection_brush);
                if (i > begin and !dwrite.drawPositioned(dc, text[begin..i], advances[begin..i], origin.x, origin.y, rect, w.GetSysColor(14))) return false;
            }
        }
        if (i == begin or (i < n and (text[i] == '\r' or text[i] == '\n' or text[i] == '\t'))) i += 1;
    }
    return true;
}

pub fn suspendNativePaint(hwnd: w.HANDLE, msg: u32) bool {
    if (!enabled() or !repaintsAfter(msg) or w.GetWindowLongPtrW(hwnd, -16) & w.WS_VISIBLE == 0) return false;
    _ = w.SendMessageW(hwnd, 0x000B, 0, 0);
    return true;
}

pub fn resumeNativePaint(hwnd: w.HANDLE, msg: u32, redraw: bool) void {
    if (redraw) _ = w.SendMessageW(hwnd, 0x000B, 1, 0);
    invalidateAfter(hwnd, msg);
}

pub fn invalidateAfter(hwnd: w.HANDLE, msg: u32) void {
    if (enabled() and repaintsAfter(msg)) _ = w.InvalidateRect(hwnd, null, 0);
}

fn repaintsAfter(msg: u32) bool {
    return switch (msg) {
        0x0005,
        0x0007,
        0x0008,
        0x000C,
        0x0030,
        0x00B1,
        0x00B3,
        0x00B4,
        0x00B6,
        0x00B7,
        0x00C2,
        0x00C7,
        0x00CB,
        0x0100...0x0102,
        0x010D...0x010F,
        0x0113,
        0x0114,
        0x0115,
        0x0200...0x0203,
        0x020A,
        0x0286,
        0x0300...0x0304,
        => true,
        else => false,
    };
}

test "IGSH-731 switch defaults on and only zero restores native EDIT" {
    var previous: [32768]u16 = undefined;
    const length = w.GetEnvironmentVariableW(L("IGSH_731"), &previous, previous.len);
    defer _ = w.SetEnvironmentVariableW(L("IGSH_731"), if (length > 0 and length < previous.len) @ptrCast(&previous) else null);
    try std.testing.expect(w.SetEnvironmentVariableW(L("IGSH_731"), null) != 0);
    try std.testing.expect(enabled());
    for ([_][:0]const u16{ L("0"), L("1"), L("00"), L("false"), L("off"), L(" 0"), L("0 ") }) |value| {
        try std.testing.expect(w.SetEnvironmentVariableW(L("IGSH_731"), value.ptr) != 0);
        try std.testing.expectEqual(!std.mem.eql(u16, value, L("0")), enabled());
    }
}

test {
    _ = @import("chat_composer_text_proof.zig");
}
